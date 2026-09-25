#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec "${GODOT:-godot}" --headless --path . -- --server --config="${QQSG_CONFIG:-res://deploy/server.json}" "$@"
