#!/usr/bin/env python3
"""Claude Code hooks that push the scripts Claude changed into the Godot editor.

    UserPromptSubmit -> claude_godot_sync.py start   remembers when the turn began
    Stop             -> claude_godot_sync.py stop    sends every .gd file modified since
                                                     then to Godot in one batch

Sending once at the end of the turn, rather than after each edit, keeps half-finished
changes across several scripts out of the running game. Going by modification time
also catches files changed through the shell, not just through the Edit tool.
Configured in .claude/settings.json; tools/godot_lsp_save.py does the sending.
"""

import json
import os
import sys
import tempfile

from godot_lsp_save import PROJECT, notify, project_scripts

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
            if name.endswith(".gd") and os.path.getmtime(path) > since:
                changed.append(path)
    return sorted(changed)


def touch(path: str) -> None:
    with open(path, "a"):
        os.utime(path)


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        session_id = json.load(sys.stdin).get("session_id", "")
    except ValueError:
        session_id = ""
    stamp = stamp_path(session_id)

    if mode == "start":
        touch(stamp)
        return 0
    if mode != "stop":
        print(f"usage: {sys.argv[0]} start|stop", file=sys.stderr)
        return 1

    if not os.path.exists(stamp):  # hooks were turned on mid-turn; start counting from now
        touch(stamp)
        return 0
    scripts = project_scripts(changed_since(os.path.getmtime(stamp)))
    touch(stamp)  # a second Stop in the same turn shouldn't resend these
    if not scripts:
        return 0
    names = ", ".join(os.path.relpath(p, PROJECT) for p in scripts)
    if error := notify(scripts):
        message = f"Godot not updated with {names}: {error}"
    else:
        message = f"Godot reloaded {names}"
    print(json.dumps({"systemMessage": message}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
