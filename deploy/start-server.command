#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p server-data
executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' SanguoServer.app/Contents/Info.plist)
exec "./SanguoServer.app/Contents/MacOS/$executable" --headless -- --server --config="$PWD/server.json" --data_dir="$PWD/server-data" "$@"
