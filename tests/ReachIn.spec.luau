local ReachIn = require(Shared.Logic.ReachIn)
local BuildingGen = require(Shared.Logic.BuildingGen)
local Buildings = require(Shared.Config.Buildings)
local Grabs = require(Shared.Config.Grabs)
local Tuning = require(Shared.Config.Tuning)
local Grab = require(Shared.Logic.Grab)

local R = Tuning.BruteRemake.Reach

-- a window in a wall along x at z = 10, facing +z (outside is +z)
local WINDOW = {
	id = 1,
	kind = "Window",
	x = 0,
	z = 10,
	nx = 0,
	nz = 1,
	width = 4,
	floor = 0,
	sill = 3.4,
}
local INNER = 10 - Buildings.Wall / 2 -- the inner face

local function step(track, covered, there, lit, dt)
	return ReachIn.step(track, { dt = dt or 0.25, covered = covered, there = there, lit = lit or false })
end

describe("ReachIn: what it can take through an opening", function()
	it("takes a player standing just inside, within Depth", function()
		expect(ReachIn.covers(WINDOW, 0, 0, INNER - 1)).toBe(true)
		expect(ReachIn.covers(WINDOW, 0, 0, INNER - R.Depth + 0.1)).toBe(true)
	end)

	it("can't take a player further in than Depth", function()
		expect(ReachIn.covers(WINDOW, 0, 0, INNER - R.Depth - 0.5)).toBe(false)
	end)

	it("can't take a player beside the opening, past its Slack", function()
		expect(ReachIn.covers(WINDOW, WINDOW.width / 2 + R.Slack + 0.5, 0, INNER - 1)).toBe(false)
		expect(ReachIn.covers(WINDOW, WINDOW.width / 2 + R.Slack - 0.1, 0, INNER - 1)).toBe(true)
	end)

	it("never takes someone on another floor", function()
		expect(ReachIn.covers(WINDOW, 0, 11, INNER - 1)).toBe(false)
	end)

	it("stands outside the wall, far enough for the Reach hold to land outside too", function()
		local sx, sz = ReachIn.stand(WINDOW)
		expect(sx).toBe(0)
		expect(sz > 10 + Buildings.Wall / 2).toBe(true)
		-- the hold sits |Reach.z| in front of it: the victim's body (0.8 deep) must clear the wall's face
		local reach = Grabs.ById.Reach.hold.pos
		expect(sz - math.abs(reach[3]) - 0.4 >= 10 + Buildings.Wall / 2).toBe(true)
	end)
end)

