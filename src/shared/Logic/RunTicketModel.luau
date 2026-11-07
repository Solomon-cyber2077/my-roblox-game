--!strict
--[[
	The end-of-run ticket's data: one hero line for how the run ended, this player's own cause
	(Logic/DeathCause), at most three supporting stats (stops reached, loot, the crew by their
	initials) and the stamp. UI/RunTicket draws any table of this shape, so the ticket book
	(brief F) can keep these and redraw old runs.
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local DeathCause = require(Shared.Logic.DeathCause)
local RunLog = require(Shared.Logic.RunLog)
local Rank = require(Shared.Logic.Rank)

export type CrewMark = { initials: string, name: string, lost: boolean }
export type Stat = { label: string, value: string }
export type Data = {
	serial: string,
	won: boolean,
	hero: string,
	causeTitle: string,
	causeLine: string,
	stats: { Stat }, -- never more than three; the crew's is the last and is drawn from `crew`
	crew: { CrewMark },
	stamp: string,
	nextLine: string?, -- what the player is working toward; old tickets have none
}

export type CrewEntry = { name: string?, status: string?, cause: string? }
export type Input = {
	outcome: string?,
	log: { any }?,
	nextStop: number?,
	xp: number?, -- lifetime XP, for the NEXT line
	stopCount: number?, -- run.stopCount: a Short Line's victory stamps SHORT LINE
	runId: string?,
	crew: { [string]: CrewEntry }?,
	cashedOut: { [string]: string }?, -- run.cashedOut: user id -> display name; no longer in `crew`
	me: string,
}

local RunTicketModel = {}

RunTicketModel.MaxStats = 3

local HERO: { [string]: string } = {
	Victory = "ALL STOPS MADE",
	Wiped = "THE CREW WAS LOST",
	Derailed = "THE TRAIN WAS LOST",
	CashedOut = "THE CREW CASHED OUT",
}

local MADE_IT = { title = "MADE IT", line = "You rode it to the last stop." }
local CASHED_OUT = {
	title = "CASHED OUT",
	line = `You walked away at stop {Tuning.Run.CashOutStop} with your pay and your life.`,
}

-- Up to two capital letters for a display name: "Tame Giant" and "TameGiant" are both TG.
function RunTicketModel.initials(name: string?): string
	local text = name or ""
	local words: { string } = {}
	for word in string.gmatch(text, "%w+") do
		table.insert(words, word)
	end
	if #words == 0 then
		return "?"
	end
	if #words >= 2 then
		return string.upper(string.sub(words[1], 1, 1) .. string.sub(words[2], 1, 1))
	end
	local word = words[1]
	local second = string.match(string.sub(word, 2), "%u") -- a capital inside: TameGiant
	return string.upper(string.sub(word, 1, 1) .. (second or string.sub(word, 2, 2)))
end

function RunTicketModel.build(input: Input): Data
	local outcome = input.outcome or "Wiped"
	local won = outcome == "Victory"
	local totals = RunLog.totals(input.log :: any)
	local crew: { [string]: CrewEntry } = table.clone(input.crew or {})
	local cashedOut: { [string]: string } = input.cashedOut or {}
	-- whoever cashed out left the crew list; they rode with this crew all the same
	for key, name in cashedOut do
		if crew[key] == nil then
			crew[key] = { name = name, status = "CashedOut" }
		end
	end

	-- your own line: how you went down, or that you made it
	local mine = crew[input.me]
	local words: { title: string, line: string }
	if cashedOut[input.me] then
		words = CASHED_OUT
	elseif won and not (mine and mine.status == "Eliminated") then
		words = MADE_IT
	elseif mine and mine.cause then
		-- how you went down; or Wrecked, still aboard when the train failed
		words = DeathCause.line(mine.cause)
	elseif outcome == "Derailed" then
		words = DeathCause.line("Wrecked")
	else
		words = DeathCause.line("Other")
	end

	local keys: { string } = {}
	for key in crew do
		table.insert(keys, key)
	end
	table.sort(keys)
	local marks: { CrewMark } = {}
	for _, key in keys do
		local entry = crew[key]
		table.insert(marks, {
			initials = RunTicketModel.initials(entry.name),
			name = entry.name or "",
			lost = entry.status == "Eliminated",
		})
	end
	local initials: { string } = {}
	for _, mark in marks do
		table.insert(initials, mark.initials)
	end

	return {
		serial = `No. {string.upper(string.sub(string.gsub(input.runId or "", "%W", ""), 1, 6))}`,
		won = won,
		hero = HERO[outcome] or HERO.Wiped,
		causeTitle = words.title,
		causeLine = words.line,
		stats = {
			{ label = "STOPS REACHED", value = tostring(totals.stops) },
			{ label = "LOOT", value = tostring(totals.loot) },
			{ label = "CREW", value = table.concat(initials, " · ") },
		},
		crew = marks,
		nextLine = if input.xp then RunTicketModel.nextLine(input.xp) else nil,
		stamp = RunLog.final(
			outcome :: any,
			RunLog.endStop(input.log :: any, input.nextStop),
			input.stopCount == Tuning.Run.Routes.Short
		),
	}
end

-- The ticket's NEXT line: the XP left to the next Crew Rank; nil at the top rank.
function RunTicketModel.nextLine(xp: number): string?
	local rank, into, span = Rank.progress(xp)
	if span == 0 then
		return nil
	end
	return `NEXT: CREW RANK {rank + 1} IN {span - into} XP`
end

return table.freeze(RunTicketModel)
