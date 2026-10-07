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
	  Windup    the tell: it rears back, and seizes the target if it is still in reach
	  Grab      holding its prey (Config/Grabs): it bites on the grab's rhythm until the
	            victim fights free, the crew pry them loose, a flash makes it let go, or
	            they die in its hands
	  Recover   after a strike that missed
	  Reel      thrown off by a victim who broke free
	  Repelled  the target stands in light: hold at its edge
	  Stunned   frozen by a Flashbulb

	Every Hollow moves at its own pace: its kind's (the Crawler creeps, then bolts; the
	Brute plods) and a little of its own on top. Hunters closing on the same crew member
	fan out around them and keep their bodies apart, so a pack surrounds its prey instead
	of piling into one shape.

	Hollows never collide with crew (WorldService), so a chase can't end with one
	standing on someone's head; they stop StopShort studs from their target instead.
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Buildings = require(Shared.Config.Buildings)
local Difficulty = require(Shared.Config.Difficulty)
local Grabs = require(Shared.Config.Grabs)
local Tuning = require(Shared.Config.Tuning)
local Grab = require(Shared.Logic.Grab)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local LayoutGen = require(Shared.Logic.LayoutGen)
local MathX = require(Shared.Util.MathX)
local Rng = require(Shared.Util.Rng)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local HollowBuilder = require(script.Parent.Parent.Builders.HollowBuilder)
local Registry = require(script.Parent.Parent.Registry)
local NetService = require(script.Parent.NetService)
local StationService = require(script.Parent.StationService)

-- Keep one active slot available until this station's delayed wanderer arrives.
local wandererPending = false

type KindDef = {
	walk: number,
	chase: number,
	reach: number,
	windup: number,
	radius: number,
	grip: number,
	crush: number,
}

type Hold = {
	def: Grabs.Def,
	victim: Player,
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	frame: CFrame, -- where the victim's root is held
	escape: number,
	startedAt: number, -- os.clock()
	elapsed: number, -- seconds into the hold at the last tick
	shownEscape: number,
	diedAt: number?,
	prompt: ProximityPrompt?,
	link: ObjectValue,
	pryAt: { [Player]: number },
}

type Hollow = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	kind: string,
	def: KindDef,
	pace: number,
	order: { Grabs.Def },
	state: string,
	stateAt: number, -- os.clock() when the state began
	target: Player?,
	lastSeen: Vector3?,
	lastSeenAt: number,
	lastStrike: number,
	stunnedUntil: number,
	reelUntil: number,
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
	hold: Hold?,
}

local H = Tuning.Hollow
local G = Tuning.Grab

local HollowService = {}

local hollows: { Hollow } = {}
local params: Types.HazardParams? = nil
local folder: Folder
local rng = Random.new()
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
local roomParams = OverlapParams.new()
roomParams.FilterType = Enum.RaycastFilterType.Exclude
roomParams.RespectCanCollide = true
local graceUntil: { [Player]: number } = {}
local AGENT = {
	AgentRadius = 2.2,
	AgentHeight = 7,
	AgentCanJump = false,
	AgentCanClimb = false,
	WaypointSpacing = 6,
}
-- the victim's upper body, from its root: the part of them a hold must find room for
local BODY_OFFSET = CFrame.new(0, 0.5, 0)
local BODY_SIZE = Vector3.new(1.8, 2.8, 0.8)

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
	roomParams.FilterDescendantsInstances = filter
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
	return p.hollowWalk * hollow.def.walk * hollow.pace, p.hollowChase * hollow.def.chase * hollow.pace
end

-- The Hollow holding `player`, if any.
local function holderOf(player: Player): Hollow?
	for _, hollow in hollows do
		if hollow.hold and hollow.hold.victim == player then
			return hollow
		end
	end
	return nil
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

