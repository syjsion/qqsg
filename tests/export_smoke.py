#!/usr/bin/env python3
"""Run the actual exported executable, using temporary server storage."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import plistlib

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('target',choices=['windows','macos','macos-server','linux-server'])
    args = parser.parse_args()
    folder = ROOT/'build'/args.target
    name = {'windows':'Sanguo.exe','macos':'Sanguo.app/Contents/MacOS/Sanguo',
            'macos-server':'SanguoServer.app/Contents/MacOS/SanguoServer',
            'linux-server':'SanguoServer.x86_64'}[args.target]
    executable = folder/name
    if args.target.startswith('macos'):
        app = folder/('SanguoServer.app' if args.target.endswith('server') else 'Sanguo.app')
        with (app/'Contents/Info.plist').open('rb') as f:
            executable = app/'Contents/MacOS'/plistlib.load(f)['CFBundleExecutable']
    with tempfile.TemporaryDirectory(prefix='qqsg-export-') as temporary:
        command = [str(executable),'--headless','--quit-after','120']
        if args.target.endswith('server'):
            command += ['--','--server',f'--config={folder/"server.json"}',f'--data_dir={temporary}','--port=25467']
        result = subprocess.run(command,cwd=folder,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
        print(result.stdout)
        if result.returncode or 'SCRIPT ERROR' in result.stdout or '\nERROR:' in result.stdout:
            raise SystemExit('Exported program failed smoke test')
        if args.target.endswith('server'):
            assert 'SERVER_READY' in result.stdout
            assert (Path(temporary)/'world.json').exists()
        print(f'EXPORT_SMOKE {args.target} PASS')

if __name__ == '__main__': main()
