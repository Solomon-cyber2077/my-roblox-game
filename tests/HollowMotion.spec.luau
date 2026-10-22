local HollowMotion = require(Shared.Logic.HollowMotion)
local Tuning = require(Shared.Config.Tuning)

describe("HollowMotion look-at", function()
	it("caps the head per kind: Stalker 70, Crawler 50, Brute 35 degrees", function()
		expect(math.deg(HollowMotion.yawTo("Stalker", -10, 0))).toBeCloseTo(70)
		expect(math.deg(HollowMotion.yawTo("Crawler", 10, 0))).toBeCloseTo(-50)
		expect(math.deg(HollowMotion.yawTo("Brute", -10, 1))).toBeCloseTo(35)
	end)

	it("looks straight at a target ahead and turns left for one on the left", function()
		expect(HollowMotion.yawTo("Stalker", 0, -10)).toBeCloseTo(0)
		expect(HollowMotion.yawTo("Stalker", -1, -10) > 0).toBe(true)
	end)

	it("lags its target with the 0.25 s time constant", function()
		local yaw = HollowMotion.follow(0, 1, Tuning.HollowMotion.LookLag)
		expect(yaw).toBeCloseTo(1 - math.exp(-1), 1e-6)
		local settled = 0
		for _ = 1, 120 do
			settled = HollowMotion.follow(settled, 1, 1 / 60)
		end
		expect(settled > 0.99).toBe(true)
	end)

	it("scans slowly within the cap while prowling", function()
		for t = 0, 10, 0.1 do
			expect(math.abs(HollowMotion.scan("Brute", t, 3)) <= HollowMotion.cap("Brute") + 1e-9).toBe(true)
		end
	end)
end)

describe("HollowMotion lean", function()
	it("leans into acceleration and out of deceleration, clamped", function()
		expect(HollowMotion.lean(10) < 0).toBe(true)
		expect(HollowMotion.lean(-10) > 0).toBe(true)
		expect(HollowMotion.lean(1000)).toBeCloseTo(-Tuning.HollowMotion.LeanMax)
		expect(HollowMotion.lean(-1000)).toBeCloseTo(Tuning.HollowMotion.LeanMax)
	end)
end)

describe("HollowMotion transitions", function()
	it("blends ordinary changes over 0.2-0.35 s", function()
		for _, pair in
			{ { "Prowl", "Stalk" }, { "Stalk", "Hunt" }, { "Hunt", "Recover" }, { "Hunt", "Repelled" } }
		do
			expect(HollowMotion.blendSeconds(pair[1], pair[2])).toBeBetween(0.2, 0.35)
		end
	end)

	it("snaps the attack tells", function()
		expect(HollowMotion.blendSeconds("Hunt", "Coil")).toBe(0)
		expect(HollowMotion.blendSeconds("Coil", "Windup")).toBe(0)
		expect(HollowMotion.blendSeconds("Hunt", "Lunge")).toBe(0)
	end)

	it("eases out", function()
		expect(HollowMotion.easeOut(0)).toBe(0)
		expect(HollowMotion.easeOut(1)).toBe(1)
		expect(HollowMotion.easeOut(0.5) > 0.5).toBe(true)
	end)
end)

describe("HollowMotion plants", function()
	it("plants each biped foot once per gait cycle", function()
		local left, right = 0, 0
		local phase = 0
		for _ = 1, 400 do
			local nextPhase = phase + 0.05
			for _, foot in HollowMotion.plants("Stalker", phase, nextPhase) do
				if foot == "L" then
					left += 1
				else
					right += 1
				end
			end
			phase = nextPhase
		end
		-- 20 radians: three full cycles and change
		expect(left).toBe(3)
		expect(right).toBe(3)
	end)

	it("plants all four Crawler limbs, paired, twice per cycle in total", function()
		local count = 0
		local phase = 0.01
		for _ = 1, 126 do
			local nextPhase = phase + 0.05
			count += #HollowMotion.plants("Crawler", phase, nextPhase)
			phase = nextPhase
		end
		expect(count).toBe(4) -- one cycle of 2 pi: each limb once
	end)

	it("plants nothing when the phase stands still", function()
		expect(#HollowMotion.plants("Brute", 1, 1)).toBe(0)
	end)
end)
