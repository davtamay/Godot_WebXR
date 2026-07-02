#!/usr/bin/env python3
"""Local static server for web builds and the capability probe.

Extends prototype_starter/server/serve_with_headers.py with --directory and
optional header suppression, so one script covers both hosting profiles:

  isolated (default): COOP/COEP headers on -> crossOriginIsolated=true,
      SharedArrayBuffer available (what Godot THREADED web exports require).
  --no-isolation: plain static hosting (GitHub-Pages-like) -> what Godot
      NON-threaded (nothreads) web exports are built for.

Local testing only. Headset/WebXR device testing needs HTTPS hosting.
"""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class Handler(SimpleHTTPRequestHandler):
    isolate = True

    def end_headers(self):
        if self.isolate:
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
            self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("port", nargs="?", type=int, default=8000)
    parser.add_argument("--directory", default=".")
    parser.add_argument("--no-isolation", action="store_true",
                        help="serve without COOP/COEP (plain-host profile)")
    args = parser.parse_args()

    Handler.isolate = not args.no_isolation
    handler = partial(Handler, directory=args.directory)
    server = ThreadingHTTPServer(("0.0.0.0", args.port), handler)
    profile = "isolated (COOP/COEP)" if Handler.isolate else "plain (no isolation)"
    print(f"Serving {args.directory} on http://localhost:{args.port} [{profile}]")
    server.serve_forever()


if __name__ == "__main__":
    main()
