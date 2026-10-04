local Journey = require(Shared.Logic.Journey)
local Motion = require(Shared.Logic.Motion)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

local J = Tuning.Journey

local function area(rects)
	local total = 0
	for _, r in rects do
		total += (r.x1 - r.x0) * (r.z1 - r.z0)
	end
	return total
end

describe("Journey biomes", function()
	it("maps every archetype to a biome and starts in the railway corridor", function()
		for id in Stations.List do
			expect(Journey.biomeFor(id) ~= nil).toBe(true)
		end
		expect(Journey.biomeFor("Halt")).toBe("Farmland")
		expect(Journey.biomeFor("Terminus")).toBe("Coast")
		expect(Journey.biomeFor(nil)).toBe("Corridor")
	end)

	it("blends into the next biome and keeps it afterwards", function()
		local transitions = {
			{ at = 1000, length = 600, biome = "Farmland" },
			{ at = 5000, length = 600, biome = "Mountain" },
		}
		local a, b, w = Journey.sample("Corridor", transitions, 500)
		expect(a).toBe("Corridor")
		expect(b).toBe("Corridor")
		expect(w).toBe(0)
		a, b, w = Journey.sample("Corridor", transitions, 1300)
		expect(a).toBe("Corridor")
		expect(b).toBe("Farmland")
		expect(w).toBeCloseTo(0.5, 1e-6)
		a, b = Journey.sample("Corridor", transitions, 3000)
		expect(a).toBe("Farmland")
		expect(b).toBe("Farmland")
		a, b = Journey.sample("Corridor", transitions, 9000)
		expect(a).toBe("Mountain")
		expect(b).toBe("Mountain")
	end)

	it("starts the blend at 35% of the leg but never inside what is built", function()
		expect(Journey.blendStart(0, 6000, 0)).toBeCloseTo(2100, 1e-6)
		expect(Journey.blendStart(0, 6000, 2500)).toBe(2500)
	end)
end)

