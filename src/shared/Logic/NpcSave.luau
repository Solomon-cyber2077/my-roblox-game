--!strict
--[[
	The NPC part of a saved profile: profile.npcs[npcId] for every enabled resident.

	  stage    index of the next quest in the NPC's chain (#chain + 1: chain finished)
	  done     quest ids completed
	  choices  story choices, key -> option id (personal; never shared with the crew)
	  seen     line ids this player has heard
	  failed   the quest that ran out on the player last run; the NPC remarks on it once

	Profile schema history (DataService.SCHEMA_VERSION):
	  1  no npcs
	  2  npcs added; migrate() fills it

	migrate() runs on every load. It repairs what it recognises and never deletes a key it
	does not know, so a save written by a newer build, or for an NPC switched off again,
	survives a round trip. Pure: no engine globals.
]]

local Npcs = require(script.Parent.Parent.Config.Npcs)

export type Progress = {
	stage: number,
	done: { [string]: boolean },
	choices: { [string]: string },
	seen: { [string]: boolean },
	failed: string?,
}

local NpcSave = {}

NpcSave.VERSION = 2

function NpcSave.defaultProgress(): Progress
	return { stage = 1, done = {}, choices = {}, seen = {} }
end

-- A save entry for every enabled NPC.
function NpcSave.defaults(): { [string]: Progress }
	local out: { [string]: Progress } = {}
	for _, id in Npcs.Order do
		if Npcs.List[id].enabled then
			out[id] = NpcSave.defaultProgress()
		end
	end
	return out
end

local function isSet(value: any): boolean
	return type(value) == "table"
end

local function repair(entry: any): Progress
	if type(entry) ~= "table" then
		return NpcSave.defaultProgress()
	end
	if type(entry.stage) ~= "number" or entry.stage ~= entry.stage or entry.stage < 1 then
		entry.stage = 1
	end
	entry.stage = math.floor(entry.stage)
	for _, key in { "done", "choices", "seen" } do
		if not isSet(entry[key]) then
			entry[key] = {}
		end
	end
	if entry.failed ~= nil and type(entry.failed) ~= "string" then
		entry.failed = nil
	end
	return entry :: Progress
end

-- Brings a loaded profile table up to VERSION in place and returns it.
function NpcSave.migrate(profile: { [string]: any }): { [string]: any }
	local npcs = profile.npcs
	if type(npcs) ~= "table" then
		npcs = {}
		profile.npcs = npcs
	end
	for _, id in Npcs.Order do
		if Npcs.List[id].enabled or npcs[id] ~= nil then
			npcs[id] = repair(npcs[id])
		end
	end
	return profile
end

-- True when DataStores can hold the value unchanged: tables are either arrays or string-keyed
-- dictionaries, numbers are finite, and there are no functions, userdata or cycles.
function NpcSave.isStorable(value: any, visited: { [any]: boolean }?): boolean
	local kind = type(value)
	if kind == "string" or kind == "boolean" then
		return true
	elseif kind == "number" then
		return value == value and value ~= math.huge and value ~= -math.huge
	elseif kind ~= "table" then
		return false
	end
	local seen = visited or {}
	if seen[value] then
		return false
	end
	seen[value] = true
	local count, stringKeys = 0, 0
	for key, child in value do
		count += 1
		if type(key) == "string" then
			stringKeys += 1
		elseif type(key) ~= "number" then
			return false
		end
		if not NpcSave.isStorable(child, seen) then
			return false
		end
	end
	seen[value] = nil
	-- a dictionary, or an array with no holes
	return stringKeys == count or (stringKeys == 0 and #value == count)
end

return NpcSave
