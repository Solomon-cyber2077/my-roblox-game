local Tuning = require(Shared.Config.Tuning)
local Difficulty = require(Shared.Config.Difficulty)

describe("Benched Hollow kinds", function()
	it("keeps the Brute out of the Test Launch", function()
		expect(Tuning.HollowBenched.Brute).toBe(true)
	end)

	it("benches only real kinds and leaves kinds that can still be rolled", function()
		local left = 0
		for kind in Tuning.HollowBenched do
			expect(Tuning.HollowKinds[kind] ~= nil).toBe(true)
		end
		for kind, pair in Difficulty.HollowKinds :: { [string]: { number } } do
			if not Tuning.HollowBenched[kind] and pair[1] > 0 then
				left += 1
			end
		end
		-- the Stoker (Brute) still comes, benched, by his late return when it is on (Logic/ReachIn.returns)
		if Tuning.HollowBenched.Brute and Tuning.BruteRemake.Enabled and Tuning.BruteRemake.Returns then
			left += 1
		end
		expect(left >= 2).toBe(true)
	end)

	it("never benches the Stalker, which stands in for a benched sleeper", function()
		expect(Tuning.HollowBenched.Stalker == nil).toBe(true)
	end)
end)
