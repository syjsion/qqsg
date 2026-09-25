#!/usr/bin/env python3
"""Launch a real ENet server and four Godot clients; no RPC mocks."""
import argparse
import sys
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=os.environ.get('GODOT', 'godot'))
    args = parser.parse_args()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    with tempfile.TemporaryDirectory(prefix='qqsg-network-') as folder:
        work = Path(folder)
        handles, processes = [], []
        def start(name, *extra):
            log = open(work / (name + '.log'), 'w', encoding='utf-8')
            handles.append(log)
            process = subprocess.Popen([args.godot, '--headless', '--path', str(ROOT), *extra], stdout=log, stderr=subprocess.STDOUT)
            processes.append(process)
            return process
        try:
            server = start('server', '--', '--server', f'--port={port}', f'--data_dir={work / "save"}')
            deadline = time.monotonic() + 15
            while 'SERVER_READY' not in (work / 'server.log').read_text(encoding="utf-8"):
                if server.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('server failed to become ready')
                time.sleep(0.1)
            for mode in ['version', 'credential']:
                probe = start('probe-'+mode, 'tests/probe.tscn', '--', f'--port={port}', f'--probe={mode}')
                if probe.wait(timeout=10) != 0:
                    raise RuntimeError(f'{mode} rejection probe failed')
                print('PROBE_OK ' + mode)
            bots = [start(f'bot{i}', 'tests/bot.tscn', '--', f'--port={port}', f'--bot={i}', f'--credentials={work / ("credentials" + str(i) + ".json")}') for i in range(4)]
            deadline = time.monotonic() + 5
            while 'PLAYER_JOIN online=4' not in (work / 'server.log').read_text(encoding="utf-8"):
                if time.monotonic() > deadline: raise RuntimeError('four clients not connected')
                time.sleep(.05)
            probe = start('probe-capacity', 'tests/probe.tscn', '--', f'--port={port}', '--probe=capacity')
            if probe.wait(timeout=10) != 0: raise RuntimeError('capacity rejection probe failed')
            print('PROBE_OK capacity')
            for bot in bots:
                if bot.wait(timeout=30) != 0:
                    raise RuntimeError('bot failed')
            for i in range(4):
                log = (work / f'bot{i}.log').read_text(encoding="utf-8")
                if 'BOT_OK' not in log or 'SCRIPT ERROR' in log:
                    raise RuntimeError(f'bot {i} did not report success')
                print(next(line for line in log.splitlines() if 'BOT_OK' in line))
            save = json.loads(json.loads((work / 'save/world.json').read_text(encoding="utf-8"))['payload'])
            assert len(save['records']) == 4
            assert all(p['money'] == 130 and p['quests']['arrival']['state'] == 'done' for p in save['records'].values())
            print('NETWORK_RESULT 4 clients; saved rewards verified; PASS')
        except Exception:
            for log in work.glob('*.log'):
                print(f'--- {log.name} ---\n{log.read_text(encoding="utf-8")[-12000:]}')
            raise
        finally:
            for process in processes:
                if process.poll() is None: process.terminate()
            for process in processes:
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill()
            for handle in handles: handle.close()

if __name__ == '__main__':
    main()
