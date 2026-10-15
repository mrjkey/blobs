#!/usr/bin/env python3
"""Relay between VS Code (in WSL) and the Godot editor's language server (on Windows).

Godot knows this project as //wsl.localhost/<distro>/home/..., while VS Code in WSL
calls it /home/.... With mismatched paths Godot can't map a saved file to its
res:// path, so saves from VS Code never reach the editor or the running game
("Attempt to open script '/home/...' resulted in error 'File not found'").

This relay rewrites the project's file URIs in every message:
    VS Code -> Godot:  file:///home/me/game  becomes  file:////wsl.localhost/Ubuntu/home/me/game
    Godot -> VS Code:  file:///wsl.localhost/Ubuntu/home/me/game  becomes  file:///home/me/game
plus rootPath in the "initialize" request. Godot 4.7 then accepts the root as its
own project and maps every file under it to res://. (It misreads the usual UNC form
file://wsl.localhost/... as a host name, hence the four slashes going in.)

Usage: python3 tools/godot_lsp_relay.py [--listen 6008] [--godot 6005]
Then point VS Code at it: "godotTools.lsp.serverPort": 6008 (.vscode/settings.json).
The task in .vscode/tasks.json starts it when the folder opens.
"""

import argparse
import asyncio
import json
import os
import subprocess
import sys

HEADER_END = b"\r\n\r\n"


def windows_project_path(project_dir: str) -> str:
    """The project path the way Windows Godot sees it, e.g. //wsl.localhost/Ubuntu/home/me/game."""
    win = subprocess.run(["wslpath", "-w", project_dir], capture_output=True, text=True, check=True)
    return win.stdout.strip().replace("\\", "/")


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
    parser.add_argument("--listen", type=int, default=6008, help="port VS Code connects to")
    parser.add_argument("--godot", type=int, default=6005, help="Godot editor's language server port")
    parser.add_argument("--project", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    args = parser.parse_args()

    win_root = windows_project_path(args.project)                  # //wsl.localhost/Ubuntu/home/me/game
    wsl_uri = ("file://" + args.project).encode()                  # file:///home/me/game
    win_uri_in = ("file://" + win_root).encode()                   # file:////wsl.localhost/Ubuntu/home/me/game
    win_uri_out = ("file:///" + win_root.lstrip("/")).encode()     # file:///wsl.localhost/Ubuntu/home/me/game
    to_godot = [(wsl_uri, win_uri_in)]
    to_client = [(win_uri_in, wsl_uri), (win_uri_out, wsl_uri)]
    server = await asyncio.start_server(
        lambda r, w: handle(r, w, args, to_godot, to_client, win_root), "127.0.0.1", args.listen)
    print(f"Godot LSP relay: 127.0.0.1:{args.listen} -> 127.0.0.1:{args.godot}", flush=True)
    print(f"  {wsl_uri.decode()}  ->  {win_uri_in.decode()}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
