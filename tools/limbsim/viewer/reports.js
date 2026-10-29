// Reports tab: everything from summary.json (v3: features, feedback, byHour, byDevice, population) plus the people
// and bug reports found in the loaded traces. Plain DOM, no libraries. Every page carries the "simulated" banner.
(function () {
	"use strict";
	const C = window.LimbCore;
	const $ = (id) => document.getElementById(id);

	function el(tag, cls, text) {
		const e = document.createElement(tag);
		if (cls) e.className = cls;
		if (text !== undefined) e.textContent = text;
		return e;
	}

	function isNum(v) {
		return typeof v === "number" && isFinite(v);
	}

	// Rates (fractions that are not whole numbers) read as percentages; big counts get separators.
	function fmt(v, rate) {
		if (!isNum(v)) return v === undefined || v === null ? "–" : typeof v === "object" ? JSON.stringify(v) : String(v);
		if (rate || (v > 0 && v < 1)) return (v * 100).toFixed(v < 0.1 ? 1 : 0) + "%";
		return Number.isInteger(v) ? v.toLocaleString("en-GB") : v.toFixed(2);
	}

	function detailText(d) {
		if (d === undefined || d === null) return "";
		if (typeof d !== "object") return String(d);
		return Object.keys(d).map((k) => k + ": " + (typeof d[k] === "object" ? JSON.stringify(d[k]) : d[k])).join(" · ");
	}

	function verdictClass(v) {
		const s = String(v || "").toLowerCase();
		if (/hold|fail|broken|bad|fix|boring|too hard|unfair|cut/.test(s)) return "bad";
		if (/^(ok|good|fine|works|fair|pass|keep)|\b(ok|good|works|fair|pass)\b/.test(s) && !/but|hard|,/.test(s)) return "good";
		return "warn";
	}

	function heading(parent, text, sub) {
		parent.appendChild(el("h2", "rep-h", text));
		if (sub) parent.appendChild(el("p", "rep-sub", sub));
	}

	// ---------- sections ----------

	function features(parent, list) {
		heading(parent, "Feature report", "One card per feature the sim judged: its verdict, the evidence and the numbers.");
		const box = el("div", "cards");
		box.id = "repFeatures";
		for (const f of list) {
			const card = el("div", "fcard");
			card.appendChild(el("h4", "", f.name || "?"));
			card.appendChild(el("span", "stamp " + verdictClass(f.verdict), f.verdict || "no verdict"));
			const ul = el("ul");
			for (const ev of Array.isArray(f.evidence) ? f.evidence : []) ul.appendChild(el("li", "", typeof ev === "string" ? ev : detailText(ev)));
			if (ul.children.length) card.appendChild(ul);
			const nums = f.numbers && typeof f.numbers === "object" ? Object.keys(f.numbers) : [];
			if (nums.length) {
				const grid = el("div", "nums");
				for (const k of nums) grid.append(el("span", "", k), el("span", "", fmt(f.numbers[k])));
				card.appendChild(grid);
			}
			box.appendChild(card);
		}
		if (!list.length) box.appendChild(el("p", "muted", "No features in this summary."));
		parent.appendChild(box);
	}

	function ranked(parent, id, title, sub, obj, kind) {
		const wrap = el("div", "box");
		wrap.appendChild(el("h2", "rep-h", title));
		if (sub) wrap.appendChild(el("p", "rep-sub", sub));
		const rows = C.rank(obj);
		const box = el("div", "rank k-" + kind);
		box.id = id;
		const max = Math.max(1, ...rows.map((r) => r.count));
		rows.forEach((r, i) => {
			const row = el("div", "row");
			row.title = "Click for more examples";
			const bar = el("div", "bar");
			const fill = el("i");
			fill.style.width = (r.count / max) * 100 + "%";
			bar.appendChild(fill);
			row.append(el("span", "n", String(i + 1)), el("span", "", r.topic.replace(/_/g, " ")), bar, el("span", "c", fmt(r.count)));
			r.examples.forEach((ex, k) => row.appendChild(el("span", "ex" + (k ? " more" : ""), "“" + (typeof ex === "string" ? ex : detailText(ex)) + "”")));
			row.addEventListener("click", () => row.classList.toggle("open"));
			box.appendChild(row);
		});
		if (!rows.length) box.appendChild(el("p", "muted", "None reported."));
		wrap.appendChild(box);
		parent.appendChild(wrap);
	}

	function bugs(parent, summaryBugs, traceBugs, open) {
		heading(parent, "Bug reports", "A simulated player only reports a bug when the sim really detected one; the details are the sim's facts.");
		const grid = el("div", "cols2");
		const a = el("div", "box");
		a.appendChild(el("h3", "", "All sessions (summary.json)"));
		const t1 = el("table", "bugs");
		t1.id = "repBugs";
		const h1 = t1.insertRow();
		for (const h of ["Topic", "Count", "What they said / facts"]) h1.appendChild(el("th", h === "Count" ? "num" : "", h));
		for (const b of [...summaryBugs].sort((x, y) => (y.count || 0) - (x.count || 0))) {
			const r = t1.insertRow();
			r.insertCell().textContent = String(b.topic || "?").replace(/_/g, " ");
			const c = r.insertCell();
			c.className = "num";
			c.textContent = fmt(b.count !== undefined ? b.count : 1);
			const d = r.insertCell();
			if (b.text) d.appendChild(el("div", "", "“" + b.text + "”"));
			d.appendChild(el("div", "dl", detailText(b.example !== undefined ? b.example : b.detail)));
		}
		if (!summaryBugs.length) t1.insertRow().insertCell().textContent = "No bugs in this summary.";
		a.appendChild(t1);
		const b = el("div", "box");
		b.appendChild(el("h3", "", "In the loaded traces (" + traceBugs.length + ")"));
		const t2 = el("table", "bugs");
		t2.id = "repTraceBugs";
		const h2 = t2.insertRow();
		for (const h of ["Who / where", "What they said", "Detail", ""]) h2.appendChild(el("th", "", h));
		for (const x of traceBugs) {
			const r = t2.insertRow();
			r.insertCell().textContent = x.who + " · " + x.where;
			r.insertCell().textContent = "“" + x.text + "”";
			const d = r.insertCell();
			d.className = "dl";
			d.textContent = detailText(x.detail);
			const btn = el("button", "", "Watch");
			btn.title = "Open this moment in Replay";
			btn.addEventListener("click", () => open(x.key, x.t - 4));
			r.insertCell().appendChild(btn);
		}
		if (!traceBugs.length) t2.insertRow().insertCell().textContent = "No bug reports in the loaded traces.";
		b.appendChild(t2);
		grid.append(a, b);
		parent.appendChild(grid);
	}

	// One breakdown as a single-series bar chart (vertical for hours, horizontal otherwise), a metric picker and a table.
	function breakdownBox(title, id, obj, hours) {
		const box = el("div", "box");
		box.id = id;
		box.appendChild(el("h2", "rep-h", title));
		const bd = C.breakdown(obj);
		if (!bd.rows.length || !bd.cols.length) {
			box.appendChild(el("p", "muted", "Not in this summary."));
			return box;
		}
		const pick = el("select");
		for (const c of bd.cols) pick.appendChild(new Option(c.replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase(), c));
		const def = bd.cols.find((c) => /quit|complain|fun/i.test(c)) || bd.cols[0];
		pick.value = def;
		const line = el("div", "metric");
		line.append(document.createTextNode("Show"), pick);
		box.appendChild(line);
		const plot = el("div");
		box.appendChild(plot);
		hours = hours && bd.numeric; // day-part bands get ordered bars instead of a 24-hour chart
		const draw = () => {
			const c = pick.value;
			plot.textContent = "";
			const rows = hours ? Array.from({ length: 24 }, (_, h) => String(h)) : bd.rows;
			const vals = rows.map((r) => bd.get(r, c));
			const max = Math.max(1e-9, ...vals.filter(isNum));
			if (hours) {
				const chart = el("div", "chart");
				const xs = el("div", "chart-x");
				rows.forEach((r, k) => {
					const col = el("div", "col");
					const bar = el("i");
					bar.style.height = isNum(vals[k]) ? Math.max(1, (vals[k] / max) * 100) + "%" : "0";
					col.title = r.padStart(2, "0") + ":00 local · " + c + ": " + fmt(vals[k], bd.isRate[c]);
					col.appendChild(bar);
					chart.appendChild(col);
					xs.appendChild(el("span", "", k % 3 === 0 ? r : ""));
				});
				plot.append(chart, xs);
			} else {
				const list = el("div", "hbars");
				rows.forEach((r, k) => {
					const row = el("div", "row");
					const bar = el("div", "bar");
					const fill = el("i");
					fill.style.width = isNum(vals[k]) ? (vals[k] / max) * 100 + "%" : "0";
					bar.appendChild(fill);
					row.title = r + " · " + c + ": " + fmt(vals[k], bd.isRate[c]);
					row.append(el("span", "", r), bar, el("span", "v", fmt(vals[k], bd.isRate[c])));
					list.appendChild(row);
				});
				plot.appendChild(list);
			}
		};
		pick.addEventListener("change", draw);
		draw();
		const det = el("details", "tbl");
		det.appendChild(el("summary", "", "Table"));
		const t = el("table");
		const hr = t.insertRow();
		hr.appendChild(el("th", "", hours ? "Hour" : "Key"));
		for (const c of bd.cols) hr.appendChild(el("th", "num", c));
		for (const r of bd.rows) {
			const row = t.insertRow();
			row.insertCell().textContent = r;
			for (const c of bd.cols) {
				const td = row.insertCell();
				td.className = "num";
				td.textContent = fmt(bd.get(r, c), bd.isRate[c]);
			}
		}
		det.appendChild(t);
		box.appendChild(det);
		return box;
	}

	function distribution(title, obj) {
		const d = el("div", "box");
		d.appendChild(el("h4", "", title));
		if (isNum(obj)) {
			d.appendChild(el("div", "stat", fmt(obj)));
			return d;
		}
		if (Array.isArray(obj)) {
			d.appendChild(el("div", "", obj.map((x) => (typeof x === "object" ? detailText(x) : String(x))).join(", ")));
			return d;
		}
		const keys = Object.keys(obj || {}).filter((k) => isNum(obj[k]));
		const total = keys.reduce((s, k) => s + obj[k], 0) || 1;
		const max = Math.max(1e-9, ...keys.map((k) => obj[k]));
		const list = el("div", "hbars");
		for (const k of keys) {
			const row = el("div", "row");
			const bar = el("div", "bar");
			const fill = el("i");
			fill.style.width = (obj[k] / max) * 100 + "%";
			bar.appendChild(fill);
			row.title = k + ": " + obj[k] + " (" + ((obj[k] / total) * 100).toFixed(0) + "%)";
			row.append(el("span", "", k), bar, el("span", "v", fmt(obj[k])));
			list.appendChild(row);
		}
		if (!keys.length) list.appendChild(el("div", "muted", detailText(obj)));
		d.appendChild(list);
		return d;
	}

	function countBy(list, f) {
		const out = {};
		for (const x of list) {
			const k = f(x);
			if (k === undefined || k === null || k === "") continue;
			out[k] = (out[k] || 0) + 1;
		}
		return out;
	}

	function population(parent, pop, traces, open) {
		heading(parent, "Population explorer", "Who these simulated people are: the whole population from summary.json, then everyone in the loaded traces.");
		const root = el("div");
		root.id = "repPopulation";
		const dists = el("div", "dists");
		for (const k of Object.keys(pop || {})) dists.appendChild(distribution(k, pop[k]));
		const people = C.people(traces);
		const withProfile = people.filter((p) => p.profile);
		if (withProfile.length) {
			const ages = countBy(withProfile, (p) => (isNum(p.age) ? (p.age < 13 ? "under 13" : p.age < 16 ? "13-15" : p.age < 19 ? "16-18" : "19+") : null));
			dists.appendChild(distribution("age (loaded traces)", ages));
			const hrs = countBy(withProfile, (p) => (isNum(p.localHour) ? String(Math.floor(p.localHour)).padStart(2, "0") + ":00" : null));
			const sorted = {};
			for (const k of Object.keys(hrs).sort()) sorted[k] = hrs[k];
			dists.appendChild(distribution("local hour (loaded traces)", sorted));
		}
		if (!dists.children.length) dists.appendChild(el("p", "muted", "No population in this summary."));
		root.appendChild(dists);

		const box = el("div", "box");
		box.style.marginTop = "12px";
		box.appendChild(el("h3", "", "People in the loaded traces (" + people.length + " in " + traces.length + " sessions)"));
		if (people.length && !withProfile.length)
			box.appendChild(el("p", "muted", "These traces have no profiles yet (format v2); names and devices only."));
		const filters = el("div", "filters");
		const sel = (label, key) => {
			const s = el("select");
			s.appendChild(new Option("all " + label, ""));
			for (const v of [...new Set(people.map((p) => p[key]).filter((v) => v !== ""))].sort()) s.appendChild(new Option(v, v));
			s.dataset.key = key;
			filters.appendChild(s);
			return s;
		};
		const fs = [sel("platforms", "platform"), sel("devices", "device"), sel("connections", "connection"), sel("motives", "motive")];
		const quit = el("select");
		for (const [v, t] of [["", "quit or stayed"], ["1", "quit"], ["0", "stayed"]]) quit.appendChild(new Option(t, v));
		const search = el("input");
		search.type = "search";
		search.placeholder = "name or region";
		filters.append(quit, search);
		box.appendChild(filters);
		const scroller = el("div", "people");
		const table = el("table");
		scroller.appendChild(table);
		box.appendChild(scroller);
		const cols = [
			["Name", "name"], ["Age", "age", 1], ["Platform", "platform"], ["Device", "device"], ["Conn.", "connection"], ["Region", "region"],
			["RTT", "rttMs", 1], ["Local time", "localHour", 1], ["Session", "sessionMinutes", 1], ["Runs", "runsBefore", 1], ["Motive", "motive"],
			["Traits", null], ["Lines", "lines", 1], ["Complaints", "complaints", 1], ["Quit", "quit"],
		];
		let sortKey = "name", sortDir = 1;
		const draw = () => {
			const q = search.value.trim().toLowerCase();
			const rows = people.filter((p) => fs.every((s) => !s.value || String(p[s.dataset.key]) === s.value) &&
				(!quit.value || p.quit === (quit.value === "1")) &&
				(!q || (p.name + " " + p.region).toLowerCase().includes(q)));
			rows.sort((a, b) => {
				const x = a[sortKey], y = b[sortKey];
				return (x === y ? 0 : x === undefined ? 1 : y === undefined ? -1 : x < y ? -1 : 1) * sortDir;
			});
			table.textContent = "";
			const hr = table.insertRow();
			for (const [t, k, n] of cols) {
				const th = el("th", n ? "num" : "", t + (k === sortKey ? (sortDir > 0 ? " ▲" : " ▼") : ""));
				if (k) th.addEventListener("click", () => {
					sortDir = sortKey === k ? -sortDir : 1;
					sortKey = k;
					draw();
				});
				hr.appendChild(th);
			}
			for (const p of rows) {
				const r = table.insertRow();
				r.className = "p";
				r.title = "Open " + (p.title || p.trace) + " in Replay";
				r.addEventListener("click", () => open(p.key, null));
				for (const [, k, n] of cols) {
					const td = r.insertCell();
					if (n) td.className = "num";
					if (k === null) {
						const tr = el("span", "traits");
						const names = Object.keys(p.traits);
						for (const name of names) {
							const v = p.traits[name];
							const bar = el("i");
							bar.style.height = Math.round(3 + 11 * (isNum(v) ? v : 0)) + "px";
							bar.title = name + " " + fmt(v, true);
							tr.appendChild(bar);
						}
						td.title = names.map((n2) => n2 + " " + fmt(p.traits[n2], true)).join(", ");
						td.appendChild(tr);
					} else if (k === "localHour") td.textContent = p.local;
					else if (k === "rttMs") td.textContent = isNum(p.rttMs) ? p.rttMs + "ms" : "";
					else if (k === "sessionMinutes") td.textContent = isNum(p.sessionMinutes) ? p.sessionMinutes + " min" : "";
					else if (k === "quit") td.textContent = p.quit ? "quit" : "";
					else td.textContent = p[k] === undefined ? "" : String(p[k]);
				}
			}
			table.dataset.rows = String(rows.length);
		};
		for (const s of [...fs, quit]) s.addEventListener("change", draw);
		search.addEventListener("input", draw);
		draw();
		root.appendChild(box);
		parent.appendChild(root);
	}

	// The v2 parts: totals, by station, rescue rate by rescuer.
	function totals(s) {
		const body = $("summaryBody");
		body.textContent = "";
		body.classList.remove("muted");
		if (s.totals) {
			const box = el("div");
			box.appendChild(el("h3", "", "Totals over " + (s.sessions !== undefined ? s.sessions : "?") + " sessions"));
			const grid = el("div", "tot");
			for (const k of Object.keys(s.totals)) grid.append(el("span", "", k), el("span", "", fmt(s.totals[k])));
			box.appendChild(grid);
			body.appendChild(box);
		}
		if (s.byStation) {
			// Whatever numbers each station carries (v2: sessions/died/armless/returned; v3 adds more).
			const bd = C.breakdown(s.byStation);
			body.appendChild(tableBox("By station", ["Station", ...bd.cols], bd.rows.map((r) => [r, ...bd.cols.map((c) => fmt(bd.get(r, c), bd.isRate[c]))])));
		}
		if (Array.isArray(s.rescue)) body.appendChild(tableBox("Rescue success by rescuer (" + s.rescue.length + ")",
			["Persona", "Device", "RTT", "Own crew", "Rate"],
			s.rescue.map((r) => [r.persona, r.device, r.rttMs + "ms", r.own ? "yes" : "no", isNum(r.rate) ? (r.rate * 100).toFixed(1) + "%" : "?"])));
		if (!body.children.length) body.textContent = "No totals in this summary.";
	}

	function tableBox(title, heads, rows) {
		const box = el("div");
		box.appendChild(el("h3", "", title));
		const table = el("table");
		const hr = table.insertRow();
		heads.forEach((t, k) => hr.appendChild(el("th", k > 0 ? "num" : "", t)));
		for (const r of rows) {
			const tr = table.insertRow();
			r.forEach((v, k) => {
				const td = tr.insertCell();
				td.textContent = v === undefined ? "" : String(v);
				if (k > 0) td.className = "num";
			});
		}
		box.appendChild(table);
		return box;
	}

	function isV3(s) {
		return !!(s && (s.feedback || s.features || s.byHour || s.byDevice || s.population));
	}

	// opts: { summary, label, sample, traces: [{ key, id, title, meta, events }], open(key, t), preview() }
	function render(opts) {
		const s = opts.summary || {};
		const banner = document.querySelector("#reports .sim-banner");
		banner.classList.toggle("sample", !!opts.sample);
		$("repSource").textContent = opts.sample
			? "SHOWING THE HAND-MADE SAMPLE SUMMARY: invented numbers that only exercise this page."
			: opts.label || "";
		const notice = $("repNotice");
		notice.textContent = "";
		if (!isV3(s) && !opts.sample) {
			notice.appendChild(el("div", "", "summary.json is still format v2 (from before the HP's job A), so the feature report, " +
				"complaints, bugs, hour/device breakdowns and population summary are not in it yet. The people and bug reports " +
				"from the loaded traces still show below."));
			if (opts.preview) {
				const b = el("button", "", "Preview this page with the hand-made sample");
				b.addEventListener("click", opts.preview);
				notice.appendChild(b);
			}
		}
		const body = $("repBody");
		body.textContent = "";
		const fb = s.feedback || {};
		if (isV3(s)) features(body, Array.isArray(s.features) ? s.features : []);
		if (isV3(s)) {
			const two = el("div", "cols2");
			ranked(two, "repComplaints", "Complaints", "Topics ranked by how often simulated players raised them. Click a topic for more lines.", fb.complaints, "complaint");
			ranked(two, "repPraise", "Praise", "What they liked.", fb.praise, "praise");
			body.appendChild(two);
		}
		const traceBugs = [];
		for (const t of opts.traces) {
			const crew = {};
			for (const c of t.meta.crew || []) crew[String(c.id)] = c.name;
			const stops = (t.meta.stops || []).slice().sort((a, b) => a.startT - b.startT);
			for (const e of t.events || []) {
				if (e.type !== "say" || e.kind !== "bug") continue;
				let where = t.meta.station || "";
				for (const st of stops) if (st.startT <= e.t) where = "stop " + st.n + " " + (st.station || "");
				traceBugs.push({ key: t.key, t: e.t, who: crew[String(e.who)] || "#" + e.who, where: where + " · " + (t.title || t.id), text: e.text, detail: e.detail });
			}
		}
		bugs(body, Array.isArray(fb.bugs) ? fb.bugs : [], traceBugs, opts.open);
		if (isV3(s)) {
			const two = el("div", "cols2");
			two.appendChild(breakdownBox("By hour of day (player's local time)", "repHour", s.byHour, true));
			two.appendChild(breakdownBox("By device", "repDevice", s.byDevice, false));
			if (s.byConnection) two.appendChild(breakdownBox("By connection", "repConnection", s.byConnection, false));
			body.appendChild(two);
		}
		population(body, s.population, opts.traces, opts.open);
		totals(s);
	}

	window.LimbReports = { render, isV3, fmt, verdictClass };
})();
