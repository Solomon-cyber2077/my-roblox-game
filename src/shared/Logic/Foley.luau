--!strict
--[[
	Which handling sound an item makes (Config/Audio). Pure, for the client's FxController.

	  pickup   coal lumps, a clanky part, or a small bell for a relic or a valuable; a tool or
	           anything else keeps the plain Loot sound
	  deposit  coal poured into the bunker or parts tipped into the bin, by what was delivered
]]

local Items = require(script.Parent.Parent.Config.Items)

local Foley = {}

function Foley.pickup(itemId: string): string
	local def = Items[itemId]
	if def == nil then
		return "Loot"
	end
	if (def.coal or 0) > 0 then
		return "PickupCoal"
	end
	if (def.parts or 0) > 0 then
		return "PickupParts"
	end
	if def.kind == "Relic" or def.kind == "Valuable" then
		return "PickupRelic"
	end
	return "Loot"
end

-- The delivery sounds for `coal` and `parts` delivered at once, coal first.
function Foley.deposit(coal: number, parts: number): { string }
	local cues = {}
	if coal > 0 then
		table.insert(cues, "DepositCoal")
	end
	if parts > 0 then
		table.insert(cues, "DepositParts")
	end
	return cues
end

return table.freeze(Foley)
