#!/usr/bin/env python3
"""Zips the builds that tools/export_builds.sh made, one zip per platform, for
a release: <out>/dist/BumperBlobs-<version>-<platform>.zip.

    python3 tools/package_builds.py <version> [linux windows web]

Keeps the Linux binary executable (the zip stores file modes).
"""
import os
import sys
import zipfile

OUT = os.environ.get("OUT", "/mnt/c/godot_exports/bumper_blobs")
PLATFORMS = ["linux", "windows", "web"]


def package(version: str, platform: str) -> str:
    src = os.path.join(OUT, platform)
    if not os.path.isdir(src) or not os.listdir(src):
        sys.exit(f"No {platform} build in {src}: run tools/export_builds.sh {platform} first")
    os.makedirs(os.path.join(OUT, "dist"), exist_ok=True)
    path = os.path.join(OUT, "dist", f"BumperBlobs-{version}-{platform}.zip")
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for root, _dirs, files in os.walk(src):
            for name in sorted(files):
                full = os.path.join(root, name)
                info = zipfile.ZipInfo.from_file(full, os.path.relpath(full, src))
                # /mnt/c reports every file as 777: give the zip sane modes.
                executable = platform == "linux" and name.endswith(".x86_64")
                info.external_attr = (0o100755 if executable else 0o100644) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                with open(full, "rb") as f:
                    z.writestr(info, f.read())
    return path


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    version = sys.argv[1]
    for platform in sys.argv[2:] or PLATFORMS:
        path = package(version, platform)
        print(f"{path}  {os.path.getsize(path) / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
