#!/usr/bin/env python3
"""Publish a completed numeric resource run, plots, and README/report summaries."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import statistics

ROOT = Path(__file__).resolve().parents[1]
GROUPS = {'installed-app', 'installed-helper', 'installed-native-total', 'active-app',
          'active-helper', 'active-native-total', 'idle-app', 'idle-helper',
          'idle-native-total', 'observer'}
SCENARIOS = [('installed', 'Installed · normal Chrome use'),
             ('active', 'Controlled active · synthetic'), ('idle', 'Controlled idle · unavailable')]
MARKER_START, MARKER_END = '<!-- resource-results:start -->', '<!-- resource-results:end -->'


def mb(value):
    return f'{value / 1_000_000:,.1f}'


def replace_section(path, content, before=None):
    text = path.read_text()
    if MARKER_START in text and MARKER_END in text:
        first, tail = text.split(MARKER_START, 1)
        _, last = tail.split(MARKER_END, 1)
        text = first + MARKER_START + '\n' + content.strip() + '\n' + MARKER_END + last
    elif before and before in text:
        text = text.replace(before, MARKER_START+'\n'+content.strip()+'\n'+MARKER_END+'\n\n'+before, 1)
    else:
        raise ValueError('Expected documentation section marker is missing')
    path.write_text(text)


def load_samples(path):
    values = []
    with path.open(newline='') as handle:
        for row in csv.DictReader(handle):
            if row['group'] not in GROUPS:
                raise ValueError('Unknown sample group; do not publish arbitrary text')
            value = {'group': row['group']}
            for key, item in row.items():
                if key == 'group':
                    continue
                number = float(item)
                if not math.isfinite(number) or number < 0:
                    raise ValueError('Invalid numeric sample')
                value[key] = number
            values.append(value)
    if not values:
        raise ValueError('No samples')
    return values


def plot(rows, destination):
    cache = ROOT / '.build/matplotlib-report-cache'
    cache.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault('MPLCONFIGDIR', str(cache))
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'font.size': 10, 'axes.titlesize': 12, 'axes.labelsize': 10,
                         'axes.spines.top': False, 'axes.spines.right': False,
                         'svg.fonttype': 'path', 'svg.hashsalt': 'surfmeter-resource-report-v1'})
    fig, axes = plt.subplots(2, 2, figsize=(12, 7.5), constrained_layout=True)
    colors = {'installed': '#326DF1', 'active': '#B46517', 'idle': '#68768A'}
    names = {'installed': 'Installed', 'active': 'Fresh active', 'idle': 'Fresh idle'}
    for scenario, _ in SCENARIOS:
        app = [r for r in rows if r['group'] == scenario+'-app']
        helper = [r for r in rows if r['group'] == scenario+'-helper']
        x = [r['elapsed_seconds'] / 60 for r in app]
        interval = [r for r in app if r['interval_seconds'] > 0]
        axes[0, 0].plot([r['elapsed_seconds']/60 for r in interval], [r['cpu_percent'] for r in interval], label=names[scenario], color=colors[scenario], linewidth=1.1)
        axes[0, 1].plot(x, [r['rss_bytes']/1e6 for r in app], color=colors[scenario], linewidth=1.5)
        axes[1, 0].plot(x, [r['footprint_bytes']/1e6 for r in helper], color=colors[scenario], linewidth=1.5)
        baseline = helper[0]['footprint_bytes']
        axes[1, 1].plot(x, [(r['footprint_bytes']-baseline)/1e6 for r in helper], color=colors[scenario], linewidth=1.5)
    axes[0, 0].axhline(1, color='#B3433E', linestyle='--', linewidth=1, label='1% app CPU goal')
    axes[0, 1].axhline(100, color='#B3433E', linestyle='--', linewidth=1)
    axes[0, 0].set(title='App CPU · five-second intervals', ylabel='% of one logical core')
    axes[0, 1].set(title='App resident memory · sampled RSS', ylabel='MB · 100 MB goal shown')
    axes[1, 0].set(title='Helper charged footprint · absolute', ylabel='MB')
    axes[1, 1].set(title='Helper footprint growth since first sample', ylabel='MB change')
    for axis in axes.flat:
        axis.set_xlabel('Measured minutes')
        axis.grid(axis='y', color='#DCE2EA', linewidth=.7)
        axis.set_axisbelow(True)
    axes[0, 0].legend(frameon=False, fontsize=9, loc='center right')
    fig.suptitle('SurfMeter · native development build resource measurements', fontsize=15, fontweight='bold')
    fig.savefig(destination/'resource-usage.png', dpi=200, metadata={'Software': 'Matplotlib'})
    fig.savefig(destination/'resource-usage.svg', metadata={'Date': None, 'Creator': 'Matplotlib'})
    plt.close(fig)
    return matplotlib.__version__


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('run', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--allow-short', action='store_true', help='smoke-report generation only')
    parser.add_argument('--no-plot', action='store_true', help='smoke-report generation only')
    parser.add_argument('--update-docs', action='store_true')
    parser.add_argument('--use-recovered-counter-run', action='store_true', help='explicitly publish a validated deadline-recovered counter window')
    args = parser.parse_args()
    source = json.loads((args.run/('recovered-summary.json' if args.use_recovered_counter_run else 'summary.json')).read_text())
    recovery = source.get('resource_counter_recovery') if args.use_recovered_counter_run else None
    if not source.get('complete') and not (recovery and recovery['status'] == 'deadline-counter-window-recovered' and recovery['nominal_window_shortfall_seconds'] <= .001):
        parser.error('Measurement is incomplete; no report can be published without validated deadline recovery')
    if not args.allow_short and (source['actual_measured_seconds'] < 1800 - (.001 if recovery else 0) or source['duration_requested_seconds'] < 1800):
        parser.error('A full reference report requires at least 1800 measured seconds')
    if args.update_docs and (args.allow_short or args.no_plot):
        parser.error('Documentation updates require a full run and plots')
    samples = load_samples(args.run/'samples.csv')
    result = source['results']
    active_delta = idle_delta = None
    if not recovery:
        active_delta = source['synthetic_recorded_seconds_at_end']['active'] - source['synthetic_recorded_seconds_at_start']['active']
        idle_delta = source['synthetic_recorded_seconds_at_end']['idle'] - source['synthetic_recorded_seconds_at_start']['idle']
        if not args.allow_short and (abs(active_delta-source['actual_measured_seconds']) > 20 or idle_delta != 0):
            parser.error('Synthetic workload accounting did not validate; investigate before publishing')
    args.output.mkdir(parents=True, exist_ok=False)
    public_keys = ['schema_version', 'source_revision', 'app_version', 'binary_sha256',
                   'measurement_script_sha256', 'hardware', 'macos', 'macos_build',
                   'duration_requested_seconds', 'actual_measured_seconds', 'warmup_seconds',
                   'sample_interval_seconds', 'mach_timebase', 'cpu_calibration_seconds',
                   'bundle_size', 'units', 'scope', 'workload', 'wall_clock_discontinuities',
                   'heartbeat_late_over_500ms', 'process_events', 'storage_start', 'storage_end', 'results', 'complete']
    public = {key: source[key] for key in public_keys}
    if recovery:
        public['resource_counter_recovery'] = recovery
        shutil.copyfile(args.run/'measurement-harness-at-run.py', args.output/'measurement-harness-at-run.py')
    public['measurement_date'] = source['measurement_started_local'].split('T')[0]
    public['sample_data_sha256'] = hashlib.sha256((args.run/'samples.csv').read_bytes()).hexdigest()
    public['controlled_recording_delta_seconds'] = {'active': active_delta, 'idle': idle_delta}
    context = args.run/'age-context.json'
    if context.exists():
        public['installed_helper_age_at_start_hours_approximate'] = json.loads(context.read_text())['helper_age_at_measurement_start_seconds_approximate']/3600
    public['helper_footprint_growth'] = {}
    public['app_footprint_growth'] = {}
    for scenario, _ in SCENARIOS:
        selected = [r for r in samples if r['group'] == scenario+'-helper']
        seconds = [r['elapsed_seconds'] for r in selected]
        sizes = [r['footprint_bytes'] for r in selected]
        slope, _ = statistics.linear_regression(seconds, sizes)
        public['helper_footprint_growth'][scenario] = {'start_bytes': sizes[0], 'end_bytes': sizes[-1],
                                                      'change_bytes': sizes[-1]-sizes[0], 'linear_fit_MB_per_minute': slope*60/1e6}
    for scenario, _ in SCENARIOS:
        selected = [r for r in samples if r['group'] == scenario+'-app']
        seconds = [r['elapsed_seconds'] for r in selected]
        sizes = [r['footprint_bytes'] for r in selected]
        slope, _ = statistics.linear_regression(seconds, sizes)
        public['app_footprint_growth'][scenario] = {'start_bytes': sizes[0], 'end_bytes': sizes[-1],
                                                  'change_bytes': sizes[-1]-sizes[0], 'linear_fit_MB_per_minute': slope*60/1e6}
    shutil.copyfile(args.run/'samples.csv', args.output/'samples.csv')
    if not args.no_plot:
        public['plot_matplotlib_version'] = plot(samples, args.output)
    (args.output/'summary.json').write_text(json.dumps(public, indent=2)+'\n')
    installed_cpu_met = result['installed-app']['cpu_mean_percent_one_core'] < 1
    installed_rss_met = result['installed-app']['rss_peak_sampled_bytes'] < 100_000_000
    helper_grew = public['helper_footprint_growth']['installed']['change_bytes'] > 1_000_000
    cpu_note = 'The installed app stayed below the CPU goal in this run.' if installed_cpu_met else 'The CPU goal is not met in this run.'
    memory_note = ' Charged-memory growth needs investigation.' if helper_grew else ' Review charged footprint separately from RSS.'
    run_label = f"{source['actual_measured_seconds']/60:.1f}-minute" if not args.allow_short else f"{source['actual_measured_seconds']:.1f}-second smoke preview of a"
    short = ['## Measured resource use', '',
             f"{run_label} native development-build run on {source['hardware']['machdep.cpu.brand_string']}, {int(source['hardware']['hw.memsize'])/2**30:.0f} GiB RAM, macOS {source['macos']} ({public['measurement_date']}). CPU is percent of **one logical core**; memory uses decimal MB. Chrome processes are excluded.", '',
             '| Workload | App + helper mean CPU | Peak sampled app + helper RSS | Peak app + helper charged footprint |',
             '| --- | ---: | ---: | ---: |']
    for scenario, label in SCENARIOS:
        total, helper = result[scenario+'-native-total'], result[scenario+'-helper']
        short.append(f"| {label} | {total['cpu_mean_percent_one_core']:.2f}% | {mb(total['rss_peak_sampled_bytes'])} MB | {mb(total['footprint_peak_sampled_bytes'])} MB |")
    if public.get('installed_helper_age_at_start_hours_approximate') is not None:
        short += ['', f"The installed helper was already about {public['installed_helper_age_at_start_hours_approximate']:.1f} hours old at the start; controlled helpers were fresh."]
    if recovery:
        short += ['', f"Counter samples cover {source['actual_measured_seconds']:,.6f} seconds of the nominal {source['duration_requested_seconds']/60:.0f}-minute run. A finalizer error was explicitly recovered; end-of-run database-size/accounting checks were not captured."]
    short += ['', f"App bundle: **{mb(source['bundle_size']['logical_bytes'])} MB logical** ({mb(source['bundle_size']['allocated_bytes'])} MB allocated blocks); local activity data and the installed helper copy are separate."]
    short += ['', f'**{cpu_note}{memory_note}** These are measured development-build results, not an optimized release claim.', '', '[Method, plots, disk usage, raw results, and limitations](docs/performance.md).']
    detailed = [f"## Reference results · {public['measurement_date']}", '',
                f"Measured {source['actual_measured_seconds']:.6f} seconds after a {source['warmup_seconds']}-second warmup; samples every {source['sample_interval_seconds']} seconds. Source baseline `{source['source_revision'][:7]}`; the exact installed binary and harness hashes are in the exported summary. Reference hardware: {source['hardware']['machdep.cpu.brand_string']}, {source['hardware']['hw.logicalcpu']} logical cores, {int(source['hardware']['hw.memsize'])/2**30:.0f} GiB RAM, macOS {source['macos']} ({source['macos_build']}).", '',
                '| Scenario | App CPU mean / P95 | Helper CPU mean | App peak sampled RSS | Helper peak sampled RSS | Peak native charged footprint |',
                '| --- | ---: | ---: | ---: | ---: | ---: |']
    if recovery:
        detailed[2:2] = ['**Counter-window recovery:** the harness reached the final sample, then failed on a negative sleep caused by deadline rounding. The preserved span is 0.000282 seconds short of nominal. CPU/memory/kernel-I/O summaries are computed from the retained CSV, not invented. Database-size endpoints, post-run synthetic SQL totals, and the final process-event list were not captured and remain null. The original executed harness is archived with a matching SHA-256; the fixed harness passed a separate 35-second deadline/end-snapshot retest.', '']
    for scenario, label in SCENARIOS:
        app, helper, total = result[scenario+'-app'], result[scenario+'-helper'], result[scenario+'-native-total']
        detailed.append(f"| {label} | {app['cpu_mean_percent_one_core']:.2f}% / {app['cpu_p95_percent_one_core']:.2f}% | {helper['cpu_mean_percent_one_core']:.3f}% | {mb(app['rss_peak_sampled_bytes'])} MB | {mb(helper['rss_peak_sampled_bytes'])} MB | {mb(total['footprint_peak_sampled_bytes'])} MB |")
    detailed += ['', '### Charged-memory growth', '', '| Process / scenario | Start | End | Change | Linear trend |', '| --- | ---: | ---: | ---: | ---: |']
    for scenario, label in SCENARIOS:
        for component in ['app', 'helper']:
            growth = public[component+'_footprint_growth'][scenario]
            detailed.append(f"| {label} · {component} | {mb(growth['start_bytes'])} MB | {mb(growth['end_bytes'])} MB | {mb(growth['change_bytes'])} MB | {growth['linear_fit_MB_per_minute']:.2f} MB/min |")
    age = public.get('installed_helper_age_at_start_hours_approximate')
    if age is not None:
        detailed += ['', f'The installed helper was already about **{age:.1f} hours old** at measurement start. Its starting footprint did not accumulate entirely during this 30-minute run. Controlled helpers were newly launched before warmup.']
    detailed += ['', '### Disk and observer overhead', '',
                 f"Installed app bundle: **{mb(source['bundle_size']['logical_bytes'])} MB logical**, **{mb(source['bundle_size']['allocated_bytes'])} MB allocated file blocks**. Bundled helper/extension assets are included; shared OS frameworks and Chrome are not.", '',
                 '| Scenario | Kernel written bytes during run | Database files at start | Database files at end |', '| --- | ---: | ---: | ---: |']
    for scenario, label in SCENARIOS:
        start = f"{source['storage_start'][scenario]['logical_bytes']:,} bytes" if source['storage_start'] else 'Not captured'
        end = f"{source['storage_end'][scenario]['logical_bytes']:,} bytes" if source['storage_end'] else 'Not captured'
        detailed.append(f"| {label} | {result[scenario+'-native-total']['kernel_written_bytes']:,.0f} | {start} | {end} |")
    process_quality = 'The final process-event list was not captured' if source['process_events'] is None else f"{len(source['process_events'])} process-membership changes"
    observer = result['observer']
    detailed += ['', f"Observer overhead: {observer['cpu_mean_percent_one_core']:.3f}% mean of one core; {mb(observer['rss_peak_sampled_bytes'])} MB peak sampled RSS. Observer work is excluded from app/helper totals.", '',
                 f"Data quality: {process_quality}; {source['wall_clock_discontinuities']} samples with wall/monotonic divergence over five seconds; {source['heartbeat_late_over_500ms']} heartbeat cycles over 500 ms late. " + ('Post-run synthetic SQL totals were not captured; no accounting result is claimed from this resource run.' if recovery else f'Controlled recorded-time delta: active {active_delta:.2f} seconds, unavailable {idle_delta:.2f} seconds. These counters validate synthetic workloads, not real-browser attribution.'), '',
                 '### Budget assessment', '',
                 f"{cpu_note} Sampled installed-app RSS was {'below' if installed_rss_met else 'at or above'} 100 MB in this run.{memory_note} This single development-build run does not establish a release-wide guarantee. Profile observed growth and repeat the benchmark after any fix.", '']
    if not args.no_plot:
        relative = args.output.resolve().relative_to(ROOT/'docs').as_posix() if args.output.resolve().is_relative_to(ROOT/'docs') else args.output.as_posix()
        detailed += [f'![Measured native CPU, resident memory, and helper footprint traces]({relative}/resource-usage.png)', '',
                     f'[Vector plot]({relative}/resource-usage.svg) · [Numeric samples]({relative}/samples.csv) · [Machine-readable summary]({relative}/summary.json)', '']
    if args.update_docs:
        if not args.output.resolve().is_relative_to(ROOT/'docs/benchmarks'):
            parser.error('Published documentation data must be under docs/benchmarks')
        replace_section(ROOT/'docs/performance.md', '\n'.join(detailed))
        replace_section(ROOT/'README.md', '\n'.join(short), before='## Try the first look')
    if not args.update_docs:
        (args.output/'readme-fragment.md').write_text('\n'.join(short)+'\n')
    print('Exported numeric resource data and report fragments; no local timestamps, paths, PIDs, or normal preferences are published.')


if __name__ == '__main__':
    main()
