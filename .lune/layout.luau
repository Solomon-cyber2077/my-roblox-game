--[[
	Exact touch layout check (lib/TouchLayout): for each phone and tablet, where every touch control lands,
	its size in millimetres, overlaps and gaps between targets, and where the hunted cue's eyes land.
	Fails (exit 1) on a tap target under the thumb minimum or an overlap, so it can gate a build.

	Run with:  lune run layout                  (all devices, Roblox's default control branch)
	           lune run layout --abilities=1    (Roblox's ability-controls branch, flag-gated in the client)
	           lune run layout --out=playtest/layout.md
	           lune run layout --dump=iPhoneSE.json   (compare with a Studio dump: tools/studio/layout-dump.luau)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local L = require("./lib/TouchLayout")
local Loader = require("./lib/Loader")
-- the game's own placement rule (UI/TouchButtons, UI/ActionButton and UI/CashOut call it too)
local TouchCluster = Loader.requireNode(Loader.roots.Shared.Logic.TouchCluster)

local args: { [string]: string } = {}
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-([%w_]+)=(.*)$")
	if key then
		args[key] = value
	end
end
local abilities = args.abilities == "1"
local dump = if args.dump then serde.decode("json", fs.readFile(args.dump)) else nil
local dumpDevice = if args.dump then string.match(args.dump, "([%w]+)%.json$") else nil
local out = args.out

-- Our other controls, as the code places them (keep in step with the files named).
local CARD = { pos = { 0.5, 0, 1, -170 }, size = { 470, 190 }, anchor = { 0.5, 1 } } -- UI/CashOut, desktop
local COMPACT_CARD = { maxWidth = 400, height = 120, pad = 10, margin = 8 } -- UI/CashOut COMPACT, screen units
local SLATE = { pos = { 0.5, 0, 0, 8 }, size = { 280, 36 }, anchor = { 0.5, 0 } } -- UI/Overlay
-- UI/RouteVote: the row of tickets, folded (UI/Ticket H 214 + a stamp row of 25 + jitter 4) and with one unfolded (+34)
local BALLOT = { pos = { 0.5, 0, 0, 10 }, size = { 720, 243 }, anchor = { 0.5, 0 } }
local BALLOT_OPEN = { pos = { 0.5, 0, 0, 10 }, size = { 720, 277 }, anchor = { 0.5, 0 } }
local TICKET = { w = 224, h = 214 } -- UI/Ticket, whole face tappable on touch screens
local CUE_INSET = 0.06 -- Tuning.HuntedCue.Inset
local CUE_SCREEN_UNITS = true -- UI/HuntedCue converts the camera's viewport point into the gui's canvas

local lines: { string } = {}
local failures = 0
local function say(s: string)
	table.insert(lines, s)
end

local function mm(d, units: number): number
	return units * d.mm
end

say("# Touch layout check")
say("")
say(`Roblox control branch: {if abilities then "ability controls (flag on)" else "default (flag off)"}.`)
say(
	`Thumb minimum {L.MinTapMm} mm; spacing minimum {L.MinGapUnits} units (8 dp). Top bar inset {L.TopBar} (assumed).`
)
say("")

for _, d in L.Devices do
	local s, compact = L.uiScale(d)
	local jump = L.jump(d, abilities)
	local cluster = TouchCluster.place(jump)
	local run, look, ping, action = cluster.run, cluster.look, cluster.ping, cluster.action
	local area = L.guiArea(d)
	local card, cardButtons
	if compact then
		local C = COMPACT_CARD
		local left = area.x + C.margin
		local w = math.min(C.maxWidth, action.x - C.margin * 1.5 - left)
		local top = area.y + area.h - C.margin - C.height
		card = { x = left, y = top, w = w, h = C.height }
		local bw = (w - 3 * C.pad) / 2
		local by = top + C.height - TouchCluster.Size - 12
		cardButtons = {
			{ "CASH OUT", { x = left + C.pad, y = by, w = bw, h = TouchCluster.Size } },
			{ "RIDE ON", { x = left + 2 * C.pad + bw, y = by, w = bw, h = TouchCluster.Size } },
		}
	else
		card = L.place(d, CARD.pos, CARD.size, CARD.anchor)
		-- UI/CashOut on a touch screen: slides left to clear the touch buttons by a gap
		local maxRight = action.x - TouchCluster.Gap
		if card.x + card.w > maxRight then
			card.x = maxRight - card.w
		end
		local k = s -- the desktop card's 150 x 44 buttons under our UIScale
		cardButtons = {
			{
				"CASH OUT",
				{ x = card.x + card.w - 332 * k, y = card.y + card.h - 70 * k, w = 150 * k, h = 56 * k },
			},
			{
				"RIDE ON",
				{ x = card.x + card.w - 168 * k, y = card.y + card.h - 70 * k, w = 150 * k, h = 56 * k },
			},
		}
	end
	local ballot = L.place(d, BALLOT.pos, BALLOT.size, BALLOT.anchor)
	local ballotOpen = L.place(d, BALLOT_OPEN.pos, BALLOT_OPEN.size, BALLOT_OPEN.anchor)
	local slate = L.place(d, SLATE.pos, SLATE.size, SLATE.anchor)
	local stick = L.thumbstickZone(d)

	say(`## {d.label}`)
	say("")
	say(
		string.format(
			"%d x %d units, %.3f mm a unit%s. Our UI scale %.2f%s.",
			d.w,
			d.h,
			d.mm,
			if d.android then " (Android dp: assumed density)" else "",
			s,
			if compact then ", Compact layout" else ""
		)
	)
	say("")
	say("| Target | x | y | w x h units | size mm | ok |")
	say("| --- | ---: | ---: | ---: | ---: | --- |")
	local targets = {
		{ "Jump (Roblox)", jump },
		{ "RUN", run },
		{ "LOOK", look },
		{ "PING", ping },
		{ "Action button", action },
	}
	for _, t in targets do
		local r = t[2]
		local small = math.min(mm(d, r.w), mm(d, r.h))
		local ok = small >= L.MinTapMm - 0.05
		if not ok then
			failures += 1
		end
		say(
			string.format(
				"| %s | %.0f | %.0f | %.0f x %.0f | %.1f x %.1f | %s |",
				t[1],
				r.x,
				r.y,
				r.w,
				r.h,
				mm(d, r.w),
				mm(d, r.h),
				if ok then "yes" else "**too small**"
			)
		)
	end
	-- pairwise: overlaps and spacing between the targets that share the screen
	local notes: { string } = {}
	for i = 1, #targets do
		for j = i + 1, #targets do
			local a, b = targets[i], targets[j]
			if L.overlap(a[2], b[2]) then
				failures += 1
				table.insert(notes, `**{a[1]} overlaps {b[1]}**`)
			else
				local g = L.gap(a[2], b[2])
				if g < L.MinGapUnits then
					failures += 1
					table.insert(notes, string.format("**%s and %s only %.0f units apart**", a[1], b[1], g))
				end
			end
		end
	end
	for _, t in targets do
		if L.overlap(t[2], stick) then
			table.insert(notes, `{t[1]} reaches into the thumbstick zone`)
		end
		local r = t[2]
		if r.x < 0 or r.y < 0 or r.x + r.w > d.w or r.y + r.h > d.h then
			failures += 1
			table.insert(notes, `**{t[1]} is partly off screen**`)
		end
	end
	-- the cash-out card and its buttons, shown with the route ballot during the stop-five junction
	for _, t in targets do
		if L.overlap(card, t[2]) then
			failures += 1
			table.insert(notes, `**cash-out card covers {t[1]} during the junction**`)
		end
	end
	if L.overlap(card, ballot) then
		failures += 1
		table.insert(notes, "**cash-out card overlaps the route ballot**")
	elseif L.overlap(card, ballotOpen) then
		table.insert(
			notes,
			"an unfolded ballot ticket reaches the cash-out card's top edge (folded is clear)"
		)
	end
	for _, t in targets do
		if L.overlap(ballot, t[2]) then
			table.insert(notes, `{t[1]} sits over the route ballot (touch buttons draw on top)`)
		end
	end
	local face = math.min(mm(d, TICKET.w * s), mm(d, TICKET.h * s))
	if face < L.MinTapMm then
		failures += 1
		table.insert(notes, string.format("**ballot ticket face only %.1f mm**", face))
	end
	for _, b in cardButtons do
		local r = b[2]
		local small = math.min(mm(d, r.w), mm(d, r.h))
		if small < L.MinTapMm - 0.05 then
			failures += 1
			table.insert(notes, string.format("**card button %s only %.1f mm**", b[1], small))
		end
	end
	if card.y < slate.y + slate.h then
		table.insert(notes, "cash-out card reaches the departure slate")
	end
	-- the hunted cue: a Hollow straight to the right should glint at the right edge, inset 6%
	local wantX = d.w * (1 - CUE_INSET)
	local gotX
	if CUE_SCREEN_UNITS then
		gotX = wantX
	else
		gotX = L.guiArea(d).x + s * wantX -- fromOffset(x) in the gui canvas, scaled by the UIScale
	end
	if math.abs(gotX - wantX) > 4 then
		failures += 1
		table.insert(notes, string.format("**hunted cue lands at x %.0f instead of %.0f**", gotX, wantX))
	end
	-- a Studio dump for this device: the live rectangles against the prediction
	if dump and dumpDevice == d.id then
		say("")
		say(
			string.format(
				"Studio dump: viewport %d x %d (predicted %d x %d), top inset %d (assumed %d), UI scale %s (predicted %.2f).",
				dump.viewport[1],
				dump.viewport[2],
				d.w,
				d.h,
				dump.inset[2],
				L.TopBar,
				tostring(dump.uiScale),
				s
			)
		)
		local predicted = { jump = jump, run = run, look = look, ping = ping, action = action }
		for _, key in { "jump", "run", "look", "ping", "action" } do
			local live = dump[key]
			local p = predicted[key]
			if live then
				-- AbsolutePosition space starts below the top inset
				local dx = live[1] + dump.inset[1] - p.x
				local dy = live[2] + dump.inset[2] - p.y
				local off =
					math.max(math.abs(dx), math.abs(dy), math.abs(live[3] - p.w), math.abs(live[4] - p.h))
				if off > 2 then
					failures += 1
				end
				table.insert(
					notes,
					string.format(
						"%s%s: live %d,%d %dx%d vs predicted %.0f,%.0f %.0fx%.0f%s",
						if off > 2 then "**" else "",
						key,
						live[1] + dump.inset[1],
						live[2] + dump.inset[2],
						live[3],
						live[4],
						p.x,
						p.y,
						p.w,
						p.h,
						if off > 2 then " (differs)**" else ""
					)
				)
			else
				table.insert(notes, `{key}: not in the dump`)
			end
		end
	end
	if #notes == 0 then
		say("")
		say("No overlaps, spacing fine, cue on target.")
	else
		say("")
		for _, n in notes do
			say(`- {n}`)
		end
	end
	say("")
end

say(if failures == 0 then "**All targets pass.**" else `**{failures} problem(s).**`)
local text = table.concat(lines, "\n") .. "\n"
print(text)
if out then
	local dir = string.match(out, "^(.*)[/\\]")
	if dir and not fs.isDir(dir) then
		fs.writeDir(dir)
	end
	fs.writeFile(out, text)
end
process.exit(if failures == 0 then 0 else 1)
