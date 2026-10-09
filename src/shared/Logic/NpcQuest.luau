--!strict
--[[
	Crew errands within one run. Pure: NpcService holds the state and calls these.

	Co-op model (approved): each player's story is saved separately, but a run carries
	one errand per NPC, the one at the crew's lowest saved stage. The errand is shared:
	anyone can pick up or deliver its item, and finishing it credits everyone still in
	the run (the left-behind rule decides who that is). Players at the errand's stage
	advance their story; players already past it (or joiners behind it) "lend a hand"
	for a little Brass and keep their own stage.

	Errand status: Offered (nobody has talked to the NPC yet) -> Active -> Done,
	or Failed when the run ends first. A failed errand stays at the same stage.
]]

local Npcs = require(script.Parent.Parent.Config.Npcs)
local Quests = require(script.Parent.Parent.Config.NpcQuests)

export type Status = "Offered" | "Active" | "Done" | "Failed"

export type RunQuest = {
	npc: string,
	quest: string,
	stage: number,
	status: Status,
	found: boolean, -- Find: someone in the crew is carrying the item
}

export type Credit = { advance: boolean, brass: number }

local NpcQuest = {}

function NpcQuest.questAt(npcId: string, stage: number): Quests.QuestDef?
	local def = Npcs.List[npcId]
	local id = def and def.chain[stage]
	return if id then Quests[id] else nil
end

function NpcQuest.chainLength(npcId: string): number
	local def = Npcs.List[npcId]
	return if def then #def.chain else 0
end

-- The stage the run's errand comes from: the lowest stage among the crew whose chain is not
-- finished. nil when every crew member has finished this NPC's chain (or there is no crew).
function NpcQuest.runStage(stages: { number }, chainLength: number): number?
	local lowest: number? = nil
	for _, stage in stages do
		if stage <= chainLength and (lowest == nil or stage < lowest) then
			lowest = stage
		end
	end
	return lowest
end

function NpcQuest.start(npcId: string, stages: { number }): RunQuest?
	local def = Npcs.List[npcId]
	if def == nil or not def.enabled then
		return nil
	end
	local stage = NpcQuest.runStage(stages, #def.chain)
	local quest = if stage then NpcQuest.questAt(npcId, stage) else nil
	if stage == nil or quest == nil then
		return nil
	end
	return { npc = npcId, quest = quest.id, stage = stage, status = "Offered", found = false }
end

-- Talking to the NPC while the errand is on offer takes it on.
function NpcQuest.accept(rq: RunQuest): RunQuest
	if rq.status == "Offered" then
		rq.status = "Active"
	end
	return rq
end

function NpcQuest.complete(rq: RunQuest): RunQuest
	if rq.status == "Active" or rq.status == "Offered" then
		rq.status = "Done"
	end
	return rq
end

-- The run is over: an errand that is not done has failed.
function NpcQuest.finish(rq: RunQuest): RunQuest
	if rq.status ~= "Done" then
		rq.status = "Failed"
	end
	return rq
end

-- Whether the errand's item should be hidden at this docked stop.
function NpcQuest.shouldSpawn(rq: RunQuest, stop: number): boolean
	local quest = Quests[rq.quest]
	if quest.kind ~= "Find" or rq.status ~= "Active" or rq.found then
		return false
	end
	local stops = quest.stops :: { number }
	return stop >= stops[1] and stop <= stops[2]
end

-- Whether talking to the NPC while holding the item hands it over.
function NpcQuest.canDeliver(rq: RunQuest, carrying: boolean): boolean
	return Quests[rq.quest].kind == "Find" and rq.status == "Active" and carrying
end

function NpcQuest.completesAtTerminus(rq: RunQuest): boolean
	return Quests[rq.quest].kind == "Survive" and rq.status ~= "Done" and rq.status ~= "Failed"
end

-- What finishing the errand gives one crew member, by their own saved stage.
function NpcQuest.credit(rq: RunQuest, playerStage: number, helperBrass: number): Credit
	local quest = Quests[rq.quest]
	if playerStage == rq.stage then
		return { advance = true, brass = quest.brass }
	end
	return { advance = false, brass = helperBrass }
end

-- The tracker's line for this errand.
function NpcQuest.trackerText(rq: RunQuest): string
	local quest = Quests[rq.quest]
	local name = Npcs.List[rq.npc].name
	if rq.status == "Offered" then
		return `Talk to {name}.`
	elseif rq.status == "Done" then
		return "Done. Paid at the end of the line."
	elseif rq.status == "Failed" then
		return "Ran out of line."
	elseif rq.found and quest.carried then
		return quest.carried
	end
	return quest.brief
end

return NpcQuest
