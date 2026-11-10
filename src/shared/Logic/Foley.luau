--!strict
--[[
	Which handling sound an item makes (Config/Audio). Pure, for the client's FxController.

	  pickup   one soft sound for every item
	  deposit  coal poured into the bunker or parts tipped into the bin, by what was delivered
]]

local Items = require(script.Parent.Parent.Config.Items)

local Foley = {}

function Foley.pickup(itemId: string): string
	-- one plain sound for every item (owner, 11-10); unknown ids keep the old Loot sound
	return if Items[itemId] then "Pickup" else "Loot"
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
