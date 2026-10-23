#!/usr/bin/env bash
# Builds the Windows and Linux versions of the game (the "Windows Desktop" and
# "Linux" presets in export_presets.cfg) into C:/godot_exports/bumper_blobs/.
# Exports from a copy of the project, so it works while the editor is open.
# Copy the linux/ file to the Linux computer and `chmod +x` it there.
set -euo pipefail
GD=${GD:-/mnt/c/godot/Godot_v4.7.2-stable_win64_console.exe}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=/mnt/c/godot_exports/bumper_blobs
COPY=$OUT/_project
mkdir -p "$OUT/windows" "$OUT/linux"
rsync -a --delete --exclude .git --exclude .godot/editor --exclude .godot/shader_cache "$ROOT/" "$COPY/"
W=$(wslpath -w "$COPY")
"$GD" --headless --path "$W" --import > "$OUT/export.log" 2>&1 || true
"$GD" --headless --path "$W" --export-release "Windows Desktop" "$(wslpath -w "$OUT/windows/BumperBlobs.exe")" >> "$OUT/export.log" 2>&1
"$GD" --headless --path "$W" --export-release "Linux" "$(wslpath -w "$OUT/linux/BumperBlobs.x86_64")" >> "$OUT/export.log" 2>&1
ls -la "$OUT/windows" "$OUT/linux"
