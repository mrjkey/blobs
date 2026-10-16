#!/usr/bin/env python3
"""Claude Code hooks that push the files Claude changed into the Godot editor and game.

    UserPromptSubmit -> claude_godot_sync.py start   remembers when the turn began
    Stop             -> claude_godot_sync.py stop    pushes every .gd/.tscn/.tres file
                                                     modified since then, in one batch
    By hand          -> claude_godot_sync.py push FILE...

Scripts go to Godot's language server (tools/godot_lsp_save.py), which reloads them in
the running game. Scenes and resources go to the Claude Sync editor plugin
(addons/claude_sync), which reloads open scenes and refreshes resources in the game.

Pushing once at the end of the turn, rather than after each edit, keeps half-finished
changes across several files out of the running game. Going by modification time
also catches files changed through the shell, not just through the Edit tool.
Configured in .claude/settings.json.
"""

import json
import os
import socket
import sys
import tempfile

from godot_lsp_save import PROJECT, notify, project_scripts

EDITOR_PLUGIN_PORT = 6011  # addons/claude_sync/plugin.gd
EXTENSIONS = (".gd", ".tscn", ".tres")
SKIP_DIRS = {".godot", ".git", ".claude"}


def stamp_path(session_id: str) -> str:
    safe = "".join(c for c in session_id if c.isalnum() or c in "-_") or "default"
    return os.path.join(tempfile.gettempdir(), f"claude-godot-sync-{safe}")


def changed_since(since: float) -> list[str]:
    changed = []
    for root, dirs, files in os.walk(PROJECT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            path = os.path.join(root, name)
            if name.endswith(EXTENSIONS) and os.path.getmtime(path) > since:
                changed.append(path)
    return sorted(changed)


def touch(path: str) -> None:
    with open(path, "a"):
        os.utime(path)


def res_path(path: str) -> str:
    return "res://" + os.path.relpath(path, PROJECT).replace(os.sep, "/")


def rel(paths: list[str]) -> str:
    return ", ".join(p.removeprefix("res://") if p.startswith("res://") else os.path.relpath(p, PROJECT) for p in paths)


def reload_in_editor(scenes: list[str], resources: list[str]) -> dict:
    """Ask the editor plugin to reload these; returns its reply, or {"error": ...}."""
    request = {"scenes": [res_path(p) for p in scenes], "resources": [res_path(p) for p in resources]}
    try:
        # With WSL mirrored networking a closed port can hang instead of refusing, hence the timeout.
        with socket.create_connection(("127.0.0.1", EDITOR_PLUGIN_PORT), timeout=3) as conn:
            conn.sendall((json.dumps(request) + "\n").encode())
            conn.settimeout(10)
            reply = conn.makefile(encoding="utf-8").readline()
        return json.loads(reply)
    except (OSError, ValueError) as e:
        return {"error": f"can't reach the Claude Sync editor plugin on port {EDITOR_PLUGIN_PORT} "
                         f"({e or 'timed out'}); is it enabled in Project Settings > Plugins?"}


def push(files: list[str]) -> str | None:
    """Send changed files to Godot; returns a one-line summary, or None if there was nothing to send."""
    paths = [os.path.abspath(f) for f in files if os.path.isfile(f)]
    scripts = project_scripts(paths)
    scenes = [p for p in paths if p.endswith(".tscn") and p.startswith(PROJECT + os.sep)]
    resources = [p for p in paths if p.endswith(".tres") and p.startswith(PROJECT + os.sep)]
    parts = []

    # Scripts first, so reloaded scenes and resources find the code they expect.
    if scripts:
        error = notify(scripts)
        parts.append(f"scripts not sent ({rel(scripts)}): {error}" if error else f"reloaded {rel(scripts)}")

    if scenes or resources:
        reply = reload_in_editor(scenes, resources)
        if "error" in reply:
            parts.append(f"scenes/resources not sent ({rel(scenes + resources)}): {reply['error']}")
        else:
            if reply.get("reloaded_scenes"):
                parts.append(f"reloaded {rel(reply['reloaded_scenes'])}")
            if reply.get("scenes_not_open"):
                parts.append(f"not open in the editor, so not live ({rel(reply['scenes_not_open'])})")
            if resources:
                if reply.get("games_sent_resources"):
                    parts.append(f"refreshed {rel(resources)} in the running game")
                else:
                    parts.append(f"refreshed {rel(resources)} in the editor (no game running)")

    return "Godot: " + "; ".join(parts) if parts else None


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "push":
        summary = push(sys.argv[2:])
        print(summary or "nothing to send")
        return 0
    if mode not in ("start", "stop"):
        print(f"usage: {sys.argv[0]} start|stop  (hooks, JSON on stdin)  or  push FILE...", file=sys.stderr)
        return 1

    try:
        session_id = json.load(sys.stdin).get("session_id", "")
    except ValueError:
        session_id = ""
    stamp = stamp_path(session_id)
    if mode == "start" or not os.path.exists(stamp):  # no stamp: hooks turned on mid-turn
        touch(stamp)
        return 0

    changed = changed_since(os.path.getmtime(stamp))
    touch(stamp)  # a second Stop in the same turn shouldn't resend these
    if summary := push(changed):
        print(json.dumps({"systemMessage": summary}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
