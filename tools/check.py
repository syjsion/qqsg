#!/usr/bin/env python3
"""Single local/CI validation entrypoint. Fails on Godot script errors, even exit 0."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import struct
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]

def run(command, marker=None, timeout=180):
    result = subprocess.run(command, cwd=ROOT, text=True,encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    output = result.stdout
    print(output[-12000:] if result.returncode or 'SCRIPT ERROR' in output else '\n'.join(line for line in output.splitlines() if not line.startswith('[')))
    if result.returncode or 'SCRIPT ERROR' in output or '\nERROR:' in output or (marker and marker not in output):
        raise SystemExit(f'Check failed: {command}')

def validate_data():
    content = json.loads((ROOT / 'data/content.json').read_text(encoding="utf-8"))
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
    assert sum(entry['weight'] for entry in content['boss_loot']['equipment']) == 100
    for entry in content['boss_loot']['equipment']:
        for job in ['JS', 'XS']: assert entry[job] in content['items']
    for item, count in content['boss_loot']['guaranteed'].items():
        assert item in content['items'] and count > 0
    assert len(content['enhancement']['levels']) == 6
    for recipe in content['enhancement']['levels']:
        assert 0 < recipe['chance'] <= 1 and recipe['money'] > 0 and recipe['stones'] > 0
    art = json.loads((ROOT / 'data/art.json').read_text(encoding="utf-8"))
    def walk(node):
        if isinstance(node, dict):
            for value in node.values(): walk(value)
        elif isinstance(node, list):
            for value in node: walk(value)
        elif isinstance(node, str) and node.startswith('res://'):
            assert (ROOT / node[6:]).is_file(), node
    walk(art)
    for group, ids in [('items', content['items']), ('skills', content['skills'])]:
        assert all(identifier in art[group] for identifier in ids), group
    for group in ['items', 'skills', 'portraits', 'characters', 'symbols']:
        for entry in art[group].values():
            if isinstance(entry, dict):
                assert len(entry['region']) == 4 and min(entry['region']) >= 0
                assert entry['region'][2] > 0 and entry['region'][3] > 0
                width, height = struct.unpack('>II', (ROOT / entry['path'][6:]).read_bytes()[16:24])
                x, y, w, h = entry['region']
                assert x + w <= width and y + h <= height, entry
    for manifest in ['assets/manifest.json', 'assets/generated/manifest.json']:
        for entry in json.loads((ROOT / manifest).read_text(encoding='utf-8'))['files']:
            assert hashlib.sha256((ROOT / entry['path']).read_bytes()).hexdigest() == entry['sha256'], entry['path']
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
    run([args.godot, '--headless', '--path', str(ROOT), 'tests/ui.tscn'], 'UI_RESULT')
    if not args.skip_network:
        run([sys.executable, 'tests/network.py', '--godot', args.godot], 'NETWORK_RESULT', timeout=90)
        run([sys.executable, 'tests/reconnect.py', '--godot', args.godot], 'RECONNECT_RESULT', timeout=100)
        run([sys.executable, 'tests/economy.py', '--godot', args.godot], 'ECONOMY_RESULT', timeout=100)
        if sys.platform != 'win32':
            run([sys.executable, 'tests/launcher.py', '--godot', args.godot], 'LAUNCHER_RESULT', timeout=180)
    print('CHECK_RESULT PASS')

if __name__ == '__main__':
    main()
