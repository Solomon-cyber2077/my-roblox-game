local CarryPriority = require(Shared.Logic.CarryPriority)
local Items = require(Shared.Config.Items)

-- A one-slot and a two-slot item from the real catalogue.
local function find(slots: number): string
	for id, def in Items do
		if def.slots == slots and not (def :: any).protected then
			return id
		end
	end
	error(`no {slots}-slot item`)
end

local ONE = find(1)
local TWO = find(2)

describe("CarryPriority", function()
	it("keeps everything that fits", function()
		local kept, dropped = CarryPriority.overflow({ ONE, ONE }, 4)
		expect(#kept).toBe(2)
		expect(#dropped).toBe(0)
	end)

	it("drops whole rightmost entries first, by slot cost", function()
		local kept, dropped = CarryPriority.overflow({ TWO, ONE, ONE, TWO }, 4)
		expect(#dropped).toBe(1)
		expect(dropped[1]).toBe(TWO)
		expect(CarryPriority.used(kept)).toBe(4)
		local k2, d2 = CarryPriority.overflow({ ONE, TWO, ONE, ONE }, 2)
		-- right to left: the last two ones go, leaving 1 + 2 = 3 > 2, so the two-slot goes too
		expect(#k2).toBe(1)
		expect(k2[1]).toBe(ONE)
		expect(#d2).toBe(3)
	end)

	it("keeps duplicates by position, not by id", function()
		local kept, dropped = CarryPriority.overflow({ ONE, ONE, ONE }, 2)
		expect(#kept).toBe(2)
		expect(#dropped).toBe(1)
	end)

	it("drops everything ordinary at zero capacity", function()
		local kept, dropped = CarryPriority.overflow({ ONE, TWO }, 0)
		expect(#kept).toBe(0)
		expect(#dropped).toBe(2)
	end)

	it("accepts only a permutation at the current revision", function()
		local items = { ONE, TWO, ONE }
		local moved = CarryPriority.reorder(items, 3, { 2, 1, 3 }, 3)
		expect(moved and moved[1]).toBe(TWO)
		expect(select(2, CarryPriority.reorder(items, 3, { 2, 1, 3 }, 2))).toBe("Stale")
		expect(select(2, CarryPriority.reorder(items, 3, { 1, 1, 3 }, 3))).toBe("Permutation")
		expect(select(2, CarryPriority.reorder(items, 3, { 1, 2 }, 3))).toBe("Shape")
		expect(select(2, CarryPriority.reorder(items, 3, { 1, 2, 4 }, 3))).toBe("Permutation")
		expect(select(2, CarryPriority.reorder(items, 3, { 1, 2, 3.5 }, 3))).toBe("Permutation")
		expect(select(2, CarryPriority.reorder(items, 3, "nope", 3))).toBe("Shape")
	end)
end)
