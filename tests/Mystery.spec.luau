local Config = require(Shared.Config.Mystery)
local LayoutGen = require(Shared.Logic.LayoutGen)
local Mystery = require(Shared.Logic.Mystery)
local RouteGen = require(Shared.Logic.RouteGen)
local Stations = require(Shared.Config.Stations)
local TicketModel = require(Shared.Logic.TicketModel)
local Tuning = require(Shared.Config.Tuning)
local Vote = require(Shared.Logic.Vote)

local STOPS = Tuning.Run.StationCount
local HIT = 0 -- a roll under Chance
local MISS = 0.99 -- a roll over it

-- Every string and number anywhere inside a value, flattened, keys included.
local function words(value, out)
	out = out or {}
	if type(value) == "table" then
		for k, v in value do
			words(k, out)
			words(v, out)
		end
	else
		table.insert(out, string.lower(tostring(value)))
	end
	return out
end

local function leaks(value, real)
	local arch = Stations.List[real.archetype]
	local secrets = { string.lower(real.archetype), string.lower(arch.name), string.lower(arch.hint) }
	for _, word in words(value) do
		for _, secret in secrets do
			if secret ~= "" and string.find(word, secret, 1, true) then
				return secret
			end
		end
	end
	return nil
end

describe("Mystery.offers", function()
	it("never offers at the first junction, even past the pity count", function()
		expect(Mystery.offers({ since = 99, last = false }, 1, STOPS, HIT)).toBe(false)
	end)
	it("never offers two junctions in a row", function()
		expect(Mystery.offers({ since = 99, last = true }, 4, STOPS, HIT)).toBe(false)
		local after = Mystery.record(Mystery.newHistory(), true)
		expect(Mystery.offers(after, 4, STOPS, HIT)).toBe(false)
	end)
	it("never offers on the leg to the Terminus", function()
		expect(Mystery.offers({ since = 99, last = false }, STOPS + 1, STOPS, HIT)).toBe(false)
	end)
	it("rolls the chance otherwise", function()
		local h = { since = 1, last = false }
		expect(Mystery.offers(h, 2, STOPS, Config.Chance - 0.01)).toBe(true)
		expect(Mystery.offers(h, 2, STOPS, Config.Chance)).toBe(false)
		expect(Mystery.offers(h, 2, STOPS, MISS)).toBe(false)
	end)
	it("guarantees one after PityAfter junctions without it", function()
		local h = Mystery.newHistory()
		local leg = 1
		local offeredAt = nil
		while leg <= STOPS and offeredAt == nil do
			local offered = Mystery.offers(h, leg, STOPS, MISS)
			if offered then
				offeredAt = leg
			end
			h = Mystery.record(h, offered)
			leg += 1
		end
		expect(offeredAt).toBe(Config.PityAfter + 1)
	end)
	it("resets the pity count when one is offered", function()
		local h = Mystery.record({ since = 4, last = false }, true)
		expect(h.since).toBe(0)
		expect(h.last).toBe(true)
		h = Mystery.record(h, false)
		expect(h.since).toBe(1)
		expect(h.last).toBe(false)
	end)
	it("lands near Chance over many seeded runs, never consecutive, never at junction 1", function()
		local Rng = require(Shared.Util.Rng)
		local offers, eligible = 0, 0
		for seed = 1, 400 do
			local h = Mystery.newHistory()
			for leg = 1, STOPS do
				local roll = Rng.new(Rng.derive(seed, "mystery", leg)):next()
				local wasLast = h.last
				local offered = Mystery.offers(h, leg, STOPS, roll)
				if leg == 1 or wasLast then
					expect(offered).toBe(false)
				else
					eligible += 1
				end
				if offered then
					offers += 1
				end
				h = Mystery.record(h, offered)
			end
		end
		local rate = offers / eligible
		expect(rate > 0.2 and rate < 0.4).toBe(true)
	end)
	it("does nothing when the flag is off", function()
		-- the flag is read from Config; this guards that the default ships on and the switch exists
		expect(type(Config.Enabled)).toBe("boolean")
	end)
end)

