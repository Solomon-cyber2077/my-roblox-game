// Pure trace logic for the limb-sim viewer: no DOM, so the self-test can drive it too.
// Trace format (as written by lib/LimbSim on the HP, see README.md):
//   meta   { seed, station, crew: [{ id, name, persona, device, rttMs }] }
//   map    { cols, rows, tile, length, train: { x0, x1, z }, blocked: [cellIndex], buildings: [[x0, z0, x1, z1]] }
//   frames [{ t, p: { [id]: [x, z, state, armsLost, items] }, h: [[x, z]] }]
//   events [{ t, type, who?, by?, ...extra }]
//   summary { died, rescued, returned, text }
// Format v3 adds (all optional, so v2 traces still load):
//   meta.crew[i].profile { age, platform, device, connection, region, rttMs, localHour, weekday, sessionMinutes,
//                          runsBefore, traits, motive }
//   meta.stops [{ n, station, startT, endT }]; frames[k].stop = stop number; p[id][5] = mood
//   mood   [fear, frustration, fun, boredom, fatigue], each 0..1
//   events say{who, kind, topic, text, detail?} stop{n, station} quit{who, text} mood{who, text}
//   summary + { quits, complaints: { topic: n }, bugs: [{ topic, detail }] }
(function (root) {
	"use strict";

	const STATES = ["Aboard", "Afield", "Looting", "Held", "Dead", "LeftBehind", "Left"]; // Left = quit the game
	const MOODS = ["fear", "frustration", "fun", "boredom", "fatigue"];
	const SAY_KINDS = ["complaint", "bug", "confusion", "praise", "social", "quit"];

	function isNum(v) {
		return typeof v === "number" && isFinite(v);
	}

	// Returns a list of human-readable problems; empty means the trace is usable.
	function validate(trace) {
		const errs = [];
		if (!trace || typeof trace !== "object") return ["trace is not an object"];
		const meta = trace.meta, map = trace.map, frames = trace.frames, events = trace.events;
		if (!meta || !Array.isArray(meta.crew)) errs.push("meta.crew missing");
		if (!map) errs.push("map missing");
		else {
			for (const k of ["cols", "rows", "tile", "length"]) if (!isNum(map[k])) errs.push("map." + k + " not a number");
			if (!map.train || !isNum(map.train.x0) || !isNum(map.train.x1) || !isNum(map.train.z)) errs.push("map.train bad");
			if (map.blocked !== undefined && !Array.isArray(map.blocked)) errs.push("map.blocked not a list");
			if (map.buildings !== undefined && !Array.isArray(map.buildings)) errs.push("map.buildings not a list");
			if (Array.isArray(map.blocked) && isNum(map.cols) && isNum(map.rows)) {
				const n = map.cols * map.rows;
				const bad = map.blocked.filter((i) => !Number.isInteger(i) || i < 0 || i >= n);
				if (bad.length) errs.push(bad.length + " blocked cells out of range");
			}
			if (Array.isArray(map.buildings)) {
				const bad = map.buildings.filter((b) => !Array.isArray(b) || b.length !== 4 || !b.every(isNum));
				if (bad.length) errs.push(bad.length + " buildings not [x0,z0,x1,z1]");
			}
		}
		if (!Array.isArray(frames) || frames.length === 0) errs.push("frames missing or empty");
		else {
			const ids = new Set(((meta && meta.crew) || []).map((c) => String(c.id)));
			let last = -Infinity, badP = 0, badH = 0, unknown = 0, badMood = 0, badStop = 0;
			for (const f of frames) {
				if (!isNum(f.t) || f.t < last) {
					errs.push("frame times not increasing at t=" + f.t);
					break;
				}
				last = f.t;
				for (const id in f.p || {}) {
					const p = f.p[id];
					if (!Array.isArray(p) || p.length < 3 || !isNum(p[0]) || !isNum(p[1]) || typeof p[2] !== "string") badP++;
					if (ids.size && !ids.has(id)) unknown++;
					if (Array.isArray(p) && p.length >= 6 && !isMood(p[5])) badMood++;
				}
				if (f.stop !== undefined && !isNum(f.stop)) badStop++;
				const h = f.h;
				if (h !== undefined && !Array.isArray(h) && !(h && typeof h === "object" && Object.keys(h).length === 0)) badH++;
				else if (Array.isArray(h)) for (const x of h) if (!Array.isArray(x) || !isNum(x[0]) || !isNum(x[1])) badH++;
			}
			if (badP) errs.push(badP + " player entries not [x, z, state, ...]");
			if (badH) errs.push(badH + " hollow entries not [x, z]");
			if (unknown) errs.push(unknown + " player entries with ids not in meta.crew");
			if (badMood) errs.push(badMood + " moods not [fear, frustration, fun, boredom, fatigue] in 0..1");
			if (badStop) errs.push(badStop + " frames with a stop that is not a number");
		}
		if (meta && meta.stops !== undefined) {
			if (!Array.isArray(meta.stops)) errs.push("meta.stops not a list");
			else if (meta.stops.some((s) => !s || !isNum(s.n) || !isNum(s.startT) || !isNum(s.endT))) errs.push("meta.stops entries need n, startT, endT");
		}
		if (events !== undefined && !Array.isArray(events)) errs.push("events not a list");
		else if (events) {
			const bad = events.filter((e) => !e || !isNum(e.t) || typeof e.type !== "string");
			if (bad.length) errs.push(bad.length + " events without t/type");
			const says = events.filter((e) => e && e.type === "say" && (typeof e.text !== "string" || typeof e.kind !== "string"));
			if (says.length) errs.push(says.length + " say events without kind/text");
		}
		return errs;
	}

	function isMood(m) {
		return Array.isArray(m) && m.length >= 5 && m.slice(0, 5).every((v) => isNum(v) && v >= 0 && v <= 1);
	}

	// Makes a validated trace easy to use: sorted events, crew by id, hollow lists always arrays.
	function prepare(trace) {
		const crew = {};
		for (const c of trace.meta.crew) crew[String(c.id)] = c;
		const frames = trace.frames.map((f) => ({ t: f.t, stop: isNum(f.stop) ? f.stop : null, p: f.p || {}, h: Array.isArray(f.h) ? f.h : [] }));
		// The scripted traces append some events out of time order; keep the original order for ties.
		const events = (trace.events || []).map((e, i) => ({ e, i })).sort((a, b) => a.e.t - b.e.t || a.i - b.i).map((x) => x.e);
		const map = trace.map;
		const stops = stopList(trace.meta, frames, events);
		const v3 = stops.length > 0 || events.some((e) => e.type === "say" || e.type === "mood" || e.type === "quit") ||
			frames.some((f) => Object.values(f.p).some((p) => Array.isArray(p) && isMood(p[5])));
		return {
			v3,
			stops,
			speech: events.filter((e) => e.type === "say" || e.type === "quit"),
			meta: trace.meta,
			summary: trace.summary || null,
			map: { ...map, blocked: map.blocked || [], buildings: map.buildings || [] },
			crew,
			crewIds: Object.keys(crew),
			frames,
			events,
			t0: frames[0].t,
			t1: frames[frames.length - 1].t,
		};
	}

	// meta.stops when given; otherwise rebuilt from frame stop numbers and stop events.
	function stopList(meta, frames, events) {
		if (Array.isArray(meta.stops) && meta.stops.length)
			return meta.stops.map((s) => ({ n: s.n, station: s.station || "Stop " + s.n, startT: s.startT, endT: s.endT })).sort((a, b) => a.startT - b.startT);
		const byN = {};
		for (const f of frames) {
			if (f.stop === null) continue;
			const s = byN[f.stop] || (byN[f.stop] = { n: f.stop, station: "Stop " + f.stop, startT: f.t, endT: f.t });
			s.endT = f.t;
		}
		for (const e of events) if (e.type === "stop" && byN[e.n] && e.station) byN[e.n].station = e.station;
		return Object.values(byN).sort((a, b) => a.startT - b.startT);
	}

	// The stop being played at time t (the last one started), or null for a single-station trace.
	function stopAt(tr, t) {
		let cur = null;
		for (const s of tr.stops) if (s.startT <= t) cur = s;
		return cur || tr.stops[0] || null;
	}

	// Index of the last frame with frame.t <= t (0 if t is before the first frame).
	function frameIndex(frames, t) {
		let lo = 0, hi = frames.length - 1;
		if (t <= frames[0].t) return 0;
		if (t >= frames[hi].t) return hi;
		while (lo < hi) {
			const mid = (lo + hi + 1) >> 1;
			if (frames[mid].t <= t) lo = mid;
			else hi = mid - 1;
		}
		return lo;
	}

	function lerp(a, b, k) {
		return a + (b - a) * k;
	}

	// The world at time t: positions blended between the two surrounding frames, states from the earlier one.
	function sample(tr, t) {
		const i = frameIndex(tr.frames, t);
		const a = tr.frames[i], b = tr.frames[Math.min(i + 1, tr.frames.length - 1)];
		const k = b.t > a.t ? Math.min(1, Math.max(0, (t - a.t) / (b.t - a.t))) : 0;
		const players = [];
		for (const id in a.p) {
			const pa = a.p[id], pb = b.p[id];
			// Do not blend across a state change (boarding snaps from the field to the train).
			const blend = pb && pb[2] === pa[2];
			players.push({
				id,
				name: (tr.crew[id] && tr.crew[id].name) || "#" + id,
				x: blend ? lerp(pa[0], pb[0], k) : pa[0],
				z: blend ? lerp(pa[1], pb[1], k) : pa[1],
				state: pa[2],
				armsLost: typeof pa[3] === "string" ? pa[3] : "",
				items: isNum(pa[4]) ? pa[4] : 0,
				mood: isMood(pa[5]) ? (isMood(pb && pb[5]) ? pa[5].slice(0, 5).map((v, j) => lerp(v, pb[5][j], k)) : pa[5].slice(0, 5)) : null,
			});
		}
		// Hollows carry no ids, so blend only when the count is unchanged.
		const same = a.h.length === b.h.length;
		const hollows = a.h.map((h, j) => (same ? [lerp(h[0], b.h[j][0], k), lerp(h[1], b.h[j][1], k)] : [h[0], h[1]]));
		return { t, frame: i, stop: a.stop, players, hollows };
	}

	// Map grid: cell index = row * cols + col, columns from x = -length/2, rows from z = 0.
	function cellRect(map, idx) {
		const col = idx % map.cols, row = Math.floor(idx / map.cols);
		const x0 = -map.length / 2 + col * map.tile, z0 = row * map.tile;
		return [x0, z0, x0 + map.tile, z0 + map.tile];
	}

	// World bounds that hold the map, the train and everything that moves in the trace.
	function bounds(tr) {
		const m = tr.map;
		let x0 = Math.min(-m.length / 2, m.train.x0), x1 = Math.max(m.length / 2, m.train.x1);
		let z0 = Math.min(0, m.train.z - 6), z1 = m.rows * m.tile;
		for (const b of m.buildings) {
			x0 = Math.min(x0, b[0], b[2]); x1 = Math.max(x1, b[0], b[2]);
			z0 = Math.min(z0, b[1], b[3]); z1 = Math.max(z1, b[1], b[3]);
		}
		for (const f of tr.frames) {
			for (const id in f.p) {
				const p = f.p[id];
				x0 = Math.min(x0, p[0]); x1 = Math.max(x1, p[0]); z0 = Math.min(z0, p[1]); z1 = Math.max(z1, p[1]);
			}
			for (const h of f.h) {
				x0 = Math.min(x0, h[0]); x1 = Math.max(x1, h[0]); z0 = Math.min(z0, h[1]); z1 = Math.max(z1, h[1]);
			}
		}
		return { x0, x1, z0, z1 };
	}

	function who(tr, id) {
		if (id === undefined || id === null) return "?";
		const c = tr.crew[String(id)];
		return c ? c.name : "#" + id;
	}

	const ARM = { L: "left", R: "right" };

	// One line of plain text per event; unknown types still show their fields.
	function describe(tr, e) {
		const w = who(tr, e.who), by = who(tr, e.by);
		switch (e.type) {
			case "hollow": return e.text || "A Hollow comes out";
			case "grab": return w + " is grabbed";
			case "checkMiss": return w + ": check missed";
			case "escape": return w + " fights free";
			case "board": return w + " boards the train";
			case "rescueOpen": return "Rescue window opens for " + w;
			case "rescueJoin": return by + " joins the rescue of " + w;
			case "beat": return by + " beat " + (e.beat !== undefined ? e.beat : "?") + " for " + w + ": " + (e.result || "?");
			case "tear": return w + " loses the " + (ARM[e.arm] || e.arm || "?") + " arm" + (e.by !== undefined ? " (rescued by " + by + ")" : "");
			case "drop": return w + " drops " + (Array.isArray(e.items) && e.items.length ? e.items.join(", ") : "items");
			case "returnStart": return w + " runs back armless" + (isNum(e.deadline) ? " (deadline " + e.deadline.toFixed(1) + "s)" : "");
			case "healStart": return w + " starts regrowing an arm";
			case "heal": return w + " regrows an arm";
			case "death": return w + " dies" + (e.text ? ": " + e.text : "");
			case "outcome": return "Outcome: " + (e.text || "");
			case "say": return w + ": “" + (e.text || "") + "”";
			case "quit": return w + " quits" + (e.text ? ": " + e.text : "");
			case "mood": return w + " " + (e.text || "changes mood");
			case "stop": return "Stop " + (e.n !== undefined ? e.n : "?") + (e.station ? ": " + e.station : "");
			default: {
				const extra = Object.keys(e).filter((k) => k !== "t" && k !== "type").map((k) => k + "=" + JSON.stringify(e[k]));
				return e.type + (extra.length ? " " + extra.join(" ") : "");
			}
		}
	}

	// Feed colour class: say kinds, plus quit/mood/stop and plain game events.
	function kindOf(e) {
		if (e.type === "say") return SAY_KINDS.includes(e.kind) ? e.kind : "social";
		if (e.type === "quit" || e.type === "mood" || e.type === "stop") return e.type;
		return "game";
	}

	// How long a speech bubble stays up: longer lines stay longer.
	function bubbleSeconds(text) {
		return Math.min(7, Math.max(3, 2.2 + String(text || "").length / 16));
	}

	// Speech bubbles showing at time t: the newest line per speaker that is still up.
	function speechAt(tr, t) {
		const latest = {};
		for (const e of tr.speech) {
			if (e.t > t) break;
			const dur = bubbleSeconds(e.text);
			if (t - e.t < dur) latest[String(e.who)] = { e, age: t - e.t, dur };
		}
		return Object.values(latest);
	}

	// A player's local time: localHour may be fractional (19.5 = 19:30); weekday may be a name or true/false.
	function localTime(hour, weekday) {
		if (!isNum(hour)) return "";
		const h = Math.floor(hour) % 24, m = Math.round((hour - Math.floor(hour)) * 60);
		const day = typeof weekday === "string" ? weekday + " " : weekday === true ? "weekday " : weekday === false ? "weekend " : "";
		return day + String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0");
	}

	function clock(t) {
		const s = Math.max(0, t);
		return Math.floor(s / 60) + ":" + String(Math.floor(s % 60)).padStart(2, "0");
	}

	// ---------- report helpers (summary v3) ----------

	// { topic: n | { count, examples } } -> [{ topic, count, examples }], biggest first.
	function rank(obj) {
		if (!obj || typeof obj !== "object") return [];
		return Object.keys(obj)
			.map((topic) => {
				const v = obj[topic];
				if (isNum(v)) return { topic, count: v, examples: [] };
				const examples = v && Array.isArray(v.examples) ? v.examples : v && v.example !== undefined ? [v.example] : [];
				return { topic, count: v && isNum(v.count) ? v.count : 0, examples };
			})
			.sort((a, b) => b.count - a.count || (a.topic < b.topic ? -1 : 1));
	}

	// A breakdown such as byHour or byDevice, whatever its inner shape: rows, numeric columns and a getter.
	// { key: n } gives one column "value"; { key: { a: n, b: { c: n } } } gives columns a and b.c.
	function breakdown(obj) {
		const rows = obj && typeof obj === "object" && !Array.isArray(obj) ? Object.keys(obj) : [];
		const numeric = rows.length > 0 && rows.every((r) => /^\d+$/.test(r));
		if (numeric) rows.sort((a, b) => Number(a) - Number(b));
		// Bands such as "evening (17-21)" sort by their first number.
		else if (rows.length && rows.every((r) => /\((\d+)/.test(r))) rows.sort((a, b) => Number(/\((\d+)/.exec(a)[1]) - Number(/\((\d+)/.exec(b)[1]));
		const flat = {}, cols = [];
		for (const r of rows) {
			const out = (flat[r] = {});
			const walk = (v, key) => {
				if (isNum(v)) {
					out[key] = v;
					if (!cols.includes(key)) cols.push(key);
				} else if (v && typeof v === "object" && !Array.isArray(v)) for (const k of Object.keys(v)) walk(v[k], key ? key + "." + k : k);
			};
			walk(obj[r], isNum(obj[r]) ? "value" : "");
		}
		const isRate = {};
		for (const c of cols) {
			const vals = rows.map((r) => flat[r][c]).filter(isNum);
			isRate[c] = vals.length > 0 && vals.every((v) => v >= 0 && v <= 1) && vals.some((v) => !Number.isInteger(v));
		}
		return { rows, cols, numeric, isRate, get: (r, c) => flat[r] && flat[r][c] };
	}

	// Everyone in the loaded traces: one row per simulated person per session.
	function people(traces) {
		const out = [];
		for (const t of traces) {
			for (const c of (t.meta && t.meta.crew) || []) {
				const pr = c.profile || {};
				const said = (t.events || []).filter((e) => (e.type === "say" || e.type === "quit") && String(e.who) === String(c.id));
				out.push({
					key: t.key, trace: t.id, title: t.title, name: c.name, id: c.id, age: pr.age, platform: pr.platform || "",
					device: pr.device || c.device || "", connection: pr.connection || "", region: pr.region || "",
					rttMs: isNum(pr.rttMs) ? pr.rttMs : c.rttMs, localHour: pr.localHour, weekday: pr.weekday, local: localTime(pr.localHour, pr.weekday),
					sessionMinutes: pr.sessionMinutes, runsBefore: pr.runsBefore, motive: pr.motive || "", traits: pr.traits || {},
					quit: said.some((e) => e.type === "quit"), lines: said.filter((e) => e.type === "say").length,
					complaints: said.filter((e) => e.kind === "complaint").length, profile: !!c.profile,
				});
			}
		}
		return out;
	}

	const api = {
		STATES, MOODS, SAY_KINDS, validate, prepare, frameIndex, sample, stopAt, cellRect, bounds, describe, who,
		kindOf, bubbleSeconds, speechAt, clock, localTime, rank, breakdown, people, isMood,
	};
	if (typeof module !== "undefined" && module.exports) module.exports = api;
	else root.LimbCore = api;
})(typeof window !== "undefined" ? window : this);
