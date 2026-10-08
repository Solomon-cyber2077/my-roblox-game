--!strict
--[[
	The run's ticket book as data. Pure: RunDirector builds an entry when the ballot closes
	(Cruise), reveals it at Arrival if it was sealed, resolves it when the stop ends and appends it
	to run.log; UI/TicketBook and UI/RunCard read it back.

	  entry      the closed ballot + the leg's ticket -> a pending entry (a sealed ticket stays sealed)
	  reveal     the station behind a sealed ticket, once it is unsealed
	  resolve    a pending entry + how the stop ended + close calls + the stop's haul -> the logged entry
	  haul       run counters at the stop's start and end -> what this stop banked and lost
	  haulText   an entry -> "x12 COAL · 3 PARTS · 1 DOWN" under its stub ("" when nothing happened)
	  append     a log + an entry -> a new log in stop order (one entry per stop)
	  option     an entry -> the RouteOption a ticket stub prints
	  stamps     an entry -> its stamps (CLOSE CALL, GAMBLED with the outcome, UNANIMOUS)
	  totals     a log -> km, coal burned, stops, close calls, loot banked, downs
	  endStop    a log + run.nextStop -> the stop the run ended at
	  final      the run's outcome and the stop it ended at -> the card's last stamp
]]

local Shared = script.Parent.Parent
local MysteryConfig = require(Shared.Config.Mystery)
local Types = require(Shared.Types)
local Vote = require(script.Parent.Vote)

type Entry = Types.LogEntry

local RunLog = {}

export type Ballot = {
	stop: number,
	ticket: Types.RouteOption, -- the public option that won (a sealed stand-in for a mystery)
	name: string, -- the station's name (ignored while sealed)
	difficulty: number,
	coalBurned: number,
	votes: { [string]: number }?,
	optionCount: number,
	chosen: number,
}

export type Stamp = { kind: "CloseCall" | "Gambled" | "Unanimous", text: string }
export type Totals = {
	km: number,
	coal: number,
	stops: number,
	closeCalls: number,
	loot: number, -- coal, parts and relics banked
	downs: number,
}
export type Haul = Types.StopHaul

-- Unanimous: at least two ballots, every one of them for the winner.
function RunLog.unanimous(split: { number }, chosen: number): boolean
	local total = 0
	for _, n in split do
		total += n
	end
	return total >= 2 and split[chosen] == total
end

function RunLog.entry(ballot: Ballot): Entry
	local sealed = ballot.ticket.mystery == true
	local split = Vote.counts(ballot.votes or {}, ballot.optionCount)
	return {
		stop = ballot.stop,
		name = if sealed then MysteryConfig.Name else ballot.name,
		archetype = ballot.ticket.archetype,
		tier = if sealed then 0 else ballot.ticket.tier,
		difficulty = if sealed then 0 else ballot.difficulty,
		distanceKm = ballot.ticket.distanceKm,
		coalBurned = ballot.coalBurned,
		votes = split,
		chosen = ballot.chosen,
		unanimous = RunLog.unanimous(split, ballot.chosen),
		mystery = if sealed then true else nil,
		revealed = nil,
		closeCalls = nil,
		haul = nil,
		outcome = "Cleared",
	}
end

function RunLog.reveal(entry: Entry, archetype: string, name: string, tier: number, difficulty: number): Entry
	local out = table.clone(entry)
	out.archetype, out.name, out.tier, out.difficulty = archetype, name, tier, difficulty
	out.revealed = if entry.mystery then true else nil
	return out
end

function RunLog.resolve(entry: Entry, outcome: Types.StopOutcome, closeCalls: { string }?, haul: Haul?): Entry
	local out = table.clone(entry)
	out.outcome = outcome
	out.closeCalls = if closeCalls and #closeCalls > 0 then table.clone(closeCalls) else nil
	out.haul = if haul then table.clone(haul) else nil
	return out
end

-- The difference between two snapshots of the run's counters, never negative.
function RunLog.haul(before: Haul, now: Haul): Haul
	return {
		coal = math.max(now.coal - before.coal, 0),
		parts = math.max(now.parts - before.parts, 0),
		relics = math.max(now.relics - before.relics, 0),
		downs = math.max(now.downs - before.downs, 0),
	}
end

local function count(parts: { string }, n: number, word: string)
	if n > 0 then
		table.insert(parts, `{n} {word}{if n == 1 then "" else "S"}`)
	end
end

function RunLog.haulText(entry: Entry): string
	local h = entry.haul
	if h == nil then
		return ""
	end
	local parts: { string } = {}
	if h.coal > 0 then
		table.insert(parts, `x{h.coal} COAL`)
	end
	count(parts, h.parts, "PART")
	count(parts, h.relics, "RELIC")
	count(parts, h.downs, "DOWN")
	return table.concat(parts, " · ")
end

function RunLog.append(log: { Entry }?, entry: Entry): { Entry }
	local out: { Entry } = {}
	local list: { Entry } = log or {}
	for _, e in list do
		if e.stop ~= entry.stop then
			table.insert(out, e)
		end
	end
	table.insert(out, entry)
	table.sort(out, function(a, b)
		return a.stop < b.stop
	end)
	return out
end

function RunLog.option(entry: Entry): Types.RouteOption
	local sealed = entry.mystery == true and entry.revealed ~= true
	return {
		archetype = entry.archetype,
		tier = entry.tier,
		distanceKm = entry.distanceKm,
		hint = "",
		mystery = if sealed then true else nil,
	}
end

function RunLog.stamps(entry: Entry): { Stamp }
	local out: { Stamp } = {}
	if entry.closeCalls and #entry.closeCalls > 0 then
		table.insert(out, { kind = "CloseCall", text = "CLOSE CALL" })
	end
	if entry.mystery then
		local paid = entry.outcome == "Cleared" or entry.outcome == "Victory"
		table.insert(
			out,
			{ kind = "Gambled", text = if paid then "GAMBLED · PAID OFF" else "GAMBLED · LOST" }
		)
	end
	if entry.unanimous then
		table.insert(out, { kind = "Unanimous", text = "UNANIMOUS" })
	end
	return out
end

function RunLog.totals(log: { Entry }?): Totals
	local t: Totals = { km = 0, coal = 0, stops = 0, closeCalls = 0, loot = 0, downs = 0 }
	local list: { Entry } = log or {}
	for _, e in list do
		t.km += e.distanceKm
		t.coal += e.coalBurned
		t.stops += 1
		t.closeCalls += if e.closeCalls then #e.closeCalls else 0
		if e.haul then
			t.loot += e.haul.coal + e.haul.parts + e.haul.relics
			t.downs += e.haul.downs
		end
	end
	return t
end

-- The stop the run ended at: the last logged stop if the run ended there (a crew lost as the train
-- left), otherwise the next stop (lost on the line or at a stop not yet logged).
function RunLog.endStop(log: { Entry }?, nextStop: number?): number
	local list: { Entry } = log or {}
	local last = list[#list]
	if last and last.outcome ~= "Cleared" then
		return last.stop
	end
	return nextStop or 1
end

-- "TERMINUS", "DERAILED AT STOP 6", "LOST AT STOP 6". `stop` is where the run ended (run.nextStop).
function RunLog.final(outcome: Types.Outcome?, stop: number?): string
	if outcome == "Victory" then
		return "TERMINUS"
	end
	local verb = if outcome == "Derailed" then "DERAILED" else "LOST"
	return `{verb} AT STOP {stop or 1}`
end

return table.freeze(RunLog)
