local LayoutGen = require(Shared.Logic.LayoutGen)
local Stations = require(Shared.Config.Stations)

local ALL = table.clone(Stations.Order)
table.insert(ALL, "Terminus")

local function covers(plan)
	local hits = {}
	for _, slab in plan.slabs do
		for gx = slab.gx, slab.gx + slab.w - 1 do
			for gz = slab.gz, slab.gz + slab.d - 1 do
				local key = gz * plan.cols + gx
				if hits[key] then
					return false
				end
				hits[key] = true
			end
		end
	end
	for gz = 0, plan.rows - 1 do
		for gx = 0, plan.cols - 1 do
			if not hits[gz * plan.cols + gx] then
				return false
			end
		end
	end
	return true
end

describe("LayoutGen", function()
	it("is deterministic for a seed", function()
		local a = LayoutGen.generate("Market", 77, 1.2)
		local b = LayoutGen.generate("Market", 77, 1.2)
		expect(#a.slabs).toBe(#b.slabs)
		expect(#a.containers).toBe(#b.containers)
		for i, c in a.containers do
			expect(c.x).toBe(b.containers[i].x)
			expect(c.kind).toBe(b.containers[i].kind)
		end
	end)

	it("covers every tile with exactly one slab", function()
		for _, id in ALL do
			for seed = 1, 6 do
				expect(covers(LayoutGen.generate(id, seed * 101, 1))).toBe(true)
			end
		end
	end)

	it("keeps the safe strip free of buildings, containers and pickups", function()
		for _, id in ALL do
			for seed = 1, 6 do
				local plan = LayoutGen.generate(id, seed, 1.35)
				for _, s in plan.structures do
					expect(s.gz).toBeAtLeast(plan.safeRows)
				end
				for _, c in plan.containers do
					expect(c.zone ~= "Safe").toBe(true)
					expect(plan.slabs[c.slab].kind ~= "Safe").toBe(true)
				end
				for _, item in plan.loose do
					expect(plan.slabs[item.slab].kind ~= "Safe").toBe(true)
				end
			end
		end
	end)

	it("places vaults only in the far zone", function()
		for _, id in ALL do
			for seed = 1, 6 do
				for _, c in LayoutGen.generate(id, seed, 1).containers do
					if c.kind == "Vault" then
						expect(c.zone).toBe("Far")
					end
				end
			end
		end
	end)

	it("places the configured number of containers, scaled by difficulty", function()
		local plan = LayoutGen.generate("Halt", 9, 1)
		local plan2 = LayoutGen.generate("Halt", 9, 1.35)
		local base = 0
		for _, n in Stations.List.Halt.containers do
			base += n
		end
		local function outdoors(p)
			local count = 0
			for _, c in p.containers do
				if c.building == nil then
					count += 1
				end
			end
			return count
		end
		expect(outdoors(plan)).toBe(base)
		expect(outdoors(plan2)).toBeGreaterThan(outdoors(plan))
	end)

	it("places every landmark the archetype asks for, with searchable rooms", function()
		for _, id in ALL do
			local wanted = #(Stations.List[id].landmarks or {})
			local placed = 0
			for seed = 1, 10 do
				local plan = LayoutGen.generate(id, seed, 1)
				placed += #plan.buildings
				for _, building in plan.buildings do
					local slab = plan.slabs[building.slab]
					expect(slab.kind).toBe("Foundation")
					expect(slab.building).toBe(building.id)
				end
				for _, c in plan.containers do
					if c.building then
						expect(plan.slabs[c.slab].building).toBe(c.building)
					end
				end
			end
			expect(placed / 10).toBeAtLeast(wanted * 0.9)
		end
	end)

	it("places every structure the archetype asks for on typical seeds", function()
		for _, id in ALL do
			local wanted = 0
			for _, rule in Stations.List[id].structures do
				wanted += rule.count
			end
			local placed = 0
			for seed = 1, 10 do
				placed += #LayoutGen.generate(id, seed, 1).structures
			end
			expect(placed / 10).toBeAtLeast(wanted * 0.85)
		end
	end)

	it("fences every open edge tile and rails off both ends of the platform", function()
		for _, id in ALL do
			local arch = Stations.List[id]
			for seed = 1, 4 do
				local plan = LayoutGen.generate(id, seed * 31, 1)
				local filled = {}
				for _, block in plan.structures do
					for gx = block.gx, block.gx + block.w - 1 do
						for gz = block.gz, block.gz + block.d - 1 do
							filled[gz * plan.cols + gx] = true
						end
					end
				end
				for _, block in plan.buildings do
					for gx = block.gx, block.gx + block.w - 1 do
						for gz = block.gz, block.gz + block.d - 1 do
							filled[gz * plan.cols + gx] = true
						end
					end
				end
				local fences = {}
				local ends = 0
				for _, prop in plan.props do
					if prop.kind == arch.edge.fence then
						local gx = math.floor((prop.x + plan.length / 2) / plan.tile)
						local gz = math.floor(prop.z / plan.tile)
						fences[gz * plan.cols + math.clamp(gx, 0, plan.cols - 1)] = true
					elseif prop.kind == "PlatformEnd" then
						ends += 1
						expect(plan.slabs[prop.slab].kind).toBe("Safe")
					end
				end
				expect(ends).toBe(2)
				local rows, cols = plan.rows, plan.cols
				for gx = 0, cols - 1 do
					local key = (rows - 1) * cols + gx
					expect(filled[key] or fences[key]).toBe(true)
				end
				for gz = plan.safeRows, rows - 1 do
					for _, gx in { 0, cols - 1 } do
						local key = gz * cols + gx
						expect(filled[key] or fences[key]).toBe(true)
					end
				end
			end
		end
	end)

	it("keeps the platform's clutter clear of its benches, signs and canopy columns", function()
		local reach = {
			Bench = 2.8,
			Sign = 7.4,
			Lamp = 1,
			Trolley = 3.2,
			Churns = 2.4,
			FireBuckets = 2.2,
			Timetable = 2.4,
			Planter = 2,
		}
		for _, id in ALL do
			local plan = LayoutGen.generate(id, 5, 1)
			local spots = {}
			for _, prop in plan.props do
				if prop.slab == 1 and reach[prop.kind] then
					table.insert(spots, prop)
				end
			end
			local canopy = 0
			for _, prop in plan.props do
				if prop.kind == "Canopy" then
					canopy = (prop.size or 0) / 2
				end
			end
			for i, a in spots do
				for j = i + 1, #spots do
					local b = spots[j]
					local apart = math.abs(a.x - b.x) >= reach[a.kind] + reach[b.kind] - 1e-6
						or math.abs(a.z - b.z) >= 1.6
					expect(apart).toBe(true)
				end
				for _, x in Stations.canopyColumns(canopy) do
					local clear = math.abs(a.x - x) >= reach[a.kind] + 1.2 - 1e-6
						or math.abs(a.z - Stations.CanopyColumnZ) >= 2
					expect(clear).toBe(true)
				end
			end
		end
	end)

	it("dresses the yard away from the edge and from the containers", function()
		for _, id in ALL do
			local arch = Stations.List[id]
			local dressing = {}
			for _, kind in arch.dressing do
				dressing[kind] = true
			end
			for seed = 1, 4 do
				local plan = LayoutGen.generate(id, seed * 17, 1)
				local count = 0
				for _, prop in plan.props do
					if dressing[prop.kind] then
						count += 1
						expect(math.abs(prop.x)).toBeLessThan(plan.length / 2 - plan.tile + 2.5)
						expect(prop.z).toBeLessThan(plan.depth - plan.tile + 2.5)
						expect(prop.z).toBeGreaterThan(plan.safeRows * plan.tile - 2.5)
						for _, container in plan.containers do
							local d = math.sqrt((prop.x - container.x) ^ 2 + (prop.z - container.z) ^ 2)
							expect(d).toBeGreaterThan(2)
						end
					end
				end
				if not arch.terminus then
					expect(count).toBeGreaterThan(2)
				end
			end
		end
	end)

	it("finds the slab under a point", function()
		local plan = LayoutGen.generate("Halt", 3, 1)
		expect(LayoutGen.slabAt(plan, 0, 5).kind).toBe("Safe")
		local container = plan.containers[1]
		local slab = LayoutGen.slabAt(plan, container.x, container.z)
		expect(slab ~= nil).toBe(true)
		expect(LayoutGen.slabAt(plan, 0, plan.depth + 5)).toBe(nil)
	end)
end)
