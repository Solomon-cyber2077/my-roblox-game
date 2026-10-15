local LayoutGen = require(Shared.Logic.LayoutGen)
local Stations = require(Shared.Config.Stations)

local function laidOut(): { string }
	local ids = {}
	for _, id in Stations.Order do
		if Stations.List[id].layout then
			table.insert(ids, id)
		end
	end
	return ids
end

local function key(plan, gx: number, gz: number): number
	return gz * plan.cols + gx
end

local function tileOf(plan, x: number, z: number): (number, number)
	return math.clamp(math.floor((x + plan.length / 2) / plan.tile), 0, plan.cols - 1),
		math.floor(z / plan.tile)
end

-- Every tile something stands on or in, keyed gz * cols + gx.
local function features(plan): { [number]: boolean }
	local out = {}
	for _, list in { plan.structures, plan.buildings } do
		for _, block in list do
			for gx = block.gx, block.gx + block.w - 1 do
				for gz = block.gz, block.gz + block.d - 1 do
					out[key(plan, gx, gz)] = true
				end
			end
		end
	end
	for _, list in { plan.props, plan.containers, plan.loose } do
		for _, thing in list do
			if thing.slab ~= 1 then
				local gx, gz = tileOf(plan, thing.x, thing.z)
				out[key(plan, gx, gz)] = true
			end
		end
	end
	return out
end

