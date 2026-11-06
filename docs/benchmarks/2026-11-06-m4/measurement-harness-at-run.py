#!/usr/bin/env python3
"""Measure native SurfMeter processes on macOS without reading browsing content.

Runs installed observation plus isolated active/idle app+helper workloads together.
Writes numeric samples and a sanitized summary; temporary workloads are removed.
"""
from __future__ import annotations

import argparse
import csv
import ctypes
from contextlib import ExitStack
import hashlib
import json
import math
import os
from pathlib import Path
import plistlib
import select
import shutil
import signal
import sqlite3
import statistics
import struct
import subprocess
import sys
import tempfile
import time
import uuid
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ['user_time', 'system_time', 'pkg_idle_wkups', 'interrupt_wkups', 'pageins',
          'wired_size', 'resident_size', 'phys_footprint', 'proc_start_abstime',
          'proc_exit_abstime', 'child_user_time', 'child_system_time',
          'child_pkg_idle_wkups', 'child_interrupt_wkups', 'child_pageins',
          'child_elapsed_abstime', 'diskio_bytesread', 'diskio_byteswritten']


class Usage(ctypes.Structure):
    _fields_ = [('uuid', ctypes.c_uint8 * 16)] + [(field, ctypes.c_uint64) for field in FIELDS]


class Timebase(ctypes.Structure):
    _fields_ = [('numer', ctypes.c_uint32), ('denom', ctypes.c_uint32)]


class Counters:
    def __init__(self):
        self.lib = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
        self.lib.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
        self.lib.proc_pid_rusage.restype = ctypes.c_int
        self.clock = Timebase()
        ctypes.CDLL('/usr/lib/libSystem.B.dylib').mach_timebase_info(ctypes.byref(self.clock))
        assert ctypes.sizeof(Usage) == 160 and self.clock.denom > 0

    def read(self, pid):
        value = Usage()
        if self.lib.proc_pid_rusage(pid, 2, ctypes.byref(value)) != 0:
            raise ProcessLookupError(pid)
        return {
            'identity': (pid, value.proc_start_abstime),
            'cpu_seconds': (value.user_time + value.system_time) * self.clock.numer / self.clock.denom / 1e9,
            'rss_bytes': value.resident_size, 'footprint_bytes': value.phys_footprint,
            'read_bytes': value.diskio_bytesread, 'written_bytes': value.diskio_byteswritten,
            'idle_wakeups': value.pkg_idle_wkups,
        }


def ps_cpu_seconds(pid):
    value = subprocess.check_output(['ps', '-p', str(pid), '-o', 'time='], text=True).strip()
    days = 0
    if '-' in value:
        prefix, value = value.split('-', 1); days = int(prefix)
    pieces = [float(part) for part in value.split(':')]
    return days * 86400 + sum(part * 60**index for index, part in enumerate(reversed(pieces)))


def discover(executable):
    rows = subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True).splitlines()
    return [int(row.split(None, 1)[0]) for row in rows if len(row.split(None, 1)) == 2 and row.split(None, 1)[1] == str(executable)]


def storage(directory):
    paths = [path for path in directory.glob('activity.sqlite*') if path.is_file()]
    return {'logical_bytes': sum(path.stat().st_size for path in paths),
            'allocated_bytes': sum(path.stat().st_blocks * 512 for path in paths)}


def bundle_size(bundle):
    sizes = [path.stat() for path in bundle.rglob('*') if path.is_file()]
    return {'logical_bytes': sum(info.st_size for info in sizes),
            'allocated_bytes': sum(info.st_blocks * 512 for info in sizes)}


