// Limb-sim viewer UI: Live (spectate sessions back to back), Replay (scrub one trace) and Reports (reports.js).
// The trace logic lives in core.js. Talks to serve.py for New session (/__new, /__job) and live traces (/__live).
(function () {
	"use strict";
	const C = window.LimbCore;
	const R = window.LimbReports;
	const $ = (id) => document.getElementById(id);
	const params = new URLSearchParams(location.search);
	const SELFTEST = params.get("selftest") === "1";
	const HTTP = location.protocol.startsWith("http");

	// Sim traces from the HP win; sessions made on this laptop come first; the hand-made sample is the fallback.
	const SOURCES = [
		{ key: "live", label: "New sessions (this laptop)", index: "/__live", url: (x) => "/__livefile/" + x.file, http: true },
		{ key: "real", label: "Sim traces (from the HP)", index: "../traces/index.json", url: (x) => "../traces/" + x.file },
		{ key: "sample", label: "Sample (hand-made)", index: "sample/index.json", url: (x) => "sample/" + x.file },
	];
	const CREW_COLORS = ["#5aa9e6", "#7bd389", "#c792ea", "#f2a65a", "#f06292", "#4dd0e1"];
	const HOLLOW = "#e5544b";
	const KIND_COLORS = {
		complaint: "#e5544b", bug: "#f0a830", praise: "#7bd389", confusion: "#5aa9e6", social: "#aeb4be",
		quit: "#ff7a59", mood: "#c792ea", stop: "#e0b354", game: "#8b919c",
	};
	const KIND_LABELS = { complaint: "complaint", bug: "bug", praise: "praise", confusion: "confusion", social: "chat", quit: "quit", mood: "mood", stop: "stop", game: "game" };
	const MOOD_COLORS = ["#b07cf0", "#f2a65a", "#7bd389", "#8b919c", "#5aa9e6", "#f2d45a"];
	const MOOD_SHORT = ["fear", "frustr.", "fun", "bored", "sleepy", "energy"];
	const MARK_COLORS = {
		death: "#e5544b", tear: "#f2a65a", grab: "#c792ea", rescueOpen: "#7bd389", rescueJoin: "#7bd389",
		returnStart: "#e0b354", heal: "#4dd0e1", outcome: "#ffffff", quit: "#ff7a59",
	};
	const TRAIL_SECONDS = 8;
	const RECENT_SECONDS = 1.5;
	const LIVE_GAP = 4; // seconds between sessions in Live
	const POLL_MS = 8000;

	const canvas = $("map");
	const ctx = canvas.getContext("2d");
	const state = {
		items: [], tr: null, trKey: null, t: 0, playing: false, view: null, lastTick: 0, eventEls: [], cards: {},
		mode: "live", ended: null, pending: [], knownKeys: null, summary: null, summaryText: "", summarySample: false,
		reportCache: {}, job: { supported: false, why: "", state: "idle" }, lastBubbles: 0, feedShown: -1,
	};

	function fetchJson(url) {
		return fetch(url, { cache: "no-store" }).then((r) => {
			if (!r.ok) throw new Error(url + ": HTTP " + r.status);
			return r.json();
		});
	}

	function toast(text, err) {
		const d = document.createElement("div");
		d.textContent = text;
		if (err) d.className = "err";
		$("toasts").appendChild(d);
		setTimeout(() => d.remove(), err ? 12000 : 6000);
	}

	// ---------- trace lists ----------

	function loadIndexes() {
		return Promise.all(
			SOURCES.map((s) =>
				s.http && !HTTP
					? []
					: fetchJson(s.index)
						.then((list) => (Array.isArray(list) ? list : []).filter((x) => x && x.file).map((x) => ({ ...x, source: s, key: s.key + ":" + x.file })))
						.catch(() => []),
			),
		).then((lists) => {
			const items = lists.flat();
			const before = state.knownKeys;
			state.knownKeys = new Set(items.map((x) => x.key));
			state.items = items;
			renderPick();
			const real = items.filter((x) => x.source.key === "real").length;
			const live = items.filter((x) => x.source.key === "live").length;
			$("source").textContent = real || live
				? real + " sim traces" + (live ? " + " + live + " new sessions" : "")
				: items.length
					? "No sim traces yet; showing the hand-made sample"
					: HTTP ? "No traces found" : "Open this through the desktop launcher (browsers block file:// loading); Open file… still works";
			return { items, added: before ? items.filter((x) => !before.has(x.key)) : [] };
		});
	}

	function renderPick() {
		const pick = $("pick");
		pick.textContent = "";
		for (const s of SOURCES) {
			const mine = state.items.filter((x) => x.source === s);
			if (!mine.length) continue;
			const group = document.createElement("optgroup");
			group.label = s.label + " (" + mine.length + ")";
			for (const x of mine) {
				const o = new Option(x.title || x.id || x.file, x.key);
				if (x.outcome) o.title = x.outcome;
				group.appendChild(o);
			}
			pick.appendChild(group);
		}
		if (state.trKey) pick.value = state.trKey;
	}

	const byKey = (key) => state.items.find((x) => x.key === key);
	const isV3Item = (x) => x.source.key === "live" || x.stops !== undefined || Array.isArray(x.crew);

	// What Live plays: new sessions and v3 sim traces; all sim traces if none are v3 yet; the sample if there are none.
	function livePool() {
		if (params.get("source") === "sample") return state.items.filter((x) => x.source.key === "sample");
		const pool = state.items.filter((x) => x.source.key !== "sample");
		if (!pool.length) return state.items.filter((x) => x.source.key === "sample");
		const v3 = pool.filter(isV3Item);
		return v3.length ? v3 : pool;
	}

	function nextLiveItem() {
		while (state.pending.length) {
			const it = byKey(state.pending.shift());
			if (it) return it;
		}
		const pool = livePool();
		if (!pool.length) return null;
		const i = pool.findIndex((x) => x.key === state.trKey);
		return pool[(i + 1) % pool.length];
	}

	function liveAdvance() {
		state.ended = null;
		const it = nextLiveItem();
		if (!it) return Promise.resolve(null);
		state.trKey = it.key; // so a failed load still moves the rotation on
		return loadKey(it.key).then((tr) => {
			// A trace that will not load (say, one Syncthing is still writing) is skipped after the usual gap.
			if (!tr && state.mode === "live") state.ended = performance.now();
			return tr;
		});
	}

	// A trace being replaced by Syncthing can read as cut-off JSON for a moment: try once more before giving up.
	function fetchTrace(url) {
		return fetchJson(url).catch(() => new Promise((res) => setTimeout(res, 1500)).then(() => fetchJson(url)));
	}

	function loadKey(key) {
		const item = byKey(key);
		if (!item) return Promise.resolve(null);
		return fetchTrace(item.source.url(item)).then(
			(trace) => setTrace(trace, (item.source.key === "sample" ? "[sample] " : item.source.key === "live" ? "[new] " : "") + item.file, key),
			(err) => {
				showProblems(["Could not load " + item.file + ": " + err.message]);
				return null;
			},
		);
	}

	function setTrace(trace, label, key) {
		const problems = C.validate(trace);
		state.ended = null;
		if (problems.length) {
			state.tr = null;
			state.playing = false;
			$("title").textContent = label;
			showProblems(problems);
			draw();
			return null;
		}
		state.tr = C.prepare(trace);
		state.trKey = key || null;
		if (key) $("pick").value = key;
		state.t = state.tr.t0;
		state.view = makeView(state.tr);
		state.feedShown = -1;
		state.playing = state.mode === "live";
		showProblems([]);
		renderSide(label);
		renderCards();
		renderMarks();
		renderLegend();
		renderBoard();
		update();
		return state.tr;
	}

	function showProblems(list) {
		const el = $("problems");
		el.textContent = "";
		for (const p of list) {
			const d = document.createElement("div");
			d.textContent = "⚠ " + p;
			el.appendChild(d);
		}
	}

	// ---------- side panel ----------

	function crewColor(tr, id) {
		return CREW_COLORS[Math.max(0, tr.crewIds.indexOf(String(id))) % CREW_COLORS.length];
	}

	function renderSide(label) {
		const tr = state.tr;
		const stations = tr.stops.length ? tr.stops.map((s) => s.station).join(" → ") : tr.meta.station;
		$("title").textContent = stations + " · seed " + tr.meta.seed;
		$("meta").textContent = label + " · " + (tr.stops.length ? tr.stops.length + " stops · " : "") + C.clock(tr.t1 - tr.t0) + " · " +
			(tr.v3 ? "format v3" : "format v2 (no speech or moods)");
		$("result").textContent = tr.summary ? tr.summary.text || JSON.stringify(tr.summary) : "No summary in this trace.";
		const key = $("feedKey");
		key.textContent = "";
		for (const k of ["complaint", "bug", "praise", "confusion", "social", "quit"]) {
			const s = document.createElement("span");
			s.className = "k-" + k;
			s.textContent = KIND_LABELS[k];
			key.appendChild(s);
		}
		const list = $("events");
		list.textContent = "";
		state.eventEls = tr.events.map((e) => {
			const kind = C.kindOf(e);
			const li = document.createElement("li");
			li.dataset.base = "k-" + kind + (e.type === "say" ? " k-say" : "");
			const b = document.createElement("b");
			b.textContent = C.clock(e.t);
			b.title = e.t.toFixed(1) + "s";
			li.appendChild(b);
			if (e.type === "say" || e.type === "quit") {
				const chip = document.createElement("span");
				chip.className = "chip";
				chip.textContent = KIND_LABELS[kind] + (e.topic ? " · " + e.topic : "");
				li.appendChild(chip);
			}
			const s = document.createElement("span");
			s.className = "txt";
			s.textContent = C.describe(tr, e);
			li.appendChild(s);
			if (e.detail !== undefined) {
				const d = document.createElement("span");
				d.className = "detail";
				d.textContent = typeof e.detail === "object" ? Object.keys(e.detail).map((k) => k + ": " + JSON.stringify(e.detail[k])).join(" · ") : String(e.detail);
				li.appendChild(d);
			}
			li.className = li.dataset.base;
			li.addEventListener("click", () => seek(e.t));
			list.appendChild(li);
			return li;
		});
	}

	function profileLine(c) {
		const p = c.profile;
		if (!p) return [c.device, c.rttMs !== undefined ? c.rttMs + "ms" : ""].filter(Boolean).join(" · ");
		const parts = [];
		if (p.age !== undefined) parts.push(p.age + " y");
		parts.push(p.device || c.device || p.platform || "");
		if (p.connection) parts.push(p.connection + (p.rttMs !== undefined ? " " + p.rttMs + "ms" : ""));
		if (p.region) parts.push(p.region);
		if (p.localHour !== undefined) parts.push(C.localTime(p.localHour, p.weekday));
		if (p.motive) parts.push(p.motive);
		if (p.runsBefore !== undefined) parts.push(p.runsBefore ? p.runsBefore + " runs before" : "first run");
		return parts.filter(Boolean).join(" · ");
	}

	// Crew cards are built once per trace and updated every frame, so the mood bars animate smoothly.
	function renderCards() {
		const tr = state.tr, box = $("crew");
		box.textContent = "";
		state.cards = {};
		const hasMood = tr.frames.some((f) => Object.values(f.p).some((p) => C.isMood(p[5])));
		for (const id of tr.crewIds) {
			const c = tr.crew[id];
			const card = document.createElement("div");
			card.className = "card";
			const stripe = document.createElement("span");
			stripe.className = "stripe";
			stripe.style.background = crewColor(tr, id);
			const top = document.createElement("div");
			top.className = "top";
			const name = document.createElement("b");
			name.textContent = c.name;
			const st = document.createElement("span");
			st.className = "state";
			top.append(name, st);
			const prof = document.createElement("div");
			prof.className = "prof";
			prof.textContent = profileLine(c);
			if (c.profile && c.profile.traits) prof.title = "traits: " + Object.keys(c.profile.traits).map((k) => k + " " + c.profile.traits[k]).join(", ");
			card.append(stripe, top, prof);
			const bars = [];
			if (hasMood) {
				const moods = document.createElement("div");
				moods.className = "moods";
				C.MOODS.forEach((m, j) => {
					const cell = document.createElement("div");
					cell.textContent = MOOD_SHORT[j];
					cell.title = m;
					const bar = document.createElement("div");
					bar.className = "bar";
					const fill = document.createElement("i");
					fill.style.background = MOOD_COLORS[j];
					fill.style.width = "0";
					bar.appendChild(fill);
					cell.appendChild(bar);
					moods.appendChild(cell);
					bars.push(fill);
				});
				card.appendChild(moods);
			}
			box.appendChild(card);
			state.cards[id] = { card, st, bars };
		}
	}

	function updateCards(snap) {
		const tr = state.tr;
		const byId = {};
		for (const p of snap.players) byId[p.id] = p;
		for (const id of tr.crewIds) {
			const ui = state.cards[id];
			if (!ui) continue;
			const p = byId[id];
			const quit = (!p || p.state === "Left") && tr.events.some((e) => e.type === "quit" && String(e.who) === id && e.t <= snap.t);
			ui.card.classList.toggle("gone", !p || p.state === "Left" || p.state === "LeftBehind");
			ui.st.textContent = quit || (p && p.state === "Left") ? "left the game" : p && p.state === "LeftBehind" ? "left behind" : p ? p.state + (p.armsLost ? " · −" + p.armsLost + " arm" : "") + (p.items ? " · " + p.items + " item" + (p.items > 1 ? "s" : "") : "") : quit ? "left the game" : "–";
			ui.bars.forEach((fill, j) => {
				const v = p && p.mood ? p.mood[j] ?? 0 : 0;
				fill.style.width = Math.round(v * 100) + "%";
				fill.parentElement.title = C.MOODS[j] + " " + (p && p.mood ? v.toFixed(2) : "–");
			});
		}
	}

	function renderBoard() {
		const tr = state.tr;
		if (!tr) return;
		const item = byKey(state.trKey);
		$("boardNow").textContent = "Now playing · " + ((item && item.title) || tr.meta.station);
		const next = state.pending.length ? byKey(state.pending[0]) : (() => {
			const pool = livePool();
			const i = pool.findIndex((x) => x.key === state.trKey);
			return pool.length > 1 ? pool[(i + 1) % pool.length] : null;
		})();
		$("boardNext").textContent = next ? "next: " + (next.title || next.file) : "";
	}

	function renderMarks() {
		const tr = state.tr, marks = $("marks"), scrub = $("scrub");
		marks.textContent = "";
		if (!tr) return;
		marks.style.marginLeft = scrub.offsetLeft - marks.parentElement.offsetLeft + "px";
		marks.style.width = scrub.offsetWidth + "px";
		const span = tr.t1 - tr.t0 || 1;
		const add = (t, color, title, cls) => {
			const m = document.createElement("span");
			m.style.left = ((t - tr.t0) / span) * 100 + "%";
			m.style.background = color;
			m.title = title;
			if (cls) m.className = cls;
			m.addEventListener("click", () => seek(t));
			marks.appendChild(m);
		};
		for (const s of tr.stops) add(s.startT, "#c9ced6", "Stop " + s.n + ": " + s.station, "stopmark");
		for (const e of tr.events) {
			const color = e.type === "say" && e.kind === "bug" ? KIND_COLORS.bug : MARK_COLORS[e.type];
			if (color) add(e.t, color, C.clock(e.t) + " " + C.describe(tr, e));
		}
	}

	function renderLegend() {
		const items = [["#5aa9e6", "crew (colour per player)"], [HOLLOW, "Hollow"], ["#e0b354", "looting ring"],
			["#ff3b30", "held ring"], ["#aeb4be", "left behind (dashed)"], ["#777", "dead ✕ / aboard faded"], ["#3a3f48", "blocked tile"], ["#4a3a2a", "building"]];
		const el = $("legend");
		el.textContent = "";
		for (const [c, t] of items) {
			const s = document.createElement("span");
			const i = document.createElement("i");
			i.style.background = c;
			s.append(i, document.createTextNode(t));
			el.appendChild(s);
		}
	}

	// ---------- map drawing ----------

	function makeView(tr) {
		const b = C.bounds(tr);
		const pad = 24, top = 70; // headroom so bubbles over the train row stay on the canvas
		const w = b.x1 - b.x0 || 1, h = b.z1 - b.z0 || 1;
		canvas.width = 900;
		canvas.height = Math.round(Math.min(900, Math.max(400, (900 * h) / w + top)));
		const s = Math.min((canvas.width - 2 * pad) / w, (canvas.height - pad - top) / h);
		const ox = (canvas.width - w * s) / 2, oy = top + (canvas.height - pad - top - h * s) / 2;
		return { s, X: (x) => ox + (x - b.x0) * s, Y: (z) => oy + (z - b.z0) * s };
	}

	function rect(v, x0, z0, x1, z1) {
		const a = v.X(Math.min(x0, x1)), b = v.Y(Math.min(z0, z1));
		return [a, b, v.X(Math.max(x0, x1)) - a, v.Y(Math.max(z0, z1)) - b];
	}

	function roundRect(x, y, w, h, r) {
		ctx.beginPath();
		ctx.moveTo(x + r, y);
		ctx.arcTo(x + w, y, x + w, y + h, r);
		ctx.arcTo(x + w, y + h, x, y + h, r);
		ctx.arcTo(x, y + h, x, y, r);
		ctx.arcTo(x, y, x + w, y, r);
		ctx.closePath();
	}

	function wrap(text, width, maxLines) {
		const words = String(text).split(/\s+/);
		const lines = [];
		let cur = "";
		for (const w of words) {
			const tryLine = cur ? cur + " " + w : w;
			if (ctx.measureText(tryLine).width > width && cur) {
				lines.push(cur);
				cur = w;
			} else cur = tryLine;
		}
		if (cur) lines.push(cur);
		if (lines.length > maxLines) {
			lines.length = maxLines;
			lines[maxLines - 1] = lines[maxLines - 1].replace(/\s*\S*$/, "") + "…";
		}
		return lines;
	}

	// Speech bubbles over the speakers, nudged apart so two never overlap. Returns how many were drawn.
	function drawBubbles(snap, v, r) {
		if (!$("bubbles").checked) return 0;
		const tr = state.tr;
		const list = C.speechAt(tr, snap.t).sort((a, b) => a.e.t - b.e.t);
		const pos = {};
		for (const p of snap.players) pos[p.id] = [v.X(p.x), v.Y(p.z)];
		const placed = [];
		for (const b of list) {
			const e = b.e;
			const kind = C.kindOf(e);
			const color = KIND_COLORS[kind] || KIND_COLORS.social;
			const anchor = pos[String(e.who)] || [canvas.width / 2, 40];
			ctx.font = "12px system-ui";
			const lines = wrap(e.text || "", 190, 3);
			const head = C.who(tr, e.who) + " · " + KIND_LABELS[kind];
			ctx.font = "bold 10px system-ui";
			const headW = ctx.measureText(head.toUpperCase()).width;
			ctx.font = "12px system-ui";
			const w = Math.max(headW, ...lines.map((l) => ctx.measureText(l).width)) + 16;
			const h = 16 + lines.length * 15 + 4;
			let x = Math.min(canvas.width - w - 4, Math.max(4, anchor[0] - w / 2));
			let y = anchor[1] - r - 12 - h;
			if (y < 4) y = anchor[1] + r + 12;
			for (let k = 0; k < 8; k++) {
				const hit = placed.find((q) => x < q.x + q.w + 4 && q.x < x + w + 4 && y < q.y + q.h + 4 && q.y < y + h + 4);
				if (!hit) break;
				y = hit.y - h - 6;
				if (y < 4) y = hit.y + hit.h + 6;
			}
			placed.push({ x, y, w, h });
			const fadeIn = Math.min(1, b.age / 0.15), fadeOut = Math.min(1, (b.dur - b.age) / 0.6);
			ctx.globalAlpha = Math.max(0, Math.min(fadeIn, fadeOut));
			// Tail to the speaker, then the body.
			const tx = Math.min(x + w - 10, Math.max(x + 10, anchor[0]));
			const below = y > anchor[1];
			ctx.fillStyle = "rgba(20,22,26,0.94)";
			ctx.strokeStyle = color;
			ctx.lineWidth = 2;
			ctx.beginPath();
			ctx.moveTo(tx - 6, below ? y : y + h);
			ctx.lineTo(anchor[0], below ? anchor[1] + r + 2 : anchor[1] - r - 2);
			ctx.lineTo(tx + 6, below ? y : y + h);
			ctx.closePath();
			ctx.fill();
			ctx.stroke();
			roundRect(x, y, w, h, 6);
			ctx.fill();
			ctx.stroke();
			ctx.fillStyle = color;
			ctx.font = "bold 10px system-ui";
			ctx.fillText(head.toUpperCase(), x + 8, y + 13);
			ctx.fillStyle = "#eef0f3";
			ctx.font = "12px system-ui";
			lines.forEach((l, k) => ctx.fillText(l, x + 8, y + 28 + k * 15));
			ctx.globalAlpha = 1;
		}
		return list.length;
	}

	function draw(snap) {
		ctx.setTransform(1, 0, 0, 1, 0, 0);
		ctx.fillStyle = "#101215";
		ctx.fillRect(0, 0, canvas.width, canvas.height);
		const tr = state.tr, v = state.view;
		if (!tr || !v) {
			ctx.fillStyle = "#8b919c";
			ctx.font = "14px system-ui";
			ctx.fillText("No trace loaded", 20, 30);
			return;
		}
		const m = tr.map, half = m.length / 2, depth = m.rows * m.tile;
		ctx.fillStyle = "#171a1f";
		ctx.fillRect(...rect(v, -half, 0, half, depth));
		ctx.strokeStyle = "#1f232a";
		ctx.lineWidth = 1;
		ctx.beginPath();
		for (let c = 0; c <= m.cols; c++) {
			const x = Math.round(v.X(-half + c * m.tile)) + 0.5;
			ctx.moveTo(x, v.Y(0));
			ctx.lineTo(x, v.Y(depth));
		}
		for (let r = 0; r <= m.rows; r++) {
			const y = Math.round(v.Y(r * m.tile)) + 0.5;
			ctx.moveTo(v.X(-half), y);
			ctx.lineTo(v.X(half), y);
		}
		ctx.stroke();
		for (const b of m.buildings) {
			ctx.fillStyle = "#4a3a2a";
			ctx.fillRect(...rect(v, b[0], b[1], b[2], b[3]));
			ctx.strokeStyle = "#7a6146";
			ctx.strokeRect(...rect(v, b[0], b[1], b[2], b[3]));
		}
		ctx.fillStyle = "#3a3f48";
		for (const idx of m.blocked) ctx.fillRect(...rect(v, ...C.cellRect(m, idx)));
		ctx.fillStyle = "#3b4658";
		ctx.fillRect(...rect(v, m.train.x0, m.train.z - 6, m.train.x1, m.train.z + 6));
		ctx.fillStyle = "#c9d1dd";
		ctx.font = "11px system-ui";
		ctx.fillText("TRAIN", v.X(m.train.x0) + 4, v.Y(m.train.z) + 4);
		ctx.fillStyle = "rgba(224,179,84,0.35)";
		ctx.font = "bold 12px ui-monospace, monospace";
		ctx.fillText("SIMULATED", canvas.width - 88, canvas.height - 8);

		if (!snap) return;
		if ($("trails").checked) {
			const i1 = snap.frame, i0 = C.frameIndex(tr.frames, snap.t - TRAIL_SECONDS);
			for (const id of tr.crewIds) {
				ctx.strokeStyle = crewColor(tr, id);
				ctx.globalAlpha = 0.35;
				ctx.lineWidth = 2;
				ctx.beginPath();
				let started = false;
				for (let i = i0; i <= i1; i++) {
					const f = tr.frames[i], p = f.p[id];
					// Positions are local to each stop: never draw a trail across a stop change.
					if (!p || p[2] === "Aboard" || f.stop !== snap.stop) {
						started = false;
						continue;
					}
					if (started) ctx.lineTo(v.X(p[0]), v.Y(p[1]));
					else ctx.moveTo(v.X(p[0]), v.Y(p[1]));
					started = true;
				}
				ctx.stroke();
			}
			ctx.globalAlpha = 1;
		}
		const r = Math.max(5, Math.min(9, 3 * v.s));
		ctx.fillStyle = HOLLOW;
		for (const h of snap.hollows) {
			const x = v.X(h[0]), y = v.Y(h[1]);
			ctx.beginPath();
			ctx.moveTo(x, y - r);
			ctx.lineTo(x + r, y);
			ctx.lineTo(x, y + r);
			ctx.lineTo(x - r, y);
			ctx.closePath();
			ctx.fill();
		}
		const pulse = 0.5 + 0.5 * Math.sin(performance.now() / 150);
		for (const p of snap.players) {
			if (p.state === "Left") continue; // quit the game: off the map, the card says so
			const x = v.X(p.x), y = v.Y(p.z), color = crewColor(tr, p.id);
			ctx.globalAlpha = p.state === "Aboard" ? 0.45 : p.state === "LeftBehind" ? 0.5 : 1;
			if (p.state === "Dead") {
				ctx.strokeStyle = "#777";
				ctx.lineWidth = 3;
				ctx.beginPath();
				ctx.moveTo(x - r, y - r);
				ctx.lineTo(x + r, y + r);
				ctx.moveTo(x + r, y - r);
				ctx.lineTo(x - r, y + r);
				ctx.stroke();
			} else {
				ctx.fillStyle = color;
				ctx.beginPath();
				ctx.arc(x, y, r, 0, Math.PI * 2);
				ctx.fill();
				if (p.state === "Held" || p.state === "Looting" || p.state === "LeftBehind") {
					ctx.strokeStyle = p.state === "Held" ? "#ff3b30" : p.state === "LeftBehind" ? "#aeb4be" : "#e0b354";
					ctx.lineWidth = 2;
					if (p.state === "LeftBehind") ctx.setLineDash([3, 3]);
					ctx.beginPath();
					ctx.arc(x, y, r + 3 + (p.state === "Held" ? 3 * pulse : 0), 0, Math.PI * 2);
					ctx.stroke();
					ctx.setLineDash([]);
				}
			}
			ctx.globalAlpha = 1;
			ctx.fillStyle = "#e4e6ea";
			ctx.font = "12px system-ui";
			let tag = p.name;
			if (p.armsLost) tag += " −" + p.armsLost;
			if (p.items) tag += " ·" + p.items;
			ctx.fillText(tag, x + r + 4, y + r + 10);
		}
		// Recent game events (not speech, which has its bubbles), bottom left.
		const recent = tr.events.filter((e) => e.type !== "say" && e.t <= snap.t && e.t > snap.t - RECENT_SECONDS * 2).slice(-3);
		ctx.font = "13px system-ui";
		recent.forEach((e, k) => {
			const text = C.clock(e.t) + "  " + C.describe(tr, e);
			const y = canvas.height - 26 - (recent.length - 1 - k) * 18;
			ctx.fillStyle = "rgba(16,18,21,0.8)";
			ctx.fillRect(8, y - 13, ctx.measureText(text).width + 12, 18);
			ctx.fillStyle = MARK_COLORS[e.type] || KIND_COLORS[C.kindOf(e)] || "#e4e6ea";
			ctx.fillText(text, 14, y);
		});
		state.lastBubbles = drawBubbles(snap, v, r);
		drawStopBanner(snap);
		if (state.mode === "live" && state.ended !== null) {
			const left = Math.max(0, Math.ceil(LIVE_GAP - (performance.now() - state.ended) / 1000));
			banner("Next session in " + left + "…", 0.85, canvas.height / 2);
		}
	}

	function banner(text, alpha, y) {
		ctx.font = "bold 20px ui-monospace, monospace";
		const w = ctx.measureText(text).width + 36;
		ctx.globalAlpha = alpha;
		ctx.fillStyle = "#0d0e10";
		ctx.fillRect((canvas.width - w) / 2, y - 22, w, 36);
		ctx.strokeStyle = "#e0b354";
		ctx.setLineDash([6, 4]);
		ctx.strokeRect((canvas.width - w) / 2, y - 22, w, 36);
		ctx.setLineDash([]);
		ctx.fillStyle = "#e0b354";
		ctx.fillText(text, (canvas.width - w) / 2 + 18, y + 3);
		ctx.globalAlpha = 1;
	}

	function drawStopBanner(snap) {
		const tr = state.tr;
		const s = C.stopAt(tr, snap.t);
		if (!s) return;
		const since = snap.t - s.startT;
		if (since >= 0 && since < 3.5) banner(("Stop " + s.n + " · " + s.station).toUpperCase(), Math.min(1, (3.5 - since) / 0.8), 34);
		else if (snap.t > s.endT) {
			const next = tr.stops.find((x) => x.startT > snap.t);
			if (next) banner("On the train to " + next.station, 0.7, 34);
		}
	}

	// ---------- playback ----------

	function seek(t) {
		const tr = state.tr;
		if (!tr) return;
		state.ended = null;
		state.t = Math.min(tr.t1, Math.max(tr.t0, t));
		update();
	}

	function update() {
		const tr = state.tr;
		if (!tr) return draw();
		const snap = C.sample(tr, state.t);
		draw(snap);
		updateCards(snap);
		$("clock").textContent = C.clock(state.t) + " / " + C.clock(tr.t1);
		$("scrub").value = String(Math.round(((state.t - tr.t0) / (tr.t1 - tr.t0 || 1)) * 1000));
		$("play").textContent = state.playing ? "❚❚" : "▶";
		const s = C.stopAt(tr, state.t);
		const next = s && state.t > s.endT ? tr.stops.find((x) => x.startT > state.t) : null;
		$("stopline").textContent = !s ? "" : next ? "Between stops · riding to " + next.station : "Stop " + s.n + " of " + tr.stops.length + " · " + s.station;
		const list = $("events");
		const atBottom = list.scrollHeight - list.scrollTop - list.clientHeight < 60;
		let shown = 0;
		// At the end of a session, lines stamped after the last frame (the outcome) count as said.
		const upTo = state.t >= tr.t1 ? Infinity : state.t;
		tr.events.forEach((e, k) => {
			const el = state.eventEls[k];
			if (!el) return;
			const now = e.t <= upTo && e.t > state.t - RECENT_SECONDS;
			if (e.t <= upTo) shown++;
			el.className = el.dataset.base + (now ? " now" : e.t <= upTo ? " past" : " future");
		});
		// Live feed: keep the newest line in view unless the reader scrolled up.
		if (state.mode === "live" && shown !== state.feedShown) {
			if (atBottom || state.feedShown < 0) list.scrollTop = list.scrollHeight;
			state.feedShown = shown;
		}
		return snap;
	}

	function tick(now) {
		const dt = state.lastTick ? Math.min(0.1, (now - state.lastTick) / 1000) : 0;
		state.lastTick = now;
		step(dt);
		if (state.mode === "live" && state.ended !== null && now - state.ended > LIVE_GAP * 1000) liveAdvance();
		requestAnimationFrame(tick);
	}

	function step(dt) {
		const tr = state.tr;
		if (state.mode === "reports") return;
		if (tr && state.playing) {
			state.t += dt * Number($("speed").value);
			if (state.t >= tr.t1) {
				state.t = tr.t1;
				state.playing = false;
				if (state.mode === "live") state.ended = performance.now();
			}
			update();
		} else if (tr) {
			draw(C.sample(tr, state.t));
		}
	}

	function togglePlay() {
		const tr = state.tr;
		if (!tr) return;
		state.ended = null;
		if (!state.playing && state.t >= tr.t1) state.t = tr.t0;
		state.playing = !state.playing;
		update();
	}

	// ---------- modes ----------

	function setMode(mode) {
		state.mode = mode;
		document.body.className = "mode-" + mode;
		for (const b of document.querySelectorAll("#tabs button")) b.setAttribute("aria-selected", String(b.dataset.mode === mode));
		$("reports").hidden = mode !== "reports";
		if (mode === "reports") return openReports();
		$("speed").value = mode === "live" ? "1" : "2";
		state.feedShown = -1;
		if (mode === "live" && state.tr) {
			renderBoard();
			if (!state.playing && state.t < state.tr.t1) state.playing = true;
			else if (state.t >= state.tr.t1) state.ended = performance.now();
		}
		requestAnimationFrame(renderMarks);
		update();
		return Promise.resolve();
	}

	// ---------- reports ----------

	function loadSummary() {
		const url = state.summarySample ? "sample/summary-v3.json" : "../summary.json";
		return fetch(url, { cache: "no-store" })
			.then((r) => (r.ok ? r.text() : Promise.reject(new Error("HTTP " + r.status))))
			.then((text) => {
				const changed = text !== state.summaryText;
				state.summaryText = text;
				state.summary = JSON.parse(text);
				$("note").textContent = state.summary.note || "";
				return changed;
			})
			.catch(() => {
				state.summary = null;
				return false;
			});
	}

	function reportPool() {
		if (state.summarySample || params.get("source") === "sample") return state.items.filter((x) => x.source.key === "sample");
		const pool = state.items.filter((x) => x.source.key !== "sample");
		return pool.length ? pool : state.items.filter((x) => x.source.key === "sample");
	}

	function reportTraces() {
		const pool = reportPool().slice(0, 150);
		return Promise.all(pool.map((it) => {
			if (state.reportCache[it.key]) return state.reportCache[it.key];
			return fetchTrace(it.source.url(it)).then((t) => {
				const light = C.validate(t).length ? null : { key: it.key, id: it.id || it.file, title: it.title, meta: t.meta, events: t.events || [] };
				state.reportCache[it.key] = light;
				return light;
			}, () => null);
		})).then((list) => list.filter(Boolean));
	}

	function openReports() {
		return Promise.all([state.summary ? null : loadSummary(), reportTraces()]).then(([, traces]) => {
			R.render({
				summary: state.summary || {},
				sample: state.summarySample,
				label: state.summary ? "Source: tools/limbsim/summary.json, " + (state.summary.sessions || "?") + " sessions." : "tools/limbsim/summary.json not found.",
				traces,
				open: (key, t) => setMode("replay").then(() => loadKey(key)).then(() => {
					if (t !== null && t !== undefined) seek(t);
				}),
				preview: () => {
					state.summarySample = true;
					state.summary = null;
					openReports();
				},
			});
		});
	}

	// ---------- new session (serve.py runs the sim) ----------

	function setJobButton() {
		const b = $("newSession"), j = state.job;
		b.hidden = !HTTP;
		b.classList.toggle("unavailable", !j.supported);
		b.disabled = j.state === "running";
		b.textContent = j.state === "running" ? "Simulating… " + Math.round(j.elapsed || 0) + "s" : "＋ New session";
		b.title = j.supported ? "Simulate one fresh session on this laptop (lune run limbsim --one) and play it" : "Not available yet: " + j.why;
	}

	function pollJob() {
		return fetchJson("/__job").then((j) => {
			const was = state.job.state;
			state.job = j;
			setJobButton();
			return { j, was };
		});
	}

	function newSession() {
		if (!state.job.supported) {
			toast("New session is not available yet: " + state.job.why, true);
			return Promise.resolve({ ok: false, error: state.job.why });
		}
		return fetch("/__new", { method: "POST", headers: { "X-LimbSim": "1" } })
			.then((r) => r.json().then((body) => ({ status: r.status, body })))
			.then(({ status, body }) => {
				if (status !== 202 && status !== 409) {
					toast("Could not start a session: " + (body.error || status), true);
					return { ok: false, error: body.error };
				}
				toast(status === 409 ? "A session is already being simulated; it will play when ready." : "Simulating a new session (seed " + body.seed + ")…");
				return waitForJob();
			});
	}

	function waitForJob() {
		return new Promise((resolve) => {
			const loop = () => pollJob().then(({ j }) => {
				if (j.state === "running") return setTimeout(loop, 1000);
				if (j.state === "error") {
					toast("The sim failed: " + j.error, true);
					if (j.log) console.warn("limbsim log:\n" + j.log.join("\n"));
					return resolve({ ok: false, error: j.error });
				}
				loadIndexes().then(() => {
					const key = "live:" + j.file;
					if (!byKey(key)) return resolve({ ok: false, error: "finished trace not listed" });
					toast("New session ready (" + j.seconds + "s to simulate). Playing it now.");
					state.pending = state.pending.filter((k) => k !== key);
					state.pending.unshift(key);
					return setMode("live").then(liveAdvance).then(() => resolve({ ok: state.trKey === key, id: j.id }));
				});
			}, () => resolve({ ok: false, error: "lost the viewer server" }));
			loop();
		});
	}

	// New traces synced from the HP (or made here) show up without a reload.
	function refresh() {
		return Promise.all([loadIndexes(), loadSummary()]).then(([{ added }, summaryChanged]) => {
			if (added.length) {
				const live = added.filter((x) => isV3Item(x) || livePool().includes(x));
				for (const x of live) if (!state.pending.includes(x.key) && x.key !== state.trKey) state.pending.push(x.key);
				toast(added.length === 1 ? "New trace: " + (added[0].title || added[0].file) : added.length + " new traces arrived");
				renderBoard();
			}
			if (state.mode === "reports" && (added.length || summaryChanged)) openReports();
			return added;
		});
	}

	// ---------- wiring ----------

	for (const b of document.querySelectorAll("#tabs button")) b.addEventListener("click", () => setMode(b.dataset.mode));
	$("pick").addEventListener("change", (e) => loadKey(e.target.value));
	$("play").addEventListener("click", togglePlay);
	$("skip").addEventListener("click", liveAdvance);
	$("newSession").addEventListener("click", newSession);
	$("scrub").addEventListener("input", (e) => {
		const tr = state.tr;
		if (tr) seek(tr.t0 + (Number(e.target.value) / 1000) * (tr.t1 - tr.t0));
	});
	$("trails").addEventListener("change", () => update());
	$("bubbles").addEventListener("change", () => update());
	$("file").addEventListener("change", (e) => {
		const f = e.target.files && e.target.files[0];
		if (!f) return;
		f.text().then((txt) => {
			let trace;
			try {
				trace = JSON.parse(txt);
			} catch (err) {
				return showProblems([f.name + " is not valid JSON: " + err.message]);
			}
			setTrace(trace, "[file] " + f.name, null);
		});
	});
	window.addEventListener("resize", renderMarks);
	document.addEventListener("keydown", (e) => {
		if (state.mode === "reports") return;
		if (e.target && (e.target.tagName === "SELECT" || e.target.tagName === "INPUT") && e.target.type !== "range") return;
		const step = e.shiftKey ? 5 : 1;
		if (e.code === "Space") togglePlay();
		else if (e.code === "ArrowRight") seek(state.t + step);
		else if (e.code === "ArrowLeft") seek(state.t - step);
		else if (e.code === "Home" && state.tr) seek(state.tr.t0);
		else if (e.code === "End" && state.tr) seek(state.tr.t1);
		else if (e.code === "KeyN" && state.mode === "live") liveAdvance();
		else return;
		e.preventDefault();
	});

	if (HTTP) setInterval(() => fetch("/__ping", { cache: "no-store" }).catch(() => {}), 60000);
	if (params.get("summary") === "sample") state.summarySample = true;
	setJobButton();
	const jobReady = HTTP ? pollJob().then(({ j }) => (j.state === "running" ? waitForJob() : null), () => null) : Promise.resolve();

	const startMode = ["live", "replay", "reports"].includes(params.get("mode")) ? params.get("mode") : "live";
	const ready = Promise.all([loadIndexes(), loadSummary()]).then(([{ items }]) => {
		state.mode = startMode === "reports" ? "live" : startMode;
		if (!items.length) {
			draw();
			return setMode(startMode);
		}
		const want = params.get("trace");
		const hit = want ? items.find((x) => x.id === want || x.file === want) : null;
		const first = hit || (state.mode === "live" ? livePool()[0] : items[0]) || items[0];
		return loadKey(first.key).then(() => {
			if (params.has("t")) seek(Number(params.get("t")) || 0);
			return setMode(startMode);
		});
	});

	if (SELFTEST) ready.then(() => jobReady).then(selfTest);
	else if (params.get("selftest") === "shot")
		ready.then(() => fetch("/__report", { method: "POST", body: JSON.stringify({ png: canvas.toDataURL("image/png") }) }));
	else {
		ready.then(() => requestAnimationFrame(tick));
		if (HTTP) setInterval(() => refresh().catch(() => {}), POLL_MS);
	}

	// ---------- self-test (?selftest=1, driven by check.py through headless Firefox) ----------

	const errors = [];
	window.addEventListener("error", (e) => errors.push("window error: " + e.message + " @" + (e.filename || "") + ":" + (e.lineno || "")));
	window.addEventListener("unhandledrejection", (e) => errors.push("unhandled rejection: " + ((e.reason && e.reason.message) || e.reason)));

	async function selfTest() {
		const report = { traces: [], errors };
		await setMode("replay");
		for (const item of state.items.slice()) {
			const r = { file: item.source.key + "/" + item.file, ok: false };
			try {
				const tr = await loadKey(item.key);
				if (!tr) throw new Error("did not load: " + $("problems").textContent);
				r.frames = tr.frames.length;
				r.events = tr.events.length;
				r.crew = tr.crewIds.length;
				r.v3 = tr.v3;
				for (let k = 0; k <= 40; k++) {
					state.t = tr.t0 + ((tr.t1 - tr.t0) * k) / 40;
					const snap = update();
					if (!snap || snap.players.length === 0) throw new Error("no players at step " + k);
				}
				for (const e of tr.events) seek(e.t);
				state.t = tr.t0;
				state.playing = true;
				for (let k = 0; k < 100000 && state.playing; k++) step(0.1);
				if (state.playing || state.t !== tr.t1) throw new Error("playback did not reach the end");
				r.eventLines = $("events").children.length;
				if (r.eventLines !== tr.events.length) throw new Error("event list has " + r.eventLines + " of " + tr.events.length);
				r.ok = true;
			} catch (err) {
				r.error = String((err && err.stack) || err);
			}
			report.traces.push(r);
		}

		// Live: every v3 trace plays at 1x like a spectator, with bubbles, a coloured feed, mood bars and stop banners.
		report.live = [];
		await setMode("live");
		for (const item of state.items.filter((x) => isV3Item(x))) {
			const r = { file: item.source.key + "/" + item.file, ok: false };
			try {
				const tr = await loadKey(item.key);
				if (!tr) throw new Error("did not load: " + $("problems").textContent);
				if (!state.playing) throw new Error("live did not start playing");
				let maxBubbles = 0, minFeed = Infinity, kinds = new Set(), stops = new Set();
				for (let k = 0; k < 200000 && state.playing; k++) {
					step(0.1);
					maxBubbles = Math.max(maxBubbles, state.lastBubbles);
					const snap = C.sample(tr, state.t);
					if (snap.stop !== null) stops.add(snap.stop);
				}
				if (state.ended === null) throw new Error("live did not end the session");
				const shown = [...$("events").children].filter((li) => !li.classList.contains("future"));
				for (const li of shown) kinds.add(li.dataset.base.split(" ")[0]);
				minFeed = shown.length;
				const bars = $("crew").querySelectorAll(".moods .bar i").length;
				Object.assign(r, { bubbles: maxBubbles, feed: minFeed, kinds: [...kinds].sort(), moodBars: bars, stops: stops.size, board: $("boardNow").textContent });
				if (tr.speech.length && maxBubbles === 0) throw new Error("no speech bubble was drawn");
				if (minFeed !== tr.events.length) throw new Error("feed shows " + minFeed + " of " + tr.events.length + " at the end");
				if (bars && bars !== tr.crewIds.length * 5) throw new Error("mood bars " + bars);
				r.ok = true;
			} catch (err) {
				r.error = String((err && err.stack) || err);
			}
			report.live.push(r);
		}
		// Live moves on to another session by itself.
		const before = state.trKey;
		state.ended = performance.now() - LIVE_GAP * 1000 - 1;
		await liveAdvance();
		report.liveAdvances = livePool().length < 2 || state.trKey !== before;

		// New session through serve.py (check.py swaps in a fake sim when lune's --one mode is missing).
		if (state.job.supported) {
			report.newSession = await newSession();
			report.newSession.listed = state.items.some((x) => x.source.key === "live");
			report.newSession.playing = state.mode === "live" && String(state.trKey).startsWith("live:");
		} else report.newSession = { skipped: state.job.why };

		// Reports: the real summary first, then the hand-made v3 sample.
		try {
			await setMode("reports");
			const n = (sel) => document.querySelectorAll(sel).length;
			report.reportsReal = {
				v3: R.isV3(state.summary), features: n("#repFeatures .fcard"), complaints: n("#repComplaints .row"), praise: n("#repPraise .row"),
				bugs: Math.max(0, n("#repBugs tr") - 1), traceBugs: Math.max(0, n("#repTraceBugs tr") - 1), hourRows: n("#repHour .row, #repHour .chart .col"),
				devices: n("#repDevice .hbars .row"), connections: n("#repConnection .hbars .row"),
				people: $("repPopulation") ? Number($("repPopulation").querySelector("table").dataset.rows) : 0,
				population: !!$("repPopulation"), totals: !!$("summaryBody").querySelector("table, .tot"),
			};
			if (report.reportsReal.v3 && (!report.reportsReal.features || !report.reportsReal.complaints || !report.reportsReal.people))
				throw new Error("real v3 summary rendered empty sections: " + JSON.stringify(report.reportsReal));
			state.summarySample = true;
			state.summary = null;
			await openReports();
			const sample = JSON.parse(state.summaryText);
			const q = (sel) => document.querySelectorAll(sel).length;
			report.reportsSample = {
				features: q("#repFeatures .fcard") + "/" + sample.features.length,
				complaints: q("#repComplaints .row") + "/" + Object.keys(sample.feedback.complaints).length,
				bugs: q("#repBugs tr") - 1 + "/" + sample.feedback.bugs.length,
				traceBugs: q("#repTraceBugs tr") - 1,
				hours: q("#repHour .chart .col"),
				devices: q("#repDevice .hbars .row") + "/" + Object.keys(sample.byDevice).length,
				people: Number(document.querySelector("#repPopulation table").dataset.rows),
				banner: document.querySelector("#reports .sim-banner").textContent.includes("not real people"),
			};
			const rs = report.reportsSample;
			report.reportsOk = rs.features.split("/")[0] === rs.features.split("/")[1] && rs.complaints.split("/")[0] === rs.complaints.split("/")[1] &&
				rs.bugs.split("/")[0] === rs.bugs.split("/")[1] && rs.hours === 24 && rs.devices.split("/")[0] === rs.devices.split("/")[1] &&
				rs.people > 0 && rs.traceBugs > 0 && rs.banner && report.reportsReal.population;
			// Opening a bug report jumps to Replay at that moment.
			const watch = document.querySelector("#repTraceBugs button");
			watch.click();
			await new Promise((res) => setTimeout(res, 500));
			report.bugOpensReplay = state.mode === "replay" && state.tr !== null;
		} catch (err) {
			report.reportsOk = false;
			report.reportsError = String((err && err.stack) || err);
		}

		const bad = setTrace({ meta: {}, frames: [] }, "bad", null);
		report.rejectsBad = bad === null && $("problems").children.length > 0;
		document.title = "SELFTEST DONE";
		await fetch("/__report", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(report) }).catch(() => {});
	}
})();
