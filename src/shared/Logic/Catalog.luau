--!strict
--[[
	Cosmetic ownership and purchase rules, shared by ShopService (authority)
	and the Outfitter UI (to explain why a button is disabled before asking).
]]

local Shared = script.Parent.Parent
local Cosmetics = require(Shared.Config.Cosmetics)
local CrewClothing = require(Shared.Logic.CrewClothing)
local Progression = require(Shared.Config.Progression)
local Rng = require(Shared.Util.Rng)

type CosmeticDef = Cosmetics.CosmeticDef
type OwnedSet = { [string]: boolean }

export type BuyCheck = "Ok" | "Unknown" | "Owned" | "NotForBrass" | "Brass"

local Catalog = {}

function Catalog.isOwned(owned: OwnedSet, id: string): boolean
	local def = Cosmetics.ById[id]
	return def ~= nil and (def.default == true or owned[id] == true)
end

function Catalog.devUnlocked(userId: number, isStudio: boolean): boolean
	local unlock = Cosmetics.DevUnlock
	return unlock.Enabled and (isStudio or userId == unlock.UserId)
end

function Catalog.canUse(owned: OwnedSet, id: string, userId: number, isStudio: boolean): boolean
	local def = Cosmetics.ById[id]
	if def == nil then
		return false
	end
	if def.category == "Uniform" then
		return CrewClothing.canWear(id, owned)
	end
	return Catalog.isOwned(owned, id) or Catalog.devUnlocked(userId, isStudio)
end

function Catalog.dayNumber(unixSeconds: number): number
	return unixSeconds // 86400
end

-- Three Brass-priced items, the same for every server on a given UTC day.
function Catalog.dailySpecials(day: number): { string }
	local pool: { string } = {}
	for _, def in Cosmetics.List do
		if def.brass and not def.default then
			table.insert(pool, def.id)
		end
	end
	table.sort(pool)
	local rng = Rng.new(Rng.derive(day, "specials"))
	rng:shuffle(pool)
	local picks: { string } = {}
	for i = 1, math.min(Cosmetics.DailySpecialCount, #pool) do
		table.insert(picks, pool[i])
	end
	return picks
end

function Catalog.brassPrice(id: string, day: number): number?
	local def = Cosmetics.ById[id]
	if def == nil or def.brass == nil then
		return nil
	end
	if table.find(Catalog.dailySpecials(day), id) then
		return math.floor(def.brass * (1 - Cosmetics.DailySpecialDiscount) + 0.5)
	end
	return def.brass
end

function Catalog.canBuyWithBrass(owned: OwnedSet, brass: number, id: string, day: number): (BuyCheck, number?)
	local def = Cosmetics.ById[id]
	if def == nil then
		return "Unknown", nil
	end
	if Catalog.isOwned(owned, id) then
		return "Owned", nil
	end
	local price = Catalog.brassPrice(id, day)
	if price == nil then
		return "NotForBrass", nil
	end
	if brass < price then
		return "Brass", price
	end
	return "Ok", price
end

-- A status item's record, as the Outfitter and the Roll show it: "3 Terminus arrivals", and both
-- halves of an AND ("1 Long Line finish + 50 stops departed").
function Catalog.recordText(def: CosmeticDef): string?
	local record = def.record
	if record == nil then
		return nil
	end
	local parts: { string } = {}
	for _, req in record do
		table.insert(parts, string.format(Progression.StatText[req.stat] or `{req.stat} %d`, req.goal))
	end
	return table.concat(parts, " + ")
end

-- Whether a profile's lifetime stats meet a status item's whole record (every requirement).
function Catalog.recordMet(stats: { [string]: number }, def: CosmeticDef): boolean
	local record = def.record
	if record == nil then
		return false
	end
	for _, req in record do
		if (stats[req.stat] or 0) < req.goal then
			return false
		end
	end
	return true
end

-- Human-readable unlock path for locked items.
function Catalog.unlockText(def: CosmeticDef): string
	if def.default then
		return "Owned by every crew member"
	elseif def.record then
		return `Line Mastery: {Catalog.recordText(def)}`
	elseif def.milestone then
		return "Line Mastery reward"
	elseif def.charterStamps then
		return `{def.charterStamps} Charter Stamps`
	elseif def.npc then
		return "Crew errands reward"
	elseif def.gamePass then
		return "Game pass"
	elseif def.robux then
		return "Robux"
	end
	return "Outfitter"
end

return table.freeze(Catalog)
