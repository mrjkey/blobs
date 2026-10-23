#!/usr/bin/env bash
# Online play test on this computer: tools/net_test.gd as host and as client,
# headless, from a copy of the project (so the editor can stay open). Extra
# arguments go to the client, e.g. --lag=200 --jitter=30 --loss=10.
# Logs: /mnt/c/godot_exports/bumper_blobs/_net_test/{host,client}.log
set -uo pipefail
GD=${GD:-/mnt/c/godot/Godot_v4.7.2-stable_win64_console.exe}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=/mnt/c/godot_exports/bumper_blobs/_net_test
mkdir -p "$WORK"
rsync -a --delete --exclude .git --exclude .godot/editor --exclude .godot/shader_cache "$ROOT/" "$WORK/project/"
sed -i 's/^config\/name=.*/config\/name="Bumper Blobs Net Test"/' "$WORK/project/project.godot"
W=$(wslpath -w "$WORK/project")
"$GD" --headless --path "$W" --import > "$WORK/import.log" 2>&1
"$GD" --headless --path "$W" -s res://tools/net_test.gd -- role=host --bind=127.0.0.1 --name=HOST > "$WORK/host.log" 2>&1 &
HOST=$!
sleep 2
"$GD" --headless --path "$W" -s res://tools/net_test.gd -- role=client --name=GUEST "$@" > "$WORK/client.log" 2>&1
wait $HOST
for side in host client; do
	echo "--- $side"
	grep -E '^(host|client):|PASS|FAIL|SCRIPT ERROR|Parse Error' "$WORK/$side.log"
done
grep -q '^PASS host' "$WORK/host.log" && grep -q '^PASS client' "$WORK/client.log"