describe("Journey set pieces", function()
	it("is deterministic per seed and leg", function()
		local a = Journey.legPlan(1234, 3, 10000, false)
		local b = Journey.legPlan(1234, 3, 10000, false)
		expect(#a).toBe(#b)
		for i, piece in a do
			expect(piece.kind).toBe(b[i].kind)
			expect(piece.at).toBe(b[i].at)
		end
	end)

	it("spaces pieces at least the minimum gap apart, past the near window", function()
		for leg = 1, 11 do
			local pieces = Journey.legPlan(987, leg, 5000, false)
			expect(#pieces).toBeGreaterThan(2)
			expect(pieces[1].at).toBeAtLeast(5000 + J.PieceStart)
			for i = 2, #pieces do
				local gap = pieces[i].at - (pieces[i - 1].at + pieces[i - 1].length)
				expect(gap).toBeAtLeast(J.PieceGap[1])
				expect(pieces[i].kind ~= pieces[i - 1].kind).toBe(true)
			end
		end
	end)

	it("opens every leg with a tunnel, gorge or burning town", function()
		local seen = {}
		for leg = 1, 6 do
			local first = Journey.legPlan(42, leg, 0, false)[1]
			seen[first.kind] = true
			expect(first.kind == "Tunnel" or first.kind == "Gorge" or first.kind == "BurningTown").toBe(true)
		end
		expect(seen.Tunnel and seen.Gorge and seen.BurningTown).toBe(true)
	end)

	it("keeps the final leg's pieces inland and without a lake", function()
		for seed = 1, 20 do
			for _, piece in Journey.legPlan(seed, 11, 0, true) do
				expect(piece.kind ~= "Lake").toBe(true)
				expect(piece.side <= 0).toBe(true)
			end
		end
	end)

	it("trims pieces that would come near the dock", function()
		local pieces = Journey.legPlan(77, 2, 0, false)
		local sink = Journey.sinkhole(5000, 300, 180, "CoalYard", false)
		local kept = Journey.trim(pieces, sink)
		expect(#kept).toBeLessThan(#pieces)
		for _, piece in kept do
			expect(piece.at + piece.length).toBeAtMost(sink.rect.x0 - J.DockClearance)
		end
	end)

	it("reserves footprints on the right side and cuts gorges out of the ground", function()
		local piece = {
			kind = "Lake",
			leg = 1,
			index = 1,
			at = 100,
			length = 300,
			side = -1,
			style = 1,
			seed = 1,
		}
		local rect = Journey.footprint(piece)
		expect(rect.z1).toBeAtMost(0)
		expect(rect.x0).toBeLessThan(100)
		expect(Journey.groundCut(piece)).toBe(nil)
		piece.kind = "Gorge"
		piece.side = 0
		local cut = Journey.groundCut(piece)
		expect(cut and cut.x0).toBe(100)
		expect(cut and cut.z1).toBe(J.GorgeHalfWidth)
		piece.kind = "Tunnel"
		local entry, exit = Journey.tunnelPortals(piece)
		expect(entry).toBe(100 + J.TunnelCutting)
		expect(exit).toBe(400 - J.TunnelCutting)
	end)
end)

describe("Journey stations", function()
	it("predicts the dock from the cruise clock", function()
		local dock = Journey.dockFromCruise(1000, 20)
		expect(dock).toBeCloseTo(1000 + Tuning.Motion.CruiseSpeed * 20 + Motion.arrivalDistance(), 1e-6)
		expect(Journey.dockFromCruise(1000, -3)).toBeCloseTo(1000 + Motion.arrivalDistance(), 1e-6)
		-- still spinning up: 70 -> 110 at SpinUp, then cruise for the rest
		local a = Tuning.Motion.SpinUp
		local spin = (110 - 70) / a
		local expected = 1000 + (110 * 110 - 70 * 70) / (2 * a) + 110 * (20 - spin) + Motion.arrivalDistance()
		expect(Journey.dockFromCruise(1000, 20, 70)).toBeCloseTo(expected, 1e-6)
	end)

	it("opens the sinkhole on the platform side around the station", function()
		local arch = Stations.List.Minehead
		local sink = Journey.sinkhole(8000, arch.length, arch.depth, arch.id, false)
		expect(sink.rect.x0).toBe(8000 - arch.length / 2 - J.SinkholeMarginX)
		expect(sink.rect.x1).toBe(8000 + arch.length / 2 + J.SinkholeMarginX)
		expect(sink.rect.z0).toBe(Tuning.World.PlatformEdgeZ)
		expect(sink.rect.z1).toBe(Tuning.World.PlatformEdgeZ + arch.depth + J.SinkholeMarginZ)
	end)
end)

describe("Journey geometry", function()
	it("subtracts cuts without losing or doubling area", function()
		local ground = { x0 = 0, x1 = 120, z0 = 18, z1 = 420 }
		local cut = { x0 = 40, x1 = 400, z0 = 7, z1 = 250 }
		local pieces = Journey.subtract(ground, { cut })
		expect(area(pieces)).toBeCloseTo(120 * 402 - 80 * 232, 1e-6)
		for _, piece in pieces do
			expect(Journey.overlaps(piece, cut)).toBe(false)
		end
		expect(#Journey.subtract(ground, { { x0 = 500, x1 = 600, z0 = 0, z1 = 10 } })).toBe(1)
		expect(#Journey.subtract(ground, { { x0 = -1, x1 = 200, z0 = 0, z1 = 500 } })).toBe(0)
	end)

	it("paints spans along the track", function()
		local spans = { { a = 0, b = 48, kind = "Land" } }
		spans = Journey.split(spans, 10, 20, "Gorge")
		spans = Journey.split(spans, 30, 100, "Sink")
		local kinds = {}
		for _, span in spans do
			table.insert(kinds, `{span.kind}:{span.a}-{span.b}`)
		end
		expect(table.concat(kinds, ",")).toBe("Land:0-10,Gorge:10-20,Land:20-30,Sink:30-48")
	end)
end)

describe("Journey sky", function()
	it("runs from dusk at the lobby through the night to sunrise at the Terminus", function()
		local stops = Tuning.Run.StationCount
		expect(Journey.hour(0, stops)).toBeCloseTo(18.3, 1e-6)
		expect(Journey.hour(1, stops)).toBeCloseTo(18.9, 1e-6)
		expect(Journey.hour(2, stops)).toBeCloseTo(19.6, 1e-6)
		expect(Journey.clock(Journey.hour(stops, stops))).toBeCloseTo(4.9, 1e-6)
		expect(Journey.clock(Journey.hour(stops + 1, stops))).toBeCloseTo(6.5, 1e-6)
		local last = -1
		for p = 0, stops + 1, 0.25 do
			local hour = Journey.hour(p, stops)
			expect(hour).toBeAtLeast(last)
			last = hour
		end
		local midnight = Journey.clock(Journey.hour((stops + 1) * 0.55, stops))
		expect(midnight < 4 or midnight > 22).toBe(true)
	end)

	it("measures progress by legs travelled", function()
		expect(Journey.progress(1, 0)).toBe(0)
		expect(Journey.progress(1, 1)).toBe(1)
		expect(Journey.progress(2, 0)).toBe(1)
		expect(Journey.legShare(1500, 1000, 2000)).toBeCloseTo(0.5, 1e-6)
		expect(Journey.legShare(99999, 0, nil)).toBe(J.UnknownShareCap)
		expect(Journey.legShare(500, 500, 500)).toBe(1)
	end)

	it("lets the night run on while the train stands at a stop", function()
		local stop = J.StopHours
		-- docked at the first stop the doors have just opened: most of the leg's night has passed
		expect(Journey.skyProgress(1, 1, 0)).toBeCloseTo(1 - stop, 1e-9)
		-- the doors closing finish it, and the next leg starts exactly there
		expect(Journey.skyProgress(1, 1, 1)).toBeCloseTo(1, 1e-9)
		expect(Journey.skyProgress(2, 0, 0)).toBeCloseTo(1, 1e-9)
		-- halfway through a stop the clock has moved on from the arrival
		expect(Journey.skyProgress(3, 1, 0.5)).toBeGreaterThan(Journey.skyProgress(3, 1, 0))
		expect(Journey.skyProgress(0, 0, 0)).toBe(0)
	end)
end)
