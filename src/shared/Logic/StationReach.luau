--!strict
--[[
	How far the loot is from the train, on foot. Pure: a breadth-first walk over a
	station plan's tiles (Logic/LayoutGen), four ways, round structures and barriers
	(plan.blocked). Enterable buildings are walked through: their doors let you in.

	It starts from the platform tiles in front of the train (|x| within Stations.Reach
	DoorHalfSpan), so a distance is studs from the nearest door to the tile's centre.
	The stop's clock (Logic/DifficultyModel) is checked against these distances in
	tests/StationReach.spec: the farthest loot and back, at a jog, must fit with margin.
]]

local Shared = script.Parent.Parent
local Stations = require(Shared.Config.Stations)

local StationReach = {}

export type Reach = {
	dist: { [number]: number }, -- studs from the train, keyed gz * cols + gx; missing = unreachable
	farthestLoot: number, -- studs to the farthest container or loose pickup
	unreachable: number, -- containers and pickups no walk reaches
	walkable: number, -- tiles you can stand on (outside the safe strip)
	area: number, -- walkable studs², safe strip included
}

local DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- The tile under a station-local point.
function StationReach.tileOf(plan: any, x: number, z: number): (number, number)
	local gx = math.clamp(math.floor((x + plan.length / 2) / plan.tile), 0, plan.cols - 1)
	local gz = math.clamp(math.floor(z / plan.tile), 0, plan.rows - 1)
	return gx, gz
end

function StationReach.measure(plan: any): Reach
	local cols, rows, tile = plan.cols, plan.rows, plan.tile
	local blocked: { [number]: boolean } = plan.blocked
	local dist: { [number]: number } = {}
	local queue: { number } = {}
	local half = Stations.Reach.DoorHalfSpan
	for gx = 0, cols - 1 do
		local x = -plan.length / 2 + (gx + 0.5) * tile
		if math.abs(x) <= half and not blocked[gx] then
			dist[gx] = tile / 2
			table.insert(queue, gx)
		end
	end
	local head = 1
	while head <= #queue do
		local key = queue[head]
		head += 1
		local gx, gz = key % cols, key // cols
		for _, dir in DIRECTIONS do
			local nx, nz = gx + dir[1], gz + dir[2]
			if nx >= 0 and nx < cols and nz >= 0 and nz < rows then
				local n = nz * cols + nx
				if not blocked[n] and dist[n] == nil then
					dist[n] = dist[key] + tile
					table.insert(queue, n)
				end
			end
		end
	end

	local farthest, unreachable = 0, 0
	local function spot(x: number, z: number)
		local gx, gz = StationReach.tileOf(plan, x, z)
		local d = dist[gz * cols + gx]
		if d == nil then
			-- a pickup can sit at the very edge of a blocked tile: try its open neighbours
			for _, dir in DIRECTIONS do
				local nx, nz = gx + dir[1], gz + dir[2]
				local n = nz * cols + nx
				if nx >= 0 and nx < cols and nz >= 0 and nz < rows and dist[n] then
					d = math.min(d or math.huge, dist[n] + tile)
				end
			end
		end
		if d == nil then
			unreachable += 1
		else
			farthest = math.max(farthest, d)
		end
	end
	for _, container in plan.containers do
		spot(container.x, container.z)
	end
	for _, item in plan.loose do
		spot(item.x, item.z)
	end

	local walkable = 0
	for gz = plan.safeRows, rows - 1 do
		for gx = 0, cols - 1 do
			if not blocked[gz * cols + gx] then
				walkable += 1
			end
		end
	end
	return {
		dist = dist,
		farthestLoot = farthest,
		unreachable = unreachable,
		walkable = walkable,
		area = (walkable + plan.safeRows * cols) * tile * tile,
	}
end

--[[
	Seconds to walk `studs` out and back. `speed` studs/s. With `sprint`, the crew sprints
	while the breath lasts and jogs while it comes back (Tuning.Crew), which is the best
	sustained pace the stamina bar allows.
]]
function StationReach.roundTrip(studs: number, crew: any, sprint: boolean): number
	if not sprint then
		return 2 * studs / crew.WalkSpeed
	end
	local burst = crew.StaminaMax / crew.StaminaDrainPerSecond -- seconds of sprint from full
	local recover = crew.StaminaRegenDelay + crew.StaminaMax / crew.StaminaRegenPerSecond
	local pace = (burst * crew.SprintSpeed + recover * crew.WalkSpeed) / (burst + recover)
	local total = 2 * studs
	-- the first burst starts from a full bar
	local first = burst * crew.SprintSpeed
	if total <= first then
		return total / crew.SprintSpeed
	end
	return burst + (total - first) / pace
end

return table.freeze(StationReach)
