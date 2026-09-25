#!/usr/bin/env python3
"""Single local/CI validation entrypoint. Fails on Godot script errors, even exit 0."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def run(command, marker=None, timeout=180):
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    output = result.stdout
    print(output[-12000:] if result.returncode or 'SCRIPT ERROR' in output else '\n'.join(line for line in output.splitlines() if not line.startswith('[')))
    if result.returncode or 'SCRIPT ERROR' in output or '\nERROR:' in output or (marker and marker not in output):
        raise SystemExit(f'Check failed: {command}')

def validate_data():
    content = json.loads((ROOT / 'data/content.json').read_text())
    for job in content['classes'].values():
        for skill in job['skills']: assert skill in content['skills']
    for item in content['items'].values():
        assert item['stack'] >= 1 and item['price'] > 0
    for monster in content['monsters'].values():
        assert monster['hp'] > 0
        for item in monster['loot']: assert item in content['items']
    for area in content['maps'].values():
        for portal in area['portals']: assert portal['to'] in content['maps']
        for spawn in area['spawns']: assert spawn['kind'] in content['monsters']
    for quest in content['quests'].values():
        assert not quest['previous'] or quest['previous'] in content['quests']
        if quest['type'] == 'kill': assert quest['target'] in content['monsters']
        if quest['type'] == 'collect': assert quest['target'] in content['items']
    art = json.loads((ROOT / 'data/art.json').read_text())
    def walk(node):
        if isinstance(node, dict):
            for value in node.values(): walk(value)
        elif isinstance(node, list):
            for value in node: walk(value)
        elif isinstance(node, str) and node.startswith('res://'):
            assert (ROOT / node[6:]).is_file(), node
    walk(art)
    assert (ROOT / 'assets/generated/healer-sheet.png').is_file()
    print('DATA_RESULT references and content constraints PASS')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    parser.add_argument('--skip-network', action='store_true')
    args = parser.parse_args()
    validate_data()
    run([args.godot, '--headless', '--path', str(ROOT), '--editor', '--import'])
    run([args.godot, '--headless', '--path', str(ROOT), '--script', 'tests/unit.gd'], 'UNIT_RESULT')
    if not args.skip_network:
        run([sys.executable, 'tests/network.py', '--godot', args.godot], 'NETWORK_RESULT', timeout=90)
    print('CHECK_RESULT PASS')

if __name__ == '__main__':
    main()