describe("Station layouts", function()
	it("gives every stop but the Terminus a layout", function()
		for _, id in Stations.Order do
			expect(Stations.List[id].layout ~= nil).toBe(true)
		end
		expect(Stations.List.Terminus.layout).toBe(nil)
	end)

	it("lays out the same props for a seed", function()
		for _, id in laidOut() do
			local a = LayoutGen.generate(id, 913, 1)
			local b = LayoutGen.generate(id, 913, 1)
			expect(#a.props).toBe(#b.props)
			for i, prop in a.props do
				expect(prop.kind).toBe(b.props[i].kind)
				expect(prop.x).toBe(b.props[i].x)
				expect(prop.z).toBe(b.props[i].z)
			end
		end
	end)

	it("stands cover in a rhythm a Hollow can always walk round", function()
		for _, id in laidOut() do
			local arch = Stations.List[id]
			local kinds = {}
			for _, list in { arch.layout.cover, arch.layout.sights or {} } do
				for _, kind in list do
					kinds[kind] = true
				end
			end
			for seed = 1, 6 do
				local plan = LayoutGen.generate(id, seed * 37, 1)
				local solid = {}
				for _, list in { plan.structures, plan.buildings } do
					for _, block in list do
						for gx = block.gx, block.gx + block.w - 1 do
							for gz = block.gz, block.gz + block.d - 1 do
								solid[key(plan, gx, gz)] = true
							end
						end
					end
				end
				local cover = {}
				local count = 0
				for _, prop in plan.props do
					if kinds[prop.kind] and prop.slab ~= 1 then
						local gx, gz = tileOf(plan, prop.x, prop.z)
						if gz > plan.safeRows then
							count += 1
							cover[key(plan, gx, gz)] = { gx, gz }
							-- open ground on all four sides
							for _, dir in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
								expect(solid[key(plan, gx + dir[1], gz + dir[2])] == nil).toBe(true)
							end
						end
					end
				end
				expect(count).toBeAtLeast(8)
				for k, cell in cover do
					for dx = -1, 1 do
						for dz = -1, 1 do
							local other = key(plan, cell[1] + dx, cell[2] + dz)
							expect(other == k or cover[other] == nil).toBe(true)
						end
					end
				end
				-- cover never closes a tile: nothing but structures is blocked
				local blockedCount = 0
				for _ in plan.blocked do
					blockedCount += 1
				end
				local structureTiles = 0
				for _, block in plan.structures do
					structureTiles += block.w * block.d
				end
				expect(blockedCount).toBe(structureTiles)
			end
		end
	end)

	it("leaves no long empty stretch to cross", function()
		for _, id in laidOut() do
			for seed = 1, 4 do
				local plan = LayoutGen.generate(id, seed * 53, 1)
				local near = features(plan)
				for gz = plan.safeRows + 1, plan.rows - 2 do
					for gx = 1, plan.cols - 2 do
						local found = false
						for dx = -3, 3 do
							for dz = -3, 3 do
								found = found or near[key(plan, gx + dx, gz + dz)] == true
							end
						end
						if not found then
							error(`{id} seed {seed * 53}: nothing within 3 tiles of {gx},{gz}`)
						end
					end
				end
			end
		end
	end)

	it("lays loot out by depth: coal by the platform, the best at the back", function()
		local depth = { CoalBin = {}, Crate = {}, ToolChest = {}, Vault = {} }
		local mid, ground = 0, 0
		for _, id in laidOut() do
			for seed = 1, 6 do
				local plan = LayoutGen.generate(id, seed * 17, 1)
				for _, c in plan.containers do
					if c.building == nil and c.zone ~= "Village" then
						ground += 1
						if c.zone == "Mid" then
							mid += 1
						end
						if depth[c.kind] then
							table.insert(depth[c.kind], c.z / plan.depth)
						end
						if c.kind == "CoalBin" then
							expect(c.zone).toBe("Near")
						end
					end
				end
				for _, item in plan.loose do
					if item.item == "CoalLump" then
						expect(LayoutGen.zoneFor(item.z, plan.depth, plan.safeRows * plan.tile, nil) ~= "Far").toBe(
							true
						)
					end
				end
			end
		end
		local function mean(list: { number }): number
			local total = 0
			for _, v in list do
				total += v
			end
			return total / math.max(1, #list)
		end
		expect(mid / ground).toBeLessThan(0.1)
		expect(mean(depth.CoalBin)).toBeLessThan(mean(depth.Crate))
		expect(mean(depth.Crate)).toBeLessThan(mean(depth.ToolChest) + 0.02)
		expect(mean(depth.ToolChest)).toBeLessThan(mean(depth.Vault) + 0.02)
	end)

	it("keeps the very back clear for the payroll crate", function()
		for _, id in Stations.Order do
			for seed = 1, 4 do
				local plan = LayoutGen.generate(id, seed * 29, 1)
				local spot = plan.payroll
				expect(spot ~= nil).toBe(true)
				local gx, gz = tileOf(plan, spot.x, spot.z)
				expect(gz).toBe(plan.rows - 2)
				local taken = features(plan)
				for dx = -Stations.Payroll.HalfTiles, Stations.Payroll.HalfTiles do
					expect(taken[key(plan, gx + dx, gz)] == nil).toBe(true)
				end
			end
		end
		expect(LayoutGen.generate("Terminus", 1, 1).payroll).toBe(nil)
	end)

	it("lays sidings across a coal yard", function()
		for seed = 1, 6 do
			local tracks = 0
			for _, prop in LayoutGen.generate("CoalYard", seed, 1).props do
				if prop.kind == "Siding" then
					tracks += 1
				end
			end
			expect(tracks).toBeAtLeast(20)
		end
	end)

	it("stands the market fountain in an open square ringed by stalls", function()
		for seed = 1, 6 do
			local plan = LayoutGen.generate("Market", seed, 1)
			local fountain, stalls = nil, {}
			for _, s in plan.structures do
				if s.kind == "Fountain" then
					fountain = s
				elseif s.kind == "Stall" then
					table.insert(stalls, s)
				end
			end
			expect(fountain ~= nil).toBe(true)
			local close = 0
			for _, stall in stalls do
				-- the square round the fountain stays open
				local dx = math.abs(stall.x - fountain.x)
				local dz = math.abs(stall.z - fountain.z)
				expect(dx > 1.5 * plan.tile or dz > 1.5 * plan.tile).toBe(true)
				if dx <= 6 * plan.tile and dz <= 5 * plan.tile then
					close += 1
				end
			end
			expect(close).toBeAtLeast(3)
		end
	end)

	it("keeps the better containers deeper in", function()
		local far, near = 0, 0
		for seed = 1, 20 do
			for _, c in LayoutGen.generate("SignalWorks", seed, 1).containers do
				if c.kind == "ToolChest" and c.building == nil then
					if c.zone == "Far" then
						far += 1
					elseif c.zone == "Near" then
						near += 1
					end
				end
			end
		end
		expect(far).toBeGreaterThan(near)
	end)

	it("breaks the ground up beside the routes", function()
		for _, id in laidOut() do
			local arch = Stations.List[id]
			local kinds = {}
			for _, kind in arch.layout.ground do
				kinds[kind] = true
			end
			for seed = 1, 4 do
				local plan = LayoutGen.generate(id, seed * 11, 1)
				local count = 0
				for _, prop in plan.props do
					if kinds[prop.kind] and prop.z ~= (math.floor(prop.z / plan.tile) + 0.5) * plan.tile then
						count += 1
						expect(math.abs(prop.x)).toBeLessThan(plan.length / 2 - plan.tile + 1)
						expect(prop.z).toBeLessThan(plan.depth - plan.tile + 1)
					end
				end
				expect(count).toBeAtLeast(arch.layout.groundCount - 1)
			end
		end
	end)
end)
