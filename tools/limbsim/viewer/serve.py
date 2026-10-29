#!/usr/bin/env python3
"""Serve the limb-sim viewer on a free localhost port and open it in the default browser.

Serves tools/limbsim/ (so the page can read ../traces/ and ../summary.json) on 127.0.0.1 only.
Exits by itself once no open viewer page has pinged it for IDLE_SECONDS (never while a sim is running).
Standard library only. Usage: python3 serve.py [--no-browser]

New session (POST /__new): runs `lune run limbsim --one --seed=<random> --out=tools/limbsim/traces/live/<id>.json`
in the repo, one at a time, killed after SIM_TIMEOUT seconds. It writes only into traces/live/. It refuses to start
until .lune/limbsim.luau has the --one mode, because without it lune would run the full batch and rewrite
traces/ and summary.json. GET /__job is the job's state, GET /__live lists the finished live traces and
GET /__livefile/<id>.json serves one.
"""
import functools
import http.server
import json
import os
import random
import re
import signal
import socketserver
import subprocess
import sys
import threading
import time
import webbrowser

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # tools/limbsim
REPO = os.path.dirname(os.path.dirname(ROOT))  # the game folder (~/roblox-shared)
LIVE_DIR = os.path.join(ROOT, "traces", "live")
LUNE = os.path.expanduser("~/.rokit/bin/lune")
SIM_SCRIPT = os.path.join(REPO, ".lune", "limbsim.luau")
IDLE_SECONDS = 15 * 60
SIM_TIMEOUT = 180
LIVE_NAME = re.compile(r"^live-[0-9]{8}-[0-9]{6}-[0-9]{1,10}\.json$")


class Job:
    """One sim run at a time. command() and supported() are replaceable so check.py can test without lune."""

    def __init__(self, live_dir=LIVE_DIR):
        self.live_dir = live_dir
        self.lock = threading.Lock()
        self.state = {"state": "idle"}
        self.proc = None

    def supported(self):
        try:
            with open(SIM_SCRIPT, encoding="utf-8") as f:
                text = f.read()
        except OSError:
            return False, "no .lune/limbsim.luau in " + REPO
        if "--one" not in text:
            return False, "the HP's `lune run limbsim --one` mode is not in .lune/limbsim.luau yet"
        if not os.access(LUNE, os.X_OK):
            return False, "lune not found at " + LUNE
        return True, ""

    def command(self, seed, out):
        return [LUNE, "run", "limbsim", "--one", "--seed=%d" % seed, "--out=" + os.path.relpath(out, REPO)]

    def status(self):
        with self.lock:
            s = dict(self.state)
        if s["state"] == "running":
            s["elapsed"] = round(time.time() - s["started"], 1)
        return s

    def start(self):
        ok, why = self.supported()
        if not ok:
            return 503, {"error": why}
        with self.lock:
            if self.state["state"] == "running":
                return 409, {"error": "a session is already being simulated", "id": self.state["id"]}
            seed = random.SystemRandom().randint(1, 2**31 - 1)
            rid = "live-%s-%d" % (time.strftime("%Y%m%d-%H%M%S"), seed)
            out = os.path.join(self.live_dir, rid + ".json")
            self.state = {"state": "running", "id": rid, "seed": seed, "file": rid + ".json", "started": time.time()}
        threading.Thread(target=self._run, args=(rid, seed, out), daemon=True).start()
        return 202, {"id": rid, "seed": seed}

    def _finish(self, rid, **fields):
        with self.lock:
            if self.state.get("id") == rid:
                self.state = {"state": fields.pop("state"), "id": rid, "file": rid + ".json", "seed": self.state.get("seed"),
                              "seconds": round(time.time() - self.state.get("started", time.time()), 1), **fields}

    def _run(self, rid, seed, out):
        os.makedirs(self.live_dir, exist_ok=True)
        try:
            proc = subprocess.Popen(self.command(seed, out), cwd=REPO, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, start_new_session=True)
        except OSError as err:
            return self._finish(rid, state="error", error="could not start lune: %s" % err)
        self.proc = proc
        try:
            output, _ = proc.communicate(timeout=SIM_TIMEOUT)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                proc.kill()
            proc.communicate()
            return self._finish(rid, state="error", error="the sim took longer than %d s and was stopped" % SIM_TIMEOUT)
        finally:
            self.proc = None
        tail = (output or b"").decode("utf-8", "replace").strip().splitlines()[-12:]
        if proc.returncode != 0:
            return self._finish(rid, state="error", error="lune exited with code %d" % proc.returncode, log=tail)
        try:
            with open(out, encoding="utf-8") as f:
                trace = json.load(f)
            if not isinstance(trace, dict) or not trace.get("frames"):
                raise ValueError("no frames")
        except (OSError, ValueError) as err:
            return self._finish(rid, state="error", error="the sim did not write a usable trace (%s)" % err, log=tail)
        self._finish(rid, state="done", log=tail)

    def stop(self):
        proc = self.proc
        if proc and proc.poll() is None:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except OSError:
                pass


