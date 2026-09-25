#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p server-data
exec ./SanguoServer.x86_64 --headless -- --server --config="$PWD/server.json" --data_dir="$PWD/server-data" "$@"
