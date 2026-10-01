#!/usr/bin/env python3
"""Capture real graphical fixtures; artifacts do not substitute for LAN playtests."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = {
    'companions': ['--preview=companions', '--map=bajun'],
    'companions-full': ['--preview=companions', '--map=bajun', '--full=true'],
    'companions-empty': ['--preview=companions', '--map=bajun', '--empty=true'],
    'companions-small-down': ['--preview=companions', '--map=bajun', '--down=true', '--width=960', '--height=700'],
    'companion-release': ['--preview=companions', '--map=bajun', '--release=true'],
    'companion-attack': ['--preview=companion-world', '--map=west', '--motion=attack'],
    'companion-hurt': ['--preview=companion-world', '--map=west', '--motion=hurt'],
    'companion-run': ['--preview=companion-world', '--map=west', '--motion=run'],
    'companion-down': ['--preview=companion-world', '--map=west', '--down=true'],
    'companion-world': ['--preview=companion-world', '--map=west'],
    'bag': ['--preview=bag', '--map=bajun'],
    'bag-full': ['--preview=bag', '--map=bajun', '--full=true'],
    'bag-empty-long': ['--preview=bag', '--map=bajun', '--empty=true', '--long=true'],
    'bag-xs-small': ['--preview=bag', '--map=bajun', '--job=XS', '--width=960', '--height=700'],
    'shop': ['--preview=shop', '--map=bajun'],
    'shop-empty': ['--preview=shop', '--map=bajun', '--sell=true', '--empty=true'],
    'sale-confirm': ['--preview=shop', '--map=bajun', '--sell=true', '--confirm=true'],
    'enhance': ['--preview=enhance', '--map=bajun'],
    'quests': ['--preview=quests', '--map=bajun'],
    'team': ['--preview=team', '--map=west'],
    'settings': ['--preview=settings', '--map=bajun'],
    'login': ['--preview=login', '--job=XS'],
    'reconnect': ['--preview=reconnect'],
    'death': ['--preview=death', '--map=camp'],
    'drops': ['--preview=drops', '--map=west'],
    'menu': ['--preview=menu', '--map=bajun'],
}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for name, options in SCENARIOS.items():
        target = args.output / f'{name}.png'
        result = subprocess.run([args.godot, '--path', str(ROOT), 'tests/render.tscn', '--',
                                 *options, f'--output={target}'], cwd=ROOT, capture_output=True,
                                text=True, encoding='utf-8', timeout=40)
        output = result.stdout + result.stderr
        (args.output / f'{name}.log').write_text(output, encoding='utf-8')
        if result.returncode or 'ERROR:' in output or not target.is_file():
            raise SystemExit(f'VISUAL_FAIL {name}\n{output}')
        print(f'VISUAL_CAPTURE {name}', flush=True)
    print(f'VISUAL_RESULT {len(SCENARIOS)} graphical fixtures captured; inspect PNGs separately')

if __name__ == '__main__':
    main()
