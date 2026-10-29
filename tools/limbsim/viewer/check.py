#!/usr/bin/env python3
"""Checks for the limb-sim viewer. Standard library only.

1. Format: every trace in ../traces/index.json, ../traces/live/ and sample/index.json loads and follows the trace
   format, v2 or v3 (the same rules as LimbCore.validate in core.js), and the summaries follow summary v2/v3.
2. Server: serve.py answers on 127.0.0.1 only, refuses a New session POST without its header or with a foreign Host,
   and reports whether the real `lune run limbsim --one` mode is available.
3. Browser (skip with --no-browser): serves the viewer with a stand-in sim (copies the v3 sample, so New session can
   be tested before HP's --one mode exists; output goes to a temp folder, never to traces/live/), opens it in
   headless Firefox with ?selftest=1 and waits for the page's report: every trace replayed, every v3 trace spectated
   in Live (bubbles, feed, mood bars), a New session made and played, the Reports tab rendered, no JS errors.
Usage: python3 check.py [--no-browser]; exit code 0 means everything passed.
"""
import http.client
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

STATES = {"Aboard", "Afield", "Looting", "Held", "Dead", "LeftBehind", "Left"}
ARMS = {"", "L", "R", "LR"}
SAY_KINDS = {"complaint", "bug", "confusion", "praise", "social", "quit"}
CONNECTIONS = {"wifi", "mobile", "ethernet"}
MOTIVES = {"social", "thrill", "mastery", "explore", "chill"}


def num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def is_mood(m):
    return isinstance(m, list) and len(m) >= 5 and all(num(v) and 0 <= v <= 1 for v in m[:5])


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
    # v3 additions (all optional)
    v3 = False
    for c in meta.get("crew", []):
        p = c.get("profile")
        if p is None:
            continue
        v3 = True
        if not isinstance(p, dict):
            errs.append("crew %s: profile not an object" % c.get("id"))
            continue
        if p.get("connection") is not None and p["connection"] not in CONNECTIONS:
            notes.append("crew %s: connection %r not in %s" % (c.get("id"), p["connection"], sorted(CONNECTIONS)))
        if p.get("motive") is not None and p["motive"] not in MOTIVES:
            notes.append("crew %s: motive %r not in %s" % (c.get("id"), p["motive"], sorted(MOTIVES)))
        traits = p.get("traits", {})
        if not isinstance(traits, dict) or not all(num(v) and 0 <= v <= 1 for v in traits.values()):
            errs.append("crew %s: traits not {name: 0..1}" % c.get("id"))
    stops = meta.get("stops")
    if stops is not None:
        v3 = True
        if not isinstance(stops, list) or not all(isinstance(s, dict) and num(s.get("n")) and num(s.get("startT")) and num(s.get("endT")) for s in stops):
            errs.append("meta.stops entries need n, startT, endT")
    if not frames:
        errs.append("no frames")
        return errs, notes
    last = float("-inf")
    for f in frames:
        if not num(f.get("t")) or f["t"] < last:
            errs.append("frame times not increasing at %r" % f.get("t"))
            break
        last = f["t"]
        if "stop" in f and not num(f["stop"]):
            errs.append("frame t=%s: stop %r" % (f["t"], f["stop"]))
        for pid, p in f.get("p", {}).items():
            if pid not in crew:
                errs.append("frame t=%s: player %s not in crew" % (f["t"], pid))
            elif not (isinstance(p, list) and len(p) >= 3 and num(p[0]) and num(p[1]) and p[2] in STATES):
                errs.append("frame t=%s: player %s entry %r" % (f["t"], pid, p))
            elif len(p) >= 5 and (p[3] not in ARMS or not num(p[4])):
                errs.append("frame t=%s: player %s arms/items %r" % (f["t"], pid, p[3:]))
            elif len(p) >= 6:
                v3 = True
                if not is_mood(p[5]):
                    errs.append("frame t=%s: player %s mood %r" % (f["t"], pid, p[5]))
        h = f.get("h", [])
        if h != {} and not (isinstance(h, list) and all(isinstance(x, list) and len(x) >= 2 and num(x[0]) and num(x[1]) for x in h)):
            errs.append("frame t=%s: hollows %r" % (f["t"], h))
        if len(errs) > 10:
            break
    for e in events:
        if not (num(e.get("t")) and isinstance(e.get("type"), str)):
            errs.append("event without t/type: %r" % e)
            continue
        for k in ("who", "by"):
            if k in e and str(e[k]) not in crew:
                errs.append("event %s: %s=%r not in crew" % (e.get("type"), k, e[k]))
        if e["type"] == "say":
            v3 = True
            if not isinstance(e.get("text"), str) or e.get("kind") not in SAY_KINDS:
                errs.append("say at t=%s: kind %r / text %r" % (e["t"], e.get("kind"), e.get("text")))
            elif e["kind"] == "bug" and "detail" not in e:
                errs.append("bug report at t=%s has no detail (bugs must come from a real detection)" % e["t"])
        elif e["type"] == "stop" and not num(e.get("n")):
            errs.append("stop event at t=%s without n" % e["t"])
    if [e["t"] for e in events if num(e.get("t"))] != sorted(e["t"] for e in events if num(e.get("t"))):
        notes.append("events out of time order (the viewer sorts them)")
    notes.insert(0, "v3" if v3 else "v2")
    return errs, notes