-- Pushes `goal` out of the way of every other Hollow's body, so none walks into another.
local function spaced(hollow: Hollow, goal: Vector3): Vector3
	local position = hollow.root.Position
	local push = Vector3.zero
	for _, other in hollows do
		if other ~= hollow and other.state ~= "Dormant" then
			local gap = hollow.def.radius + other.def.radius + H.Spacing
			local offset = position - other.root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude
			if distance < gap then
				local away = if distance > 0.05
					then flat / distance
					else hollow.root.CFrame.RightVector * (if hollow.pace > other.pace then 1 else -1)
				push += away * (gap - distance) * 1.6
			end
		end
	end
	return goal + push
end

--[[
	Where a hunter heads for: straight at its prey once close, but from further off each
	hunter on the same prey takes its own place in a ring around them, one to either side
	of the first, so the pack closes in from several sides at once.
]]
local function approach(hollow: Hollow, prey: Player, preyAt: Vector3, distance: number): Vector3
	local position = hollow.root.Position
	if distance <= H.FlankUntil then
		return spaced(hollow, shortOf(position, preyAt))
	end
	local rank, count = 0, 0
	for _, other in hollows do
		if other.target == prey and (other.state == "Hunt" or other.state == "Windup") then
			count += 1
			if other == hollow then
				rank = count
			end
		end
	end
	if count <= 1 or rank <= 1 then
		return spaced(hollow, shortOf(position, preyAt))
	end
	-- 2 goes left, 3 right, 4 further left...
	local step = math.ceil((rank - 1) / 2)
	local sign = if rank % 2 == 0 then 1 else -1
	local angle = math.rad(H.FlankAngle * step * sign)
	local from = Vector3.new(position.X - preyAt.X, 0, position.Z - preyAt.Z)
	if from.Magnitude < 0.1 then
		return spaced(hollow, shortOf(position, preyAt))
	end
	local around = CFrame.Angles(0, angle, 0):VectorToWorldSpace(from.Unit)
	local ring = math.min(distance * 0.75, 18)
	return spaced(hollow, preyAt + around * ring)
end

-- Grabs ---------------------------------------------------------------------------------------

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- The Hollow's root, stood upright, facing where it faces.
local function level(root: BasePart): CFrame
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(root.Position, root.Position + flat.Unit)
end

-- Where `def` holds its victim's root, for a Hollow standing at `base`.
local function holdFrame(base: CFrame, def: Grabs.Def): CFrame
	local hold = def.hold
	local up = vec(hold.up).Unit
	local back = -vec(hold.face).Unit
	local right = up:Cross(back).Unit
	return base * CFrame.fromMatrix(vec(hold.pos), right, up, back)
end

-- True when a hold has room: nothing solid where the victim's body goes, nor between.
local function roomFor(base: CFrame, frame: CFrame): boolean
	if #Workspace:GetPartBoundsInBox(frame * BODY_OFFSET, BODY_SIZE, roomParams) > 0 then
		return false
	end
	local from = base.Position
	local to = (frame * BODY_OFFSET).Position
	return Workspace:Raycast(from, to - from, sightParams) == nil
end

local function publishEscape(hold: Hold)
	local shown = math.floor(hold.escape * 50 + 0.5) / 50
	if shown ~= hold.shownEscape then
		hold.shownEscape = shown
		hold.character:SetAttribute("GrabEscape", shown)
	end
end