describe("ReachIn: openings of real buildings", function()
	it("lists exterior doors and windows on the ground floor, never boarded windows", function()
		local seen = 0
		for kind in Buildings.Defs do
			for seed = 1, 4 do
				local plan = BuildingGen.generate(kind, seed)
				local list = ReachIn.openings(plan)
				local boarded = 0
				for _, w in plan.windows do
					if w.glass == "Boarded" then
						boarded += 1
					end
				end
				local windows = 0
				for _, o in list do
					seen += 1
					expect(o.floor <= R.MaxFloor + 1e-6).toBe(true)
					expect(math.abs(o.nx) + math.abs(o.nz)).toBe(1)
					-- the outward normal points away from the building's middle
					expect(o.x * o.nx + o.z * o.nz > 0).toBe(true)
					if o.kind == "Window" then
						windows += 1
					end
				end
				expect(windows <= #plan.windows - boarded).toBe(true)
			end
		end
		expect(seen > 0).toBe(true)
	end)
end)

describe("ReachIn: choosing an opening", function()
	local other = table.clone(WINDOW)
	other.id, other.x = 2, 12

	it("picks the opening that covers the prey", function()
		local o, covered = ReachIn.choose({ other, WINDOW }, 0, 0, INNER - 1, 20, 20)
		expect(o and o.id).toBe(1)
		expect(covered).toBe(true)
	end)

	it("skips an opening still cooling down", function()
		local o, covered = ReachIn.choose({ WINDOW }, 0, 0, INNER - 1, 0, 20, { [1] = 3 })
		expect(o == nil).toBe(true)
		expect(covered).toBe(false)
	end)

	it("waits at an opening near prey deep inside", function()
		local o, covered = ReachIn.choose({ other, WINDOW }, 0, 0, 0, 30, 30)
		expect(o ~= nil).toBe(true)
		expect(covered).toBe(false)
	end)
end)

describe("ReachIn: the tell and the reach", function()
	it("reaches only after Tell seconds at the frame", function()
		local track = ReachIn.aim(ReachIn.newTrack(), WINDOW)
		local fired
		track, fired = step(track, true, true)
		expect(track.phase).toBe("Tell")
		local t = 0
		while fired == nil and t < 10 do
			track, fired = step(track, true, true)
			t += 0.25
		end
		expect(fired).toBe("Reach")
		expect(t >= R.Tell - 1e-6).toBe(true)
		expect(track.cooldown[1]).toBe(R.Cooldown)
	end)

	it("stepping back out of reach during the tell stops it", function()
		local track = ReachIn.aim(ReachIn.newTrack(), WINDOW)
		track = step(track, true, true)
		local fired
		track, fired = step(track, false, true)
		expect(fired == nil).toBe(true)
		expect(track.phase).toBe("Approach")
	end)

	it("light at the opening stops it and cools the opening", function()
		local track = ReachIn.aim(ReachIn.newTrack(), WINDOW)
		track = step(track, true, true)
		local fired
		track, fired = step(track, true, true, true)
		expect(fired == nil).toBe(true)
		expect(track.phase).toBe("Idle")
		expect(track.cooldown[1]).toBe(R.Cooldown)
	end)

	it("gives up lurking after Lurk seconds and cools that opening", function()
		local track = ReachIn.aim(ReachIn.newTrack(), WINDOW)
		track = step(track, false, true)
		expect(track.phase).toBe("Lurk")
		local t = 0
		while track.phase == "Lurk" and t < 30 do
			track = step(track, false, true)
			t += 0.25
		end
		expect(track.phase).toBe("Idle")
		expect(t >= R.Lurk - 0.25).toBe(true)
		expect((track.cooldown[1] or 0) > 0).toBe(true)
	end)

	it("cooldowns run out", function()
		local track = ReachIn.newTrack()
		track.cooldown[1] = 1
		track = step(track, false, false, false, 1.5)
		expect(track.cooldown[1] == nil).toBe(true)
	end)
end)

describe("ReachIn: the late return", function()
	it("never comes in a tutorial run or before the first late stop", function()
		for seed = 1, 50 do
			expect(ReachIn.returns(seed, 10, 2, 1)).toBe(false)
			expect(ReachIn.returns(seed, 1, nil, 0)).toBe(false)
			expect(ReachIn.returns(seed, 5, nil, 1)).toBe(false)
		end
	end)

	it("comes at about Chance of late stops", function()
		local hits, n = 0, 400
		for seed = 1, n do
			if ReachIn.returns(seed * 7919, 9, nil, 0.5) then
				hits += 1
			end
		end
		local share = hits / n
		expect(math.abs(share - Tuning.BruteRemake.Return.Chance) < 0.08).toBe(true)
	end)

	it("is the same on every server for the same stop", function()
		expect(ReachIn.returns(1234, 8, nil, 0.3)).toBe(ReachIn.returns(1234, 8, nil, 0.3))
	end)
end)

describe("ReachIn: switches", function()
	-- The Stoker goes into the Test Launch (owner, 2026-11-18): the switches may be on, but only as one set.
	-- The late return needs the remake on, and he stays on the bench otherwise (the return is his only way in).
	it("ships as one set: the late return only with the remake, benched otherwise", function()
		if Tuning.BruteRemake.Returns then
			expect(Tuning.BruteRemake.Enabled).toBe(true)
		end
		expect(Tuning.HollowBenched.Brute).toBe(true)
	end)

	it("an ordinary strike never picks the reach-in", function()
		for _, def in Grab.order("Brute", 3) do
			expect(def.reach == true).toBe(false)
		end
	end)
end)
