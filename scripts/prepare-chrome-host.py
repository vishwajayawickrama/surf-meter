#!/usr/bin/env python3
"""Prepare a development Chrome host; register only with explicit --install."""
import argparse
import json
from pathlib import Path
import re
import shlex
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--extension-id', required=True, help='ID shown by chrome://extensions after loading the unpacked extension')
parser.add_argument('--install', action='store_true', help='Write the per-user Chrome native messaging registration')
args = parser.parse_args()
if not re.fullmatch('[a-p]{32}', args.extension_id):
    parser.error('extension ID must contain exactly 32 letters a–p')
root = Path(__file__).resolve().parents[1]
source = root / '.build/SurfMeter.app/Contents/Helpers/SurfMeterNativeHost'
if not source.is_file():
    parser.error('run ./scripts/build-native.sh first')
# Keep generated configuration out of the signed app bundle.
directory = root / '.build/chrome-native-host'
helper = directory / 'SurfMeterNativeHost'
origin = f'chrome-extension://{args.extension_id}/'
manifest = {'name':'dev.surfmeter.bridge', 'description':'SurfMeter local browser bridge',
            'path':str(helper), 'type':'stdio', 'allowed_origins':[origin]}
destination = Path.home() / 'Library/Application Support/Google/Chrome/NativeMessagingHosts/dev.surfmeter.bridge.json'
if destination.exists():
    try:
        existing = json.loads(destination.read_text())
    except (OSError, ValueError):
        parser.error(f'cannot safely inspect existing registration at {destination}')
    if existing != manifest:
        parser.error(f'another registration exists at {destination}; inspect/remove it before replacing')
directory.mkdir(mode=0o700, parents=True, exist_ok=True)
shutil.copy2(source, helper)
(directory / 'host-config.json').write_text(json.dumps({'allowedOrigin': origin, 'appBundle': str(root / '.build/SurfMeter.app')}, indent=2) + '\n')
prepared = directory / 'dev.surfmeter.bridge.json'
prepared.write_text(json.dumps(manifest, indent=2) + '\n')
print(f'Prepared: {prepared}')
if args.install:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(prepared, destination)
    print(f'Registered: {destination}')
else:
    print('Preview only. To register this exact host, run:')
    print(f'python3 {shlex.quote(str(Path(__file__).resolve()))} --extension-id {args.extension_id} --install')
