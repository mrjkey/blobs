#!/usr/bin/env bash
# Makes a GitHub release: builds Linux, Windows and web, zips them, tags the
# current commit as <version> on GitHub and uploads the zips.
#
#   tools/release.sh v0.2.0          (or: make release VERSION=v0.2.0)
#
# The commit has to be pushed and the working tree clean, so the release's
# tag is exactly what was built (ALLOW_DIRTY=1 skips that check).
# NOTES=file.md uses that file for the release notes instead of the default.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${OUT:-/mnt/c/godot_exports/bumper_blobs}
VERSION=${1:-}
cd "$ROOT"

if [[ ! $VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
	echo "Usage: $0 v<major>.<minor>.<patch>   (e.g. v0.2.0)" >&2
	exit 1
fi
if [ -z "${ALLOW_DIRTY:-}" ] && [ -n "$(git status --porcelain)" ]; then
	echo "Uncommitted changes: commit them first, so the tag matches the build (or ALLOW_DIRTY=1)." >&2
	exit 1
fi
git fetch -q origin
COMMIT=$(git rev-parse HEAD)
if ! git branch -r --contains "$COMMIT" | grep -q .; then
	echo "Commit ${COMMIT:0:7} isn't on GitHub yet: push it first." >&2
	exit 1
fi
if gh release view "$VERSION" > /dev/null 2>&1; then
	echo "Release $VERSION already exists." >&2
	exit 1
fi

VERSION=$VERSION "$ROOT/tools/export_builds.sh" linux windows web
rm -rf "$OUT/dist"
python3 "$ROOT/tools/package_builds.py" "$VERSION" linux windows web

NOTES_FILE=${NOTES:-}
if [ -z "$NOTES_FILE" ]; then
	NOTES_FILE=$OUT/release_notes.md
	PREV=$(gh release list --limit 1 --json tagName --jq '.[0].tagName // ""')
	{
		cat <<EOF
Bumper Blobs $VERSION

## Downloads
- **Windows**: \`BumperBlobs-$VERSION-windows.zip\`. Unzip and run \`BumperBlobs.exe\`. Windows may warn that the app is unrecognised: More info, then Run anyway.
- **Linux**: \`BumperBlobs-$VERSION-linux.zip\`. Unzip and run \`./BumperBlobs.x86_64\` (\`chmod +x\` it if your unzip tool dropped the permission).
- **Web**: \`BumperBlobs-$VERSION-web.zip\`. On itch.io: upload the zip as an HTML game ("This file will be played in the browser"), viewport 1440 x 1000 or smaller, and tick "SharedArrayBuffer support": the game uses threads, which browsers only allow with it. Other hosts have to send the \`Cross-Origin-Opener-Policy: same-origin\` and \`Cross-Origin-Embedder-Policy: require-corp\` headers (\`tools/serve_web.py\` does, for testing). Opening \`index.html\` as a file doesn't work.

Online play (PLAY ONLINE) is in the Windows and Linux builds only: browsers can't open the network connections it uses.
EOF
		if [ -n "$PREV" ]; then
			printf '\n## Changes since %s\n' "$PREV"
			git log --no-merges --format='- %s' "$PREV..$COMMIT"
		fi
	} > "$NOTES_FILE"
fi

gh release create "$VERSION" "$OUT"/dist/*.zip --target "$COMMIT" --title "Bumper Blobs $VERSION" --notes-file "$NOTES_FILE"