-- Lets go of the victim: they fall free (and, if they fought free, are thrown clear).
local function release(hollow: Hollow, why: string)
	local hold = hollow.hold
	if hold == nil then
		return
	end
	hollow.hold = nil
	if hold.prompt then
		hold.prompt:Destroy()
	end
	hold.link:Destroy()
	local character = hold.character
	if character.Parent then
		-- Publish the outcome before clearing the attribute the client watches.
		character:SetAttribute("GrabOutcome", why)
		character:SetAttribute("GrabFreeAt", serverNow())
		for _, name in { "GrabStyle", "GrabAt", "GrabKind", "GrabEscape" } do
			character:SetAttribute(name, nil)
		end
		if hold.root.Parent then
			hold.root.Anchored = false
		end
		if hold.root.Parent and hold.humanoid.Health > 0 then
			-- A prone hold must release an upright body above the floor, not inside it.
			local position = hold.root.Position
			local floor = Workspace:Raycast(position + Vector3.yAxis * 3, -Vector3.yAxis * 12, sightParams)
			if floor and floor.Normal.Y > 0.5 then
				local leg = character:FindFirstChild("Left Leg") :: BasePart?
				local height = hold.humanoid.HipHeight
					+ hold.root.Size.Y / 2
					+ (if leg then leg.Size.Y else 0)
				position =
					Vector3.new(position.X, math.max(position.Y, floor.Position.Y + height), position.Z)
			end
			local facing = level(hollow.root).LookVector
			hold.root.CFrame = CFrame.lookAt(position, position + facing)
			pcall(function()
				hold.root:SetNetworkOwner(hold.victim)
			end)
			if why == "Escaped" or why == "Flash" or why == "Timeout" then
				local away = hold.root.Position - hollow.root.Position
				local flat = Vector3.new(away.X, 0, away.Z)
				local direction = if flat.Magnitude > 0.1 then flat.Unit else -hollow.root.CFrame.LookVector
				NetService.Fire("Fx", hold.victim, "Escaped", {
					why = why,
					kind = hollow.kind,
					knockback = direction * G.Throw + Vector3.new(0, G.Throw * 0.35, 0),
				})
			end
		end
	end
	graceUntil[hold.victim] = os.clock() + G.Grace
	for _, name in { "GrabStyle", "GrabAt", "GrabVictim" } do
		hollow.model:SetAttribute(name, nil)
	end
	hollow.root.Anchored = false
	pcall(function()
		hollow.root:SetNetworkOwner(nil)
	end)
	hollow.lastStrike = os.clock()
	if why == "Escaped" then
		hollow.reelUntil = os.clock() + G.Stagger
		setState(hollow, "Reel")
		NetService.FireAll("Notify", "Crew", `{hold.victim.DisplayName} fought free of a {hollow.kind}!`)
	elseif why == "Flash" then
		setState(hollow, "Stunned")
	else
		setState(hollow, "Recover")
	end
end