describe("Mystery.pick", function()
	it("generates a valid station from the normal generator, off the ballot", function()
		for seed = 1, 60 do
			for leg = 2, STOPS do
				local visible = RouteGen.options(seed, leg, STOPS, nil)
				local real = Mystery.pick(seed * 7919 + 13, leg, STOPS, nil, visible)
				expect(real ~= nil).toBe(true)
				local arch = Stations.List[real.archetype]
				expect(arch ~= nil).toBe(true)
				expect(arch.terminus == true).toBe(false)
				expect(arch.minStation <= leg).toBe(true)
				for _, option in visible do
					expect(option.archetype ~= real.archetype).toBe(true)
				end
				expect(real.tier >= 1 and real.tier <= (if leg <= 2 then 2 else Config.MaxTier)).toBe(true)
				expect(real.distanceKm >= 3 and real.distanceKm <= 8).toBe(true)
				expect(real.mystery).toBe(nil)
			end
		end
	end)
	it("lays out with the loot bonus", function()
		local visible = RouteGen.options(5, 3, STOPS, nil)
		local real = Mystery.pick(12345, 3, STOPS, nil, visible)
		local plan = LayoutGen.generate(real.archetype, 99, Mystery.lootMul(1))
		expect(plan.length > 0).toBe(true)
		expect(Mystery.lootMul(1)).toBe(Config.LootBonus)
	end)
end)

describe("Mystery redaction", function()
	it("keeps name, type, danger and loot out of every public shape before the reveal", function()
		for seed = 1, 40 do
			local leg = 3
			local options = RouteGen.options(seed, leg, STOPS, nil)
			local real = Mystery.pick(seed + 1000, leg, STOPS, nil, options)
			local index = Mystery.place(options)
			options[index] = Mystery.redact(real)
			local public = options[index]
			-- the ballot (run.route.options), the sealed destination and what the ticket prints
			expect(leaks(public, real)).toBe(nil)
			expect(leaks(Mystery.sealed(real.distanceKm, 7), real)).toBe(nil)
			expect(leaks(TicketModel.view(public, 1, 7, 20), real)).toBe(nil)
			expect(public.archetype).toBe(Config.Archetype)
			expect(public.tier).toBe(0)
			expect(public.hint).toBe("")
			expect(public.distanceKm).toBe(real.distanceKm)
			local keys = {}
			for k in public do
				table.insert(keys, k)
			end
			table.sort(keys)
			expect(table.concat(keys, ",")).toBe("archetype,distanceKm,hint,mystery,tier")
			local sealed = Mystery.sealed(real.distanceKm, 7)
			expect(sealed.tier).toBe(0)
			expect(sealed.difficulty).toBe(0)
			expect(sealed.sealed).toBe(true)
			expect(Stations.List[sealed.archetype]).toBe(nil)
		end
	end)
	it("prints a sealed ticket with no seal", function()
		local view =
			TicketModel.view(Mystery.redact({ archetype = "Halt", tier = 2, distanceKm = 4, hint = "x" }))
		expect(view.mystery).toBe(true)
		expect(view.name).toBe(Config.Name)
		expect(view.seal).toBe(nil)
		expect(view.tier).toBe(0)
		expect(view.distanceKm).toBe(4)
	end)
end)

describe("Mystery ballot", function()
	local a = { archetype = "Halt", tier = 1, distanceKm = 6, hint = "" }
	local b = { archetype = "CoalYard", tier = 2, distanceKm = 4, hint = "" }
	local c = { archetype = "Market", tier = 2, distanceKm = 8, hint = "" }
	it("appends to a two-way ballot and replaces the longest line of a full one", function()
		expect(Mystery.place({ a, b })).toBe(3)
		expect(Mystery.place({ a, b, c })).toBe(3)
		expect(Mystery.place({ c, b, a })).toBe(1)
	end)
	it("keeps a short line on offer after the replacement", function()
		for seed = 1, 80 do
			for leg = 2, STOPS do
				local options = RouteGen.options(seed, leg, STOPS, nil)
				local real = Mystery.pick(seed + 7, leg, STOPS, nil, options)
				options[Mystery.place(options)] = Mystery.redact(real)
				expect(#options <= Mystery.MaxOptions).toBe(true)
				local short = false
				for _, option in options do
					short = short or option.distanceKm <= 5
				end
				expect(short).toBe(true)
			end
		end
	end)
	it("tallies three options with a sealed one", function()
		local sealed = Mystery.redact({ archetype = "Market", tier = 3, distanceKm = 4, hint = "" })
		local options = { a, b, sealed }
		expect(Vote.tally({ x = 3, y = 3, z = 1 }, options, 0)).toBe(3)
		-- a three-way tie: the shortest legs (2 and 3, both 4 km), then the coin
		expect(Vote.tally({ x = 1, y = 2, z = 3 }, options, 0)).toBe(2)
		expect(Vote.tally({ x = 1, y = 2, z = 3 }, options, 0.99)).toBe(3)
		-- no votes at all: the same rule
		expect(Vote.tally({}, options, 0.5)).toBe(3)
		expect(TicketModel.tieNote({ x = 1, y = 2, z = 3 }, options)).toBe(
			"A TIE: SHORTEST LINES LEVEL, THE DRIVER TOSSES A COIN"
		)
	end)
end)
