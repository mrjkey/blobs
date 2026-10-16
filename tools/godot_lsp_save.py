#!/usr/bin/env python3
"""Tell the Godot editor that scripts changed on disk, as if VS Code had just saved them.

Edits made outside VS Code and Godot (by a script, or by Claude Code) land on disk with
no textDocument/didSave, so Godot neither reloads the script nor pushes it into the
running game. This sends that notification through tools/godot_lsp_relay.py, which
fixes the paths the same way it does for VS Code.

Usage: python3 tools/godot_lsp_save.py ui/menus/treadmill_menu.gd [more.gd ...]
Only .gd files are sent; Godot's language server doesn't reload scenes or resources.
"""

import argparse
import asyncio
import json
import os
import sys
from urllib.parse import quote

from godot_lsp_relay import read_message

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


async def send(writer: asyncio.StreamWriter, msg: dict) -> None:
    body = json.dumps({"jsonrpc": "2.0", **msg}).encode()
    writer.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    await writer.drain()


async def response(reader: asyncio.StreamReader, msg_id: int) -> dict:
    """Wait for the reply to request msg_id, skipping Godot's notifications."""
    while (body := await read_message(reader)) is not None:
        msg = json.loads(body)
        if msg.get("id") == msg_id and "method" not in msg:
            return msg
    raise ConnectionError("connection closed before Godot replied")


class RelayUnreachable(Exception):
    pass


async def notify_saved(paths: list[str], port: int) -> None:
    # With WSL mirrored networking a closed port can hang instead of refusing, hence the timeout.
    try:
        reader, writer = await asyncio.wait_for(asyncio.open_connection("127.0.0.1", port), timeout=3)
    except OSError as e:  # TimeoutError is an OSError
        raise RelayUnreachable(str(e) or "timed out") from e
    await send(writer, {"id": 1, "method": "initialize", "params": {
        "processId": os.getpid(),
        "rootUri": "file://" + quote(PROJECT),
        "rootPath": PROJECT,
        "capabilities": {},
    }})
    await response(reader, 1)
    await send(writer, {"method": "initialized", "params": {}})
    for path in paths:
        with open(path, encoding="utf-8") as f:
            text = f.read()
        await send(writer, {"method": "textDocument/didSave", "params": {
            "textDocument": {"uri": "file://" + quote(path)},
            "text": text,
        }})
    # didSave gets no reply. Godot handles messages in order, so once this request is
    # answered the saves have been processed and it's safe to hang up.
    await send(writer, {"id": 2, "method": "textDocument/documentSymbol", "params": {
        "textDocument": {"uri": "file://" + quote(paths[-1])},
    }})
    await response(reader, 2)
    writer.close()


def project_scripts(files: list[str]) -> list[str]:
    """The absolute paths of the .gd files in this project among files."""
    paths = [os.path.abspath(f) for f in files]
    return [p for p in paths if p.endswith(".gd") and p.startswith(PROJECT + os.sep) and os.path.isfile(p)]


def notify(scripts: list[str], port: int = 6010) -> str | None:
    """Send the saves to Godot; returns what went wrong, or None if Godot took them."""
    try:
        asyncio.run(asyncio.wait_for(notify_saved(scripts, port), timeout=10))
    except RelayUnreachable as e:
        return f"can't reach the LSP relay on port {port} ({e}); is the relay task running?"
    except OSError as e:  # includes TimeoutError and ConnectionError
        return f"Godot didn't answer ({e or 'timed out'}); is the editor open?"
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("files", nargs="+")
    parser.add_argument("--relay", type=int, default=6010, help="port the LSP relay listens on")
    args = parser.parse_args()

    scripts = project_scripts(args.files)
    if not scripts:
        return 0
    if error := notify(scripts, args.relay):
        print(error, file=sys.stderr)
        return 1
    for p in scripts:
        print(f"Godot notified of save: {os.path.relpath(p, PROJECT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
