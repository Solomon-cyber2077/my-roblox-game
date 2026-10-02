--!strict
--[[
	Hollows: what claws up out of the ground at the fog front, climbs over a station's
	edge from the dark beneath it, or sits slumped in an abandoned building waiting for
	someone to come close. One think loop drives them all at ThinkHz. They cannot be
	killed, only outrun, stunned or kept out with light: they never enter the lit band
	beside the train, nor a building whose power is back on.

	States (mirrored to the model's State and StateAt attributes; HollowAnimator plays them)
	  Emerge    rising, climbing or waking (attribute Emerge): no moving, no striking yet
	  Dormant   a sleeper in a building, until crew come close or the dwell runs on
	  Prowl     no target: drift between the light and the fog
	  Hunt      chase the nearest crew member it senses, pathing around walls, lunging close
	  Windup    the tell: it rears back, and strikes at the end if the target is still in reach
	  Recover   after a strike
	  Repelled  the target stands in light: hold at its edge
	  Stunned   frozen by a Flashbulb

	Hollows never collide with crew (WorldService), so a chase can't end with one
	standing on someone's head; they stop StopShort studs from their target instead.
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local LayoutGen = require(Shared.Logic.LayoutGen)
local MathX = require(Shared.Util.MathX)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local HollowBuilder = require(script.Parent.Parent.Builders.HollowBuilder)
local Registry = require(script.Parent.Parent.Registry)
local NetService = require(script.Parent.NetService)
local StationService = require(script.Parent.StationService)

type KindDef = { speed: number, damage: number, reach: number, windup: number, knockback: number }

type Hollow = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	kind: string,
	def: KindDef,
	state: string,
	stateAt: number, -- os.clock() when the state began
	target: Player?,
	lastSeen: Vector3?,
	lastSeenAt: number,
	lastStrike: number,
	stunnedUntil: number,
	wanderUntil: number,
	lastPosition: Vector3,
	stuckSince: number,
	lungeUntil: number,
	lastLunge: number,
	path: { Vector3 }?,
	pathIndex: number,
	pathAt: number,
	pathing: boolean,
	sleeper: boolean,
	stirAt: number, -- seconds into the dwell when a sleeper wakes by itself
	checkAt: number,
}

local H = Tuning.Hollow

local HollowService = {}

local hollows: { Hollow } = {}
local params: Types.HazardParams? = nil
local folder: Folder
local rng = Random.new()
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
local AGENT = {
	AgentRadius = 2.2,
	AgentHeight = 7,
	AgentCanJump = false,
	AgentCanClimb = false,
	WaypointSpacing = 6,
}

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function refreshSightFilter()
	local filter: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	sightParams.FilterDescendantsInstances = filter
end

-- True when nothing solid stands between the two points (walls, doors, crates).
local function clearBetween(from: Vector3, to: Vector3): boolean
	local origin = from + Vector3.new(0, 1.5, 0)
	return Workspace:Raycast(origin, (to + Vector3.new(0, 1, 0)) - origin, sightParams) == nil
end

local function setState(hollow: Hollow, state: string)
	if hollow.state == state then
		return
	end
	hollow.state = state
	hollow.stateAt = os.clock()
	hollow.model:SetAttribute("State", state)
	hollow.model:SetAttribute("StateAt", serverNow())
end

local function safeEdge(): number
	local p = params :: Types.HazardParams
	return p.safeBand + H.SafeMargin
end

local function isLit(position: Vector3): boolean
	local buildings = Registry.BuildingService
	return buildings ~= nil and buildings.IsLitAt(position)
end

local function speeds(hollow: Hollow): (number, number)
	local p = params :: Types.HazardParams
	return p.hollowWalk * hollow.def.speed, p.hollowChase * hollow.def.speed
end

local function wanderPoint(): Vector3?
	local plan = StationService.Plan()
	local info = StationService.Info()
	if plan == nil or info == nil then
		return nil
	end
	local p = params :: Types.HazardParams
	local geo = { depth = plan.depth, safe = Tuning.World.SafeStrip }
	local fog = HazardSchedule.fogFront(p, geo, serverNow() - info.startedAt)
	local nearZ = safeEdge() + 8
	local farZ = math.max(nearZ + 6, math.min(plan.depth - 4, fog + 12))
	local x = rng:NextNumber(-plan.length / 2 + 10, plan.length / 2 - 10)
	local z = rng:NextNumber(nearZ, farZ)
	return StationService.ToWorld(x, 3, z)
end

-- Walks toward `goal`: straight when the way is clear, otherwise along a computed path.
local function moveToward(hollow: Hollow, goal: Vector3, direct: boolean)
	if direct then
		hollow.path = nil
		hollow.humanoid:MoveTo(goal)
		return
	end
	local clock = os.clock()
	if not hollow.pathing and (hollow.path == nil or clock - hollow.pathAt > H.PathEvery) then
		hollow.pathing = true
		hollow.pathAt = clock
		local start = hollow.root.Position
		task.spawn(function()
			local path = PathfindingService:CreatePath(AGENT)
			local ok = pcall(function()
				path:ComputeAsync(start, goal)
			end)
			hollow.pathing = false
			if ok and path.Status == Enum.PathStatus.Success then
				local points: { Vector3 } = {}
				for _, waypoint in path:GetWaypoints() do
					table.insert(points, waypoint.Position)
				end
				hollow.path = points
				hollow.pathIndex = 2
			else
				hollow.path = nil
			end
		end)
	end
	local points = hollow.path
	if points then
		local position = hollow.root.Position
		local waypoint = points[hollow.pathIndex]
		while waypoint and Vector3.new(waypoint.X - position.X, 0, waypoint.Z - position.Z).Magnitude < 3 do
			hollow.pathIndex += 1
			waypoint = points[hollow.pathIndex]
		end
		if waypoint then
			hollow.humanoid:MoveTo(waypoint)
			return
		end
	end
	hollow.humanoid:MoveTo(goal)
end

-- A point StopShort studs short of the target, so hunters crowd but never climb.
local function shortOf(from: Vector3, to: Vector3): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude <= H.StopShort then
		return from
	end
	return to - flat.Unit * H.StopShort
end

local function resolveStrike(hollow: Hollow)
	local p = params :: Types.HazardParams
	local target = hollow.target
	setState(hollow, "Recover")
	hollow.lastStrike = os.clock()
	if target == nil or not Registry.CrewService.IsAlive(target) or Registry.CrewService.IsAboard(target) then
		return
	end
	local character = target.Character
	local root = characterRoot(target)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local offset = root.Position - hollow.root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > H.HitRange * hollow.def.reach or math.abs(offset.Y) > 8 then
		return
	end
	if flat.Magnitude > 2 and hollow.root.CFrame.LookVector:Dot(flat.Unit) < 0.1 then
		return
	end
	if not clearBetween(hollow.root.Position, root.Position) or Registry.DevService.IsGod(target) then
		return
	end
	local damage = math.floor(p.hollowDamage * hollow.def.damage + 0.5)
	character:SetAttribute("LastDamageSource", "Hollow")
	humanoid:TakeDamage(damage)
	local knockback: Vector3? = nil
	if hollow.def.knockback > 0 and flat.Magnitude > 0.1 then
		knockback = flat.Unit * hollow.def.knockback + Vector3.new(0, hollow.def.knockback * 0.45, 0)
	end
	NetService.Fire(
		"Fx",
		target,
		"Hit",
		{ from = hollow.root.Position, damage = damage, knockback = knockback }
	)
end

local function wake(hollow: Hollow)
	if hollow.state ~= "Dormant" then
		return
	end
	hollow.sleeper = false
	hollow.model:SetAttribute("Emerge", "Wake")
	setState(hollow, "Emerge")
	-- one waking stirs the others nearby
	for _, other in hollows do
		if other.state == "Dormant" and (other.root.Position - hollow.root.Position).Magnitude < 26 then
			local delay = rng:NextNumber(0.4, 1.4)
			task.delay(delay, function()
				if other.model.Parent then
					wake(other)
				end
			end)
		end
	end
end

local function shouldWake(hollow: Hollow): boolean
	local info = StationService.Info()
	if info and serverNow() - info.startedAt >= hollow.stirAt then
		return true
	end
	local position = hollow.root.Position
	for _, player in Registry.CrewService.AlivePlayers() do
		if not Registry.CrewService.IsAboard(player) then
			local root = characterRoot(player)
			if root then
				local distance = (root.Position - position).Magnitude
				if
					distance <= H.WakeRange
					or (distance <= H.WakeSight and clearBetween(position, root.Position))
				then
					return true
				end
			end
		end
	end
	return false
end

local function think(hollow: Hollow)
	local clock = os.clock()
	local position = hollow.root.Position

	if hollow.state == "Dormant" then
		if clock >= hollow.checkAt then
			hollow.checkAt = clock + 0.25
			if shouldWake(hollow) then
				wake(hollow)
			end
		end
		return
	end
	if hollow.state == "Emerge" then
		if clock - hollow.stateAt < H.EmergeSeconds then
			return
		end
		hollow.root.Anchored = false
		pcall(function()
			hollow.root:SetNetworkOwner(nil)
		end)
		setState(hollow, "Prowl")
	end

	local walk, chase = speeds(hollow)
	if clock < hollow.stunnedUntil then
		setState(hollow, "Stunned")
		hollow.humanoid.WalkSpeed = 0
		hollow.humanoid:MoveTo(position)
		return
	end

	-- caught inside a building as its lights come on: cower, then get out
	if isLit(position) then
		if hollow.state ~= "Repelled" then
			setState(hollow, "Repelled")
		end
		if clock - hollow.stateAt < H.LitFlee then
			hollow.humanoid.WalkSpeed = 0
			hollow.humanoid:MoveTo(position)
		else
			hollow.humanoid.WalkSpeed = walk
			local exit = Registry.BuildingService.ExitPoint(position)
			moveToward(hollow, exit or position, false)
		end
		return
	end

	if hollow.state == "Windup" then
		local target = hollow.target
		local root = target and characterRoot(target)
		hollow.humanoid.WalkSpeed = chase * 0.3
		if root then
			hollow.humanoid:MoveTo(shortOf(position, root.Position))
		end
		if clock - hollow.stateAt >= H.WindupSeconds * hollow.def.windup then
			resolveStrike(hollow)
		end
		return
	end
	if hollow.state == "Recover" then
		hollow.humanoid.WalkSpeed = walk * 0.5
		if clock - hollow.stateAt < H.RecoverSeconds then
			return
		end
		setState(hollow, "Hunt")
	end

	-- the nearest crew member it can sense
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	local bestVisible = false
	for _, player in Registry.CrewService.AlivePlayers() do
		if not Registry.CrewService.IsAboard(player) then
			local root = characterRoot(player)
			if root then
				local distance = (root.Position - position).Magnitude
				if distance < H.SightRange and distance < bestDistance then
					local visible = clearBetween(position, root.Position)
					if visible or distance <= H.AwarenessRange then
						best, bestRoot, bestDistance, bestVisible = player, root, distance, visible
					end
				end
			end
		end
	end

	local edge = safeEdge()
	local ownLocal = StationService.ToLocal(position)
	if ownLocal.Z < edge then
		-- pushed into the light somehow: back out first
		hollow.humanoid.WalkSpeed = walk
		hollow.humanoid:MoveTo(StationService.ToWorld(ownLocal.X, 3, edge + 8))
		setState(hollow, "Repelled")
		return
	end

	if best and bestRoot then
		hollow.target = best
		hollow.lastSeen = bestRoot.Position
		hollow.lastSeenAt = clock
		local targetLocal = StationService.ToLocal(bestRoot.Position)
		if targetLocal.Z < edge or isLit(bestRoot.Position) then
			setState(hollow, "Repelled")
			hollow.humanoid.WalkSpeed = walk
			if targetLocal.Z < edge then
				hollow.humanoid:MoveTo(StationService.ToWorld(targetLocal.X, 3, edge + 2))
			else
				hollow.humanoid:MoveTo(position)
			end
			return
		end
		setState(hollow, "Hunt")
		local lunging = clock < hollow.lungeUntil
		if
			not lunging
			and bestVisible
			and bestDistance <= H.LungeRange
			and bestDistance > H.StrikeRange
			and clock - hollow.lastLunge >= H.LungeCooldown
		then
			hollow.lungeUntil = clock + H.LungeSeconds
			hollow.lastLunge = clock
			lunging = true
			hollow.model:SetAttribute("LungeAt", serverNow())
		end
		hollow.humanoid.WalkSpeed = if lunging then chase * H.LungeBoost else chase
		moveToward(hollow, shortOf(position, bestRoot.Position), bestVisible)
		if
			bestDistance <= H.StrikeRange * hollow.def.reach
			and math.abs(bestRoot.Position.Y - position.Y) < 8
			and clock - hollow.lastStrike >= H.StrikeCooldown
		then
			setState(hollow, "Windup")
		end
	elseif hollow.lastSeen and clock - hollow.lastSeenAt < 4 then
		-- lost sight: search where it saw them last
		setState(hollow, "Hunt")
		hollow.humanoid.WalkSpeed = chase * 0.85
		moveToward(hollow, hollow.lastSeen :: Vector3, false)
		if (position - (hollow.lastSeen :: Vector3)).Magnitude < 4 then
			hollow.lastSeen = nil
		end
	else
		setState(hollow, "Prowl")
		hollow.target = nil
		hollow.humanoid.WalkSpeed = walk
		if clock >= hollow.wanderUntil then
			local point = wanderPoint()
			if point then
				moveToward(hollow, point, false)
			end
			hollow.wanderUntil = clock + rng:NextNumber(3, 6)
		end
	end

	-- stuck on a corner: sidestep
	if (position - hollow.lastPosition).Magnitude < 0.4 and hollow.state == "Hunt" then
		if clock - hollow.stuckSince > 1.2 then
			local side = hollow.root.CFrame.RightVector * (if rng:NextNumber() > 0.5 then 8 else -8)
			hollow.humanoid:MoveTo(position + side)
			hollow.path = nil
			hollow.stuckSince = clock
		end
	else
		hollow.stuckSince = clock
	end
	hollow.lastPosition = position
end

local function pickKind(): string
	local p = params :: Types.HazardParams
	local options: { { kind: string, weight: number } } = {}
	local total = 0
	for kind, pair in Difficulty.HollowKinds :: { [string]: { number } } do
		local weight = MathX.lerp(pair[1], pair[2], p.difficulty)
		total += weight
		table.insert(options, { kind = kind, weight = weight })
	end
	table.sort(options, function(a, b)
		return a.kind < b.kind
	end)
	local roll = rng:NextNumber() * total
	for _, option in options do
		roll -= option.weight
		if roll <= 0 then
			return option.kind
		end
	end
	return "Stalker"
end

local function add(at: CFrame, kind: string, state: string, emerge: string?): Hollow
	local model, humanoid = HollowBuilder.build(at, kind)
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	model:SetAttribute("Seed", rng:NextInteger(1, 1e6))
	model:SetAttribute("State", state)
	model:SetAttribute("StateAt", serverNow())
	if emerge then
		model:SetAttribute("Emerge", emerge)
	end
	model.Parent = folder
	humanoid.WalkSpeed = 0
	local hollow: Hollow = {
		model = model,
		humanoid = humanoid,
		root = root,
		kind = kind,
		def = (Tuning.HollowKinds :: any)[kind] :: KindDef,
		state = state,
		stateAt = os.clock(),
		target = nil,
		lastSeen = nil,
		lastSeenAt = 0,
		lastStrike = 0,
		stunnedUntil = 0,
		wanderUntil = 0,
		lastPosition = at.Position,
		stuckSince = os.clock(),
		lungeUntil = 0,
		lastLunge = 0,
		path = nil,
		pathIndex = 1,
		pathAt = 0,
		pathing = false,
		sleeper = state == "Dormant",
		stirAt = math.huge,
		checkAt = 0,
	}
	table.insert(hollows, hollow)
	return hollow
end

-- Lifecycle -----------------------------------------------------------------------------------

function HollowService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Hollows"
	folder.Parent = Workspace
end

function HollowService.Start()
	StationService.Cleared:Connect(HollowService.Clear)
	task.spawn(function()
		while true do
			task.wait(1 / H.ThinkHz)
			if params then
				refreshSightFilter()
				for i = #hollows, 1, -1 do
					local hollow = hollows[i]
					if hollow.model.Parent == nil or hollow.root.Position.Y < Tuning.World.FloorY - 60 then
						hollow.model:Destroy()
						table.remove(hollows, i)
					else
						Safe.call("HollowService.think", think, hollow)
					end
				end
			end
		end
	end)
end

function HollowService.Configure(hazards: Types.HazardParams)
	params = hazards
end

-- Seats the station's sleepers in their buildings (LayoutGen plans them).
function HollowService.Prepare(plan: LayoutGen.Plan)
	local p = params
	if p == nil or p.hollowCap <= 0 then
		return
	end
	for _, sleeper in plan.sleepers do
		local height = HollowBuilder.rootHeight(sleeper.kind)
		local position = StationService.ToWorld(sleeper.x, sleeper.y + height, sleeper.z)
		local facing = StationService.ToWorld(
			sleeper.x - math.sin(math.rad(sleeper.rot)),
			sleeper.y + height,
			sleeper.z - math.cos(math.rad(sleeper.rot))
		)
		local hollow = add(CFrame.lookAt(position, facing), sleeper.kind, "Dormant", nil)
		hollow.stirAt = p.dwell * H.SleeperStir * rng:NextNumber(1, 1.6)
	end
end

-- Hollows on the hunt or prowling (sleepers do not count toward the cap).
function HollowService.Count(): number
	local count = 0
	for _, hollow in hollows do
		if hollow.state ~= "Dormant" then
			count += 1
		end
	end
	return count
end

-- Spawns one Hollow near station-local (x, z) if the cap allows and the ground holds.
-- Some climb up over the far edge out of the dark instead.
function HollowService.TrySpawn(x: number, z: number): boolean
	local p = params
	local plan = StationService.Plan()
	if p == nil or plan == nil or HollowService.Count() >= p.hollowCap then
		return false
	end
	local fromEdge = rng:NextNumber() < 0.35
	if fromEdge then
		z = plan.depth - plan.tile / 2
	end
	local slab = LayoutGen.slabAt(plan, x, z)
	local tries = 0
	while (slab == nil or slab.kind ~= "Floor" or StationService.IsCollapsed(slab.id)) and tries < 8 do
		tries += 1
		fromEdge = false
		z -= plan.tile
		x += rng:NextNumber(-6, 6)
		slab = LayoutGen.slabAt(plan, x, z)
	end
	if slab == nil or slab.kind ~= "Floor" or z < safeEdge() + 10 then
		return false
	end
	local kind = pickKind()
	local height = HollowBuilder.rootHeight(kind)
	local localZ = if fromEdge then plan.depth - 3 else slab.z
	local position = StationService.ToWorld(slab.x, height, localZ)
	local facing = StationService.ToWorld(slab.x, height, 0)
	add(CFrame.lookAt(position, facing), kind, "Emerge", if fromEdge then "Climb" else "Rise")
	return true
end

-- Freezes every Hollow within `radius` studs. Returns how many were caught.
function HollowService.Stun(position: Vector3, radius: number, seconds: number): number
	local count = 0
	for _, hollow in hollows do
		if hollow.state ~= "Dormant" and (hollow.root.Position - position).Magnitude <= radius then
			hollow.stunnedUntil = os.clock() + seconds
			hollow.model:SetAttribute("StunnedUntil", serverNow() + seconds)
			count += 1
		end
	end
	return count
end

-- Wakes every sleeper within `radius` of a point (a slammed door, a forced lock).
function HollowService.Disturb(position: Vector3, radius: number)
	for _, hollow in hollows do
		if hollow.state == "Dormant" and (hollow.root.Position - position).Magnitude <= radius then
			wake(hollow)
		end
	end
end

function HollowService.Clear()
	for _, hollow in hollows do
		hollow.model:Destroy()
	end
	table.clear(hollows)
	params = nil
end

return HollowService
