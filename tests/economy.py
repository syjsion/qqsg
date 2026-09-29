"""Real server restart with client reconnect; isolated credentials and storage."""
import argparse
import json
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    processes, logs = [], []
    with tempfile.TemporaryDirectory(prefix='qqsg-economy-') as folder:
        work = Path(folder)
        def launch(name, extra):
            log = (work / (name + '.log')).open('w', encoding='utf-8')
            logs.append(log)
            proc = subprocess.Popen([args.godot, '--headless', '--path', str(ROOT), *extra], stdout=log, stderr=subprocess.STDOUT)
            processes.append(proc)
            return proc
        def marker(name, text, proc, timeout=25):
            end = time.monotonic() + timeout
            while time.monotonic() < end:
                if text in (work / (name + '.log')).read_text(encoding='utf-8'): return
                if proc.poll() is not None: break
                time.sleep(.1)
            raise RuntimeError('Missing marker: ' + text)
        server_args = ['tests/economy_server.tscn', '--', '--server', f'--credentials={work / "credentials.json"}', f'--port={port}', f'--data_dir={work / "save"}', f'--control-dir={work}', '--instance-id=restart-test']
        try:
            server = launch('server1', server_args)
            marker('server1', 'ECONOMY_SERVER_READY', server)
            bot = launch('bot', ['tests/economy_bot.tscn', '--', f'--port={port}', f'--credentials={work / "credentials.json"}'])
            marker('bot', 'ECONOMY_RESTART_READY', bot)
            (work / 'stop.json').write_text(json.dumps({'instance':'restart-test'}), encoding='utf-8')
            assert server.wait(timeout=10) == 0
            marker('bot', 'ECONOMY_RETRY', bot)
            server = launch('server2', server_args)
            marker('server2', 'ECONOMY_SERVER_READY', server)
            assert bot.wait(timeout=30) == 0
            marker('bot', 'ECONOMY_RESULT', bot)
            state = json.loads(json.loads((work/'save/world.json').read_text(encoding='utf-8'))['payload'])
            player = next(iter(state['records'].values()))
            assert player['money'] == 440 and player['inventory']['enhance_stone'] == 7
            assert player['gear'][player['equipment']['weapon']]['enhance'] == 2
            for log in work.glob('*.log'):
                assert 'SCRIPT ERROR' not in log.read_text(encoding='utf-8'), log
            print('ECONOMY_RESULT duplicate restart stale revision exact-cost PASS')
        except Exception:
            for log in work.glob('*.log'): print(log.name, log.read_text(encoding='utf-8')[-6000:])
            raise
        finally:
            for proc in processes:
                if proc.poll() is None: proc.terminate()
            for proc in processes:
                try: proc.wait(timeout=5)
                except subprocess.TimeoutExpired: proc.kill(); proc.wait()
            for log in logs: log.close()

if __name__ == '__main__': main()
