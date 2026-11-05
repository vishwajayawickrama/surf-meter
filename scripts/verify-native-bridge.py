#!/usr/bin/env python3
"""Build first. Exercises the real app/host with synthetic hostnames; no browser history."""
import json
import os
from pathlib import Path
import select
import shutil
import struct
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / '.build/SurfMeter.app/Contents/MacOS/SurfMeter'
HOST = ROOT / '.build/SurfMeter.app/Contents/Helpers/SurfMeterNativeHost'
ORIGIN = 'chrome-extension://' + 'a' * 32 + '/'

def request(host, message, fragmented=False):
    data = json.dumps(message).encode()
    frame = struct.pack('<I', len(data)) + data
    if fragmented:
        for piece in [frame[:2], frame[2:7], frame[7:]]:
            host.stdin.write(piece)
            host.stdin.flush()
            time.sleep(0.02)
    else:
        host.stdin.write(frame)
        host.stdin.flush()
    assert select.select([host.stdout], [], [], 5)[0], 'host response timed out'
    length = struct.unpack('<I', host.stdout.read(4))[0]
    assert 0 < length <= 16384
    return json.loads(host.stdout.read(length))['accepted']

with tempfile.TemporaryDirectory(prefix='sm-bridge-', dir='/private/tmp') as temporary:
    directory = Path(temporary)
    helper = directory / 'SurfMeterNativeHost'
    shutil.copy2(HOST, helper)
    (directory / 'host-config.json').write_text(json.dumps({'allowedOrigin': ORIGIN, 'bridgeDirectory': temporary}))
    app = subprocess.Popen([str(APP), '--bridge-directory', temporary], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    host = None
    try:
        for _ in range(100):
            if (directory / 'bridge.sock').exists(): break
            assert app.poll() is None, 'app exited before opening its bridge'
            time.sleep(0.05)
        assert (directory / 'bridge.sock').exists(), 'app bridge not ready'
        assert (directory.stat().st_mode & 0o777) == 0o700
        assert ((directory / 'bridge.sock').stat().st_mode & 0o777) == 0o600
        host = subprocess.Popen([str(helper), ORIGIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        message = {'protocolVersion': 1, 'browser': 'chrome', 'sessionID': str(uuid.uuid4()),
                   'sequence': 0, 'state': 'active', 'hostname': 'example.com'}
        assert request(host, message, fragmented=True)
        assert not request(host, message), 'duplicate sequence was accepted'
        assert not request(host, dict(message, sequence=1, title='must never cross boundary'))
        assert not request(host, dict(message, sequence=1, hostname='https://example.com/private?q=1'))
        assert not request(host, dict(message, browser='safari', sequence=1))
        assert request(host, dict(message, sequence=1, state='unavailable', hostname=None))
        assert request(host, dict(message, sessionID=str(uuid.uuid4()), sequence=0)), 'new worker session rejected'
        host.stdin.close()
        assert host.wait(timeout=5) == 0
        host = subprocess.Popen([str(helper), ORIGIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        assert request(host, dict(message, sessionID=str(uuid.uuid4()))), 'helper reconnect failed'
        app.terminate()
        app.wait(timeout=5)
        assert not request(host, dict(message, sessionID=str(uuid.uuid4()))), 'missing app reported success'
        wrong = subprocess.run([str(helper), 'chrome-extension://' + 'b'*32 + '/'], input=b'', capture_output=True, timeout=5)
        assert wrong.returncode != 0, 'unregistered origin accepted'
        print('PASS: app → Unix socket ← native host; framing, privacy, ordering, reconnect, app loss, origin, permissions')
    finally:
        if host and host.poll() is None:
            host.terminate()
            host.wait(timeout=5)
        if app.poll() is None:
            app.terminate()
            app.wait(timeout=5)
