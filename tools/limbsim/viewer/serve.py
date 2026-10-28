#!/usr/bin/env python3
"""Serve the limb-sim viewer on a free localhost port and open it in the default browser.

Serves tools/limbsim/ (so the page can read ../traces/ and ../summary.json) on 127.0.0.1 only.
Exits by itself once no open viewer page has pinged it for IDLE_SECONDS. Standard library only.
Usage: python3 serve.py [--no-browser]
"""
import functools
import http.server
import json
import os
import socketserver
import sys
import threading
import time
import webbrowser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # tools/limbsim
IDLE_SECONDS = 15 * 60


class Handler(http.server.SimpleHTTPRequestHandler):
    server_version = "LimbSimViewer"

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        self.server.last_seen = time.time()
        if self.path.startswith("/__ping"):
            self.send_response(204)
            self.end_headers()
            return
        super().do_GET()

    def do_POST(self):
        self.server.last_seen = time.time()
        on_report = getattr(self.server, "on_report", None)
        if self.path != "/__report" or on_report is None:
            self.send_error(404)
            return
        size = min(int(self.headers.get("Content-Length") or 0), 4 * 1024 * 1024)
        body = self.rfile.read(size)
        self.send_response(204)
        self.end_headers()
        try:
            on_report(json.loads(body or b"null"))
        except ValueError:
            on_report({"errors": ["report was not JSON"]})

    def log_message(self, fmt, *args):
        pass


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = False


def start(on_report=None):
    """Start the server on a free port in a background thread; returns (server, base_url)."""
    server = Server(("127.0.0.1", 0), functools.partial(Handler, directory=ROOT))
    server.last_seen = time.time()
    server.on_report = on_report
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, "http://127.0.0.1:%d/viewer/" % server.server_address[1]


def main():
    server, url = start()
    print("LTO Limb Sim viewer: " + url + " (stops after %d idle minutes)" % (IDLE_SECONDS // 60), flush=True)
    if "--no-browser" not in sys.argv:
        webbrowser.open(url)
    try:
        while time.time() - server.last_seen < IDLE_SECONDS:
            time.sleep(5)
    except KeyboardInterrupt:
        pass
    server.shutdown()


if __name__ == "__main__":
    main()
