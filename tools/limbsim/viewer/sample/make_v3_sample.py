#!/usr/bin/env python3
"""Writes the hand-made format v3 sample (sample-v3-run.json, summary-v3.json) used until the HP's v3 traces land.

Every person, line and number here is invented to exercise the viewer; none of it comes from the sim.
Deterministic: running it again writes the same files. Usage: python3 make_v3_sample.py
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DT = 0.5
MAP = {"cols": 10, "rows": 8, "tile": 12, "length": 120, "train": {"x0": -60, "x1": 60, "z": -4},
       "blocked": [23, 24, 56], "buildings": [[12, 60, 48, 84]]}

CREW = [
    {"id": 1, "name": "Ana", "persona": "ana", "device": "Desktop", "rttMs": 35,
     "profile": {"age": 24, "platform": "PC", "device": "Desktop", "connection": "ethernet", "region": "UK", "rttMs": 35,
                 "localHour": 21, "weekday": "Fri", "sessionMinutes": 70, "runsBefore": 14,
                 "traits": {"skill": 0.8, "patience": 0.6, "bravery": 0.7, "sociability": 0.5}, "motive": "mastery"}},
    {"id": 2, "name": "Bo", "persona": "bo", "device": "Phone", "rttMs": 140,
     "profile": {"age": 13, "platform": "Mobile", "device": "iPhone 11", "connection": "wifi", "region": "US-East", "rttMs": 140,
                 "localHour": 16, "weekday": "Fri", "sessionMinutes": 25, "runsBefore": 2,
                 "traits": {"skill": 0.35, "patience": 0.4, "bravery": 0.3, "sociability": 0.9}, "motive": "social"}},
    {"id": 3, "name": "Cy", "persona": "cy", "device": "Laptop", "rttMs": 80,
     "profile": {"age": 17, "platform": "PC", "device": "Laptop", "connection": "wifi", "region": "DE", "rttMs": 80,
                 "localHour": 22, "weekday": "Fri", "sessionMinutes": 45, "runsBefore": 6,
                 "traits": {"skill": 0.6, "patience": 0.7, "bravery": 0.9, "sociability": 0.4}, "motive": "thrill"}},
    {"id": 4, "name": "Dee", "persona": "dee", "device": "BudgetAndroid", "rttMs": 230,
     "profile": {"age": 11, "platform": "Mobile", "device": "Budget Android", "connection": "mobile", "region": "BR", "rttMs": 230,
                 "localHour": 18, "weekday": "Fri", "sessionMinutes": 15, "runsBefore": 0,
                 "traits": {"skill": 0.2, "patience": 0.25, "bravery": 0.4, "sociability": 0.6}, "motive": "explore"}},
]
# n, station, startT, endT (the ride between stops is the gap, everyone aboard)
STOPS = [(1, "Halt", 0.0, 60.0), (2, "Viaduct", 72.0, 140.0), (3, "Market", 152.0, 210.0)]
LOOT = {1: [(-30, 30), (20, 40), (-10, 70)], 2: [(-40, 50), (0, 30), (35, 20)], 3: [(-20, 40), (30, 30), (-45, 75)]}


def lerp(a, b, k):
    return a + (b - a) * k


def path(points, t0, t1, t):
    """Position along a polyline of (x, z) at time t, walking it evenly between t0 and t1."""
    if t <= t0:
        return points[0]
    if t >= t1:
        return points[-1]
    k = (t - t0) / (t1 - t0) * (len(points) - 1)
    i = min(int(k), len(points) - 2)
    f = k - i
    return (lerp(points[i][0], points[i + 1][0], f), lerp(points[i][1], points[i + 1][1], f))


def clamp(v):
    return round(max(0.0, min(1.0, v)), 2)


def main():
    frames, events = [], []
    say = lambda t, who, kind, topic, text, **kw: events.append({"t": t, "type": "say", "who": who, "kind": kind, "topic": topic, "text": text, **kw})
    for n, station, a, b in STOPS:
        events.append({"t": a, "type": "stop", "n": n, "station": station})
    # Stop 1: a calm loot, Dee is confused by the departure bell.
    say(4.0, 2, "social", "greeting", "hiii can i follow someone")
    say(6.5, 1, "social", "plan", "Bo with me, Cy take the left yard")
    say(18.0, 4, "confusion", "objective", "what are we supposed to grab??")
    say(31.0, 3, "praise", "atmosphere", "the fog rolling in over the platform is sick")
    events.append({"t": 44.0, "type": "mood", "who": 4, "text": "is getting bored (nothing is happening)"})
    say(50.0, 4, "confusion", "departure", "why is the train bell ringing")
    for w, t in ((1, 55.0), (2, 56.0), (3, 57.5), (4, 59.5)):
        events.append({"t": t, "type": "board", "who": w})
    # Stop 2: a Hollow grabs Bo, Ana and Cy pry, the left arm is torn, Bo runs back armless.
    events.append({"t": 90.0, "type": "hollow", "text": "A Hollow comes out of the arches"})
    say(91.5, 2, "social", "panic", "THERE'S SOMETHING HERE")
    events.append({"t": 96.0, "type": "mood", "who": 2, "text": "is terrified (fear 0.9)"})
    events.append({"t": 98.0, "type": "grab", "who": 2})
    events.append({"t": 99.0, "type": "checkMiss", "who": 2})
    say(99.5, 2, "complaint", "struggle on touch", "i cant tap fast enough on my phone")
    events.append({"t": 101.0, "type": "rescueOpen", "who": 2})
    events.append({"t": 102.0, "type": "rescueJoin", "who": 2, "by": 1})
    events.append({"t": 103.5, "type": "rescueJoin", "who": 2, "by": 3})
    events.append({"t": 104.0, "type": "beat", "who": 2, "by": 1, "beat": 1, "result": "Hit"})
    events.append({"t": 105.0, "type": "beat", "who": 2, "by": 3, "beat": 2, "result": "Miss"})
    events.append({"t": 106.0, "type": "beat", "who": 2, "by": 1, "beat": 3, "result": "Hit"})
    events.append({"t": 107.0, "type": "tear", "who": 2, "arm": "L", "by": 1})
    events.append({"t": 107.2, "type": "drop", "who": 2, "items": ["Lantern"]})
    say(108.0, 3, "praise", "rescue", "GOT YOU. that pull was so close")
    say(109.5, 2, "complaint", "arm loss", "bro my arm is GONE")
    events.append({"t": 110.0, "type": "returnStart", "who": 2, "deadline": 35.0})
    say(118.0, 1, "social", "guide", "Bo follow the arrow, train is straight down")
    say(124.0, 4, "confusion", "rescue", "how do you help someone who got grabbed")
    for w, t in ((1, 133.0), (3, 134.5), (2, 136.0), (4, 139.5)):
        events.append({"t": t, "type": "board", "who": w})
    say(139.6, 4, "bug", "deadline at the door",
        "the timer ran out right as i got to the door??",
        detail={"stop": 2, "station": "Viaduct", "deadlineLeft": 0.6, "distanceToDoor": 2.1,
                "note": "boarded 0.6 s before the doors shut; the warning cue was not shown to this player (hand-made example)"})
    # Stop 3: Bo heals, Dee gets frustrated and quits, Cy dies to a second Hollow.
    events.append({"t": 156.0, "type": "healStart", "who": 2})
    events.append({"t": 164.0, "type": "heal", "who": 2})
    say(164.5, 2, "praise", "regrowth", "ARM'S BACK lets gooo")
    events.append({"t": 168.0, "type": "mood", "who": 4, "text": "is frustrated (frustration 0.85, tilt)"})
    say(170.0, 4, "complaint", "lag", "everything is lagging so bad")
    say(173.0, 4, "quit", "lag", "this is too laggy im out")
    events.append({"t": 173.5, "type": "quit", "who": 4, "text": "left the game (frustration and lag)"})
    events.append({"t": 180.0, "type": "hollow", "text": "A Hollow drops from the market roof"})
    events.append({"t": 186.0, "type": "grab", "who": 3})
    events.append({"t": 187.0, "type": "rescueOpen", "who": 3})
    say(187.5, 1, "complaint", "rescue reach", "too far, i can't get there in time")
    events.append({"t": 191.0, "type": "death", "who": 3, "text": "Taken at Market"})
    say(193.0, 3, "complaint", "spectating", "spectating is boring, can't do anything")
    say(198.0, 1, "praise", "tension", "that was actually scary ngl")
    for w, t in ((1, 205.0), (2, 206.5)):
        events.append({"t": t, "type": "board", "who": w})
    events.append({"t": 210.0, "type": "outcome", "text": "2 of 4 reached the train after stop 3 (1 taken, 1 quit)"})

    # Moods by person over time; nudged by what happens to them.
    def mood(who, t):
        fear = 0.15 + 0.1 * math.sin(t / 9 + who)
        frus = 0.1 + 0.02 * who
        fun = 0.55 + 0.1 * math.sin(t / 13 + who * 2)
        bore = 0.2 + (0.004 * t if who == 4 else 0.0)
        fat = 0.05 + t / 600
        if 90 <= t <= 140:
            fear += 0.35
            fun += 0.1
        if who == 2 and 96 <= t <= 140:
            fear, frus = fear + 0.35, frus + (0.4 if t > 99 else 0.1)
        if who == 2 and t >= 164:
            fun += 0.25
            frus -= 0.1
        if who == 4 and t >= 150:
            frus += 0.6 * min(1.0, (t - 150) / 20)
            fun -= 0.35
        if who == 3 and 180 <= t:
            fear += 0.4
        if who == 1 and 104 <= t <= 110:
            fun += 0.3
        return [clamp(fear), clamp(frus), clamp(fun), clamp(bore), clamp(fat)]

    seats = {1: (-12, 1), 2: (-4, 1), 3: (4, 1), 4: (12, 1)}
    t = 0.0
    while t <= 210.0 + 1e-9:
        tt = round(t, 1)
        stop = next((s for s in STOPS if s[2] <= tt <= s[3]), None)
        ride = stop is None
        n = stop[0] if stop else next(s[0] for s in STOPS if s[2] > tt)
        a = stop[2] if stop else 0
        p, h = {}, []
        for c in CREW:
            w = c["id"]
            if w == 4 and tt >= 173.5:
                continue  # quit: leaves the frames
            boarded = [e["t"] for e in events if e["type"] == "board" and e["who"] == w and stop and stop[2] <= e["t"] <= stop[3]]
            st, arms, items = "Aboard", "", 0
            x, z = seats[w]
            if not ride and not (boarded and tt >= boarded[0]):
                out = LOOT[n][(w - 1) % 3]
                back = (boarded[0] if boarded else stop[3]) - 3
                if w == 3 and n == 3 and tt >= 186:
                    out = (30, 30)
                x, z = path([seats[w], (out[0] * 0.5, out[1] * 0.5), out, (out[0] * 0.6, out[1] * 0.4), seats[w]], a + 3, back, tt)
                st = "Afield"
                if abs(x - out[0]) < 4 and abs(z - out[1]) < 4:
                    st = "Looting"
                items = 1 if tt > (a + back) / 2 else 0
            if w == 2 and 98 <= tt < 107:
                st, x, z = "Held", 0, 30
            if w == 2 and 107 <= tt < 164:
                arms = "L"
            if w == 3 and n == 3 and 186 <= tt < 191:
                st, x, z = "Held", 30, 30
            if w == 3 and tt >= 191:
                st, x, z, items = "Dead", 30, 30, 0
            if w in (1, 3) and 102 <= tt < 107:
                x, z = (-3, 27) if w == 1 else (3, 33)
            p[str(w)] = [round(x, 1), round(z, 1), st, arms, items, mood(w, tt)]
        if stop and stop[0] == 2 and 90 <= tt <= 112:
            h.append([round(lerp(-50, 0, min(1, (tt - 90) / 8)), 1), round(lerp(80, 31, min(1, (tt - 90) / 8)), 1)])
        if stop and stop[0] == 3 and 180 <= tt <= 195:
            h.append([round(lerp(48, 31, min(1, (tt - 180) / 6)), 1), round(lerp(70, 31, min(1, (tt - 180) / 6)), 1)])
        frames.append({"t": tt, "stop": n, "p": p, "h": h})
        t += DT

    complaints = {}
    for e in events:
        if e["type"] == "say" and e["kind"] == "complaint":
            complaints[e["topic"]] = complaints.get(e["topic"], 0) + 1
    trace = {
        "meta": {"seed": 900001, "station": "Halt", "crew": CREW,
                 "stops": [{"n": n, "station": s, "startT": a, "endT": b} for n, s, a, b in STOPS]},
        "map": MAP,
        "frames": frames,
        "events": sorted(events, key=lambda e: e["t"]),
        "summary": {"died": 1, "rescued": 1, "returned": 1, "quits": 1, "complaints": complaints,
                    "bugs": [{"topic": e["topic"], "detail": e["detail"]} for e in events if e["type"] == "say" and e["kind"] == "bug"],
                    "text": "3 stops; Bo rescued (left arm lost, regrown at Market); Dee quit at Market; Cy taken at Market"},
    }
    with open(os.path.join(HERE, "sample-v3-run.json"), "w") as f:
        json.dump(trace, f, separators=(",", ":"))

    summary = {
        "sessions": 400,
        "note": "HAND-MADE SAMPLE: invented numbers that only exercise the viewer. Not sim output and not player data.",
        "population": {
            "platform": {"PC": 168, "Mobile": 196, "Console": 36},
            "connection": {"wifi": 231, "mobile": 112, "ethernet": 57},
            "motive": {"social": 121, "thrill": 98, "mastery": 64, "explore": 71, "chill": 46},
            "ageBand": {"9-12": 102, "13-15": 141, "16-18": 88, "19-25": 46, "26+": 23},
            "medianSessionMinutes": 27,
        },
        "totals": {"stops": 1460, "grabs": 612, "rescues": 188, "armsLost": 241, "deaths": 130, "quits": 74},
        "byStation": {"Halt": {"sessions": 140, "died": 30, "armless": 41, "returned": 33},
                      "Viaduct": {"sessions": 132, "died": 51, "armless": 49, "returned": 31},
                      "Market": {"sessions": 128, "died": 49, "armless": 38, "returned": 27}},
        "rescue": [{"persona": "ana", "device": "Desktop", "rttMs": 35, "own": True, "rate": 0.81},
                   {"persona": "dee", "device": "BudgetAndroid", "rttMs": 230, "own": False, "rate": 0.52}],
        "feedback": {
            "complaints": {
                "lag": {"count": 58, "examples": ["everything is lagging so bad", "my taps register late"]},
                "struggle on touch": {"count": 44, "examples": ["i cant tap fast enough on my phone"]},
                "rescue reach": {"count": 31, "examples": ["too far, i can't get there in time", "nobody could reach me"]},
                "spectating": {"count": 22, "examples": ["spectating is boring, can't do anything"]},
                "arm loss": {"count": 17, "examples": ["bro my arm is GONE"]},
            },
            "bugs": [
                {"topic": "deadline at the door", "count": 9, "example": {"deadlineLeft": 0.6, "distanceToDoor": 2.1, "station": "Viaduct"}},
                {"topic": "item out of reach", "count": 3, "example": {"item": "Lantern", "cell": 57, "station": "Market", "note": "dropped inside a blocked cell"}},
            ],
            "praise": {"atmosphere": {"count": 40, "examples": ["the fog rolling in over the platform is sick"]},
                       "rescue": {"count": 27, "examples": ["GOT YOU. that pull was so close"]},
                       "regrowth": {"count": 12, "examples": ["ARM'S BACK lets gooo"]}},
        },
        "features": [
            {"name": "Crew rescue", "verdict": "works, hard on phones",
             "evidence": ["PC rescuers succeed 81% (sample)", "budget Android rescuers 52% (sample)"],
             "numbers": {"attempts": 188, "success": 0.68, "phoneSuccess": 0.57}},
            {"name": "Armless return", "verdict": "fair", "evidence": ["most armless players reach the train"],
             "numbers": {"armless": 241, "returned": 0.74, "medianSecondsLeft": 6.2}},
            {"name": "Spectating after death", "verdict": "boring, fix", "evidence": ["22 complaints, 0 praise"],
             "numbers": {"deaths": 130, "quitAfterDeath": 0.31}},
        ],
        "byHour": {str(h): {"sessions": [4, 2, 1, 1, 0, 0, 1, 3, 6, 9, 11, 14, 17, 19, 22, 28, 34, 38, 41, 40, 36, 30, 22, 11][h],
                            "quitRate": round(0.1 + 0.08 * math.sin(h / 3.8), 2)} for h in range(24)},
        "byDevice": {"Desktop": {"sessions": 120, "deaths": 0.22, "quitRate": 0.09, "fun": 0.71},
                     "Laptop": {"sessions": 48, "deaths": 0.25, "quitRate": 0.12, "fun": 0.66},
                     "Phone": {"sessions": 142, "deaths": 0.34, "quitRate": 0.2, "fun": 0.58},
                     "BudgetAndroid": {"sessions": 54, "deaths": 0.41, "quitRate": 0.31, "fun": 0.47},
                     "Console": {"sessions": 36, "deaths": 0.28, "quitRate": 0.14, "fun": 0.62}},
    }
    with open(os.path.join(HERE, "summary-v3.json"), "w") as f:
        json.dump(summary, f, indent=1)

    index = [
        {"file": "sample-tear.json", "id": "sample-tear", "title": "Hand-made sample: arm torn in a rescue, rescuer dies"},
        {"file": "sample-v3-run.json", "id": "sample-v3-run", "title": "Hand-made v3 sample: three stops, a rescue, a quit",
         "kind": "sample", "crew": [c["name"] for c in CREW], "stops": len(STOPS), "outcome": "2 of 4 aboard"},
    ]
    with open(os.path.join(HERE, "index.json"), "w") as f:
        json.dump(index, f, indent=2)
    print("wrote sample-v3-run.json (%d frames, %d events), summary-v3.json, index.json" % (len(frames), len(events)))


if __name__ == "__main__":
    main()
