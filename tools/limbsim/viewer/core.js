// Pure trace logic for the limb-sim viewer: no DOM, so the self-test can drive it too.
// Trace format (as written by lib/LimbSim on the HP, see README.md):
//   meta   { seed, station, crew: [{ id, name, persona, device, rttMs }] }
//   map    { cols, rows, tile, length, train: { x0, x1, z }, blocked: [cellIndex], buildings: [[x0, z0, x1, z1]] }
//   frames [{ t, p: { [id]: [x, z, state, armsLost, items] }, h: [[x, z]] }]
//   events [{ t, type, who?, by?, ...extra }]
//   summary { died, rescued, returned, text }
(function (root) {
	"use strict";

	const STATES = ["Aboard", "Afield", "Looting", "Held", "Dead"];

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
			let last = -Infinity, badP = 0, badH = 0, unknown = 0;
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
				}
				const h = f.h;
				if (h !== undefined && !Array.isArray(h) && !(h && typeof h === "object" && Object.keys(h).length === 0)) badH++;
				else if (Array.isArray(h)) for (const x of h) if (!Array.isArray(x) || !isNum(x[0]) || !isNum(x[1])) badH++;
			}
			if (badP) errs.push(badP + " player entries not [x, z, state, ...]");
			if (badH) errs.push(badH + " hollow entries not [x, z]");
			if (unknown) errs.push(unknown + " player entries with ids not in meta.crew");
		}
		if (events !== undefined && !Array.isArray(events)) errs.push("events not a list");
		else if (events) {
			const bad = events.filter((e) => !e || !isNum(e.t) || typeof e.type !== "string");
			if (bad.length) errs.push(bad.length + " events without t/type");
		}
		return errs;
	}

	// Makes a validated trace easy to use: sorted events, crew by id, hollow lists always arrays.
	function prepare(trace) {
		const crew = {};
		for (const c of trace.meta.crew) crew[String(c.id)] = c;
		const frames = trace.frames.map((f) => ({ t: f.t, p: f.p || {}, h: Array.isArray(f.h) ? f.h : [] }));
		// The scripted traces append some events out of time order; keep the original order for ties.
		const events = (trace.events || []).map((e, i) => ({ e, i })).sort((a, b) => a.e.t - b.e.t || a.i - b.i).map((x) => x.e);
		const map = trace.map;
		return {
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
			});
		}
		// Hollows carry no ids, so blend only when the count is unchanged.
		const same = a.h.length === b.h.length;
		const hollows = a.h.map((h, j) => (same ? [lerp(h[0], b.h[j][0], k), lerp(h[1], b.h[j][1], k)] : [h[0], h[1]]));
		return { t, frame: i, players, hollows };
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
			default: {
				const extra = Object.keys(e).filter((k) => k !== "t" && k !== "type").map((k) => k + "=" + JSON.stringify(e[k]));
				return e.type + (extra.length ? " " + extra.join(" ") : "");
			}
		}
	}

	const api = { STATES, validate, prepare, frameIndex, sample, cellRect, bounds, describe, who };
	if (typeof module !== "undefined" && module.exports) module.exports = api;
	else root.LimbCore = api;
})(typeof window !== "undefined" ? window : this);
