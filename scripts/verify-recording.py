#!/usr/bin/env python3
"""Real native app + helper + engine + disk, with explicitly isolated synthetic browser input."""
import json
from pathlib import Path
import select
import shutil
import sqlite3
import struct
import subprocess
import tempfile
import time
import uuid

root = Path(__file__).resolve().parents[1]
app_path = root / '.build/SurfMeter.app/Contents/MacOS/SurfMeter'
origin = 'chrome-extension://' + 'a'*32 + '/'
with tempfile.TemporaryDirectory(prefix='sm-recording-', dir='/private/tmp') as temporary:
    directory = Path(temporary)
    helper = directory / 'SurfMeterNativeHost'
    shutil.copy2(root / '.build/SurfMeter.app/Contents/Helpers/SurfMeterNativeHost', helper)
    (directory / 'host-config.json').write_text(json.dumps({'allowedOrigin':origin, 'bridgeDirectory':temporary}))
    app = subprocess.Popen([str(app_path), '--bridge-directory', temporary, '--simulate-chrome'], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    host = None
    try:
        for _ in range(100):
            if (directory / 'bridge.sock').exists(): break
            assert app.poll() is None, 'app failed to launch'
            time.sleep(0.05)
        host = subprocess.Popen([str(helper), origin], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        session = str(uuid.uuid4())
        def send(sequence, state, hostname=None):
            payload = {'protocolVersion':1, 'browser':'chrome', 'sessionID':session, 'sequence':sequence, 'state':state}
            if hostname: payload['hostname'] = hostname
            data = json.dumps(payload).encode()
            host.stdin.write(struct.pack('<I',len(data)) + data); host.stdin.flush()
            assert select.select([host.stdout], [], [], 5)[0], 'no bridge response'
            length = struct.unpack('<I',host.stdout.read(4))[0]
            assert json.loads(host.stdout.read(length))['accepted']
        for second in range(12):
            send(second, 'active', 'm.youtube.com')
            time.sleep(1)
        # Unavailable input stops the old platform. No URL or title is ever sent.
        for second in range(12, 22):
            send(second, 'unavailable')
            time.sleep(1)
        database = directory / 'Data/activity.sqlite'
        connection = sqlite3.connect(f'file:{database}?mode=ro', uri=True)
        values = connection.execute('SELECT ZPLATFORM, SUM(ZSECONDS) FROM ZBUCKET GROUP BY ZPLATFORM').fetchall()
        coverage = connection.execute('SELECT ZREASONS FROM ZCOVERAGE').fetchall()
        assert any('recorded' in row[0].split(',') for row in coverage), 'recorded-day coverage missing'
        connection.close()
        assert len(values) == 1 and values[0][0] == 'youtube.com', values
        assert 10 <= values[0][1] <= 13, 'unavailable time was counted or eligible time was lost'
        print('PASS: real app → accounting → SQLite; ~12 synthetic seconds grouped to YouTube; unavailable interval adds zero')
    finally:
        if host and host.poll() is None: host.terminate(); host.wait(timeout=5)
        if app.poll() is None: app.terminate(); app.wait(timeout=5)
