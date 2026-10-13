local Difficulty = require(Shared.Config.Difficulty)
local DifficultyModel = require(Shared.Logic.DifficultyModel)
local Grab = require(Shared.Logic.Grab)
local Grabs = require(Shared.Config.Grabs)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

local KINDS = { "Stalker", "Crawler", "Brute" }

local SkillCheck = require(Shared.Logic.SkillCheck)

-- Plays a hold out frame by frame from full health with the bite floor, up to its finish.
-- Returns the health left when the clock runs out.
local function holdOut(def, params, kindName: string, finish: number): number
	local kind = Grab.kind(kindName)
	local dt = 1 / 60
	local health = Tuning.Crew.MaxHealth
	local t = 0
	while t < finish do
		local after = t + dt
		health -= Grab.survivable(Grab.damage(def, params, kind, t, after), health)
		t = after
	end
	return health
end

describe("Grab", function()
	it("gives every kind three grabs with distinct ids", function()
		for _, kind in KINDS do
			local list = Grabs.Kinds[kind]
			expect(#list).toBe(if kind == "Brute" then 4 else 3)
			local seen = {}
			for _, def in list do
				expect(seen[def.id]).toBe(nil)
				seen[def.id] = true
				expect(Grabs.ById[def.id]).toBe(def)
				expect(def.bite).toBeGreaterThan(0.3)
			end
		end
	end)

	it("orders the grabs by the Hollow's seed, the same every time", function()
		local a = Grab.order("Crawler", 77)
		local b = Grab.order("Crawler", 77)
		expect(#a).toBe(3)
		for i, def in a do
			expect(def.id).toBe(b[i].id)
		end
		local firsts = {}
		for seed = 1, 40 do
			firsts[Grab.order("Stalker", seed)[1].id] = true
		end
		local variety = 0
		for _ in firsts do
			variety += 1
		end
		expect(variety).toBe(3)
	end)

	it("counts bites on the grab's rhythm, none before the snatch settles", function()
		local def = Grabs.ById.Throttle
		local settle = Tuning.Grab.Settle
		expect(Grab.bitesBetween(def, 0, settle + def.bite - 0.01)).toBe(0)
		expect(Grab.bitesBetween(def, 0, settle + def.bite)).toBe(1)
		expect(Grab.bitesBetween(def, 0, settle + 3 * def.bite + 0.01)).toBe(3)
		-- split into frames, the count is the same
		local total = 0
		for i = 0, 299 do
			total += Grab.bitesBetween(def, i / 60, (i + 1) / 60)
		end
		expect(total).toBe(Grab.bitesBetween(def, 0, 5))
	end)

	it("never kills before the grab's clock runs out, at any stop, for any grab", function()
		for _, id in Stations.Order do
			for stop = 1, Tuning.Run.StationCount do
				local d = DifficultyModel.forStop(stop, Tuning.Run.StationCount, 3)
				local params = DifficultyModel.params(d, Stations.List[id], 4, nil)
				local finish = SkillCheck.finishSeconds(stop, SkillCheck.zoneWidth(stop))
				for _, kind in KINDS do
					for _, def in Grabs.Kinds[kind] do
						expect(holdOut(def, params, kind, finish)).toBeAtLeast(Grab.BiteFloor)
					end
				end
			end
		end
	end)

	it("still hurts: a long hold takes most of a full-health crew member", function()
		local params = DifficultyModel.params(0.8, Stations.List.Market, 4, nil)
		local left = holdOut(Grabs.ById.Bearhug, params, "Brute", 9)
		expect(left).toBeLessThan(Tuning.Crew.MaxHealth / 2)
		expect(Grab.survivable(50, 30)).toBe(30 - Grab.BiteFloor)
		expect(Grab.survivable(5, 30)).toBe(5)
		expect(Grab.survivable(5, 0.5)).toBe(0)
	end)

	it("makes every Brute strike a face-down slam and pin", function()
		for seed = 1, 20 do
			local order = Grab.order("Brute", seed)
			expect(#order).toBe(1)
			expect(order[1].id).toBe("Slam")
		end
		local slam = Grabs.ById.Slam
		expect(slam.pin).toBe(true)
		expect(slam.lying).toBe(true)
		expect(slam.hold.face[2]).toBe(-1) -- face down
		expect(slam.bite).toBe(Tuning.Grab.Pin.Tick)
		-- pinned damage ticks at the Tuning rate, not the kind's crush
		local params = DifficultyModel.params(0.5, Stations.List.Halt, 4, nil)
		local tick = params.hollowDamage * Difficulty.GrabDamage.PinDpsShare * Tuning.Grab.Pin.Tick
		expect(math.abs(Grab.bite(slam, params, Grab.kind("Brute")) - tick)).toBeLessThan(1e-6)
	end)

	it("never lets one bite kill a full-health crew member", function()
		local cap = Difficulty.GrabDamage.MaxBiteShare * Tuning.Crew.MaxHealth
		expect(cap).toBeLessThan(Tuning.Crew.MaxHealth)
		for _, id in Stations.Order do
			local params = DifficultyModel.params(1, Stations.List[id], 4, nil)
			for _, kind in KINDS do
				for _, def in Grabs.Kinds[kind] do
					expect(Grab.bite(def, params, Grab.kind(kind))).toBeLessThan(cap + 1e-6)
				end
			end
		end
		-- even an absurd stop is clamped
		local params = table.clone(DifficultyModel.params(1, Stations.List.Halt, 4, nil))
		params.hollowDamage = 10000
		local def = Grabs.ById.Throttle
		expect(Grab.bite(def, params, Grab.kind("Brute"))).toBe(cap)
		expect(Grab.damage(def, params, Grab.kind("Brute"), 0, Tuning.Grab.Settle + def.bite)).toBe(cap)
	end)

	it("hurts more at the hard stops", function()
		local halt = Stations.List.Halt
		local easy = DifficultyModel.params(0, halt, 4, nil)
		local hard = DifficultyModel.params(1, halt, 4, nil)
		for _, kind in KINDS do
			local k = Grab.kind(kind)
			expect(Grab.dps(hard, k)).toBeGreaterThan(Grab.dps(easy, k))
		end
		-- the Brute hurts most, the Crawler least
		local brute, crawler = Grab.kind("Brute"), Grab.kind("Crawler")
		expect(Grab.dps(hard, brute)).toBeGreaterThan(Grab.dps(hard, crawler))
	end)
end)
