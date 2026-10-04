local DifficultyModel = require(Shared.Logic.DifficultyModel)
local Grab = require(Shared.Logic.Grab)
local Grabs = require(Shared.Config.Grabs)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

local KINDS = { "Stalker", "Crawler", "Brute" }

-- Plays a hold out frame by frame: the victim presses `rate` times a second (and an ally
-- `ally` times), from full health. Returns whether they broke free and the health left.
local function struggle(def, params, kindName: string, rate: number, ally: number?): (boolean, number)
	local kind = Grab.kind(kindName)
	local dt = 1 / 60
	local health = Tuning.Crew.MaxHealth
	local escape = 0
	local t = 0
	local nextPress = 1 / rate
	local nextPry = if ally then 1 / ally else math.huge
	while t < Tuning.Grab.MaxSeconds do
		local after = t + dt
		while nextPress <= after do
			escape = Grab.press(escape, params, kind)
			nextPress += 1 / rate
		end
		while nextPry <= after do
			escape = Grab.pry(escape, params, kind)
			nextPry += 1 / (ally :: number)
		end
		escape = Grab.slip(escape, params, dt)
		health -= Grab.damage(def, params, kind, t, after)
		t = after
		if health <= 0 then
			return false, 0
		end
		if Grab.free(escape) then
			return true, health
		end
	end
	return false, health
end

describe("Grab", function()
	it("gives every kind three grabs with distinct ids", function()
		for _, kind in KINDS do
			local list = Grabs.Kinds[kind]
			expect(#list).toBe(3)
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
		local a = Grab.order("Brute", 77)
		local b = Grab.order("Brute", 77)
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

	it("lets a steady masher break every grab at every stop from full health", function()
		for _, id in Stations.Order do
			for d = 0, 1, 0.25 do
				local params = DifficultyModel.params(d, Stations.List[id], 4, nil)
				for _, kind in KINDS do
					for _, def in Grabs.Kinds[kind] do
						local free = struggle(def, params, kind, 6)
						expect(free).toBe(true)
					end
				end
			end
		end
	end)

	it("kills someone who barely struggles, unless the crew pulls them free", function()
		local params = DifficultyModel.params(0.8, Stations.List.Market, 4, nil)
		local def = Grabs.ById.Bearhug
		expect(Grab.escapeSeconds(params, Grab.kind("Brute"), 2)).toBe(math.huge)
		local free = struggle(def, params, "Brute", 2)
		expect(free).toBe(false)
		local saved = struggle(def, params, "Brute", 2, 4)
		expect(saved).toBe(true)
	end)

	it("holds tighter at the hard stops", function()
		local halt = Stations.List.Halt
		local easy = DifficultyModel.params(0, halt, 4, nil)
		local hard = DifficultyModel.params(1, halt, 4, nil)
		for _, kind in KINDS do
			local k = Grab.kind(kind)
			expect(Grab.escapeSeconds(hard, k, 6)).toBeGreaterThan(Grab.escapeSeconds(easy, k, 6))
			expect(Grab.dps(hard, k)).toBeGreaterThan(Grab.dps(easy, k))
		end
		-- the Brute holds hardest and hurts most, the Crawler least
		local brute, crawler = Grab.kind("Brute"), Grab.kind("Crawler")
		expect(Grab.escapeSeconds(hard, brute, 6)).toBeGreaterThan(Grab.escapeSeconds(hard, crawler, 6))
		expect(Grab.dps(hard, brute)).toBeGreaterThan(Grab.dps(hard, crawler))
	end)
end)
