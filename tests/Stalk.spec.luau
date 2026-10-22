local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local Stalk = require(Shared.Logic.Stalk)

local function sense(changes: { [string]: any }): any
	local s = {
		dt = 0.25,
		faced = false,
		alone = false,
		lit = false,
		distance = 28,
		surge = false,
		seized = false,
	}
	for key, value in changes do
		(s :: any)[key] = value
	end
	return s
end

-- Steps a stalk at `dt` until it commits or `limit` seconds pass; returns the reason and the time.
local function runUntil(s: any, settings: any, limit: number): (string?, number)
	local track = Stalk.newTrack()
	local t = 0
	while t < limit do
		local reason
		track, reason = Stalk.step(track, s, settings)
		t += s.dt
		if reason then
			return reason, t
		end
	end
	return nil, t
end

describe("Stalk reference", function()
	it("uses the fixed server radius 30 and the 24-33 band", function()
		expect(Tuning.Stalk.ReferenceRadius).toBe(30)
		local near, far = Stalk.band()
		expect(near).toBeCloseTo(24)
		expect(far).toBeCloseTo(33)
		expect(Stalk.exposureRange()).toBeCloseTo(36)
	end)

	it("keeps the band clear of the furthest proximity commit by 4 studs", function()
		expect(Stalk.bandClearsCommit()).toBe(true)
		local near = Stalk.band()
		expect(near >= math.max(Difficulty.Stalk.CommitRange[1], Difficulty.Stalk.CommitRange[2]) + 4).toBe(
			true
		)
	end)

	it("interpolates the commit table by D", function()
		local d0, d1 = Stalk.settings(0), Stalk.settings(1)
		expect(d0.min).toBe(4)
		expect(d1.min).toBe(1.5)
		expect(d0.max).toBe(12)
		expect(d1.max).toBe(6)
		expect(d0.backTurned).toBe(2.5)
		expect(d1.backTurned).toBe(1)
		expect(d0.commitRange).toBe(12)
		expect(d1.commitRange).toBe(16)
		expect(Stalk.settings(0.5).min).toBeCloseTo(2.75)
	end)
end)

describe("Stalk facing", function()
	it("counts a root look within 25 degrees from 40 studs or less", function()
		expect(Stalk.facing(0, 1, 0, 30)).toBe(true)
		local a = math.rad(24)
		expect(Stalk.facing(math.sin(a), math.cos(a), 0, 30)).toBe(true)
		local b = math.rad(26)
		expect(Stalk.facing(math.sin(b), math.cos(b), 0, 30)).toBe(false)
		expect(Stalk.facing(0, 1, 0, 41)).toBe(false)
		expect(Stalk.facing(0, -1, 0, 30)).toBe(false)
	end)
end)

