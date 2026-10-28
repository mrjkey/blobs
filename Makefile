# Builds and releases. The builds land in C:/godot_exports/bumper_blobs/
# (OUT=... to change); see tools/export_builds.sh.
#
#   make            build Linux, Windows and web
#   make linux      (or windows, web) build one
#   make serve      play the web build at http://localhost:8000
#   make package VERSION=v0.2.0   zip the builds into dist/
#   make release VERSION=v0.2.0   build, zip and publish a GitHub release
#   make net-test   online play test, host + client headless

OUT ?= /mnt/c/godot_exports/bumper_blobs
PORT ?= 8000
export OUT

.PHONY: all linux windows web serve package release net-test clean

all:
	tools/export_builds.sh linux windows web

linux windows web:
	tools/export_builds.sh $@

serve:
	@test -f "$(OUT)/web/index.html" || { echo "No web build: run make web first"; exit 1; }
	python3 tools/serve_web.py "$(OUT)/web" $(PORT)

package:
	@test -n "$(VERSION)" || { echo "Usage: make package VERSION=v0.2.0"; exit 1; }
	python3 tools/package_builds.py $(VERSION)

release:
	@test -n "$(VERSION)" || { echo "Usage: make release VERSION=v0.2.0"; exit 1; }
	tools/release.sh $(VERSION)

net-test:
	tools/net_test.sh

clean:
	rm -rf "$(OUT)/_project" "$(OUT)/linux" "$(OUT)/windows" "$(OUT)/web" "$(OUT)/dist"
