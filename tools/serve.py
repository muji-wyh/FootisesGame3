"""Tiny static server for the exported web build (Brawl Arena).

    python tools/serve.py [port]      # default 8080

Serves web-build/ with the correct WASM MIME type and cross-origin isolation headers.
The game is exported in no-threads mode, so the isolation headers are not strictly
required - but they are harmless and make the server work for threaded builds too.
Open http://localhost:8080/ in Chrome.
"""
import http.server
import os
import socketserver
import sys

DIRECTORY = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "web-build"))
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "text/javascript",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print("Serving %s at http://localhost:%d/" % (DIRECTORY, PORT))
        httpd.serve_forever()


if __name__ == "__main__":
    main()
