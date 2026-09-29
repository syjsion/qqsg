#!/usr/bin/env python3
import argparse
import sys
import os
from pathlib import Path
import shutil
import platform
import subprocess
import zipfile

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
PRESETS = {'windows':('Windows','Sanguo.exe'), 'macos':('macOS','Sanguo.zip'),
           'macos-server':('macOS Server','SanguoServer.zip'), 'linux-server':('Linux Server','SanguoServer.x86_64')}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('target', choices=PRESETS)
    parser.add_argument('--godot', default=os.environ.get('GODOT','godot'))
    args = parser.parse_args()
    preset, name = PRESETS[args.target]
    output = ROOT / 'build' / args.target

    # This directory contains generated artifacts only (never source or server saves).
    if output.exists(): shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)
    result = subprocess.run([args.godot,'--headless','--path',str(ROOT),'--export-release',preset,str(output / name)], text=True,encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode or 'ERROR:' in result.stdout:
        print(result.stdout)
        raise SystemExit('export failed')
    shutil.copy2(ROOT/'README.md', output/'README.md')
    shutil.copy2(ROOT/'docs/PLAYING.md', output/'PLAYING.md')
    shutil.copy2(ROOT/'docs/ASSETS.md', output/'ASSETS.md')
    if args.target.startswith('macos'):
        with zipfile.ZipFile(output/name) as archive:
            archive.extractall(output)
            for entry in archive.infolist():
                mode = entry.external_attr >> 16
                if mode: (output/entry.filename).chmod(mode)
        (output/name).unlink()
        # Codesign locally on macOS; ad-hoc signing does not require a paid certificate.
        apps = list(output.glob('*.app'))
        if len(apps) != 1: raise RuntimeError('Expected one exported macOS app')
        app = output / ('SanguoServer.app' if args.target.endswith('server') else 'Sanguo.app')
        apps[0].rename(app)
        if platform.system() == 'Darwin':
            subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
    if args.target.endswith('server'):
        shutil.copy2(ROOT/'deploy/server.json',output/'server.json')
        script = 'start-server.command' if args.target == 'macos-server' else 'start-server.sh'
        shutil.copy2(ROOT/'deploy'/script,output/script)
        (output/script).chmod(0o755)
        if args.target == 'linux-server':
            (output/name).chmod(0o755)
            shutil.copy2(ROOT/'deploy/qqsg.service',output/'qqsg.service')
    commit = subprocess.run(['git','rev-parse','--short','HEAD'],cwd=ROOT,text=True,encoding="utf-8",stdout=subprocess.PIPE,stderr=subprocess.DEVNULL).stdout.strip() or 'working-tree'
    (output/'BUILD.txt').write_text(f'QQSG LAN 0.2.0\nGodot {(ROOT/".godot-version").read_text(encoding="utf-8").strip()}\nCommit {commit}\nTarget {args.target}\n', encoding='utf-8')
    # Create one zip that retains executable permissions on macOS/Linux.
    archive_path = ROOT/'build'/f'qqsg-{args.target}.zip'
    with zipfile.ZipFile(archive_path,'w',zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(output.rglob('*')):
            if path.is_file(): archive.write(path,Path('qqsg-'+args.target)/path.relative_to(output))
    print(f'PACKAGE_RESULT {archive_path}')

if __name__ == '__main__':
    main()