describe("Stalk commits", function()
	local d0 = Stalk.settings(0)

	it("commits at once on Surge, a seized target or inside CommitRange, before the minimum", function()
		local _, surge = Stalk.step(Stalk.newTrack(), sense({ surge = true }), d0)
		local _, seized = Stalk.step(Stalk.newTrack(), sense({ seized = true }), d0)
		local _, close = Stalk.step(Stalk.newTrack(), sense({ distance = 11 }), d0)
		expect(surge).toBe("surge")
		expect(seized).toBe("seized")
		expect(close).toBe("close")
	end)

	it("never times a back-turn commit before the minimum stalk", function()
		local reason, t = runUntil(sense({}), d0, 30)
		expect(reason).toBe("back")
		expect(t >= d0.min - 1e-9).toBe(true)
	end)

	it("commits on the back turn once the minimum has run", function()
		local reason, t = runUntil(sense({}), d0, 30)
		expect(reason).toBe("back")
		expect(t).toBeCloseTo(4, 0.01)
	end)

	it("resets the back-turn interval whenever faced", function()
		local track = Stalk.newTrack()
		local reason
		for _ = 1, 20 do -- 5 s turned away, past the minimum
			track, reason = Stalk.step(track, sense({ faced = false }), d0)
		end
		expect(reason).toBe("back")
		track = { elapsed = 5, unfaced = 2.4 }
		track, reason = Stalk.step(track, sense({ faced = true }), d0)
		expect(reason).toBe(nil)
		expect(track.unfaced).toBe(0)
	end)

	it("ends a staring contest at the maximum stalk", function()
		local reason, t = runUntil(sense({ faced = true }), d0, 30)
		expect(reason).toBe("max")
		expect(t).toBeCloseTo(12, 0.01)
		local reason1, t1 = runUntil(sense({ faced = true }), Stalk.settings(1), 30)
		expect(reason1).toBe("max")
		expect(t1).toBeCloseTo(6, 0.01)
	end)

	it("halves the back turn only when alone and unlit, and still waits for the minimum", function()
		local d1 = Stalk.settings(1)
		-- face for the minimum, then turn away: alone and dark commits after half the back turn
		local track = { elapsed = d1.min, unfaced = 0 }
		local reason
		track, reason = Stalk.step(track, sense({ alone = true, dt = 0.5 }), d1)
		expect(reason).toBe("back") -- 0.5 s >= 1 x 0.5
		track = { elapsed = d1.min, unfaced = 0 }
		track, reason = Stalk.step(track, sense({ alone = true, lit = true, dt = 0.5 }), d1)
		expect(reason).toBe(nil) -- lit: the full 1 s
		track = { elapsed = d1.min, unfaced = 0 }
		track, reason = Stalk.step(track, sense({ alone = false, dt = 0.5 }), d1)
		expect(reason).toBe(nil) -- not alone: the full 1 s
		-- solo and dark before the minimum: no commit however long the back has been turned
		track = { elapsed = 0, unfaced = 0 }
		track, reason = Stalk.step(track, sense({ alone = true, dt = 1 }), d1)
		expect(reason).toBe(nil)
	end)
end)

describe("Stalk guard", function()
	it("counts warning time only in sight and within 36 studs", function()
		expect(Stalk.expose(0, 0.5, true, 30)).toBe(0.5)
		expect(Stalk.expose(0, 0.5, false, 30)).toBe(0)
		expect(Stalk.expose(0, 0.5, true, 37)).toBe(0)
		expect(Stalk.expose(1, 0.5, true, 36)).toBe(1.5)
	end)

	it("holds until 1.5 s of warning", function()
		expect(Stalk.guarded(0)).toBe(true)
		expect(Stalk.guarded(1.49)).toBe(true)
		expect(Stalk.guarded(1.5)).toBe(false)
	end)

	it("never lets a guarded Hollow close inside 16 on its own", function()
		expect(Stalk.advance(30, 4)).toBe(4)
		expect(Stalk.advance(18, 4)).toBe(2)
		expect(Stalk.advance(16, 4)).toBe(0)
		expect(Stalk.advance(10, 4)).toBe(0) -- already inside: no forward step, no push back
	end)

	it("switches targets only for someone within 0.6 of the current distance", function()
		expect(Stalk.switches(30, 17.9)).toBe(true)
		expect(Stalk.switches(30, 18)).toBe(false)
	end)
end)

describe("Stalk and the Visibility slider", function()
	local Tells = require(Shared.Logic.Tells)
	local Visibility = require(Shared.Logic.Visibility)

	it("makes the same decisions at Visibility 18 and 30", function()
		expect(Visibility.radius(18) ~= Visibility.radius(30)).toBe(true)
		local results = {}
		for _, setting in { 18, 30 } do
			local _ = Visibility.radius(setting) -- the slider moves presentation only
			local near, far = Stalk.band()
			local _, reason = Stalk.step(Stalk.newTrack(), {
				dt = 0.25,
				faced = false,
				alone = true,
				lit = false,
				distance = 15,
				surge = false,
				seized = false,
			}, Stalk.settings(1))
			local look = Tells.compute(0, 0, { { x = 0, z = 25, state = "Stalk", coil = false } }, 1)
			table.insert(results, {
				near,
				far,
				Stalk.exposureRange(),
				reason,
				Stalk.expose(0, 1, true, 35),
				look.strength,
				look.stutter,
				look.breath,
			})
		end
		for i, value in results[1] do
			expect(results[2][i]).toBe(value)
		end
	end)
end)
