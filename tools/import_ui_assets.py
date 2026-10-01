#!/usr/bin/env python3
"""Import selected upstream UI images, never Godot caches; pin and hash each file."""
import hashlib
import json
from pathlib import Path
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "96db41b95dbae673aeba1c8365aa8da4c459dfe8"
FILES = ['assets/map/bajun/npc/铁匠/Sprite_5.png', 'UI/item_icons/金疮药.png', 'UI/item_icons/清心露.png', 'UI/item_icons/铁剑.png', 'item_slot_default_background.png', 'item_slot_empty_background.png', 'item_slot_selected_background.png']

def main():
    manifest_path = ROOT / "assets/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    entries = {entry["path"]: entry for entry in manifest["files"]}
    for source in FILES:
        target = ROOT / "assets/reference" / source
        url = f"https://raw.githubusercontent.com/Time1996/QQSanGuo/{COMMIT}/" + urllib.parse.quote(source)
        with urllib.request.urlopen(url, timeout=30) as response:
            data = response.read()
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        path = target.relative_to(ROOT).as_posix()
        entries[path] = {"path": path, "source_path": source, "sha256": hashlib.sha256(data).hexdigest()}
        print(path)
    manifest["files"] = list(entries.values())
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
