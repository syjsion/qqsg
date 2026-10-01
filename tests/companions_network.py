"""Four real clients: companion recruitment replay, visibility, personal boss loot and restart."""
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
    with tempfile.TemporaryDirectory(prefix='qqsg-companions-') as folder:
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
        server_args = ['tests/companion_server.tscn', '--', '--server', f'--work={work}', f'--port={port}', f'--data_dir={work / "save"}', f'--control-dir={work}', '--instance-id=restart-test']
        try:
            server = launch('server1', server_args)
            marker('server1', 'COMPANION_SERVER_READY', server)
            bots = [launch(f'bot{i}', ['tests/companion_bot.tscn', '--', f'--index={i}',
                       f'--port={port}', f'--work={work}']) for i in range(4)]
            for i, bot in enumerate(bots): marker(f'bot{i}', 'COMPANION_PHASE_READY', bot)
            (work / 'boss-go').write_text('go', encoding='utf-8')
            for i, bot in enumerate(bots): marker(f'bot{i}', 'COMPANION_RESTART_READY', bot)
            (work / 'boss-go').unlink()
            (work / 'stop.json').write_text(json.dumps({'instance':'restart-test'}), encoding='utf-8')
            assert server.wait(timeout=10) == 0
            for i, bot in enumerate(bots): marker(f'bot{i}', 'COMPANION_RETRY', bot)
            server = launch('server2', server_args)
            marker('server2', 'COMPANION_SERVER_READY', server)
            for i, bot in enumerate(bots):
                assert bot.wait(timeout=30) == 0
                marker(f'bot{i}', 'COMPANION_BOT_OK', bot)
            state = json.loads(json.loads((work/'save/world.json').read_text(encoding='utf-8'))['payload'])
            assert len(state['records']) == 4
            for player in state['records'].values():
                assert len(player['companions']) == 2 and player['inventory']['recruit_token'] == 2
                assert player['active_companion'] in player['companions'] and player['companion_revision'] == 1
            for log in work.glob('*.log'):
                assert 'ERROR:' not in log.read_text(encoding='utf-8'), log
            print('COMPANION_NETWORK_RESULT 4 clients visibility replay personal-loot restart PASS')
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
