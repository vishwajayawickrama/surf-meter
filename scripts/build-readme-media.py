#!/usr/bin/env python3
"""Build README media from current native --render-previews output at 2×.

Requires ffmpeg. Uses labeled sample activity, never recorded browser data.
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
    names = ['daily-light', 'yesterday-light', 'weekly-light', 'detail-weekly-light', 'daily-dark', 'preferences-dark']
    required = [args.capture_dir / f'native-{name}@2x.png' for name in names]
    required += [args.capture_dir / f'desktop-daily-{mode}-2x.png' for mode in ['light', 'dark']]
    missing = [path.name for path in required if not path.is_file()]
    if missing:
        parser.error('Missing native renders: ' + ', '.join(missing))
    if not shutil.which('ffmpeg'):
        parser.error('ffmpeg is required')
    for folder in ['desktop', 'native']:
        (DEST / folder).mkdir(parents=True, exist_ok=True)
    for pattern, folder in [('desktop-*-2x.png', 'desktop'), ('onboarding-*-2x.png', 'desktop'), ('native-*@2x.png', 'native')]:
        for path in args.capture_dir.glob(pattern):
            shutil.copyfile(path, DEST / folder / path.name)
    for source, target in [('daily-light', 'daily'), ('yesterday-light', 'yesterday'), ('weekly-light', 'weekly'),
                           ('daily-dark', 'daily-dark'), ('preferences-dark', 'preferences-dark')]:
        shutil.copyfile(args.capture_dir / f'native-{source}@2x.png', DEST / f'{target}-2x.png')
    with tempfile.TemporaryDirectory(prefix='surfmeter-native-media-') as tmp:
        temp = Path(tmp)
        title = temp / 'title.txt'
        title.write_text('SurfMeter — Your browsing. A little clearer.')
        subtitle = temp / 'subtitle.txt'
        subtitle.write_text('NATIVE MAC APP  ·  DAILY & WEEKLY ACTIVITY  ·  SAMPLE DATA')
        # Original 2200×1560 render stays at its native resolution on the cover.
        filters = '[0:v][1:v]overlay=100:240,' + ','.join([
            f'drawtext=fontfile=/System/Library/Fonts/Supplemental/Arial.ttf:textfile={title}:x=100:y=62:fontsize=58:fontcolor=0x202020',
            f'drawtext=fontfile=/System/Library/Fonts/Supplemental/Arial.ttf:textfile={subtitle}:x=103:y=151:fontsize=23:fontcolor=0x666666',
        ])
        run('-f', 'lavfi', '-i', 'color=c=0xf2f2f2:s=2400x1880', '-i', args.capture_dir / 'desktop-daily-light-2x.png',
            '-filter_complex', filters, '-frames:v', '1', DEST / 'cover-2x.png')
        for name in names:
            run('-i', args.capture_dir / f'native-{name}@2x.png', '-vf', 'pad=780:1532:0:0:color=0xeeeeee',
                '-frames:v', '1', temp / f'{name}.png')
        for filename, frames in [('activity-tour-2x.gif', names[:4]), ('appearance-tour-2x.gif', ['daily-light', 'daily-dark'])]:
            manifest = temp / 'frames.txt'
            manifest.write_text(''.join(f"file '{temp / (name + '.png')}'\nduration 3\n" for name in frames)
                                + f"file '{temp / (frames[-1] + '.png')}'\n")
            run('-f', 'concat', '-safe', '0', '-i', manifest, '-t', len(frames) * 3,
                '-vf', 'fps=4,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a',
                '-loop', '0', DEST / filename)
    print('Updated native cover, stills, desktop/onboarding gallery and two GIF state tours.')


if __name__ == '__main__':
    main()
