#!/usr/bin/env python3
"""Serves the web build at http://localhost:<port> for testing.

    python3 tools/serve_web.py <web build folder> [port]

The web build uses threads (the music renders on one), which browsers only
allow on cross-origin isolated pages: this sends the headers that do that,
like itch.io's "SharedArrayBuffer support" option.
"""
import http.server
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    folder = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", port), lambda *a: Handler(*a, directory=folder))
    print(f"Serving {folder} at http://localhost:{port} (Ctrl+C to stop)")
    server.serve_forever()


if __name__ == "__main__":
    main()