def live_list(live_dir, cache={}):
    """The finished live traces, newest first, with a title built from each trace (cached by mtime)."""
    items = []
    try:
        names = [n for n in os.listdir(live_dir) if LIVE_NAME.match(n)]
    except OSError:
        return items
    for name in names:
        path = os.path.join(live_dir, name)
        try:
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        key = (path, mtime)
        if key not in cache:
            try:
                with open(path, encoding="utf-8") as f:
                    t = json.load(f)
                crew = [str(c.get("name")) for c in t["meta"]["crew"]]
                stops = t["meta"].get("stops") or []
                cache[key] = {"file": name, "id": name[:-5], "kind": "live", "crew": crew, "stops": len(stops),
                              "outcome": (t.get("summary") or {}).get("text", ""), "mtime": mtime,
                              "title": "New session %s · seed %s: %s" % (time.strftime("%H:%M", time.localtime(mtime)),
                                                                        t["meta"].get("seed", "?"), ", ".join(crew))}
            except (OSError, ValueError, KeyError, TypeError):
                cache[key] = None  # still being written, or not a trace
        if cache[key]:
            items.append(cache[key])
    return sorted(items, key=lambda x: -x["mtime"])


class Handler(http.server.SimpleHTTPRequestHandler):
    server_version = "LimbSimViewer"

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def send_json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def local_request(self):
        """Only this page may drive the server: Host must be our loopback address (stops DNS rebinding) and POSTs
        must carry the X-LimbSim header, which a page on another site cannot send without a CORS preflight."""
        port = self.server.server_address[1]
        return self.headers.get("Host") in ("127.0.0.1:%d" % port, "localhost:%d" % port)

    def do_GET(self):
        self.server.last_seen = time.time()
        if not self.local_request():
            return self.send_error(403)
        path = self.path.split("?", 1)[0]
        if path == "/__ping":
            self.send_response(204)
            self.end_headers()
        elif path == "/__job":
            ok, why = self.server.job.supported()
            self.send_json(200, {**self.server.job.status(), "supported": ok, "why": why})
        elif path == "/__live":
            self.send_json(200, live_list(self.server.job.live_dir))
        elif path.startswith("/__livefile/"):
            name = path[len("/__livefile/"):]
            full = os.path.join(self.server.job.live_dir, name)
            if not LIVE_NAME.match(name) or not os.path.isfile(full):
                return self.send_error(404)
            with open(full, "rb") as f:
                body = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()

    def do_POST(self):
        self.server.last_seen = time.time()
        if not self.local_request():
            return self.send_error(403)
        if self.path == "/__new":
            if self.headers.get("X-LimbSim") != "1":
                return self.send_error(403)
            code, body = self.server.job.start()
            return self.send_json(code, body)
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


def start(on_report=None, job=None):
    """Start the server on a free port in a background thread; returns (server, base_url)."""
    server = Server(("127.0.0.1", 0), functools.partial(Handler, directory=ROOT))
    server.last_seen = time.time()
    server.on_report = on_report
    server.job = job or Job()
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, "http://127.0.0.1:%d/viewer/" % server.server_address[1]


def main():
    server, url = start()
    print("LTO Limb Sim viewer: " + url + " (stops after %d idle minutes)" % (IDLE_SECONDS // 60), flush=True)
    if "--no-browser" not in sys.argv:
        webbrowser.open(url)
    try:
        while time.time() - server.last_seen < IDLE_SECONDS or server.job.status()["state"] == "running":
            time.sleep(5)
    except KeyboardInterrupt:
        pass
    server.job.stop()
    server.shutdown()


if __name__ == "__main__":
    main()
