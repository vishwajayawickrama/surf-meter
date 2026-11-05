#!/usr/bin/env python3
"""Build README assets from full-page screenshots of the real prototype.

Capture names and dimensions are documented in docs/media/README.md.
Requires ffmpeg; no Python packages or network access are used.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'docs/media'


def run(*args):
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', *map(str, args)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture_dir', type=Path)
    args = parser.parse_args()
    names = ['01-daily', '02-yesterday', '03-weekly', '04-detail', '05-daily-dark', '06-preferences-dark']
    missing = [name for name in names if not (args.capture_dir / f'{name}.jpg').is_file()]
    if missing:
        parser.error('Missing captures: ' + ', '.join(missing))
    if not shutil.which('ffmpeg'):
        parser.error('ffmpeg is required')
    DEST.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='surfmeter-media-') as tmp:
        temp = Path(tmp)
        for name in names:
            run('-i', args.capture_dir / f'{name}.jpg', '-vf',
                'pad=1280:1042:0:0:color=0xf5f7fa,crop=450:900:788:88',
                '-frames:v', '1', temp / f'{name}.png')
        for source, target in [('01-daily', 'daily'), ('02-yesterday', 'yesterday'),
                               ('03-weekly', 'weekly'), ('05-daily-dark', 'daily-dark'),
                               ('06-preferences-dark', 'preferences-dark')]:
            shutil.copyfile(temp / f'{source}.png', DEST / f'{target}.png')

        # Compose a sharp, typeset cover around an unscaled screenshot.
        labels = [
            ('SurfMeter', 95, 90, 30, '#326df1'),
            ('YOUR BROWSING, AT A GLANCE', 98, 235, 16, '#75849b'),
            ('Your browsing.', 92, 295, 70, '#202b3b'),
            ('A little clearer.', 92, 385, 70, '#202b3b'),
            ('A quiet place in your menu bar', 98, 525, 27, '#65758b'),
            ('for where your time goes.', 98, 570, 27, '#65758b'),
            ('DAILY  /  YESTERDAY  /  WEEKLY', 98, 715, 17, '#326df1'),
            ('FIRST LOOK  /  INTERACTIVE UI PROTOTYPE', 98, 845, 12, '#838c99'),
        ]
        filters = ['[0:v][1:v]overlay=910:20']
        for i, (label, x, y, size, color) in enumerate(labels):
            path = temp / f'label-{i}.txt'
            path.write_text(label)
            filters.append(f"drawtext=fontfile=/System/Library/Fonts/Supplemental/Arial.ttf:textfile={path}:x={x}:y={y}:fontsize={size}:fontcolor={color}")
        run('-f', 'lavfi', '-i', 'color=c=0xf5f7fa:s=1400x940', '-i', temp / '01-daily.png',
            '-filter_complex', ','.join(filters), '-frames:v', '1', DEST / 'cover.png')

        for filename, frames in [
            ('activity-tour.gif', names[:4]),
            ('appearance-tour.gif', ['01-daily', '05-daily-dark']),
        ]:
            manifest = temp / f'{filename}.txt'
            manifest.write_text(''.join(f"file '{temp / (name + '.png')}'\nduration 3\n" for name in frames)
                                + f"file '{temp / (frames[-1] + '.png')}'\n")
            run('-f', 'concat', '-safe', '0', '-i', manifest, '-t', len(frames) * 3,
                '-vf', 'fps=8,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3',
                '-loop', '0', DEST / filename)
    print('Built cover, five screenshots, and two looping GIFs in docs/media.')


if __name__ == '__main__':
    main()
