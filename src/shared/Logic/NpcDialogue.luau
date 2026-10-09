--!strict
--[[
	Picks what an NPC says when a player talks to them. Pure: the lines are data
	(Config/NpcDialogue), the situation is a Context built by NpcService.

	Topics are tried in PRIORITY order. Errand and run-state topics are said at most once
	per run to each player (ctx.heardThisRun), so they never drown the rest out; the
	Greeting is said once ever; the ambient topics (StopHint, Lore, SmallTalk) repeat,
	unheard lines first, then in turn.
]]

local Npcs = require(script.Parent.Parent.Config.Npcs)

export type Context = {
	inRun: boolean,
	travelling: boolean, -- Junction or Cruise: between stops
	status: string?, -- the run errand's status for this NPC
	quest: string?, -- the run errand's quest id
	stage: number, -- the player's saved stage for this NPC
	failed: boolean, -- the player's last errand with this NPC failed
	flags: { [string]: boolean }, -- Danger, LowSupplies, CrewDown, CloseCall, NearTerminus
	choices: { [string]: string },
	seen: { [string]: boolean }, -- every line this player has heard
	heardThisRun: { [string]: boolean },
	talks: number, -- how many times this player has talked to the NPC (rotates repeats)
}

local NpcDialogue = {}

NpcDialogue.PRIORITY = table.freeze({
	"QuestDone",
	"QuestFailed",
	"QuestOffer",
	"CrewDown",
	"CloseCall",
	"Danger",
	"LowSupplies",
	"NearTerminus",
	"Greeting",
	"QuestActive",
	"StopHint",
	"Lore",
	"SmallTalk",
	"Recall",
})

-- Topics said at most once per run to a player.
local ONCE_PER_RUN = table.freeze({
	QuestDone = true,
	QuestFailed = true,
	QuestOffer = true,
	CrewDown = true,
	CloseCall = true,
	Danger = true,
	LowSupplies = true,
	NearTerminus = true,
	QuestActive = true,
})

-- Run-state reactions, each gated by the context flag of the same name.
local FLAG_TOPICS = table.freeze({
	CrewDown = true,
	CloseCall = true,
	Danger = true,
	LowSupplies = true,
	NearTerminus = true,
})

local function matches(line: Npcs.Line, ctx: Context): boolean
	local topic = line.topic
	if ONCE_PER_RUN[topic] and ctx.heardThisRun[line.id] then
		return false
	end
	if topic == "Greeting" and ctx.seen[line.id] then
		return false
	end
	if FLAG_TOPICS[topic] and not ctx.flags[topic] then
		return false
	end
	if (topic == "StopHint" and not ctx.travelling) or (topic == "QuestActive" and not ctx.inRun) then
		return false
	end
	local when = line.when
	if when == nil then
		return true
	end
	if when.status ~= nil and when.status ~= ctx.status then
		return false
	end
	if when.quest ~= nil and when.quest ~= ctx.quest then
		return false
	end
	if when.stage ~= nil and when.stage ~= ctx.stage then
		return false
	end
	if when.stageMin ~= nil and ctx.stage < when.stageMin then
		return false
	end
	if when.stageMax ~= nil and ctx.stage > when.stageMax then
		return false
	end
	if when.seen ~= nil and not ctx.seen[when.seen] then
		return false
	end
	if when.failed ~= nil and when.failed ~= ctx.failed then
		return false
	end
	if when.choice ~= nil and ctx.choices[when.choice[1]] ~= when.choice[2] then
		return false
	end
	return true
end

-- The line to say, or nil when nothing fits.
function NpcDialogue.pick(lines: { Npcs.Line }, ctx: Context): Npcs.Line?
	for _, topic in NpcDialogue.PRIORITY do
		local candidates: { Npcs.Line } = {}
		for _, line in lines do
			if line.topic == topic and matches(line, ctx) then
				table.insert(candidates, line)
			end
		end
		if #candidates > 0 then
			for _, line in candidates do
				if not ctx.seen[line.id] then
					return line
				end
			end
			return candidates[ctx.talks % #candidates + 1]
		end
	end
	return nil
end

-- Every topic a resident's lines should cover (the dialogue spec checks each NPC against it).
NpcDialogue.REQUIRED_TOPICS = table.freeze({
	"Greeting",
	"SmallTalk",
	"Lore",
	"StopHint",
	"Danger",
	"QuestOffer",
	"QuestActive",
	"QuestDone",
	"QuestFailed",
	"LowSupplies",
	"CrewDown",
	"CloseCall",
	"NearTerminus",
})

return NpcDialogue