-- Seizes `target` with the first of this Hollow's grabs that has room. False on a miss.
local function seize(hollow: Hollow, target: Player): boolean
	local character = target.Character
	local root = characterRoot(target)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or root == nil or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	if holderOf(target) or (graceUntil[target] or 0) > os.clock() or Registry.DevService.IsGod(target) then
		return false
	end
	-- face the prey, then find a hold that fits the room around it
	local position = hollow.root.Position
	local toward = Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z)
	local base = if toward.Magnitude > 0.1
		then CFrame.lookAt(position, position + toward.Unit)
		else level(hollow.root)
	local chosen: Grabs.Def? = nil
	local frame = base
	for _, def in hollow.order do
		local candidate = holdFrame(base, def)
		if roomFor(base, candidate) then
			chosen, frame = def, candidate
			break
		end
	end
	if chosen == nil then
		return false
	end
	local def = chosen :: Grabs.Def
	-- Cycle the successful hold to the back, so all three styles get used where they fit.
	local used = table.find(hollow.order, def)
	if used then
		table.remove(hollow.order, used)
		table.insert(hollow.order, def)
	end

	hollow.humanoid:MoveTo(position)
	pcall(function()
		hollow.root:SetNetworkOwner(nil)
	end)
	hollow.root.Anchored = true
	hollow.root.CFrame = base
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	humanoid.Sit = false
	root.Anchored = true
	root.CFrame = frame
	root.AssemblyLinearVelocity = Vector3.zero

	local now = serverNow()
	local link = Instance.new("ObjectValue")
	link.Name = "GrabbedBy"
	link.Value = hollow.model
	link.Parent = character
	character:SetAttribute("GrabOutcome", nil)
	character:SetAttribute("GrabKind", hollow.kind)
	character:SetAttribute("GrabAt", now)
	character:SetAttribute("GrabEscape", 0)
	character:SetAttribute("GrabStyle", def.id)
	character:SetAttribute("LastDamageSource", "Hollow")
	hollow.model:SetAttribute("GrabStyle", def.id)
	hollow.model:SetAttribute("GrabAt", now)
	hollow.model:SetAttribute("GrabVictim", target.UserId)

	-- the crew can tear at it to pull them free
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pull free"
	prompt.ObjectText = target.DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Action", "Pry")
	prompt.Parent = root

	local hold: Hold = {
		def = def,
		victim = target,
		character = character,
		root = root,
		humanoid = humanoid,
		frame = frame,
		escape = 0,
		startedAt = os.clock(),
		elapsed = 0,
		shownEscape = 0,
		diedAt = nil,
		prompt = prompt,
		link = link,
		pryAt = {},
	}
	hollow.hold = hold
	prompt.Triggered:Connect(function(ally)
		local allyRoot = characterRoot(ally)
		local clock = os.clock()
		if
			ally ~= target
			and hollow.hold == hold
			and hold.diedAt == nil
			and Registry.CrewService.IsAlive(ally)
			and holderOf(ally) == nil
			and hold.humanoid.Health > 0
			and allyRoot ~= nil
			and (allyRoot.Position - root.Position).Magnitude <= prompt.MaxActivationDistance
			and clock - (hold.pryAt[ally] or -math.huge) >= G.PryInterval
		then
			hold.pryAt[ally] = clock
			hold.escape = Grab.pry(hold.escape, params :: Types.HazardParams, hollow.def)
			publishEscape(hold)
			NetService.Fire("Fx", target, "Pried", { by = ally.UserId })
		end
	end)
	setState(hollow, "Grab")
	NetService.Fire("Fx", target, "Grabbed", { style = def.id, kind = hollow.kind })
	return true
end

-- One tick of a hold: the grip tightens, the bites land, and the victim may be free.
local function holdTick(hollow: Hollow)
	local hold = hollow.hold :: Hold
	local p = params :: Types.HazardParams
	local clock = os.clock()
	local character = hold.character
	if
		character.Parent == nil
		or hold.root.Parent == nil
		or hold.victim.Parent == nil
		or hold.victim.Character ~= character
	then
		release(hollow, "Gone")
		return
	end
	if hold.diedAt then
		-- it keeps what it caught until the dark takes the body
		if clock - (hold.diedAt :: number) > 2.6 then
			release(hollow, "Gone")
		end
		return
	end
	-- the ground under it gave way: everything falls
	local plan = StationService.Plan()
	if plan then
		local at = StationService.ToLocal(hollow.root.Position)
		local under = LayoutGen.slabAt(plan, at.X, at.Z)
		if under and StationService.IsCollapsed(under.id) then
			release(hollow, "Timeout")
			return
		end
	end
	if hold.humanoid.Health <= 0 then
		hold.diedAt = clock
		if hold.prompt then
			hold.prompt:Destroy()
			hold.prompt = nil
		end
		return
	end
	local elapsed = clock - hold.startedAt
	local dt = elapsed - hold.elapsed
	-- keep the victim where the Hollow holds them
	hold.root.Anchored = true
	hold.root.CFrame = hold.frame
	if elapsed > G.Settle then
		hold.escape = Grab.slip(hold.escape, p, dt)
	end
	local damage = Grab.damage(hold.def, p, hollow.def, hold.elapsed, elapsed)
	hold.elapsed = elapsed
	if damage > 0 and not Registry.DevService.IsGod(hold.victim) then
		character:SetAttribute("LastDamageSource", "Hollow")
		hold.humanoid:TakeDamage(damage)
		NetService.Fire("Fx", hold.victim, "Bite", { style = hold.def.id, damage = damage })
	end
	publishEscape(hold)
	if Grab.free(hold.escape) then
		release(hollow, "Escaped")
	elseif elapsed > G.MaxSeconds then
		release(hollow, "Timeout")
	end
