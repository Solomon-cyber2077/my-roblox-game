// Limb-sim viewer UI. Plays one trace on a top-down map; the trace logic lives in core.js.
(function () {
	"use strict";
	const C = window.LimbCore;
	const $ = (id) => document.getElementById(id);
	const params = new URLSearchParams(location.search);
	const SELFTEST = params.get("selftest") === "1";

	// Real traces from the HP's runs win; the hand-made sample is the fallback and test fixture.
	const SOURCES = [
		{ label: "Real traces", index: "../traces/index.json", base: "../traces/" },
		{ label: "Sample (hand-made)", index: "sample/index.json", base: "sample/" },
	];
	const CREW_COLORS = ["#5aa9e6", "#7bd389", "#c792ea", "#f2a65a", "#f06292", "#4dd0e1"];
	const HOLLOW = "#e5544b";
	const MARK_COLORS = {
		death: "#e5544b", tear: "#f2a65a", grab: "#c792ea", rescueOpen: "#7bd389", rescueJoin: "#7bd389",
		returnStart: "#e0b354", heal: "#4dd0e1", outcome: "#ffffff",
	};
	const TRAIL_SECONDS = 8;
	const RECENT_SECONDS = 1.5;

	const canvas = $("map");
	const ctx = canvas.getContext("2d");
	const state = { items: [], tr: null, t: 0, playing: false, view: null, lastTick: 0, eventEls: [] };

	function fetchJson(url) {
		return fetch(url, { cache: "no-store" }).then((r) => {
			if (!r.ok) throw new Error(url + ": HTTP " + r.status);
			return r.json();
		});
	}

	// ---------- loading ----------

	function loadIndexes() {
		return Promise.all(
			SOURCES.map((s) =>
				fetchJson(s.index)
					.then((list) => (Array.isArray(list) ? list : []).filter((x) => x && x.file).map((x) => ({ ...x, source: s })))
					.catch(() => []),
			),
		).then((lists) => {
			state.items = lists.flat();
			const pick = $("pick");
			pick.textContent = "";
			for (const s of SOURCES) {
				const mine = state.items.filter((x) => x.source === s);
				if (!mine.length) continue;
				const group = document.createElement("optgroup");
				group.label = s.label + " (" + mine.length + ")";
				for (const x of mine) {
					const o = document.createElement("option");
					o.value = String(state.items.indexOf(x));
					o.textContent = x.title || x.id || x.file;
					group.appendChild(o);
				}
				pick.appendChild(group);
			}
			const real = state.items.filter((x) => x.source === SOURCES[0]).length;
			$("source").textContent = real
				? real + " real traces from tools/limbsim/traces/"
				: state.items.length
					? "No real traces found; showing the hand-made sample"
					: location.protocol === "file:"
						? "Open this through the desktop launcher (browsers block file:// loading); Open file… still works"
						: "No traces found";
			return state.items;
		});
	}

	function loadItem(i) {
		const item = state.items[i];
		if (!item) return Promise.resolve(null);
		$("pick").value = String(i);
		return fetchJson(item.source.base + item.file).then(
			(trace) => setTrace(trace, (item.source === SOURCES[0] ? "" : "[sample] ") + item.file),
			(err) => showProblems(["Could not load " + item.file + ": " + err.message]),
		);
	}

	function setTrace(trace, label) {
		const problems = C.validate(trace);
		if (problems.length) {
			state.tr = null;
			state.playing = false;
			$("title").textContent = label;
			showProblems(problems);
			draw();
			return null;
		}
		state.tr = C.prepare(trace);
		state.t = state.tr.t0;
		state.view = makeView(state.tr);
		showProblems([]);
		renderSide(label);
		renderMarks();
		renderLegend();
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
		$("title").textContent = tr.meta.station + " · seed " + tr.meta.seed;
		$("meta").textContent = label + " · " + tr.frames.length + " frames · " + (tr.t1 - tr.t0).toFixed(1) + "s";
		$("result").textContent = tr.summary ? tr.summary.text || JSON.stringify(tr.summary) : "No summary in this trace.";
		const list = $("events");
		list.textContent = "";
		state.eventEls = tr.events.map((e) => {
			const li = document.createElement("li");
			const b = document.createElement("b");
			b.textContent = e.t.toFixed(1) + "s";
			const s = document.createElement("span");
			s.textContent = C.describe(tr, e);
			li.append(b, s);
			li.addEventListener("click", () => seek(e.t));
			list.appendChild(li);
			return li;
		});
	}

	function renderCrew(snap) {
		const tr = state.tr;
		const table = $("crew");
		table.textContent = "";
		const head = table.insertRow();
		for (const h of ["", "Name", "Device", "RTT", "State", "Arms lost", "Items"]) {
			const th = document.createElement("th");
			th.textContent = h;
			if (h === "RTT" || h === "Items") th.className = "num";
			head.appendChild(th);
		}
		const byId = {};
		for (const p of snap.players) byId[p.id] = p;
		for (const id of tr.crewIds) {
			const c = tr.crew[id], p = byId[id];
			const row = table.insertRow();
			const dot = row.insertCell();
			dot.innerHTML = '<span style="display:inline-block;width:10px;height:10px;border-radius:50%"></span>';
			dot.firstChild.style.background = crewColor(tr, id);
			const cells = [c.name + (c.persona && c.persona !== String(c.name).toLowerCase() ? " (" + c.persona + ")" : ""),
				c.device || "", c.rttMs !== undefined ? c.rttMs + "ms" : "", p ? p.state : "–", p ? p.armsLost || "–" : "–", p ? String(p.items) : "–"];
			cells.forEach((v, k) => {
				const td = row.insertCell();
				td.textContent = v;
				if (k === 2 || k === 5) td.className = "num";
			});
		}
	}

	function renderMarks() {
		const tr = state.tr, marks = $("marks"), scrub = $("scrub");
		marks.textContent = "";
		if (!tr) return;
		marks.style.marginLeft = scrub.offsetLeft - marks.parentElement.offsetLeft + "px";
		marks.style.width = scrub.offsetWidth + "px";
		const span = tr.t1 - tr.t0 || 1;
		for (const e of tr.events) {
			const color = MARK_COLORS[e.type];
			if (!color) continue;
			const m = document.createElement("span");
			m.style.left = ((e.t - tr.t0) / span) * 100 + "%";
			m.style.background = color;
			m.title = e.t.toFixed(1) + "s " + C.describe(tr, e);
			m.addEventListener("click", () => seek(e.t));
			marks.appendChild(m);
		}
	}

	function renderLegend() {
		const items = [["#5aa9e6", "crew (colour per player)"], [HOLLOW, "Hollow"], ["#e0b354", "looting ring"],
			["#ff3b30", "held ring"], ["#777", "dead ✕ / aboard faded"], ["#3a3f48", "blocked tile"], ["#4a3a2a", "building"]];
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
		const pad = 24;
		const w = b.x1 - b.x0 || 1, h = b.z1 - b.z0 || 1;
		// Size the canvas to the station's shape, within a sane range.
		canvas.width = 900;
		canvas.height = Math.round(Math.min(900, Math.max(360, (900 * h) / w)));
		const s = Math.min((canvas.width - 2 * pad) / w, (canvas.height - 2 * pad) / h);
		const ox = (canvas.width - w * s) / 2, oy = (canvas.height - h * s) / 2;
		return { s, X: (x) => ox + (x - b.x0) * s, Y: (z) => oy + (z - b.z0) * s };
	}

	function rect(v, x0, z0, x1, z1) {
		const a = v.X(Math.min(x0, x1)), b = v.Y(Math.min(z0, z1));
		return [a, b, v.X(Math.max(x0, x1)) - a, v.Y(Math.max(z0, z1)) - b];
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
		// Ground and grid.
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
		// Buildings, then blocked tiles on top.
		for (const b of m.buildings) {
			ctx.fillStyle = "#4a3a2a";
			ctx.fillRect(...rect(v, b[0], b[1], b[2], b[3]));
			ctx.strokeStyle = "#7a6146";
			ctx.strokeRect(...rect(v, b[0], b[1], b[2], b[3]));
		}
		ctx.fillStyle = "#3a3f48";
		for (const idx of m.blocked) ctx.fillRect(...rect(v, ...C.cellRect(m, idx)));
		// Train along its z line.
		ctx.fillStyle = "#3b4658";
		ctx.fillRect(...rect(v, m.train.x0, m.train.z - 6, m.train.x1, m.train.z + 6));
		ctx.fillStyle = "#c9d1dd";
		ctx.font = "11px system-ui";
		ctx.fillText("TRAIN", v.X(m.train.x0) + 4, v.Y(m.train.z) + 4);

		if (!snap) return;
		// Trails from the last few seconds of frames.
		if ($("trails").checked) {
			const i1 = snap.frame, i0 = C.frameIndex(tr.frames, snap.t - TRAIL_SECONDS);
			for (const id of tr.crewIds) {
				ctx.strokeStyle = crewColor(tr, id);
				ctx.globalAlpha = 0.35;
				ctx.lineWidth = 2;
				ctx.beginPath();
				let started = false;
				for (let i = i0; i <= i1; i++) {
					const p = tr.frames[i].p[id];
					if (!p || p[2] === "Aboard") {
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
		// Hollows as diamonds.
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
		// Crew.
		const pulse = 0.5 + 0.5 * Math.sin(performance.now() / 150);
		for (const p of snap.players) {
			const x = v.X(p.x), y = v.Y(p.z), color = crewColor(tr, p.id);
			ctx.globalAlpha = p.state === "Aboard" ? 0.45 : 1;
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
				if (p.state === "Held" || p.state === "Looting") {
					ctx.strokeStyle = p.state === "Held" ? "#ff3b30" : "#e0b354";
					ctx.lineWidth = 2;
					ctx.beginPath();
					ctx.arc(x, y, r + 3 + (p.state === "Held" ? 3 * pulse : 0), 0, Math.PI * 2);
					ctx.stroke();
				}
			}
			ctx.globalAlpha = 1;
			ctx.fillStyle = "#e4e6ea";
			ctx.font = "12px system-ui";
			let tag = p.name;
			if (p.armsLost) tag += " −" + p.armsLost;
			if (p.items) tag += " ·" + p.items;
			ctx.fillText(tag, x + r + 4, y - r);
		}
		// Recent events, newest last.
		const recent = tr.events.filter((e) => e.t <= snap.t && e.t > snap.t - RECENT_SECONDS * 2).slice(-4);
		ctx.font = "13px system-ui";
		recent.forEach((e, k) => {
			const text = e.t.toFixed(1) + "s  " + C.describe(tr, e);
			const y = canvas.height - 14 - (recent.length - 1 - k) * 18;
			ctx.fillStyle = "rgba(16,18,21,0.75)";
			ctx.fillRect(8, y - 13, ctx.measureText(text).width + 12, 18);
			ctx.fillStyle = MARK_COLORS[e.type] || "#e4e6ea";
			ctx.fillText(text, 14, y);
		});
	}

	// ---------- playback ----------

	function seek(t) {
		const tr = state.tr;
		if (!tr) return;
		state.t = Math.min(tr.t1, Math.max(tr.t0, t));
		update();
	}

	function update() {
		const tr = state.tr;
		if (!tr) return draw();
		const snap = C.sample(tr, state.t);
		draw(snap);
		renderCrew(snap);
		$("clock").textContent = state.t.toFixed(1) + " / " + tr.t1.toFixed(1) + "s";
		$("scrub").value = String(Math.round(((state.t - tr.t0) / (tr.t1 - tr.t0 || 1)) * 1000));
		$("play").textContent = state.playing ? "❚❚" : "▶";
		tr.events.forEach((e, k) => {
			const el = state.eventEls[k];
			if (!el) return;
			const now = e.t <= state.t && e.t > state.t - RECENT_SECONDS;
			el.className = now ? "now" : e.t <= state.t ? "past" : "";
		});
		return snap;
	}

	function tick(now) {
		const dt = state.lastTick ? Math.min(0.1, (now - state.lastTick) / 1000) : 0;
		state.lastTick = now;
		step(dt);
		requestAnimationFrame(tick);
	}

	function step(dt) {
		const tr = state.tr;
		if (tr && state.playing) {
			state.t += dt * Number($("speed").value);
			if (state.t >= tr.t1) {
				state.t = tr.t1;
				state.playing = false;
			}
			update();
		} else if (tr) {
			// Keep the held ring pulsing while paused.
			draw(C.sample(tr, state.t));
		}
	}

	function togglePlay() {
		const tr = state.tr;
		if (!tr) return;
		if (!state.playing && state.t >= tr.t1) state.t = tr.t0;
		state.playing = !state.playing;
		update();
	}

	// ---------- all-sessions summary ----------

	function renderSummary(s) {
		const body = $("summaryBody");
		body.textContent = "";
		body.classList.remove("muted");
		$("note").textContent = s.note || "";
		if (s.totals) {
			const box = document.createElement("div");
			const h = document.createElement("h3");
			h.textContent = "Totals over " + (s.sessions !== undefined ? s.sessions : "?") + " sessions";
			const grid = document.createElement("div");
			grid.className = "tot";
			for (const k of Object.keys(s.totals)) {
				const a = document.createElement("span"), b = document.createElement("span");
				a.textContent = k;
				b.textContent = String(s.totals[k]);
				grid.append(a, b);
			}
			box.append(h, grid);
			body.appendChild(box);
		}
		if (s.byStation) body.appendChild(tableBox("By station", ["Station", "Sessions", "Died", "Armless", "Returned"],
			Object.keys(s.byStation).map((k) => [k, s.byStation[k].sessions, s.byStation[k].died, s.byStation[k].armless, s.byStation[k].returned])));
		if (Array.isArray(s.rescue)) body.appendChild(tableBox("Rescue success by rescuer (" + s.rescue.length + ")",
			["Persona", "Device", "RTT", "Own crew", "Rate"],
			s.rescue.map((r) => [r.persona, r.device, r.rttMs + "ms", r.own ? "yes" : "no", typeof r.rate === "number" ? (r.rate * 100).toFixed(1) + "%" : "?"])));
	}

	function tableBox(title, heads, rows) {
		const box = document.createElement("div");
		const h = document.createElement("h3");
		h.textContent = title;
		const table = document.createElement("table");
		const hr = table.insertRow();
		heads.forEach((t, k) => {
			const th = document.createElement("th");
			th.textContent = t;
			if (k > 0) th.className = "num";
			hr.appendChild(th);
		});
		for (const r of rows) {
			const tr = table.insertRow();
			r.forEach((v, k) => {
				const td = tr.insertCell();
				td.textContent = v === undefined ? "" : String(v);
				if (k > 0) td.className = "num";
			});
		}
		box.append(h, table);
		return box;
	}

	// ---------- wiring ----------

	$("pick").addEventListener("change", (e) => loadItem(Number(e.target.value)));
	$("play").addEventListener("click", togglePlay);
	$("scrub").addEventListener("input", (e) => {
		const tr = state.tr;
		if (tr) seek(tr.t0 + (Number(e.target.value) / 1000) * (tr.t1 - tr.t0));
	});
	$("trails").addEventListener("change", () => update());
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
			setTrace(trace, "[file] " + f.name);
		});
	});
	window.addEventListener("resize", renderMarks);
	document.addEventListener("keydown", (e) => {
		if (e.target && (e.target.tagName === "SELECT" || e.target.tagName === "INPUT") && e.target.type !== "range") return;
		const step = e.shiftKey ? 5 : 1;
		if (e.code === "Space") togglePlay();
		else if (e.code === "ArrowRight") seek(state.t + step);
		else if (e.code === "ArrowLeft") seek(state.t - step);
		else if (e.code === "Home" && state.tr) seek(state.tr.t0);
		else if (e.code === "End" && state.tr) seek(state.tr.t1);
		else return;
		e.preventDefault();
	});

	// The launcher's server shuts itself down when no open page has pinged it for a while.
	if (location.protocol.startsWith("http")) setInterval(() => fetch("/__ping", { cache: "no-store" }).catch(() => {}), 60000);

	const summaryLoaded = fetchJson("../summary.json").then(renderSummary, () => {
		$("summaryBody").textContent = "tools/limbsim/summary.json not found.";
		return null;
	});

	const ready = loadIndexes().then((items) => {
		if (!items.length) return draw();
		const want = params.get("trace");
		const at = want ? items.findIndex((x) => x.id === want || x.file === want) : -1;
		return loadItem(at >= 0 ? at : 0).then(() => {
			if (params.has("t")) seek(Number(params.get("t")) || 0);
		});
	});

	if (SELFTEST) ready.then(() => summaryLoaded).then(selfTest);
	else if (params.get("selftest") === "shot")
		// Posts the map as drawn for ?trace=&t= so a headless check can look at it.
		ready.then(() => fetch("/__report", { method: "POST", body: JSON.stringify({ png: canvas.toDataURL("image/png") }) }));
	else ready.then(() => requestAnimationFrame(tick));

	// ---------- self-test (?selftest=1, driven by check.py through headless Firefox) ----------

	const errors = [];
	window.addEventListener("error", (e) => errors.push("window error: " + e.message + " @" + (e.filename || "") + ":" + (e.lineno || "")));
	window.addEventListener("unhandledrejection", (e) => errors.push("unhandled rejection: " + (e.reason && e.reason.message || e.reason)));

	async function selfTest() {
		const report = { traces: [], errors, summary: !!$("summaryBody").querySelector("table") };
		for (let i = 0; i < state.items.length; i++) {
			const item = state.items[i];
			const r = { file: item.source.base + item.file, ok: false };
			try {
				const tr = await loadItem(i);
				if (!tr) throw new Error("did not load: " + $("problems").textContent);
				r.frames = tr.frames.length;
				r.events = tr.events.length;
				r.crew = tr.crewIds.length;
				// Scrub the whole run and every event, as a user would.
				for (let k = 0; k <= 40; k++) {
					state.t = tr.t0 + ((tr.t1 - tr.t0) * k) / 40;
					const snap = update();
					if (!snap || snap.players.length === 0) throw new Error("no players at step " + k);
				}
				for (const e of tr.events) seek(e.t);
				// Play from the start to the end in 0.1s steps at the chosen speed.
				state.t = tr.t0;
				state.playing = true;
				for (let k = 0; k < 10000 && state.playing; k++) step(0.1);
				if (state.playing || state.t !== tr.t1) throw new Error("playback did not reach the end");
				r.eventLines = $("events").children.length;
				if (r.eventLines !== tr.events.length) throw new Error("event list has " + r.eventLines + " of " + tr.events.length);
				r.ok = true;
			} catch (err) {
				r.error = String(err && err.stack || err);
			}
			report.traces.push(r);
		}
		// A malformed trace must be reported, not thrown.
		const bad = setTrace({ meta: {}, frames: [] }, "bad");
		report.rejectsBad = bad === null && $("problems").children.length > 0;
		document.title = "SELFTEST DONE";
		await fetch("/__report", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(report) }).catch(() => {});
	}
})();
