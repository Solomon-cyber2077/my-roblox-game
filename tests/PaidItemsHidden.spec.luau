--!strict
-- The Robux items are kept in the catalog but left out of what the shop shows until the
-- Official Release (Config/Cosmetics PAID_ITEMS_SHOWN).

local Cosmetics = require(Shared.Config.Cosmetics)

describe("Robux items before the Official Release", function()
	it("are left out of the shop list while the switch is off", function()
		expect(Cosmetics.PaidItemsShown).toBe(false)
		for _, def in Cosmetics.List do
			expect(def.robux == nil and def.gamePass == nil).toBe(true)
		end
	end)

	it("keep their prices in the full catalog", function()
		local prices: { [string]: number } = {}
		for _, def in Cosmetics.All do
			if def.robux then
				prices[def.id] = def.robux.price
			elseif def.gamePass then
				prices[def.id] = def.gamePass.price
			end
		end
		expect(prices.lantern_founder).toBe(249)
		expect(prices.trail_wraith).toBe(149)
		expect(prices.livery_midnight).toBe(299)
		expect(#Cosmetics.All - #Cosmetics.List).toBe(3)
	end)

	it("still look up by id, so nothing that names one breaks", function()
		expect(Cosmetics.ById.lantern_founder ~= nil).toBe(true)
	end)
end)
