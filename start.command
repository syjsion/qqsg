#!/usr/bin/env python3
"""Single macOS source launcher. Requires Python 3 and Godot 4.7.2."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import errno
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parent
RUNTIME = Path(os.environ.get('QQSG_RUNTIME_DIR', ROOT / '.runtime')).resolve()
VERSION = (ROOT / '.godot-version').read_text(encoding='utf-8').strip()
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')


def read_json(path):
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def write_json(path, data):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
    temporary.replace(path)


def alive(record):
    if not record.get('pid') or not record.get('instance'):
        return False
    result = subprocess.run(['ps', '-p', str(record['pid']), '-o', 'command='],
                            capture_output=True, text=True, encoding='utf-8')
    return result.returncode == 0 and ('--instance-id=' + record['instance']) in result.stdout


def engine(explicit):
    selected = explicit or os.environ.get('GODOT')
    candidates = [selected] if selected else [ROOT / '.tools/Godot.app/Contents/MacOS/Godot',
        shutil.which('godot'), shutil.which('godot4'), '/Applications/Godot.app/Contents/MacOS/Godot',
        Path.home() / 'Applications/Godot.app/Contents/MacOS/Godot']
    for candidate in candidates:
        if not candidate:
            continue
        path = Path(shutil.which(str(candidate)) or candidate).expanduser()
        if path.suffix == '.app':
            path = path / 'Contents/MacOS/Godot'
        if not path.is_file():
            continue
        result = subprocess.run([str(path.resolve()), '--version'], capture_output=True,
                                text=True, encoding='utf-8', timeout=15)
        if result.returncode == 0 and result.stdout.strip().startswith(VERSION + '.stable.'):
            return str(path.resolve())
        if selected:
            raise RuntimeError(f'引擎版本需要 {VERSION}，当前输出：{result.stdout.strip()}')
    raise RuntimeError(f'未找到 Godot {VERSION}。运行 python3 tools/engine.py，或设置 GODOT / --godot。')


def import_project(godot):
    log = RUNTIME / 'import.log'
    with log.open('w', encoding='utf-8') as output:
        result = subprocess.run([godot, '--headless', '--path', str(ROOT), '--editor', '--import'],
                                stdout=output, stderr=subprocess.STDOUT, timeout=180)
    content = log.read_text(encoding='utf-8')
    if result.returncode or 'SCRIPT ERROR' in content or '\nERROR:' in content:
        raise RuntimeError(f'资源导入失败，请查看 {log}')


def describe(record):
    ready = read_json(Path(record['control']) / 'ready.json')
    print(f"服务端 PID {record['pid']}，UDP {record['port']}\n存档：{ready.get('data_dir', record['data_dir'])}\n日志：{record['log']}")


def start_server(godot, args, config):
    config_path = Path(args.config).expanduser().resolve()
    port = args.port if args.port is not None else int(config.get('port', 24567))
    data_dir = args.data_dir or str(config.get('data_dir', 'user://server'))
    if not data_dir.startswith(('user://', 'res://')):
        data_dir = str(Path(data_dir).expanduser().resolve())
    effective = dict(config, port=port, data_dir=data_dir)
    signature = hashlib.sha256(json.dumps([godot, effective], sort_keys=True).encode()).hexdigest()
    record_path = RUNTIME / 'server.json'
    old = read_json(record_path)
    if alive(old):
        if old.get('signature') != signature:
            raise RuntimeError('已有服务端使用不同配置，请先执行 ./start.command stop。')
        ready = read_json(Path(old['control']) / 'ready.json')
        if ready.get('instance') != old['instance']:
            raise RuntimeError('已记录进程尚未就绪，请查看其日志，或使用 stop 停止。')
        print('复用正在运行的服务端。')
        describe(old)
        return port
    # Check both IP families: a wildcard ENet socket may coexist with an IPv4
    # listener on some hosts, which would make localhost clients reach the wrong app.
    bind = str(config.get('bind_address', '*'))
    addresses = [(socket.AF_INET, '0.0.0.0'), (socket.AF_INET6, '::')] if bind == '*' else [(socket.AF_INET6 if ':' in bind else socket.AF_INET, bind)]
    for family, address in addresses:
        try:
            with socket.socket(family, socket.SOCK_DGRAM) as probe:
                probe.bind((address, port))
        except OSError as error:
            if error.errno not in (errno.EAFNOSUPPORT, errno.EPROTONOSUPPORT):
                raise RuntimeError(f'UDP {port} 无法使用（地址 {address}）：{error}') from error
    instance = uuid.uuid4().hex
    control = RUNTIME / instance
    control.mkdir(mode=0o700)
    log = control / 'server.log'
    command = [godot, '--headless', '--path', str(ROOT), '--', '--server',
               f'--config={config_path}', f'--port={port}', f'--data_dir={data_dir}',
               f'--control-dir={control}', f'--instance-id={instance}']
    with log.open('w', encoding='utf-8') as output:
        process = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL,
                                   stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    record = dict(pid=process.pid, instance=instance, control=str(control), log=str(log),
                  port=port, data_dir=data_dir, signature=signature)
    write_json(record_path, record)
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        ready = read_json(control / 'ready.json')
        if ready.get('instance') == instance and ready.get('pid') == process.pid:
            describe(record)
            return port
        if process.poll() is not None:
            raise RuntimeError(f'服务端启动失败（可能端口占用或存档不可写），请查看 {log}')
        time.sleep(.1)
    # Do not kill a process that may be writing a save. Leave a graceful request.
    write_json(control / 'stop.json', {'instance': instance})
    raise RuntimeError(f'服务端 20 秒内未就绪，已请求安全停服。请查看 {log}')


def stop_server():
    record = read_json(RUNTIME / 'server.json')
    if not alive(record):
        print('没有由此脚本管理的运行中服务端。')
        return
    control = Path(record['control'])
    result_path = control / 'stop-result.json'
    result_path.unlink(missing_ok=True)
    write_json(control / 'stop.json', {'instance': record['instance']})
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        result = read_json(result_path)
        if result.get('ok') is False:
            raise RuntimeError('存档失败，服务端保持运行：' + result.get('error', '未知错误'))
        if not alive(record):
            if not result.get('ok'):
                raise RuntimeError('进程退出，但未确认保存成功。请检查服务端日志和存档。')
            print('服务端已保存并停止。')
            return
        time.sleep(.1)
    raise RuntimeError('安全停服超时，未强制结束进程。请查看服务端日志。')


def main():
    parser = argparse.ArgumentParser(description='源码快速启动；无参数同时开服并进入，关闭客户端后继续开服。')
    parser.add_argument('mode', nargs='?', default='both', choices=['both', 'client', 'server', 'status', 'stop'])
    parser.add_argument('--godot')
    parser.add_argument('--port', type=int)
    parser.add_argument('--config', default=str(ROOT / 'deploy/server.json'))
    parser.add_argument('--data-dir')
    parser.add_argument('--connect', default='127.0.0.1')
    parser.add_argument('--profile', default='default')
    parser.add_argument('--name', default='蜀地旅人')
    parser.add_argument('--job', choices=['JS', 'XS'], default='JS')
    args = parser.parse_args()
    if args.mode == 'both' and args.connect != '127.0.0.1':
        parser.error('连接其他主机请使用 client 模式。')
    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    with (RUNTIME / 'launcher.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('另一个启动/停止操作正在进行，请稍后重试。')
        if args.mode == 'stop':
            stop_server()
            return
        if args.mode == 'status':
            record = read_json(RUNTIME / 'server.json')
            if alive(record): describe(record)
            else: print('服务端未运行。')
            return
        config = read_json(Path(args.config).expanduser())
        if not isinstance(config, dict) or not config:
            raise RuntimeError('配置文件不存在或不是有效 JSON 对象。')
        port = args.port if args.port is not None else int(config.get('port', 24567))
        if not 1024 <= port <= 65535:
            raise RuntimeError('端口必须在 1024–65535 之间。')
        godot = engine(args.godot)
        import_project(godot)
        if args.mode in ['both', 'server']:
            port = start_server(godot, args, config)
        if args.mode in ['both', 'client']:
            log = RUNTIME / ('client-' + uuid.uuid4().hex + '.log')
            with log.open('w', encoding='utf-8') as output:
                subprocess.Popen([godot, '--path', str(ROOT), '--', f'--connect={args.connect}',
                    f'--port={port}', f'--profile={args.profile}', f'--name={args.name}', f'--job={args.job}'],
                    cwd=ROOT, stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
            print(f'客户端已启动，日志：{log}\n关闭客户端后服务端继续运行。停服：./start.command stop')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f'启动器：{error}', file=sys.stderr)
        sys.exit(1)