end

-- Thinking ----------------------------------------------------------------------------------------

local function resolveStrike(hollow: Hollow)
	local target = hollow.target
	hollow.lastStrike = os.clock()
	local function miss()
		setState(hollow, "Recover")
	end
	if target == nil or not Registry.CrewService.IsAlive(target) or Registry.CrewService.IsAboard(target) then
		return miss()
	end
	local root = characterRoot(target)
	if root == nil then
		return miss()
	end
	local offset = root.Position - hollow.root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > H.HitRange * hollow.def.reach or math.abs(offset.Y) > 8 then
		return miss()
	end
	if flat.Magnitude > 2 and hollow.root.CFrame.LookVector:Dot(flat.Unit) < 0.1 then
		return miss()
	end
	if not clearBetween(hollow.root.Position, root.Position) then
		return miss()
	end
	if not seize(hollow, target) then
		return miss()
	end
end

local function wake(hollow: Hollow)
	if
		hollow.state ~= "Dormant"
		or params == nil
		or HollowService.Count() >= params.hollowCap - (if wandererPending then 1 else 0)
	then
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
	if hollow.hold then
		holdTick(hollow)
		return
	end

	local walk, chase = speeds(hollow)
	if clock < hollow.stunnedUntil then
		setState(hollow, "Stunned")
		hollow.humanoid.WalkSpeed = 0
		hollow.humanoid:MoveTo(position)
		return
	end
	if clock < hollow.reelUntil then
		-- thrown off: it staggers back a few steps before it comes again
		hollow.humanoid.WalkSpeed = walk * 0.4
		hollow.humanoid:MoveTo(position - hollow.root.CFrame.LookVector * 4)
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

	-- the nearest crew member it can sense, and is not already in another Hollow's hands
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	local bestVisible = false
	local wanderer = hollow.model:GetAttribute("Wanderer") == true
	for _, player in Registry.CrewService.AlivePlayers() do
		if not Registry.CrewService.IsAboard(player) and holderOf(player) == nil then
			local root = characterRoot(player)
			if root then
				local distance = (root.Position - position).Magnitude
				if (wanderer or distance < H.SightRange) and distance < bestDistance then
					local visible = clearBetween(position, root.Position)
					if wanderer or visible or distance <= H.AwarenessRange then
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
				hollow.humanoid:MoveTo(spaced(hollow, StationService.ToWorld(targetLocal.X, 3, edge + 2)))
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
		moveToward(hollow, approach(hollow, best, bestRoot.Position, bestDistance), bestVisible)
		if
			bestDistance <= H.StrikeRange * hollow.def.reach
			and math.abs(bestRoot.Position.Y - position.Y) < 8
			and clock - hollow.lastStrike >= H.StrikeCooldown
			and (graceUntil[best] or 0) <= clock
		then
			setState(hollow, "Windup")
		end
	elseif hollow.lastSeen and clock - hollow.lastSeenAt < 4 then
		-- lost sight: search where it saw them last
		setState(hollow, "Hunt")
		hollow.humanoid.WalkSpeed = chase * 0.85
		moveToward(hollow, spaced(hollow, hollow.lastSeen :: Vector3), false)
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
				moveToward(hollow, spaced(hollow, point), false)
			end
			hollow.wanderUntil = clock + rng:NextNumber(3, 6)
		end
	end

	-- stuck on a corner (or wedged against another Hollow): sidestep
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
	local seed = rng:NextInteger(1, 1e6)
	model:SetAttribute("Seed", seed)
	model:SetAttribute("State", state)
	model:SetAttribute("StateAt", serverNow())
	if emerge then
		model:SetAttribute("Emerge", emerge)
	end
	-- its own pace, a little quicker or slower than the rest of its kind
	local pace = 1 + (rng:NextNumber() * 2 - 1) * H.PaceSpread
	model:SetAttribute("Pace", pace)
	model.Parent = folder
	humanoid.WalkSpeed = 0
	local hollow: Hollow = {
		model = model,
		humanoid = humanoid,
		root = root,
		kind = kind,
		def = (Tuning.HollowKinds :: any)[kind] :: KindDef,
		pace = pace,
		order = Grab.order(kind, seed),
		state = state,
		stateAt = os.clock(),
		target = nil,
		lastSeen = nil,
		lastSeenAt = 0,
		lastStrike = 0,
		stunnedUntil = 0,
		reelUntil = 0,
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
		hold = nil,
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
	NetService.Handle("Struggle", function(player)
		local hollow = holderOf(player)
		local p = params
		if hollow == nil or p == nil then
			return
		end
		local hold = hollow.hold :: Hold
		if hold.diedAt then
			return
		end
		hold.escape = Grab.press(hold.escape, p, hollow.def)
		publishEscape(hold)
		if Grab.free(hold.escape) then
			release(hollow, "Escaped")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		graceUntil[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1 / H.ThinkHz)
			if params then
				refreshSightFilter()
				for i = #hollows, 1, -1 do
					local hollow = hollows[i]
					if hollow.model.Parent == nil or hollow.root.Position.Y < Tuning.World.FloorY - 60 then
						release(hollow, "Gone")
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
	wandererPending = hazards.hollowCap > 0
end

-- Retain planned sleepers and fill larger buildings with distinct, clear interior spots.
function HollowService.Prepare(plan: LayoutGen.Plan)
	local p = params
	if p == nil or p.hollowCap <= 0 then
		return
	end
	local sleepers = table.clone(plan.sleepers)
	local info = StationService.Info()
	local placement = Rng.new(Rng.derive(if info then info.layoutSeed else 0, "extraSleepers"))
	local tuning = Difficulty.Sleepers
	local clearance = tuning.Clearance
	for _, building in plan.buildings do
		local def = Buildings.Defs[building.plan.kind]
		local target = math.ceil(def.size[1] * def.size[2] / tuning.TilesPerSleeper)
		local count = 0
		for _, sleeper in sleepers do
			if sleeper.building == building.id then
				count += 1
			end
		end
		local rooms = building.plan.rooms
		for attempt = 1, target * tuning.AttemptsPerSleeper do
			if count >= target or #rooms == 0 then
				break
			end
			local room = rooms[(attempt - 1) % #rooms + 1]
			local rect = room.rect
			if rect.x1 - rect.x0 <= clearance * 2 or rect.z1 - rect.z0 <= clearance * 2 then
				continue
			end
			local x = placement:range(rect.x0 + clearance, rect.x1 - clearance)
			local z = placement:range(rect.z0 + clearance, rect.z1 - clearance)
			local clear = true
			for _, item in building.plan.items do
				local furniture = Buildings.Furniture[item.kind]
				local turned = item.rot % 180 ~= 0
				local halfX = (if turned then furniture.d else furniture.w) / 2
				local halfZ = (if turned then furniture.w else furniture.d) / 2
				if math.abs(x - item.x) < halfX + clearance and math.abs(z - item.z) < halfZ + clearance then
					clear = false
					break
				end
			end
			for _, door in room.doors do
				local dx, dz
				if door.side == "N" or door.side == "S" then
					dx, dz = door.at, if door.side == "N" then rect.z1 else rect.z0
				else
					dx, dz = if door.side == "E" then rect.x1 else rect.x0, door.at
				end
				if (x - dx) ^ 2 + (z - dz) ^ 2 < (clearance * 2) ^ 2 then
					clear = false
				end
			end
			local worldX, worldZ = building.x + x, building.z + z
			for _, sleeper in sleepers do
				if
					math.abs(worldX - sleeper.x) < clearance * 2
					and math.abs(worldZ - sleeper.z) < clearance * 2
				then
					clear = false
					break
				end
			end
			if clear then
				local roomDef = Buildings.Rooms[room.kind]
				local kind = (if roomDef then roomDef.sleeperKind else nil)
					or (if placement:chance(0.25) then "Crawler" else "Stalker")
				table.insert(
					sleepers,
					{ x = worldX, y = 0, z = worldZ, rot = 0, kind = kind, building = building.id }
				)
				count += 1
			end
		end
	end
	for _, sleeper in sleepers do
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
-- Some climb up over the far edge out of the dark instead. `kind` forces its kind (Studio).
function HollowService.TrySpawn(x: number, z: number, kind: string?, wanderer: boolean?): boolean
	local p = params
	local plan = StationService.Plan()
	if
		p == nil
		or plan == nil
		or HollowService.Count() >= p.hollowCap - (if wandererPending and not wanderer then 1 else 0)
	then
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
	if slab == nil or slab.kind ~= "Floor" or StationService.IsCollapsed(slab.id) or z < safeEdge() + 10 then
		return false
	end
	local chosen = if kind and (Tuning.HollowKinds :: any)[kind] then kind else pickKind()
	local height = HollowBuilder.rootHeight(chosen)
	local localZ = if fromEdge then plan.depth - 3 else slab.z
	local position = StationService.ToWorld(slab.x, height, localZ)
	local facing = StationService.ToWorld(slab.x, height, 0)
	local hollow =
		add(CFrame.lookAt(position, facing), chosen, "Emerge", if fromEdge then "Climb" else "Rise")
	if wanderer then
		hollow.model:SetAttribute("Wanderer", true)
		wandererPending = false
	end
	return true
end

-- Freezes every Hollow within `radius` studs; any it was holding drops free. Returns how many.
function HollowService.Stun(position: Vector3, radius: number, seconds: number): number
	local count = 0
	for _, hollow in hollows do
		if hollow.state ~= "Dormant" and (hollow.root.Position - position).Magnitude <= radius then
			hollow.stunnedUntil = os.clock() + seconds
			hollow.model:SetAttribute("StunnedUntil", serverNow() + seconds)
			if hollow.hold then
				release(hollow, "Flash")
			end
			count += 1
		end
	end
	return count
end

-- The train is leaving: every Hollow drops what it holds (one last chance to run for it).
function HollowService.LetGo()
	for _, hollow in hollows do
		if hollow.hold then
			release(hollow, "Timeout")
		end
	end
end

-- Studio: a Hollow of `kind` appears in front of `player` and seizes them at once.
function HollowService.DevGrab(player: Player, kind: string?): boolean
	local root = characterRoot(player)
	if params == nil or root == nil or StationService.Plan() == nil then
		return false
	end
	local chosen = if kind and (Tuning.HollowKinds :: any)[kind] then kind else pickKind()
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local ground = root.Position.Y - 3
	local position = Vector3.new(root.Position.X, ground + HollowBuilder.rootHeight(chosen), root.Position.Z)
		+ look * 4
	local hollow = add(CFrame.lookAt(position, position - look), chosen, "Hunt", nil)
	hollow.root.Anchored = false
	graceUntil[player] = nil
	hollow.target = player
	return seize(hollow, player)
end

-- True while a Hollow has `player` in its hands.
function HollowService.IsHeld(player: Player): boolean
	return holderOf(player) ~= nil
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
		release(hollow, "Gone")
		hollow.model:Destroy()
	end
	table.clear(hollows)
	table.clear(graceUntil)
	params = nil
	wandererPending = false
end

return HollowService
