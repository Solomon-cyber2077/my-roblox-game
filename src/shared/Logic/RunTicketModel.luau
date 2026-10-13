--!strict
--[[
	The end-of-run ticket's data: one hero line for how the run ended, this player's own cause
	(Logic/DeathCause), at most three supporting stats (stops reached, loot, the crew by their
	initials) and the stamp. UI/RunTicket draws any table of this shape, so the ticket book
	(brief F) can keep these and redraw old runs.
]]

local Shared = script.Parent.Parent
local DeathCause = require(Shared.Logic.DeathCause)
local RunLog = require(Shared.Logic.RunLog)

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
}

export type CrewEntry = { name: string?, status: string?, cause: string? }
export type Input = {
	outcome: string?,
	log: { any }?,
	nextStop: number?,
	runId: string?,
	crew: { [string]: CrewEntry }?,
	me: string,
}

local RunTicketModel = {}

RunTicketModel.MaxStats = 3

local HERO: { [string]: string } = {
	Victory = "REACHED THE TERMINUS",
	Wiped = "THE CREW WAS LOST",
	Derailed = "THE TRAIN BROKE DOWN",
}

local MADE_IT = { title = "MADE IT", line = "You rode it to the end of the line." }

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
	local crew: { [string]: CrewEntry } = input.crew or {}

	-- your own line: how you went down, or that you made it
	local mine = crew[input.me]
	local words: { title: string, line: string }
	if won and not (mine and mine.status == "Eliminated") then
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
		stamp = RunLog.final(outcome :: any, RunLog.endStop(input.log :: any, input.nextStop)),
	}
end

return table.freeze(RunTicketModel)