def check_summary(s):
    """summary v2 (sessions, totals, byStation, rescue) or v3 (+ population, feedback, features, byHour, byDevice)."""
    errs = []
    if not isinstance(s, dict):
        return ["not an object"], "?"
    v3 = any(k in s for k in ("feedback", "features", "byHour", "byDevice", "population"))
    fb = s.get("feedback")
    if fb is not None:
        for k in ("complaints", "praise"):
            for topic, v in (fb.get(k) or {}).items():
                if not (num(v) or (isinstance(v, dict) and num(v.get("count")))):
                    errs.append("feedback.%s.%s needs a count" % (k, topic))
        if not isinstance(fb.get("bugs", []), list) or not all(isinstance(b, dict) and "topic" in b for b in fb.get("bugs", [])):
            errs.append("feedback.bugs entries need a topic")
    for f in s.get("features", []) or []:
        if not isinstance(f, dict) or "name" not in f:
            errs.append("feature without name: %r" % f)
    for k in ("byHour", "byDevice", "population"):
        if k in s and not isinstance(s[k], dict):
            errs.append("%s not an object" % k)
    return errs, "v3" if v3 else "v2"


def check_formats():
    ok, count = True, 0
    sets = [("real", os.path.join(HERE, "..", "traces"), None), ("sample", os.path.join(HERE, "sample"), None)]
    live = serve.LIVE_DIR
    if os.path.isdir(live):
        sets.append(("live", live, [{"file": n} for n in sorted(os.listdir(live)) if serve.LIVE_NAME.match(n)]))
    for label, folder, listed in sets:
        index = os.path.join(folder, "index.json")
        if listed is None:
            if not os.path.exists(index):
                print("%-6s no index.json in %s" % (label, os.path.normpath(folder)))
                continue
            listed = json.load(open(index))
        for item in listed:
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
    for label, path in (("real", os.path.join(HERE, "..", "summary.json")), ("sample", os.path.join(HERE, "sample", "summary-v3.json"))):
        if not os.path.exists(path):
            print("%-6s no %s" % (label, os.path.basename(path)))
            continue
        try:
            errs, ver = check_summary(json.load(open(path)))
        except ValueError as err:
            errs, ver = ["not JSON: %s" % err], "?"
        ok = ok and not errs
        print("%-6s %-4s %s  (summary %s)" % (label, "ok" if not errs else "FAIL", os.path.basename(path), ver))
        for e in errs[:10]:
            print("         " + e)
    return ok and count > 0


class FakeJob(serve.Job):
    """Stands in for lune: writes a copy of the v3 sample, with the new seed, into a temp folder."""

    def supported(self):
        return True, ""

    def command(self, seed, out):
        src = os.path.join(HERE, "sample", "sample-v3-run.json")
        code = "import json,sys; t=json.load(open(sys.argv[1])); t['meta']['seed']=int(sys.argv[2]); json.dump(t, open(sys.argv[3], 'w'))"
        return [sys.executable, "-c", code, src, str(seed), out]


