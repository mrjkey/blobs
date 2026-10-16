#!/usr/bin/env python3
"""Relay between VS Code (in WSL) and the Godot editor's language server (on Windows).

Godot knows this project by its Windows path (C:/dev/example_game), while VS Code in
WSL calls it /mnt/c/dev/example_game. With mismatched paths Godot can't map a saved
file to its res:// path, so saves from VS Code never reach the editor or the running
game ("Attempt to open script '/mnt/...' resulted in error 'File not found'").

This relay rewrites the project's file URIs in every message:
    VS Code -> Godot:  file:///mnt/c/dev/game  becomes  file:///C:/dev/game
    Godot -> VS Code:  file:///C%3A/dev/game   becomes  file:///mnt/c/dev/game
plus rootPath in the "initialize" request. Godot 4.7 then accepts the root as its
own project and maps every file under it to res://. Godot percent-encodes the drive
colon in what it sends back, so both spellings (and either drive case) are mapped.

A project inside WSL (//wsl.localhost/<distro>/home/...) works too: Godot gets
file:////wsl.localhost/... (four slashes; it misreads the usual UNC form
file://wsl.localhost/... as a host name) and sends back file:///wsl.localhost/....

Usage: python3 tools/godot_lsp_relay.py [--listen 6010] [--godot 6005]
Then point VS Code at it: "godotTools.lsp.serverPort": 6010 (.vscode/settings.json).
Avoid 6005 and 6008: godot-tools treats both as Godot defaults and goes straight to 6005.
The task in .vscode/tasks.json starts it when the folder opens.
"""

import argparse
import asyncio
import errno
import json
import os
import subprocess
import sys

HEADER_END = b"\r\n\r\n"


def windows_project_path(project_dir: str) -> str:
    """The project path the way Windows Godot sees it, e.g. C:/dev/game or //wsl.localhost/Ubuntu/home/me/game."""
    win = subprocess.run(["wslpath", "-w", project_dir], capture_output=True, text=True, check=True)
    return win.stdout.strip().replace("\\", "/")


def godot_uris(win_root: str) -> tuple[str, list[str]]:
    """The project root's URI to send Godot, and every form Godot may use for it in replies."""
    if win_root.startswith("//"):  # a UNC share, e.g. a project inside WSL
        return "file://" + win_root, ["file://" + win_root, "file:///" + win_root.lstrip("/")]
    drive, rest = win_root.split(":", 1)  # "C", "/dev/game"
    replies = [f"file:///{d}{colon}{rest}" for d in (drive.upper(), drive.lower()) for colon in (":", "%3A", "%3a")]
    return f"file:///{win_root}", replies


async def read_message(reader: asyncio.StreamReader) -> bytes | None:
    """The body of one LSP message, or None when the stream ends."""
    try:
        headers = await reader.readuntil(HEADER_END)
        length = 0
        for line in headers.split(b"\r\n"):
            if line.lower().startswith(b"content-length:"):
                length = int(line.split(b":", 1)[1])
        return await reader.readexactly(length)
    except (asyncio.IncompleteReadError, ConnectionError):
        return None


async def pump(reader, writer, swaps: list[tuple[bytes, bytes]], win_root: str | None = None) -> None:
    """Copy messages from reader to writer, applying each (old, new) swap to the body."""
    while (body := await read_message(reader)) is not None:
        for old, new in swaps:
            body = body.replace(old, new)
        if win_root and b'"initialize"' in body:
            data = json.loads(body)
            if data.get("method") == "initialize":
                data.setdefault("params", {})["rootPath"] = win_root
                body = json.dumps(data).encode()
                print(f"initialize: project root sent to Godot as {win_root}", flush=True)
        writer.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
        await writer.drain()
    writer.close()


async def handle(client_reader, client_writer, args, to_godot, to_client, win_root: str) -> None:
    try:
        godot_reader, godot_writer = await asyncio.open_connection("127.0.0.1", args.godot)
    except OSError as e:
        print(f"can't reach Godot on port {args.godot} ({e}); is the editor open?", flush=True)
        client_writer.close()
        return
    print("VS Code connected, relaying to Godot", flush=True)
    await asyncio.gather(
        pump(client_reader, godot_writer, to_godot, win_root),
        pump(godot_reader, client_writer, to_client),
        return_exceptions=True,
    )
    print("connection closed", flush=True)


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--listen", type=int, default=6010, help="port VS Code connects to")
    parser.add_argument("--godot", type=int, default=6005, help="Godot editor's language server port")
    parser.add_argument("--project", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    args = parser.parse_args()

    win_root = windows_project_path(args.project)    # C:/dev/game
    wsl_uri = ("file://" + args.project).encode()    # file:///mnt/c/dev/game
    win_uri_in, win_uris_out = godot_uris(win_root)  # file:///C:/dev/game, [file:///C%3A/dev/game, ...]
    to_godot = [(wsl_uri, win_uri_in.encode())]
    to_client = [(uri.encode(), wsl_uri) for uri in win_uris_out]
    # VS Code can launch the task again (e.g. on Reload Window) while the previous relay
    # is still shutting down, so give the port a few seconds to free up before giving up.
    for attempt in range(10):
        try:
            server = await asyncio.start_server(
                lambda r, w: handle(r, w, args, to_godot, to_client, win_root), "127.0.0.1", args.listen)
            break
        except OSError as e:
            if e.errno != errno.EADDRINUSE:
                raise
            if attempt == 0:
                print(f"port {args.listen} is busy; waiting for it to free up", flush=True)
            await asyncio.sleep(1)
    else:
        print(f"another relay is already listening on port {args.listen}; exiting", flush=True)
        return
    print(f"Godot LSP relay: 127.0.0.1:{args.listen} -> 127.0.0.1:{args.godot}", flush=True)
    print(f"  {wsl_uri.decode()}  ->  {win_uri_in}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