class Workload:
    def __init__(self, mode, directory, bundle):
        self.mode, self.directory = mode, directory
        self.sequence, self.session = 0, str(uuid.uuid4())
        self.app = self.host = None
        directory.mkdir(mode=0o700)
        helper = directory / 'SurfMeterNativeHost'
        shutil.copy2(bundle / 'Contents/Helpers/SurfMeterNativeHost', helper)
        self.origin = 'chrome-extension://' + 'a' * 32 + '/'
        (directory / 'host-config.json').write_text(json.dumps({'allowedOrigin': self.origin, 'bridgeDirectory': str(directory)}))
        try:
            self.app = subprocess.Popen([str(bundle / 'Contents/MacOS/SurfMeter'), '--bridge-directory', str(directory), '--simulate-chrome'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            deadline = time.monotonic() + 10
            while not (directory / 'bridge.sock').exists():
                if self.app.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('Isolated app did not start')
                time.sleep(.05)
            self.host = subprocess.Popen([str(helper), self.origin], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        except BaseException:
            self.close(); raise

    def send(self, elapsed):
        if self.app.poll() is not None or self.host.poll() is not None:
            raise RuntimeError('Isolated workload process exited')
        message = {'protocolVersion': 1, 'browser': 'chrome', 'sessionID': self.session,
                   'sequence': self.sequence, 'state': 'active' if self.mode == 'active' else 'unavailable'}
        if self.mode == 'active':
            fixtures = ['youtube.com', 'instagram.com', 'reddit.com', 'x.com', 'github.com']
            message['hostname'] = fixtures[int(elapsed // 60) % len(fixtures)]
        self.sequence += 1
        payload = json.dumps(message, separators=(',', ':')).encode()
        self.host.stdin.write(struct.pack('<I', len(payload)) + payload); self.host.stdin.flush()
        if not select.select([self.host.stdout], [], [], 5)[0]:
            raise RuntimeError('Isolated helper reply timed out')
        length = self.host.stdout.read(4)
        if len(length) != 4:
            raise RuntimeError('Isolated helper disconnected')
        reply = json.loads(self.host.stdout.read(struct.unpack('<I', length)[0]))
        if not reply.get('accepted'):
            raise RuntimeError('Isolated snapshot was rejected')

    def total(self):
        database = self.directory / 'Data/activity.sqlite'
        if not database.exists():
            return 0
        with sqlite3.connect('file:' + str(database) + '?mode=ro', uri=True) as connection:
            return connection.execute('SELECT COALESCE(SUM(ZSECONDS),0) FROM ZBUCKET').fetchone()[0]

    def close(self):
        for process in [self.host, self.app]:
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(timeout=5)


def percentile(values, p):
    values = sorted(values)
    index = (len(values) - 1) * p
    lo, hi = math.floor(index), math.ceil(index)
    return values[lo] + (values[hi] - values[lo]) * (index - lo)


def summarize(rows, duration):
    result = {}
    for group in sorted({row['group'] for row in rows}):
        selected = [row for row in rows if row['group'] == group]
        intervals = [row for row in selected if row['interval_seconds'] > 0]
        total_interval = sum(row['interval_seconds'] for row in intervals)
        result[group] = {
            'samples': len(selected), 'measured_seconds': total_interval,
            'cpu_mean_percent_one_core': sum(row['cpu_delta_seconds'] for row in intervals) / total_interval * 100,
            'cpu_p95_percent_one_core': percentile([row['cpu_percent'] for row in intervals], .95),
            'cpu_max_percent_one_core': max(row['cpu_percent'] for row in intervals),
            'rss_mean_bytes': statistics.mean(row['rss_bytes'] for row in selected),
            'rss_peak_sampled_bytes': max(row['rss_bytes'] for row in selected),
            'footprint_mean_bytes': statistics.mean(row['footprint_bytes'] for row in selected),
            'footprint_peak_sampled_bytes': max(row['footprint_bytes'] for row in selected),
            'kernel_read_bytes': sum(row['read_delta_bytes'] for row in intervals),
            'kernel_written_bytes': sum(row['written_delta_bytes'] for row in intervals),
            'idle_wakeups': sum(row['wakeups_delta'] for row in intervals),
            'process_count_min': min(row['process_count'] for row in selected),
            'process_count_max': max(row['process_count'] for row in selected),
            'cpu_mean_below_one_percent': sum(row['cpu_delta_seconds'] for row in intervals) / total_interval * 100 < 1,
            'sampled_rss_below_100_MB': max(row['rss_bytes'] for row in selected) < 100_000_000,
        }
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--duration', type=int, default=1800, help='measured seconds after warmup')
    parser.add_argument('--warmup', type=int, default=30)
    parser.add_argument('--interval', type=int, default=5)
    parser.add_argument('--app', type=Path, default=Path('/Applications/SurfMeter.app'))
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != 'darwin' or args.duration < 5 or args.interval < 1 or args.warmup < 0:
        parser.error('Use macOS, duration >= 5, interval >= 1, and warmup >= 0')
    executable = args.app / 'Contents/MacOS/SurfMeter'
    installed = discover(executable)
    if len(installed) != 1:
        parser.error('Exactly one installed app must already be running before measurement')
    installed_pid = installed[0]
    counters = Counters()
    reference = counters.read(installed_pid)
    ps_time = ps_cpu_seconds(installed_pid)
    if abs(reference['cpu_seconds'] - ps_time) > max(0.2, ps_time * .005):
        raise RuntimeError('CPU counter conversion did not match ps TIME; do not trust this run')
    args.output.mkdir(parents=True, exist_ok=False)
    helper_path = Path.home() / 'Library/Application Support/SurfMeter/NativeHost/SurfMeterNativeHost'
    real_data = Path.home() / 'Library/Application Support/SurfMeter/Data'
    metadata = {
        'schema_version': 1, 'source_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'app_version': plistlib.loads((args.app / 'Contents/Info.plist').read_bytes())['CFBundleShortVersionString'],
        'binary_sha256': hashlib.sha256(executable.read_bytes()).hexdigest(),
        'measurement_script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'hardware': {key: subprocess.check_output(['sysctl', '-n', key], text=True).strip() for key in ['hw.model', 'hw.memsize', 'hw.logicalcpu', 'machdep.cpu.brand_string']},
        'macos': subprocess.check_output(['sw_vers', '-productVersion'], text=True).strip(),
        'macos_build': subprocess.check_output(['sw_vers', '-buildVersion'], text=True).strip(),
        'duration_requested_seconds': args.duration, 'warmup_seconds': args.warmup, 'sample_interval_seconds': args.interval,
        'mach_timebase': {'numer': counters.clock.numer, 'denom': counters.clock.denom},
        'cpu_calibration_seconds': {'kernel_converted': reference['cpu_seconds'], 'ps_time': ps_time},
        'bundle_size': bundle_size(args.app),
        'units': {'cpu': 'percent of one logical core', 'memory': 'bytes', 'disk': 'kernel-counter bytes / file-size bytes'},
        'scope': 'native app and native messaging helper only; Chrome, extension worker, WindowServer, and observer excluded from app totals',
        'workload': 'user-directed normal Chrome use plus concurrent isolated 1 Hz active and unavailable snapshot workloads; five synthetic platforms, changed every 60 seconds; panels requested closed',
        'started_local': datetime.now(ZoneInfo('Asia/Colombo')).isoformat(),
        'wall_clock_discontinuities': 0, 'heartbeat_late_over_500ms': 0,
    }
    domain = plistlib.loads(subprocess.check_output(['defaults', 'export', 'dev.surfmeter.app', '-']))
    preferences = json.loads(domain.get('preferences', b'{}'))
    metadata['installed_collection'] = {key: preferences.get(key) for key in ['enabled', 'paused', 'retention']}
    rows, previous, process_events = [], {}, []
    csv_path = args.output / 'samples.csv'
    work = []
    def stop(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, stop)
    try:
        with ExitStack() as stack:
            temporary = stack.enter_context(tempfile.TemporaryDirectory(prefix='sm-perf-', dir='/private/tmp'))
            for mode in ['active', 'idle']:
                workload = Workload(mode, Path(temporary) / mode, args.app)
                work.append(workload); stack.callback(workload.close)
            origin = time.monotonic(); wall_origin = time.time()
            measured_start = origin + args.warmup
            end = measured_start + args.duration
            next_sample, next_tick, next_status = measured_start, origin, measured_start + 60
            first_sample = None
            baselines = None
            while True:
                now = time.monotonic()
                if now < next_tick:
                    time.sleep(min(next_tick, end) - now)
                    now = time.monotonic()
                if now - next_tick > .5:
                    metadata['heartbeat_late_over_500ms'] += 1
                for workload in work:
                    workload.send(now - origin)
                next_tick = max(next_tick + 1, time.monotonic())
                sample_now = time.monotonic()
                if sample_now >= next_sample or sample_now >= end:
                    if first_sample is None:
                        first_sample = sample_now
                        end = first_sample + args.duration
                        metadata['measurement_started_local'] = datetime.now(ZoneInfo('Asia/Colombo')).isoformat()
                        baselines = {'installed': storage(real_data), **{w.mode: storage(w.directory / 'Data') for w in work}}
                        metadata['synthetic_recorded_seconds_at_start'] = {w.mode: w.total() for w in work}
                    if abs((time.time() - wall_origin) - (sample_now - origin)) > 5:
                        metadata['wall_clock_discontinuities'] += 1
                    groups = {
                        'installed-app': [installed_pid], 'installed-helper': discover(helper_path),
                        'active-app': [work[0].app.pid], 'active-helper': [work[0].host.pid],
                        'idle-app': [work[1].app.pid], 'idle-helper': [work[1].host.pid],
                        'observer': [os.getpid()],
                    }
                    values = {group: [counters.read(pid) for pid in pids] for group, pids in groups.items()}
                    values['installed-native-total'] = values['installed-app'] + values['installed-helper']
                    values['active-native-total'] = values['active-app'] + values['active-helper']
                    values['idle-native-total'] = values['idle-app'] + values['idle-helper']
                    if values['installed-app'][0]['identity'] != reference['identity']:
                        raise RuntimeError('Installed app restarted; continuous run is invalid')
                    batch_start = len(rows)
                    for group, readings in values.items():
                        present = {reading['identity']: reading for reading in readings}
                        prior_time, prior = previous.get(group, (sample_now, {}))
                        interval = sample_now - prior_time
                        delta_cpu = delta_read = delta_write = delta_wakeups = 0
                        for identity, reading in present.items():
                            if identity in prior:
                                old = prior[identity]
                                delta_cpu += max(0, reading['cpu_seconds'] - old['cpu_seconds'])
                                delta_read += max(0, reading['read_bytes'] - old['read_bytes'])
                                delta_write += max(0, reading['written_bytes'] - old['written_bytes'])
                                delta_wakeups += max(0, reading['idle_wakeups'] - old['idle_wakeups'])
                        if prior and set(prior) != set(present):
                            process_events.append({'group': group, 'elapsed_seconds': sample_now - first_sample, 'event': 'process membership changed'})
                        row = {'elapsed_seconds': round(sample_now - first_sample, 6), 'group': group,
                               'interval_seconds': interval, 'cpu_delta_seconds': delta_cpu,
                               'cpu_percent': delta_cpu / interval * 100 if interval else 0,
                               'rss_bytes': sum(value['rss_bytes'] for value in readings),
                               'footprint_bytes': sum(value['footprint_bytes'] for value in readings),
                               'read_delta_bytes': delta_read, 'written_delta_bytes': delta_write,
                               'wakeups_delta': delta_wakeups, 'process_count': len(readings)}
                        rows.append(row); previous[group] = (sample_now, present)
                    with csv_path.open('a', newline='') as handle:
                        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
                        if handle.tell() == 0:
                            writer.writeheader()
                        writer.writerows(rows[batch_start:])
                    next_sample += args.interval
                    (args.output / 'progress.json').write_text(json.dumps({'elapsed_seconds': sample_now - first_sample, 'remaining_seconds': max(0, end - sample_now), 'groups': summarize(rows, sample_now - first_sample) if sample_now > first_sample else {}}, indent=2))
                    if sample_now >= next_status:
                        live = summarize(rows, sample_now - first_sample)['installed-native-total']
                        print(f"{int(sample_now-first_sample)}s: installed app+helper CPU {live['cpu_mean_percent_one_core']:.3f}% one core; peak sampled RSS {live['rss_peak_sampled_bytes']/1e6:.2f} MB", flush=True)
                        next_status += 60
                if sample_now >= end:
                    metadata['actual_measured_seconds'] = sample_now - first_sample
                    metadata['storage_start'] = baselines
                    metadata['storage_end'] = {'installed': storage(real_data), **{w.mode: storage(w.directory / 'Data') for w in work}}
                    metadata['synthetic_recorded_seconds_at_end'] = {w.mode: w.total() for w in work}
                    break
            metadata['completed_local'] = datetime.now(ZoneInfo('Asia/Colombo')).isoformat()
            metadata['process_events'] = process_events
            metadata['results'] = summarize(rows, metadata['actual_measured_seconds'])
            metadata['complete'] = True
    except BaseException:
        metadata['complete'] = False
        (args.output / 'summary.json').write_text(json.dumps(metadata, indent=2)+'\n')
        raise
    finally:
        for workload in work:
            workload.close()
    (args.output / 'summary.json').write_text(json.dumps(metadata, indent=2)+'\n')
    print('Completed resource measurement; sanitized samples and summary written.', flush=True)


if __name__ == '__main__':
    main()