def check_server():
    ok = True
    tmp = tempfile.mkdtemp(prefix="limbsim-live-")
    server, url = serve.start(None, FakeJob(tmp))
    port = server.server_address[1]

    def req(method, path, headers=None):
        c = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
        c.request(method, path, headers=headers or {})
        r = c.getresponse()
        r.read()
        return r.status

    try:
        host = server.server_address[0]
        cases = [
            ("listens on 127.0.0.1 only", host == "127.0.0.1"),
            ("POST /__new without X-LimbSim header refused", req("POST", "/__new") == 403),
            ("foreign Host refused", req("GET", "/__job", {"Host": "evil.example:%d" % port}) == 403),
            ("bad live file name refused", req("GET", "/__livefile/..%2Fsummary.json") == 404),
            ("GET /__job answers", req("GET", "/__job") == 200),
        ]
        for name, passed in cases:
            ok = ok and passed
            print("server %-4s %s" % ("ok" if passed else "FAIL", name))
    finally:
        server.shutdown()
        shutil.rmtree(tmp, ignore_errors=True)
    real_ok, why = serve.Job().supported()
    print("server note: real New session (lune run limbsim --one): %s" % ("available" if real_ok else "NOT AVAILABLE: " + why))
    return ok


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

    tmp = tempfile.mkdtemp(prefix="limbsim-live-")
    server, url = serve.start(on_report, FakeJob(tmp))
    profile = tempfile.mkdtemp(prefix="limbsim-ff-", dir=os.path.expanduser("~/snap/firefox/common")
                               if os.path.isdir(os.path.expanduser("~/snap/firefox/common")) else None)
    proc = subprocess.Popen([firefox, "--headless", "--no-remote", "--profile", profile, url + "?selftest=1"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        finished = done.wait(240)
    finally:
        proc.terminate()
        try:
            proc.wait(15)
        except subprocess.TimeoutExpired:
            proc.kill()
        server.shutdown()
        shutil.rmtree(profile, ignore_errors=True)
        shutil.rmtree(tmp, ignore_errors=True)
    if not finished:
        print("browser: FAIL (no self-test report within 240s)")
        return False
    r = got["r"]
    ns = r.get("newSession") or {}
    ok = (not r.get("errors") and r.get("rejectsBad") and r.get("traces") and all(x.get("ok") for x in r["traces"])
          and r.get("live") and all(x.get("ok") for x in r["live"]) and r.get("liveAdvances")
          and ns.get("ok") and ns.get("listed") and ns.get("playing") and r.get("reportsOk") and r.get("bugOpensReplay"))
    for x in r.get("traces", []):
        print("replay  %-4s %s  frames=%s events=%s crew=%s%s" % ("ok" if x.get("ok") else "FAIL", x["file"], x.get("frames"),
                                                             x.get("events"), x.get("crew"), " v3" if x.get("v3") else ""))
        if x.get("error"):
            print("         " + x["error"].splitlines()[0])
    for x in r.get("live", []):
        print("live    %-4s %s  bubbles<=%s feed=%s moodBars=%s stops=%s kinds=%s" % ("ok" if x.get("ok") else "FAIL", x["file"], x.get("bubbles"),
                                                                                x.get("feed"), x.get("moodBars"), x.get("stops"), ",".join(x.get("kinds", []))))
        if x.get("error"):
            print("         " + x["error"].splitlines()[0])
    print("live    moves on to the next session by itself: %s" % r.get("liveAdvances"))
    print("new     session (stand-in sim): %s" % json.dumps(ns))
    print("reports real summary: %s" % json.dumps(r.get("reportsReal")))
    print("reports sample v3: %s -> %s" % (json.dumps(r.get("reportsSample")), "ok" if r.get("reportsOk") else "FAIL"))
    if r.get("reportsError"):
        print("         " + r["reportsError"].splitlines()[0])
    print("reports bug 'Watch' opens Replay: %s" % r.get("bugOpensReplay"))
    print("bad trace rejected cleanly: %s; JS errors: %d" % (r.get("rejectsBad"), len(r.get("errors") or [])))
    for e in (r.get("errors") or [])[:10]:
        print("         " + e)
    return bool(ok)


def main():
    fmt = check_formats()
    srv = check_server()
    br = None if "--no-browser" in sys.argv else check_browser()
    print("format: %s; server: %s; browser: %s" % ("PASS" if fmt else "FAIL", "PASS" if srv else "FAIL",
                                                 {None: "SKIPPED", True: "PASS", False: "FAIL"}[br]))
    sys.exit(0 if fmt and srv and br is not False else 1)


if __name__ == "__main__":
    main()
