#!/usr/bin/env bash
# Online play test on this computer: tools/net_test.gd as host and as client,
# headless, from a copy of the project (so the editor can stay open). Extra
# arguments go to the client, e.g. --lag=200 --jitter=30 --loss=10.
# GAME=FOOTBALL (or TREADMILL, "DON'T GET FAT!") plays another game than RING.
# LATE=1 adds a third copy that joins during the game, to watch.
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
"$GD" --headless --path "$W" -s res://tools/net_test.gd -- role=host --bind=127.0.0.1 --name=HOST "game=${GAME:-RING}" "late=${LATE:-0}" > "$WORK/host.log" 2>&1 &
HOST=$!
sleep 2
if [ "${LATE:-0}" = 1 ]; then
	(sleep 9; "$GD" --headless --path "$W" -s res://tools/net_test.gd -- role=late --name=LATECOMER > "$WORK/late.log" 2>&1) &
	LATER=$!
fi
"$GD" --headless --path "$W" -s res://tools/net_test.gd -- role=client --name=GUEST "game=${GAME:-RING}" "$@" > "$WORK/client.log" 2>&1
wait $HOST
SIDES="host client"
if [ "${LATE:-0}" = 1 ]; then
	wait $LATER
	SIDES="host client late"
fi
for side in $SIDES; do
	echo "--- $side"
	grep -E '^(host|client):|PASS|FAIL|SCRIPT ERROR|Parse Error|^ERROR' "$WORK/$side.log"
done
grep -q '^PASS host' "$WORK/host.log" && grep -q '^PASS client' "$WORK/client.log" \
	&& { [ "${LATE:-0}" != 1 ] || grep -q '^PASS late' "$WORK/late.log"; }
