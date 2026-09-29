"""Exercise the source launcher with real Godot servers and a captured client spawn."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    godot = str(Path(args.godot).resolve())
    with tempfile.TemporaryDirectory(prefix='qqsg launcher 中文 ') as directory:
        work = Path(directory)
        env = dict(os.environ, QQSG_RUNTIME_DIR=str(work / 'runtime'))
        capture = work / 'client.json'
        wrapper = work / 'godot wrapper'
        wrapper.write_text('#!/usr/bin/env python3\nimport json, os, sys\nfrom pathlib import Path\n'
            + f'godot={godot!r}\ncapture=Path({str(capture)!r})\n'
            + 'if "--headless" not in sys.argv and "--version" not in sys.argv:\n'
            + ' capture.write_text(json.dumps(sys.argv[1:]), encoding="utf-8")\n sys.exit(0)\n'
            + 'os.execv(godot, [godot, *sys.argv[1:]])\n', encoding='utf-8')
        wrapper.chmod(0o755)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        config = work / '配置 中文.json'
        config.write_text(json.dumps(dict(port=port, data_dir=str(work/'存档 空间'))), encoding='utf-8')
        options = ['--godot', str(wrapper), '--config', str(config)]
        def run(mode, extra=(), ok=True):
            result = subprocess.run([sys.executable, str(ROOT/'start.command'), mode, *options, *extra],
                                    env=env, capture_output=True, text=True, encoding='utf-8', timeout=35)
            if ok: assert result.returncode == 0, result.stdout + result.stderr
            else: assert result.returncode != 0, result.stdout
            return result
        try:
            run('server', ['--godot', str(work/'missing')], ok=False)
            with ThreadPoolExecutor(2) as pool:
                pending = [pool.submit(subprocess.run, [sys.executable, str(ROOT/'start.command'), 'server', *options],
                    env=env, capture_output=True, text=True, encoding='utf-8', timeout=35) for _ in range(2)]
                outcomes = [p.result() for p in pending]
            assert any(p.returncode == 0 for p in outcomes), outcomes
            record_path = work/'runtime/server.json'
            record = json.loads(record_path.read_text(encoding='utf-8'))
            run('server')
            assert json.loads(record_path.read_text(encoding='utf-8'))['pid'] == record['pid']
            run('server', ['--port', str(port+1)], ok=False)
            run('both', ['--profile','launch-test','--name','中文 名字'])
            import time
            deadline = time.monotonic()+5
            while not capture.exists() and time.monotonic()<deadline: time.sleep(.05)
            command = json.loads(capture.read_text(encoding='utf-8'))
            assert '--connect=127.0.0.1' in command and '--name=中文 名字' in command
            assert '--profile=launch-test' in command
            assert '服务端 PID' in run('status').stdout  # client process has exited
            run('stop')
            assert '未运行' in run('status').stdout
            save = work/'存档 空间/world.json'
            assert save.exists()
            before = save.read_bytes()
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as occupied:
                occupied.bind(('0.0.0.0', port))
                run('server', ok=False)
            assert save.read_bytes() == before, 'port conflict must not modify saves'
            bad_store = work/'not-a-directory'
            bad_store.write_text('preserve', encoding='utf-8')
            run('server', ['--data-dir', str(bad_store/'save')], ok=False)
            assert bad_store.read_text(encoding='utf-8') == 'preserve'
            run('stop')
            print('LAUNCHER_RESULT discovery concurrent reuse paths client-spawn stop port-conflict PASS')
        finally:
            run('stop')

if __name__ == '__main__': main()
