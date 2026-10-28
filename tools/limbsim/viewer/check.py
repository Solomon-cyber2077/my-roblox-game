#!/usr/bin/env python3
"""Checks for the limb-sim viewer. Standard library only.

1. Format: every trace listed in ../traces/index.json and sample/index.json loads and follows the trace format
   (the same rules as LimbCore.validate in core.js).
2. Browser (skip with --no-browser): serves the viewer, opens it in headless Firefox with ?selftest=1, and waits
   for the page's report: every trace loaded, scrubbed, played to the end, every event clicked, no JS errors.
Usage: python3 check.py [--no-browser]; exit code 0 means everything passed.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True  # keep __pycache__ out of the synced folder
sys.path.insert(0, HERE)
import serve  # noqa: E402

STATES = {"Aboard", "Afield", "Looting", "Held", "Dead"}
ARMS = {"", "L", "R", "LR"}


def num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def check_trace(t):
    errs, notes = [], []
    meta, m, frames, events = t.get("meta"), t.get("map"), t.get("frames"), t.get("events", [])
    crew = {str(c.get("id")) for c in (meta or {}).get("crew", [])}
    if not crew:
        errs.append("meta.crew empty")
    for k in ("cols", "rows", "tile", "length"):
        if not num((m or {}).get(k)):
            errs.append("map.%s not a number" % k)
    if errs:
        return errs, notes
    tr = m.get("train") or {}
    if not all(num(tr.get(k)) for k in ("x0", "x1", "z")):
        errs.append("map.train bad")
    n = m["cols"] * m["rows"]
    bad = [i for i in m.get("blocked", []) if not isinstance(i, int) or not 0 <= i < n]
    if bad:
        errs.append("%d blocked cells out of range" % len(bad))
    bad = [b for b in m.get("buildings", []) if not (isinstance(b, list) and len(b) == 4 and all(map(num, b)))]
    if bad:
        errs.append("%d buildings not [x0,z0,x1,z1]" % len(bad))
    if not frames:
        errs.append("no frames")
        return errs, notes
    last = float("-inf")
    for f in frames:
        if not num(f.get("t")) or f["t"] < last:
            errs.append("frame times not increasing at %r" % f.get("t"))
            break
        last = f["t"]
        for pid, p in f.get("p", {}).items():
            if pid not in crew:
                errs.append("frame t=%s: player %s not in crew" % (f["t"], pid))
            elif not (isinstance(p, list) and len(p) >= 3 and num(p[0]) and num(p[1]) and p[2] in STATES):
                errs.append("frame t=%s: player %s entry %r" % (f["t"], pid, p))
            elif len(p) >= 5 and (p[3] not in ARMS or not num(p[4])):
                errs.append("frame t=%s: player %s arms/items %r" % (f["t"], pid, p[3:]))
        h = f.get("h", [])
        if h != {} and not (isinstance(h, list) and all(isinstance(x, list) and len(x) >= 2 and num(x[0]) and num(x[1]) for x in h)):
            errs.append("frame t=%s: hollows %r" % (f["t"], h))
        if len(errs) > 10:
            break
    for e in events:
        if not (num(e.get("t")) and isinstance(e.get("type"), str)):
            errs.append("event without t/type: %r" % e)
        for k in ("who", "by"):
            if k in e and str(e[k]) not in crew:
                errs.append("event %s: %s=%r not in crew" % (e.get("type"), k, e[k]))
    if [e["t"] for e in events] != sorted(e["t"] for e in events):
        notes.append("events out of time order (the viewer sorts them)")
    return errs, notes


def check_formats():
    ok, count = True, 0
    for label, folder in (("real", os.path.join(HERE, "..", "traces")), ("sample", os.path.join(HERE, "sample"))):
        index = os.path.join(folder, "index.json")
        if not os.path.exists(index):
            print("%-6s no index.json in %s" % (label, os.path.normpath(folder)))
            continue
        for item in json.load(open(index)):
            count += 1
            path = os.path.join(folder, item["file"])
            try:
                errs, notes = check_trace(json.load(open(path)))
            except (OSError, ValueError) as err:
                errs, notes = ["cannot load: %s" % err], []
            ok = ok and not errs
            print("%-6s %-4s %s%s" % (label, "ok" if not errs else "FAIL", item["file"], ("  (" + "; ".join(notes) + ")") if notes else ""))
            for e in errs[:10]:
                print("         " + e)
    return ok and count > 0


def check_browser():
    firefox = shutil.which("firefox")
    if not firefox:
        print("browser: SKIPPED (no firefox on PATH)")
        return None
    done = threading.Event()
    got = {}

    def on_report(r):
        got["r"] = r
        done.set()

    server, url = serve.start(on_report)
    profile = tempfile.mkdtemp(prefix="limbsim-ff-", dir=os.path.expanduser("~/snap/firefox/common")
                               if os.path.isdir(os.path.expanduser("~/snap/firefox/common")) else None)
    proc = subprocess.Popen([firefox, "--headless", "--no-remote", "--profile", profile, url + "?selftest=1"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        finished = done.wait(120)
    finally:
        proc.terminate()
        try:
            proc.wait(15)
        except subprocess.TimeoutExpired:
            proc.kill()
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)
    if not finished:
        print("browser: FAIL (no self-test report within 120s)")
        return False
    r = got["r"]
    ok = not r.get("errors") and r.get("rejectsBad") and r.get("summary") and r.get("traces") and all(x.get("ok") for x in r["traces"])
    for x in r.get("traces", []):
        print("browser %-4s %s  frames=%s events=%s crew=%s" % ("ok" if x.get("ok") else "FAIL", x["file"], x.get("frames"), x.get("events"), x.get("crew")))
        if x.get("error"):
            print("         " + x["error"].splitlines()[0])
    print("browser summary table rendered: %s; bad trace rejected cleanly: %s; JS errors: %d"
          % (r.get("summary"), r.get("rejectsBad"), len(r.get("errors") or [])))
    for e in (r.get("errors") or [])[:10]:
        print("         " + e)
    return bool(ok)


def main():
    fmt = check_formats()
    br = None if "--no-browser" in sys.argv else check_browser()
    print("format: %s; browser: %s" % ("PASS" if fmt else "FAIL", {None: "SKIPPED", True: "PASS", False: "FAIL"}[br]))
    sys.exit(0 if fmt and br is not False else 1)


if __name__ == "__main__":
    main()
