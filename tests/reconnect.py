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
    with tempfile.TemporaryDirectory(prefix='qqsg-reconnect-') as folder:
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
        server_args = ['--', '--server', f'--port={port}', f'--data_dir={work / "save"}', f'--control-dir={work}', '--instance-id=restart-test']
        try:
            server = launch('server1', server_args)
            marker('server1', 'SERVER_READY', server)
            bot = launch('bot', ['tests/reconnect.tscn', '--', f'--port={port}', f'--credentials={work / "credentials.json"}'])
            marker('bot', 'RESTART_READY', bot)
            (work / 'stop.json').write_text(json.dumps({'instance':'restart-test'}), encoding='utf-8')
            assert server.wait(timeout=10) == 0
            marker('bot', 'RETRY_WAIT', bot)
            server = launch('server2', server_args)
            marker('server2', 'SERVER_READY', server)
            assert bot.wait(timeout=30) == 0
            marker('bot', 'RECONNECT_RESULT', bot)
            control = work / 'fixture'
            control.mkdir()
            fixture = launch('session', ['tests/session_checks.tscn', '--', f'--control={control}'])
            # Remove the previous successful stop acknowledgement before the fault fixture.
            # The fixture uses a separate control folder to avoid interfering with the server.
            assert fixture.wait(timeout=10) == 0
            marker('session', 'SESSION_RESULT', fixture)
            for log in work.glob('*.log'):
                assert 'SCRIPT ERROR' not in log.read_text(encoding='utf-8'), log
            print('RECONNECT_RESULT restart identity no-replay cancel rejection stop-failure PASS')
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
