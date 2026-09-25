#!/usr/bin/env python3
"""Install the pinned official Godot editor and templates. Python stdlib only."""
import argparse
import os
from pathlib import Path
import platform
import shutil
import stat
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / '.godot-version').read_text().strip()
BASE = f'https://github.com/godotengine/godot/releases/download/{VERSION}-stable/'

def fetch(name, target):
    if target.exists():
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + '.part')
    print(f'Downloading {name}', flush=True)
    urllib.request.urlretrieve(BASE + name, temporary)
    temporary.replace(target)

def templates_dir():
    system = platform.system()
    if system == 'Darwin':
        base = Path.home() / 'Library/Application Support/Godot'
    elif system == 'Windows':
        base = Path(os.environ['APPDATA']) / 'Godot'
    else:
        base = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'godot'
    return base / 'export_templates' / (VERSION + '.stable')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--templates', action='store_true')
    parser.add_argument('--templates-archive', type=Path)
    args = parser.parse_args()
    system = platform.system()
    suffix = {'Darwin':'macos.universal.zip', 'Windows':'win64.exe.zip', 'Linux':'linux.x86_64.zip'}[system]
    archive = ROOT / '.tools' / f'Godot_v{VERSION}-stable_{suffix}'
    executable = ROOT / '.tools' / ({'Darwin':'Godot.app/Contents/MacOS/Godot', 'Windows':f'Godot_v{VERSION}-stable_win64_console.exe', 'Linux':f'Godot_v{VERSION}-stable_linux.x86_64'}[system])
    if not executable.exists():
        fetch(archive.name, archive)
        with zipfile.ZipFile(archive) as z:
            z.extractall(ROOT / '.tools')
        if system != 'Windows': executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
    if args.templates:
        bundle = args.templates_archive or ROOT / '.tools' / f'Godot_v{VERSION}-stable_export_templates.tpz'
        if not bundle.exists(): fetch(bundle.name, bundle)
        target = templates_dir()
        target.mkdir(parents=True, exist_ok=True)
        wanted = {'version.txt', 'macos.zip', 'linux_debug.x86_64', 'linux_release.x86_64',
                  'windows_debug_x86_64.exe', 'windows_release_x86_64.exe',
                  'windows_debug_x86_64_console.exe', 'windows_release_x86_64_console.exe'}
        with zipfile.ZipFile(bundle) as z:
            for entry in z.infolist():
                name = Path(entry.filename).name
                if name in wanted:
                    with z.open(entry) as source, open(target / name, 'wb') as dest:
                        shutil.copyfileobj(source, dest)
        print(f'Templates: {target}')
    if os.environ.get('GITHUB_ENV'):
        with open(os.environ['GITHUB_ENV'], 'a') as f:
            f.write(f'GODOT={executable}\n')
    print(executable)

if __name__ == '__main__':
    main()
