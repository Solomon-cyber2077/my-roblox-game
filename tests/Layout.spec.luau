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

	it("finds the slab under a point", function()
		local plan = LayoutGen.generate("Halt", 3, 1)
		expect(LayoutGen.slabAt(plan, 0, 5).kind).toBe("Safe")
		local container = plan.containers[1]
		local slab = LayoutGen.slabAt(plan, container.x, container.z)
		expect(slab ~= nil).toBe(true)
		expect(LayoutGen.slabAt(plan, 0, plan.depth + 5)).toBe(nil)
	end)
end)
