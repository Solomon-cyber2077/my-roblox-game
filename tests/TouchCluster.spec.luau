local TouchCluster = require(Shared.Logic.TouchCluster)

local function overlap(a, b)
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

describe("TouchCluster", function()
	it("matches Roblox's jump button on a small and a large screen", function()
		local small = TouchCluster.jump(667, 375)
		expect(small.w).toBe(70)
		expect(small.x).toBe(667 - 95)
		expect(small.y).toBe(375 - 90)
		local large = TouchCluster.jump(1180, 820)
		expect(large.w).toBe(120)
		expect(large.x).toBe(1180 - 170)
		expect(large.y).toBe(820 - 210)
	end)

	it("keeps every button apart from the jump button and each other, at full size", function()
		for _, screen in { { 667, 375 }, { 852, 393 }, { 945, 436 }, { 1180, 820 } } do
			local jump = TouchCluster.jump(screen[1], screen[2])
			local c = TouchCluster.place(jump)
			local all = { jump, c.run, c.look, c.ping, c.action }
			for i = 1, #all do
				expect(math.min(all[i].w, all[i].h) >= 60).toBe(true)
				for j = i + 1, #all do
					expect(overlap(all[i], all[j])).toBe(false)
				end
				-- on screen
				expect(all[i].x >= 0 and all[i].x + all[i].w <= screen[1]).toBe(true)
				expect(all[i].y >= 0 and all[i].y + all[i].h <= screen[2]).toBe(true)
			end
		end
	end)

	it("reports the leftmost edge for the cash-out card to keep clear of", function()
		local c = TouchCluster.place(TouchCluster.jump(667, 375))
		expect(TouchCluster.left(c)).toBe(c.action.x)
	end)
end)
