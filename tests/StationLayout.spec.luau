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

-- Barrier pieces stand on a tile's centre line, square to the track (the boundary fence does not).
local function barrierTiles(plan, arch): { [number]: boolean }
	local kinds = {}
	for _, kind in arch.layout.barriers do
		kinds[kind] = true
	end
	local out = {}
	for _, prop in plan.props do
		local gz = math.floor(prop.z / plan.tile)
		if kinds[prop.kind] and prop.rot == 0 and prop.slab ~= 1 and prop.z == (gz + 0.5) * plan.tile then
			local gx = math.clamp(math.floor((prop.x + plan.length / 2) / plan.tile), 0, plan.cols - 1)
			out[key(plan, gx, gz)] = true
		end
	end
	return out
end

local function blocked(plan, arch): { [number]: boolean }
	local out = barrierTiles(plan, arch)
	for _, list in { plan.structures, plan.buildings } do
		for _, block in list do
			for gx = block.gx, block.gx + block.w - 1 do
				for gz = block.gz, block.gz + block.d - 1 do
					out[key(plan, gx, gz)] = true
				end
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

	it("pinches the zone boundaries into chokepoints that still reach the far edge", function()
		for _, id in laidOut() do
			local arch = Stations.List[id]
			for seed = 1, 6 do
				local plan = LayoutGen.generate(id, seed * 37, 1)
				local walls = barrierTiles(plan, arch)
				local count = 0
				for _ in walls do
					count += 1
				end
				expect(count).toBeAtLeast(3)

				-- every open tile is reachable from the platform, and so is the far edge
				local shut = blocked(plan, arch)
				local seen, queue = {}, {}
				for gx = 0, plan.cols - 1 do
					seen[key(plan, gx, 0)] = true
					table.insert(queue, { gx, 0 })
				end
				local head = 1
				while head <= #queue do
					local cell = queue[head]
					head += 1
					for _, dir in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						local nx, nz = cell[1] + dir[1], cell[2] + dir[2]
						local k = key(plan, nx, nz)
						if
							nx >= 0
							and nx < plan.cols
							and nz >= 0
							and nz < plan.rows
							and not seen[k]
							and not shut[k]
						then
							seen[k] = true
							table.insert(queue, { nx, nz })
						end
					end
				end
				local far = false
				for gz = 0, plan.rows - 1 do
					for gx = 0, plan.cols - 1 do
						local k = key(plan, gx, gz)
						if not shut[k] then
							expect(seen[k] == true).toBe(true)
							far = far or gz == plan.rows - 1
						end
					end
				end
				expect(far).toBe(true)
			end
		end
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
