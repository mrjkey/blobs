#!/usr/bin/env bash
# Builds the game for the platforms named (linux, windows, web; all three if
# none are) with the presets in export_presets.cfg, into
# C:/godot_exports/bumper_blobs/<platform>/. VERSION=1.2.0 stamps that version
# into the build (application/config/version, the Windows file version).
# Exports from a copy of the project, so it works while the editor is open.
# Copy the linux/ file to the Linux computer and `chmod +x` it there.
set -euo pipefail
GD=${GD:-/mnt/c/godot/Godot_v4.7.2-stable_win64_console.exe}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-/mnt/c/godot_exports/bumper_blobs}
COPY=$OUT/_project
PLATFORMS=("$@")
[ ${#PLATFORMS[@]} -gt 0 ] || PLATFORMS=(linux windows web)

mkdir -p "$OUT"
rsync -a --delete --exclude .git --exclude .godot/editor --exclude .godot/shader_cache "$ROOT/" "$COPY/"
if [ -n "${VERSION:-}" ]; then
	python3 - "$COPY/project.godot" "${VERSION#v}" <<'EOF'
import re, sys
path, version = sys.argv[1], sys.argv[2]
text = open(path, newline="").read()
text = re.sub(r'^config/version=.*\n', "", text, flags=re.M)
text = re.sub(r'^(config/name=.*\n)', r'\1config/version="%s"\n' % version, text, count=1, flags=re.M)
open(path, "w", newline="").write(text)
EOF
fi
W=$(wslpath -w "$COPY")
"$GD" --headless --path "$W" --import > "$OUT/export.log" 2>&1 || true

for p in "${PLATFORMS[@]}"; do
	case $p in
		linux) preset="Linux"; file=BumperBlobs.x86_64 ;;
		windows) preset="Windows Desktop"; file=BumperBlobs.exe ;;
		web) preset="Web"; file=index.html ;;
		*) echo "Unknown platform: $p (linux, windows or web)" >&2; exit 1 ;;
	esac
	rm -rf "${OUT:?}/$p"
	mkdir -p "$OUT/$p"
	echo "Exporting $p..."
	if ! "$GD" --headless --path "$W" --export-release "$preset" "$(wslpath -w "$OUT/$p/$file")" >> "$OUT/export.log" 2>&1 \
			|| [ ! -s "$OUT/$p/$file" ]; then
		echo "Export of $p failed, see $OUT/export.log" >&2
		exit 1
	fi
	ls -la "$OUT/$p"
done
