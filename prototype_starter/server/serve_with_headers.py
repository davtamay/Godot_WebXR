#!/usr/bin/env python3
"""Simple local server for exported Godot web builds.

Usage:
  cd path/to/exported/build
  python /path/to/serve_with_headers.py 8000

This is for local testing only. For headset testing, use an HTTPS-capable host.
"""

from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import sys

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"Serving on http://localhost:{port}")
    print("For WebXR headset testing, deploy over HTTPS instead of plain HTTP.")
    server.serve_forever()
