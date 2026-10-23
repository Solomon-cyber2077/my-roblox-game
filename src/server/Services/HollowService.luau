--!strict
--[[
	Hollows: what claws up out of the ground at the fog front, climbs over a station's
	edge from the dark beneath it, or sits slumped in an abandoned building waiting for
	someone to come close. One think loop drives them all at ThinkHz. They cannot be
	killed, only outrun, stunned or kept out with light: they never enter the lit band
	beside the train, nor a building whose power is back on, nor (in the tutorial) the radius
	of a part tagged SafeLight (attribute Radius, scaled by the tier's safeLightScale).

	Tutorial (Config/Tutorial, by HazardParams.tutorial): nobody is hunted until they have been
	off the train the tier's `grace` seconds at this stop. A first run (Prompt 5): at stop 1 a
	harmless scripted Stalker is sighted at the edge of the light and withdraws (Logic/Sighting);
	at stop 2 a scripted Crawler comes for one player to teach the skill check (an oversized zone,
	the first-strike guard, and its hold cannot kill); at stop 3 one Stalker wanders and stalks
	only a player 20+ studs from the train.

	States (mirrored to the model's State and StateAt attributes; HollowAnimator plays them)
	  Emerge    rising, climbing or waking (attribute Emerge): no moving, no striking yet
	  Dormant   a sleeper in a building, until crew come close or the dwell runs on
	  Prowl     no target: drift between the light and the fog
	  Stalk     a crew member sensed (Logic/Stalk): hold the 24-33-stud shadow band, freeze while
	            faced, slip between cover while not; commit to Hunt on Surge, proximity, a seized
	            target, the maximum stalk or a turned back. Only the nearest Hollow stalks a target;
	            one stalk per Hollow per target per stop
	  Hunt      chase the nearest crew member it senses, pathing around walls, lunging close.
	            The first-strike guard: until a target has had 1.5 s of warning in sight within 36
	            studs from this Hollow, it coils (WarningCoil), will not close inside 16 on its own
	            and cannot wind up, lunge or strike. A shut locked door in the way can be forced
	            on a forcing stop (BuildingService owns the timer)
	  Windup    the tell: it rears back, and seizes the target if it is still in reach
	  Grab      holding its prey (Config/Grabs): it bites on the grab's rhythm until the
	            victim wins their skill checks (Logic/SkillCheck), the crew pry them loose,
	            a flash makes it let go, or its clock runs out and it finishes them
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

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local HollowSpeed = require(Shared.Logic.HollowSpeed)
local Buildings = require(Shared.Config.Buildings)
local Difficulty = require(Shared.Config.Difficulty)
local Grabs = require(Shared.Config.Grabs)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)
local Grab = require(Shared.Logic.Grab)
local SkillCheck = require(Shared.Logic.SkillCheck)
local Sighting = require(Shared.Logic.Sighting)
local Stalk = require(Shared.Logic.Stalk)
local Threat = require(Shared.Logic.Threat)
local Tutorial = require(Shared.Logic.Tutorial)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local HollowBudget = require(Shared.Logic.HollowBudget)
local LayoutGen = require(Shared.Logic.LayoutGen)
local MathX = require(Shared.Util.MathX)
local Rng = require(Shared.Util.Rng)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local HollowBuilder = require(script.Parent.Parent.Builders.HollowBuilder)
local Wounds = require(script.Parent.Parent.Builders.Wounds)
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
	slamFrom: CFrame?, -- a pin drives the body from here down to `frame` (Tuning.Grab.Pin)
	progress: number, -- skill-check progress toward SkillCheck.Required (crewmates' pries add to it)
	zone: number, -- skill-check zone width in degrees
	check: SkillCheck.Check?, -- the check on the victim's screen now
	judged: boolean, -- its one press has been judged (a second one is a replay)
	checkSeq: number,
	nextCheckAt: number, -- server time the next check appears
	lastPressAt: number, -- server time of the last press the server looked at
	finishAt: number, -- server time the grab's clock runs out and it finishes them
	startedAt: number, -- os.clock()
	elapsed: number, -- seconds into the hold at the last tick
	shownEscape: number,
	diedAt: number?,
	prompt: ProximityPrompt?,
	link: ObjectValue,
	pryAt: { [Player]: number },
	lethal: boolean, -- the clock running out kills (not the tutorial's teaching grab)
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
	stallAt: Vector3, -- where the stall window began
	stallSince: number,
	forcePathUntil: number, -- os.clock() until which it paths even with the target in sight
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
	scripted: Player?, -- the tutorial's teaching Crawler: it hunts only this player
	stalk: StalkRun?, -- the stalk under way
	exposure: { [Player]: number }, -- warning seconds each target has had from this Hollow
	stalked: { [Player]: number }, -- os.clock() it stalked each target this stop (the budget)
	noStalkUntil: number, -- after a stun or stagger
	lastThink: number,
	door: BasePart?, -- the shut door it is forcing
	sighting: SightingRun?, -- stop 1's scripted sighting: never hunts, strikes or grabs
}

type SightingRun = {
	track: Sighting.State,
	lastAt: number,
	withdrawAt: number?, -- os.clock() it began to walk away
	away: Vector3?, -- where it walks to
}

type StalkRun = {
	target: Player,
	track: Stalk.Track,
	point: Vector3?, -- the shadow point it is making for
	searchAt: number, -- os.clock() of the last shadow-point search
	unseenSince: number?, -- os.clock() line of sight was lost
}

local H = Tuning.Hollow
local A = Difficulty.Aggression
local G = Tuning.Grab

local HollowService = {}

local hollows: { Hollow } = {}
local params: Types.HazardParams? = nil
local woundRng = Random.new() -- where a bite marks the body: looks only, so not from the run seed
local folder: Folder
local rng = Random.new()
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
local roomParams = OverlapParams.new()
roomParams.FilterType = Enum.RaycastFilterType.Exclude
roomParams.RespectCanCollide = true
local graceUntil: { [Player]: number } = {}
local budgetAt: { [Player]: number } = {} -- when a target's post-grab immunity ends: stalk budgets reset
local alertUntil = 0 -- os.clock() until which every Hollow hunts the crew (a Surge)
local T = Difficulty.Tutorial
local safeLights: { BasePart } = {} -- parts tagged SafeLight
local lightScale = 0 -- the tutorial tier's safeLightScale; 0 past the tutorial
local offTrainAt: { [Player]: number } = {} -- os.clock() each player first stood off the train this stop
-- the first run's teaching grab at its stop: pending until the Crawler has come and gone
local scripted: { pending: boolean, hollow: Hollow? } = { pending = false, hollow = nil }
-- stop 1's scripted sighting on a first run (E2's treatment arm): pending until it appears
local sightingPending = false
local sightingTryAt = 0 -- os.clock() of the next try at placing the sighting
local AGENT = {
	AgentRadius = 2.2,
	AgentHeight = 7,
	AgentCanJump = false,
	AgentCanClimb = false,
	WaypointSpacing = 6,
}
-- tried when AGENT finds no way: tight spots a body still fits, such as a ramp foot by a wall
local NARROW_AGENT = table.clone(AGENT)
NARROW_AGENT.AgentRadius = H.NarrowRadius
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
	if state ~= "Hunt" then
		hollow.model:SetAttribute("Intent", nil) -- the committed approach ends with the hunt
	end
	hollow.model:SetAttribute("State", state)
	hollow.model:SetAttribute("StateAt", serverNow())
end

local function safeEdge(): number
	local p = params :: Types.HazardParams
	return p.safeBand + H.SafeMargin
end

-- The tutorial's safe light whose radius covers `position`, if any.
local function safeLightAt(position: Vector3): BasePart?
	if lightScale <= 0 then
		return nil
	end
	for _, part in safeLights do
		local radius = ((part:GetAttribute("Radius") :: number?) or 0) * lightScale
		if radius > 0 and part.Parent then
			local d = part.Position - position
			if Vector3.new(d.X, 0, d.Z).Magnitude < radius then
				return part
			end
		end
	end
	return nil
end

local function isLit(position: Vector3): boolean
	local buildings = Registry.BuildingService
	return (buildings ~= nil and buildings.IsLitAt(position)) or safeLightAt(position) ~= nil
end

local function tutorialTier(): Tutorial.Def?
	return Tutorial.def(if params then params.tutorial else nil)
end

local function speeds(hollow: Hollow): (number, number, number, number)
	local p = params :: Types.HazardParams
	local chase, lunge, duration = HollowSpeed.resolve(
		p.hollowChase,
		hollow.kind,
		hollow.pace,
		hollow.scripted ~= nil,
		p.tutorial,
		p.stop
	)
	return p.hollowWalk * hollow.def.walk * hollow.pace, chase, lunge, duration
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
			if not ok or path.Status ~= Enum.PathStatus.Success then
				path = PathfindingService:CreatePath(NARROW_AGENT)
				ok = pcall(function()
					path:ComputeAsync(start, goal)
				end)
			end
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
	local shown = math.floor(SkillCheck.fraction(hold.progress) * 50 + 0.5) / 50
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
		for _, name in { "GrabStyle", "GrabAt", "GrabKind", "GrabEscape", "GrabFinishAt" } do
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
	-- post-grab protection (Logic/Threat): no Hollow may grab them for a while, and early on
	-- the one that held them is staggered and shoved away
	local p = params
	local protection =
		Threat.protection(if p then p.level or p.stop or 1 else 1, if p then p.tutorial else nil)
	graceUntil[hold.victim] = os.clock() + protection.immunity
	budgetAt[hold.victim] = graceUntil[hold.victim]
	if why == "Escaped" and protection.stagger then
		hollow.noStalkUntil = os.clock() + Difficulty.PostGrab.StaggerSeconds + Tuning.Stalk.StunExclusion
	end
	character:SetAttribute("GrabImmuneUntil", serverNow() + protection.immunity)
	for _, name in { "GrabStyle", "GrabAt", "GrabVictim" } do
		hollow.model:SetAttribute(name, nil)
	end
	hollow.root.Anchored = false
	pcall(function()
		hollow.root:SetNetworkOwner(nil)
	end)
	hollow.lastStrike = os.clock()
	if hollow.scripted then
		scripted.pending = false
		local model = hollow.model
		task.delay(Difficulty.PostGrab.StaggerSeconds + 0.5, function()
			HollowService.Dismiss(model)
		end)
	end
	if why == "Escaped" then
		Registry.TelemetryService.Escaped(hold.victim)
	end
	if why == "Escaped" and protection.stagger then
		-- staggered: it reels back, shoved hard at first, and cannot strike until it recovers
		hollow.reelUntil = os.clock() + Difficulty.PostGrab.StaggerSeconds
		setState(hollow, "Reel")
		NetService.FireAll("Notify", "Crew", `{hold.victim.DisplayName} fought free of a {hollow.kind}!`)
	elseif why == "Escaped" then
		setState(hollow, "Recover")
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
	-- a pin starts from where they stood and is slammed down over the first ticks
	local slamFrom = if def.pin then root.CFrame else nil
	root.CFrame = slamFrom or frame
	root.AssemblyLinearVelocity = Vector3.zero

	local now = serverNow()
	local hazards = params :: Types.HazardParams
	local stop = hazards.level or hazards.stop or 1 -- the skill check reads the Long Line level
	local tier = tutorialTier()
	local zone = if hollow.scripted
		then T.ScriptedGrab.ZoneDegrees
		else SkillCheck.zoneWidth(stop, tier and tier.zoneDegrees)
	local finishAt = now + SkillCheck.finishSeconds(stop, zone)
	local link = Instance.new("ObjectValue")
	link.Name = "GrabbedBy"
	link.Value = hollow.model
	link.Parent = character
	character:SetAttribute("GrabOutcome", nil)
	character:SetAttribute("GrabKind", hollow.kind)
	character:SetAttribute("GrabAt", now)
	character:SetAttribute("GrabEscape", 0)
	character:SetAttribute("GrabFinishAt", finishAt)
	character:SetAttribute("GrabStyle", def.id)
	Registry.CrewService.TagDamage(character, "Hollow")
	hollow.model:SetAttribute("GrabStyle", def.id)
	hollow.model:SetAttribute("GrabAt", now)
	hollow.model:SetAttribute("GrabVictim", target.UserId)

	-- the crew can tear at it to pull them free
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pull free"
	prompt.ObjectText = if def.pin then `{target.DisplayName}: Brute pin` else target.DisplayName
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
		slamFrom = slamFrom,
		progress = 0,
		zone = zone,
		check = nil,
		judged = false,
		checkSeq = 0,
		nextCheckAt = now + Difficulty.SkillCheck.FirstDelay,
		lastPressAt = -math.huge,
		finishAt = finishAt,
		startedAt = os.clock(),
		elapsed = 0,
		shownEscape = 0,
		diedAt = nil,
		prompt = prompt,
		link = link,
		pryAt = {},
		lethal = hollow.scripted == nil,
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
			hold.progress = SkillCheck.pry(hold.progress)
			publishEscape(hold)
			NetService.Fire("Fx", target, "Pried", { by = ally.UserId })
			Registry.TelemetryService.Pried(ally)
		end
	end)
	setState(hollow, "Grab")
	-- the first strike on this target has landed: the guard is for first strikes only
	hollow.exposure[target] = math.max(hollow.exposure[target] or 0, Tuning.Stalk.WarnSeconds)
	hollow.model:SetAttribute("WarningCoil", nil)
	hollow.model:SetAttribute("WarningTarget", nil)
	NetService.Fire("Fx", target, "Grabbed", { style = def.id, kind = hollow.kind })
	Registry.TelemetryService.Grabbed(target, hollow.kind)
	return true
end

-- Applies one skill-check result to the hold: progress, the clock, the next check.
local function judgeCheck(hollow: Hollow, result: SkillCheck.Result)
	local hold = hollow.hold
	local check = hold and hold.check
	if hold == nil or check == nil then
		return
	end
	hold.judged = true
	local progress, penalty = SkillCheck.apply(hold.progress, result)
	hold.progress = progress
	hold.finishAt -= penalty
	hold.check = nil
	hold.nextCheckAt = serverNow() + SkillCheck.gap(function(lo, hi)
		return rng:NextNumber(lo, hi)
	end)
	hold.character:SetAttribute("GrabFinishAt", hold.finishAt)
	publishEscape(hold)
	NetService.Fire("Fx", hold.victim, "SkillResult", {
		id = check.id,
		result = result,
		progress = SkillCheck.fraction(progress),
	})
	if SkillCheck.freed(progress) then
		release(hollow, "Escaped")
	end
end

-- The grab's clock ran out: it finishes them.
local function finishHold(hollow: Hollow)
	local hold = hollow.hold :: Hold
	if Registry.DevService.IsGod(hold.victim) or not hold.lethal then
		release(hollow, "Timeout")
		return
	end
	Registry.CrewService.TagDamage(hold.character, "Hollow")
	-- what it was working on comes away (Builders/Wounds keeps it short of gore)
	Safe.call("HollowService.sever", Wounds.sever, hold.character, hold.def.area)
	hold.humanoid.Health = 0
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
	-- keep the victim where the Hollow holds them (a pin slams them there first)
	hold.root.Anchored = true
	local slamFrom = hold.slamFrom
	if slamFrom and elapsed < G.Pin.SlamSeconds then
		local u = elapsed / G.Pin.SlamSeconds
		hold.root.CFrame = slamFrom:Lerp(hold.frame, u * u)
	else
		hold.root.CFrame = hold.frame
	end
	-- bites hurt, but never take the last of you: only the clock running out does
	local damage =
		Grab.survivable(Grab.damage(hold.def, p, hollow.def, hold.elapsed, elapsed), hold.humanoid.Health)
	hold.elapsed = elapsed
	if damage > 0 and not Registry.DevService.IsGod(hold.victim) then
		Registry.CrewService.TagDamage(character, "Hollow")
		hold.humanoid:TakeDamage(damage)
		NetService.Fire("Fx", hold.victim, "Bite", { style = hold.def.id, damage = damage })
		Safe.call("HollowService.wound", Wounds.mark, character, hold.def.area, woundRng)
	end
	local now = serverNow()
	-- an unpressed check runs out after its turn: a miss
	local check = hold.check
	if check and not hold.judged and now > SkillCheck.endsAt(check) then
		judgeCheck(hollow, "Miss")
		if hollow.hold ~= hold then
			return
		end
	end
	if hold.check == nil and now >= hold.nextCheckAt and now < hold.finishAt then
		hold.checkSeq += 1
		local fresh = SkillCheck.new(hold.checkSeq, now, hold.zone, function(lo, hi)
			return rng:NextNumber(lo, hi)
		end)
		hold.check = fresh
		hold.judged = false
		NetService.Fire("Fx", hold.victim, "SkillCheck", fresh)
	end
	publishEscape(hold)
	if SkillCheck.freed(hold.progress) then
		release(hollow, "Escaped")
	elseif now >= hold.finishAt then
		finishHold(hollow)
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
	-- sleepers already count toward the stop's budget, so waking never adds one
	if hollow.state ~= "Dormant" or params == nil then
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

local sightingThink: (Hollow, number) -> ()

-- Stalking (Logic/Stalk) ------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function endStalk(hollow: Hollow)
	if hollow.stalk then
		hollow.stalk = nil
		hollow.model:SetAttribute("StalkTarget", nil)
	end
	hollow.model:SetAttribute("Frozen", nil)
end

local function prowl(hollow: Hollow, clock: number)
	if clock >= hollow.wanderUntil then
		local point = wanderPoint()
		if point then
			moveToward(hollow, spaced(hollow, point), false)
		end
		hollow.wanderUntil = clock + rng:NextNumber(3, 6)
	end
end

-- Inside a light's pool: the lit band by the train, a SafeLight or a working building lamp. Red
-- edge danger lamps make no pool.
local function inLampPool(position: Vector3): boolean
	if isLit(position) or StationService.ToLocal(position).Z < safeEdge() then
		return true
	end
	for _, light in CollectionService:GetTagged("LTO_BuildingLamp") do
		local bulb = light.Parent
		if
			light:IsA("Light")
			and light.Enabled
			and bulb
			and bulb:IsA("BasePart")
			and (bulb.Position - position).Magnitude < Tuning.Stalk.LampPool
		then
			return true
		end
	end
	return false
end

-- Whether the crew member at `root` faces `at`: their root's look, never the camera, so a glance
-- never freezes a Hollow.
local function facedBy(root: BasePart, at: Vector3): boolean
	local look = root.CFrame.LookVector
	local to = at - root.Position
	return Stalk.facing(look.X, look.Z, to.X, to.Z)
end

local function nearestCrewmate(player: Player, at: Vector3): number
	local best = math.huge
	for _, other in Registry.CrewService.AlivePlayers() do
		local root = if other ~= player then characterRoot(other) else nil
		if root then
			best = math.min(best, (root.Position - at).Magnitude)
		end
	end
	return best
end

-- A shadow point for a stalk: in the 24-33-stud band around the prey, in sight of them, on open
-- ground outside every light's pool, and the nearest such to the Hollow. Nil when none is legal.
local function shadowPoint(hollow: Hollow, preyAt: Vector3): Vector3?
	local near, far = Stalk.band()
	local away = flat(hollow.root.Position - preyAt)
	local bearing = if away.Magnitude > 0.1
		then math.atan2(away.X, away.Z)
		else rng:NextNumber(0, 2 * math.pi)
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _ = 1, Tuning.Stalk.ShadowSamples do
		local angle = bearing + math.rad(rng:NextNumber(-80, 80))
		local guess = preyAt + Vector3.new(math.sin(angle), 0, math.cos(angle)) * rng:NextNumber(near, far)
		local ground = Workspace:Raycast(guess + Vector3.yAxis * 12, -Vector3.yAxis * 40, sightParams)
		if ground and ground.Normal.Y > 0.6 and math.abs(ground.Position.Y - preyAt.Y) < 8 then
			local point = ground.Position
			if not inLampPool(point) and clearBetween(point, preyAt) then
				local distance = (point - hollow.root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = point, distance
				end
			end
		end
	end
	return best
end

-- One stalk per Hollow per target per stop; a target's budgets come back when their post-grab
-- immunity ends.
local function stalkBudget(hollow: Hollow, player: Player): boolean
	local at = hollow.stalked[player]
	if at == nil then
		return true
	end
	local reset = budgetAt[player]
	return reset ~= nil and at < reset and os.clock() >= reset
end

local function huntedByOther(player: Player, except: Hollow): boolean
	for _, other in hollows do
		if
			other ~= except
			and other.target == player
			and (other.state == "Hunt" or other.state == "Windup" or other.state == "Grab")
		then
			return true
		end
	end
	return false
end

-- Whether this Hollow is the one to stalk `player`: nobody stalks them yet and no other prowler
-- sensing them is nearer.
local function nearestFor(hollow: Hollow, player: Player, distance: number): boolean
	local root = characterRoot(player)
	for _, other in hollows do
		if other ~= hollow and other.target == player then
			if other.state == "Stalk" then
				return false
			end
			if
				other.state == "Prowl"
				and root
				and (other.root.Position - root.Position).Magnitude < distance
			then
				return false
			end
		end
	end
	return true
end

-- A shut locked door this hunter faces on its way to its prey, close enough to force.
local function doorInWay(hollow: Hollow, preyAt: Vector3): BasePart?
	local origin = hollow.root.Position
	local hit = Workspace:Raycast(origin, preyAt - origin, sightParams)
	if hit == nil or hit.Distance > Tuning.DoorForce.Reach then
		return nil
	end
	local part = hit.Instance
	if part.Name == "LockedDoor" and part:IsA("BasePart") then
		return part
	end
	local parent = part.Parent
	if parent and parent.Name == "LockedDoor" and parent:IsA("BasePart") then
		return parent
	end
	return nil
end

local function leaveDoor(hollow: Hollow)
	local door = hollow.door
	if door then
		hollow.door = nil
		Registry.BuildingService.LeaveForce(door, hollow)
	end
end

-- The guard is met and the prey is in reach: the strike begins. Telemetry records the warning
-- this target had from this Hollow (an opportunity, not proof it was seen).
local function strikeAttempt(hollow: Hollow, target: Player, targetRoot: BasePart)
	local near = 0
	for _, other in Registry.CrewService.AlivePlayers() do
		local root = if other ~= target then characterRoot(other) else nil
		if root and (root.Position - targetRoot.Position).Magnitude <= 20 then
			near += 1
		end
	end
	Registry.TelemetryService.Tell(target, hollow.exposure[target] or 0, near)
	setState(hollow, "Windup")
end

local function think(hollow: Hollow)
	local clock = os.clock()
	local position = hollow.root.Position
	-- seconds since its last think, kept current through every early return (emerging, sleeping,
	-- holding) so warning time never counts a gap it was not watching (Logic/Stalk)
	local dt = math.clamp(clock - hollow.lastThink, 0, 0.5)
	hollow.lastThink = clock

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

	if hollow.sighting then
		sightingThink(hollow, dt)
		return
	end
	local walk, chase, lungeSpeed, lungeSeconds = speeds(hollow)
	if clock < hollow.stunnedUntil then
		endStalk(hollow)
		setState(hollow, "Stunned")
		hollow.humanoid.WalkSpeed = 0
		hollow.humanoid:MoveTo(position)
		return
	end
	if clock < hollow.reelUntil then
		-- thrown off: it is shoved back, slowing, before it comes again
		endStalk(hollow)
		local left = (hollow.reelUntil - clock) / Difficulty.PostGrab.StaggerSeconds
		hollow.humanoid.WalkSpeed = math.max(Difficulty.PostGrab.StaggerPush * left, walk * 0.4)
		hollow.humanoid:MoveTo(position - hollow.root.CFrame.LookVector * 4)
		return
	end

	-- caught inside a building as its lights come on: cower, then get out
	if isLit(position) then
		endStalk(hollow)
		leaveDoor(hollow)
		if hollow.state ~= "Repelled" then
			setState(hollow, "Repelled")
		end
		if clock - hollow.stateAt < H.LitFlee then
			hollow.humanoid.WalkSpeed = 0
			hollow.humanoid:MoveTo(position)
		else
			hollow.humanoid.WalkSpeed = walk
			local light = safeLightAt(position)
			local exit = if light then nil else Registry.BuildingService.ExitPoint(position)
			if light then
				local away = Vector3.new(position.X - light.Position.X, 0, position.Z - light.Position.Z)
				local radius = ((light:GetAttribute("Radius") :: number?) or 0) * lightScale
				local out = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
				exit = Vector3.new(light.Position.X, position.Y, light.Position.Z) + out * (radius + 4)
			end
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

	-- every crew member it can sense who is not already in another Hollow's hands
	local wanderer = hollow.model:GetAttribute("Wanderer") == true or clock < alertUntil
	local tier = tutorialTier()
	local grace = if tier then tier.grace else 0
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	local bestVisible = false
	local current: Player? = hollow.target
	local currentRoot: BasePart? = nil
	local currentDistance = math.huge
	local currentVisible = false
	for _, player in Registry.CrewService.AlivePlayers() do
		local offAt = offTrainAt[player]
		if
			not Registry.CrewService.IsAboard(player)
			and holderOf(player) == nil
			and offAt ~= nil
			and clock - offAt >= grace
			and (hollow.scripted == nil or hollow.scripted == player)
		then
			local root = characterRoot(player)
			local away = hollow.model:GetAttribute("AwayStuds")
			if root and typeof(away) == "number" and StationService.ToLocal(root.Position).Z < away then
				root = nil -- a first run's stop-3 Stalker leaves anyone near the train alone
			end
			if root then
				local distance = (root.Position - position).Magnitude
				if wanderer or distance < A.SightRange then
					local visible = clearBetween(position, root.Position)
					if visible then
						Registry.TelemetryService.HollowSeen(player) -- first_hollow_seen (A.4)
					end
					if wanderer or visible or distance <= A.AwarenessRange then
						if player == current then
							currentRoot, currentDistance, currentVisible = root, distance, visible
						end
						if distance < bestDistance then
							best, bestRoot, bestDistance, bestVisible = player, root, distance, visible
						end
					end
				end
			end
		end
	end
	-- keep the target it has unless someone else is much nearer (the new one's warning is its own)
	if currentRoot and best ~= current and not Stalk.switches(currentDistance, bestDistance) then
		best, bestRoot, bestDistance, bestVisible = current, currentRoot, currentDistance, currentVisible
	end
	local stalking = hollow.stalk
	if stalking and (best ~= stalking.target or stalking.target.Parent == nil) then
		-- its prey was seized by another, left, or was given up for someone much nearer
		local seized = holderOf(stalking.target) ~= nil
		endStalk(hollow)
		if seized then
			setState(hollow, "Hunt")
		end
	end

	local edge = safeEdge()
	local ownLocal = StationService.ToLocal(position)
	if ownLocal.Z < edge then
		-- pushed into the light somehow: back out first
		endStalk(hollow)
		hollow.humanoid.WalkSpeed = walk
		hollow.humanoid:MoveTo(StationService.ToWorld(ownLocal.X, 3, edge + 8))
		setState(hollow, "Repelled")
		return
	end

	if best and bestRoot then
		hollow.target = best
		hollow.model:SetAttribute("Target", best.UserId) -- who its head follows (HollowAnimator)
		hollow.lastSeen = bestRoot.Position
		hollow.lastSeenAt = clock
		local targetLocal = StationService.ToLocal(bestRoot.Position)
		if targetLocal.Z < edge or isLit(bestRoot.Position) then
			endStalk(hollow)
			setState(hollow, "Repelled")
			hollow.humanoid.WalkSpeed = walk
			if targetLocal.Z < edge then
				hollow.humanoid:MoveTo(spaced(hollow, StationService.ToWorld(targetLocal.X, 3, edge + 2)))
			else
				hollow.humanoid:MoveTo(position)
			end
			return
		end

		-- Prowl -> Stalk, or straight to Hunt (Logic/Stalk)
		local settings = Stalk.settings((params :: Types.HazardParams).difficulty)
		if hollow.state ~= "Stalk" and hollow.state ~= "Hunt" then
			local stalker = hollow.model:GetAttribute("StalkWanderer") == true
			local commitsDirectly = (wanderer and not stalker) or hollow.scripted ~= nil
			-- straight to Hunt: wanderers, alerts and the scripted Crawler, prey already close, a stun's
			-- after-effect, a spent budget, or prey another Hollow already hunts (the pack fans out)
			if
				commitsDirectly
				or bestDistance <= settings.commitRange
				or clock < alertUntil
				or clock < hollow.noStalkUntil
				or not stalkBudget(hollow, best)
				or huntedByOther(best, hollow)
			then
				setState(hollow, "Hunt")
			elseif nearestFor(hollow, best, bestDistance) then
				hollow.stalked[best] = clock
				hollow.stalk = {
					target = best,
					track = Stalk.newTrack(),
					point = nil,
					searchAt = 0,
					unseenSince = nil,
				}
				hollow.model:SetAttribute("StalkTarget", best.UserId)
				setState(hollow, "Stalk")
			else
				-- another Hollow is nearer this prey: it stalks, this one keeps prowling
				setState(hollow, "Prowl")
				hollow.humanoid.WalkSpeed = walk
				prowl(hollow, clock)
				return
			end
		end

		if hollow.state == "Stalk" then
			local run = hollow.stalk :: StalkRun
			hollow.exposure[best] = Stalk.expose(hollow.exposure[best] or 0, dt, bestVisible, bestDistance)
			if bestVisible then
				run.unseenSince = nil
			elseif run.unseenSince == nil then
				run.unseenSince = clock
			end
			if run.unseenSince and clock - run.unseenSince >= A.Persistence then
				endStalk(hollow) -- lost: back to prowling, its stalk spent
				setState(hollow, "Prowl")
				hollow.target = nil
				hollow.model:SetAttribute("Target", nil)
				return
			end
			local faced = facedBy(bestRoot, position)
			local reason
			run.track, reason = Stalk.step(run.track, {
				dt = dt,
				faced = faced,
				alone = nearestCrewmate(best, bestRoot.Position) > settings.aloneRadius,
				lit = inLampPool(bestRoot.Position),
				distance = bestDistance,
				surge = clock < alertUntil,
				seized = false,
			}, settings)
			if reason then
				endStalk(hollow)
				setState(hollow, "Hunt")
			else
				hollow.model:SetAttribute("Frozen", faced or nil)
				if faced then
					-- held by a look: no step, no sound, only the breath and the head following
					hollow.humanoid.WalkSpeed = 0
					hollow.humanoid:MoveTo(position)
					return
				end
				if clock - run.searchAt >= Tuning.Stalk.ShadowRetry then
					run.searchAt = clock
					local point = run.point
					if point == nil or not Stalk.inBand((point - bestRoot.Position).Magnitude) then
						run.point = shadowPoint(hollow, bestRoot.Position)
					end
				end
				local point = run.point
				if point == nil then
					-- no legal shadow: hold, and look again next second (the stalk clock runs on)
					hollow.humanoid.WalkSpeed = 0
					hollow.humanoid:MoveTo(position)
				else
					hollow.humanoid.WalkSpeed = walk
					moveToward(hollow, spaced(hollow, point), false)
				end
				return
			end
		end

		setState(hollow, "Hunt")
		local exposure = hollow.exposure[best] or 0
		local guarded = Stalk.guarded(exposure)
		if guarded then
			-- the first-strike guard: coil where it can be seen, and earn the warning first
			hollow.exposure[best] = Stalk.expose(exposure, dt, bestVisible, bestDistance)
			guarded = Stalk.guarded(hollow.exposure[best])
		end
		hollow.model:SetAttribute("WarningCoil", guarded or nil)
		hollow.model:SetAttribute("WarningTarget", if guarded then best.UserId else nil)
		-- Intent (Prompt 3): the committed approach, in sight within LungeRange once the guard is met.
		-- It drives the coil on every client; it never delays an attack.
		local intent = not guarded and bestVisible and bestDistance <= H.LungeRange
		if intent ~= (hollow.model:GetAttribute("Intent") == true) then
			hollow.model:SetAttribute("Intent", intent or nil)
			if intent then
				hollow.model:SetAttribute("IntentAt", serverNow())
			end
		end

		-- a shut door between it and its prey: force it, if this stop's Hollows can
		local door = if bestVisible then nil else doorInWay(hollow, bestRoot.Position)
		if door and Registry.BuildingService.RequestForce(door, hollow) then
			hollow.door = door
			hollow.humanoid.WalkSpeed = 0
			hollow.humanoid:MoveTo(position)
			return
		end
		leaveDoor(hollow)

		local lunging = lungeSpeed > 0 and clock < hollow.lungeUntil
		if
			not guarded
			and not lunging
			and lungeSpeed > 0
			and bestVisible
			and bestDistance <= H.LungeRange
			and bestDistance > H.StrikeRange
			and clock - hollow.lastLunge >= H.LungeCooldown
		then
			hollow.lungeUntil = clock + lungeSeconds
			hollow.lastLunge = clock
			lunging = true
			hollow.model:SetAttribute("LungeAt", serverNow())
		end
		hollow.humanoid.WalkSpeed = if lunging then lungeSpeed else chase
		-- straight only on its own floor: prey seen up a stairwell is reached by the ramp
		local direct = bestVisible
			and math.abs(bestRoot.Position.Y - position.Y) < H.SameFloor
			and clock >= hollow.forcePathUntil
		if guarded then
			-- never deliberately inside GuardDistance: pace the prey from there, or hold and coil
			local away = flat(position - bestRoot.Position)
			if bestDistance > Tuning.Stalk.GuardDistance + 0.5 and away.Magnitude > 0.1 then
				moveToward(hollow, bestRoot.Position + away.Unit * Tuning.Stalk.GuardDistance, direct)
			else
				hollow.humanoid.WalkSpeed = 0
				hollow.humanoid:MoveTo(position)
			end
		else
			moveToward(hollow, approach(hollow, best, bestRoot.Position, bestDistance), direct)
			if
				bestDistance <= H.StrikeRange * hollow.def.reach
				and math.abs(bestRoot.Position.Y - position.Y) < 8
				and clock - hollow.lastStrike >= A.StrikeCooldown
				and (graceUntil[best] or 0) <= clock
			then
				strikeAttempt(hollow, best, bestRoot)
			end
		end
	elseif hollow.lastSeen and clock - hollow.lastSeenAt < A.Persistence and hollow.state ~= "Stalk" then
		-- lost sight: search where it saw them last
		setState(hollow, "Hunt")
		hollow.model:SetAttribute("WarningCoil", nil)
		hollow.humanoid.WalkSpeed = chase * 0.85
		moveToward(hollow, spaced(hollow, hollow.lastSeen :: Vector3), false)
		if (position - (hollow.lastSeen :: Vector3)).Magnitude < 4 then
			hollow.lastSeen = nil
		end
	else
		endStalk(hollow)
		leaveDoor(hollow)
		setState(hollow, "Prowl")
		hollow.target = nil
		hollow.model:SetAttribute("Target", nil)
		hollow.model:SetAttribute("WarningCoil", nil)
		hollow.humanoid.WalkSpeed = walk
		prowl(hollow, clock)
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

	-- milling in one spot while hunting (pressed against a ramp's side): drop the path and
	-- follow a fresh one for a while, even with the target in sight
	if hollow.state == "Hunt" and (position - hollow.stallAt).Magnitude < H.StallRadius then
		if clock - hollow.stallSince > H.StallSeconds then
			hollow.path = nil
			hollow.pathAt = 0
			hollow.forcePathUntil = clock + H.StallRepath
			hollow.stallAt = position
			hollow.stallSince = clock
		end
	else
		hollow.stallAt = position
		hollow.stallSince = clock
	end
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
		stallAt = at.Position,
		stallSince = os.clock(),
		forcePathUntil = 0,
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
		stalk = nil,
		exposure = {},
		stalked = {},
		noStalkUntil = 0,
		lastThink = os.clock(),
		door = nil,
		sighting = nil,
	}
	table.insert(hollows, hollow)
	return hollow
end

-- Tutorial ------------------------------------------------------------------------------------

-- Open ground of the stop for the teaching Crawler: the yard's own floor (not a roof, not a
-- building, not a fallen slab), inside the edge's hazard rail and clear of the platform.
local function openGround(position: Vector3): boolean
	local plan = StationService.Plan()
	if plan == nil then
		return false
	end
	local p = StationService.ToLocal(position)
	local margin = Stations.Edge.TapeBack + 1
	if
		math.abs(p.Y) > 2.5
		or math.abs(p.X) > plan.length / 2 - margin
		or p.Z < Tuning.World.SafeStrip + 4
		or p.Z > plan.depth - margin
	then
		return false
	end
	local slab = LayoutGen.slabAt(plan, p.X, p.Z)
	return slab ~= nil and slab.kind == "Floor" and not StationService.IsCollapsed(slab.id)
end

-- Claws a slow Crawler up behind `player` to teach the skill check (Config/Tutorial ScriptedGrab),
-- out of the dark on the stop's open ground: behind first, then the sides, then ahead.
local function spawnScripted(player: Player): Hollow?
	local root = characterRoot(player)
	if root == nil then
		return nil
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local forward = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
	local right = forward:Cross(Vector3.yAxis)
	local height = HollowBuilder.rootHeight(T.ScriptedGrab.Kind)
	local sides = {
		-forward,
		(-forward + right).Unit,
		(-forward - right).Unit,
		right,
		-right,
		(forward + right).Unit,
		(forward - right).Unit,
		forward,
	}
	for _, scale in { 1, 0.7, 1.3 } do
		for _, side in sides do
			local guess = root.Position + side * T.ScriptedGrab.Distance * scale
			local ground = Workspace:Raycast(guess + Vector3.yAxis * 12, -Vector3.yAxis * 40, sightParams)
			if
				ground
				and ground.Normal.Y > 0.6
				and openGround(ground.Position)
				and not safeLightAt(ground.Position)
			then
				local at = ground.Position + Vector3.yAxis * height
				local face = Vector3.new(root.Position.X, at.Y, root.Position.Z)
				local hollow = add(CFrame.lookAt(at, face), T.ScriptedGrab.Kind, "Emerge", "Rise")
				hollow.scripted = player
				hollow.model:SetAttribute("Scripted", true)
				return hollow
			end
		end
	end
	return nil
end

-- Stop 1's sighting -------------------------------------------------------------------------

-- Clear of every light's pool by Sighting.LampMargin: the point and four around it are all dark.
local function darkAround(point: Vector3): boolean
	local margin = T.Sighting.LampMargin
	for _, offset in
		{
			Vector3.zero,
			Vector3.xAxis * margin,
			-Vector3.xAxis * margin,
			Vector3.zAxis * margin,
			-Vector3.zAxis * margin,
		}
	do
		if inLampPool(point + offset) then
			return false
		end
	end
	return true
end

-- A spot for the sighting: in sight of `root`, dark around, on the ground. 15-17 studs if any fits,
-- else the nearest legal spot up to 24.
local function sightingSpot(root: BasePart): Vector3?
	local look = flat(root.CFrame.LookVector)
	local base = if look.Magnitude > 0.1 then math.atan2(look.X, look.Z) else 0
	local function search(distances: { number }): Vector3?
		for _, distance in distances do
			for i = 0, 23 do
				-- ahead first, sweeping out to the sides and round behind
				local turn = (if i % 2 == 0 then 1 else -1) * math.ceil(i / 2) * math.rad(15)
				local angle = base + turn
				local guess = root.Position + Vector3.new(math.sin(angle), 0, math.cos(angle)) * distance
				local ground = Workspace:Raycast(guess + Vector3.yAxis * 12, -Vector3.yAxis * 40, sightParams)
				if ground and ground.Normal.Y > 0.6 and math.abs(ground.Position.Y - root.Position.Y) < 6 then
					local point = ground.Position
					if darkAround(point) and clearBetween(point, root.Position) then
						return point
					end
				end
			end
		end
		return nil
	end
	local near, far, fallback = T.Sighting.Near, T.Sighting.Far, T.Sighting.Fallback
	local preferred = search({ (near + far) / 2, near, far })
	if preferred then
		return preferred
	end
	local outward: { number } = {}
	for distance = far + 1, fallback do
		table.insert(outward, distance)
	end
	for distance = near - 1, 4, -1 do
		table.insert(outward, distance)
	end
	table.sort(outward, function(a, b)
		return math.abs(a - (near + far) / 2) < math.abs(b - (near + far) / 2)
	end)
	return search(outward)
end

local function spawnSighting(player: Player): Hollow?
	local root = characterRoot(player)
	if root == nil then
		return nil
	end
	local spot = sightingSpot(root)
	if spot == nil then
		return nil
	end
	local kind = T.Sighting.Kind
	local at = spot + Vector3.yAxis * HollowBuilder.rootHeight(kind)
	local hollow =
		add(CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)), kind, "Stalk", nil)
	hollow.sighting = { track = Sighting.new(), lastAt = os.clock(), withdrawAt = nil, away = nil }
	hollow.model:SetAttribute("Sighting", true)
	hollow.model:SetAttribute("Frozen", true)
	hollow.model:SetAttribute("Target", player.UserId)
	hollow.humanoid.WalkSpeed = 0
	return hollow
end

-- The sighting holds its Stalk freeze until Logic/Sighting lets it go, then walks into the dark and
-- is gone. It never hunts, strikes or grabs. Each crew member's line-of-sight seconds go to
-- telemetry (sighting_exposure: an opportunity to see it, not proof they noticed).
sightingThink = function(hollow: Hollow, dt: number)
	local run = hollow.sighting :: SightingRun
	local position = hollow.root.Position
	if run.withdrawAt then
		if os.clock() - run.withdrawAt >= T.Sighting.WithdrawSeconds then
			HollowService.Dismiss(hollow.model)
		end
		return
	end
	local watchers: { Sighting.Watcher } = {}
	local nearest: Player? = nil
	local nearestDistance = math.huge
	for _, player in Registry.CrewService.AlivePlayers() do
		local root = characterRoot(player)
		if root then
			local sight = clearBetween(position, root.Position)
			local distance = (root.Position - position).Magnitude
			if sight then
				Registry.TelemetryService.HollowSeen(player)
			end
			table.insert(watchers, {
				id = player.UserId,
				offTrain = not Registry.CrewService.IsAboard(player),
				sight = sight,
				facing = sight and facedBy(root, position),
			})
			if distance < nearestDistance then
				nearest, nearestDistance = player, distance
			end
		end
	end
	if nearest then
		hollow.model:SetAttribute("Target", nearest.UserId) -- the head follows the nearest watcher
	end
	local reason
	run.track, reason = Sighting.step(run.track, dt, watchers)
	if reason == nil then
		return
	end
	-- withdraw: back into the dark at walking pace, away from the train
	for _, player in Registry.CrewService.AlivePlayers() do
		Registry.TelemetryService.Sighting(player, run.track.seen[player.UserId] or 0)
	end
	run.withdrawAt = os.clock()
	local here = StationService.ToLocal(position)
	run.away = StationService.ToWorld(here.X, 3, here.Z + 60)
	hollow.model:SetAttribute("Frozen", nil)
	hollow.model:SetAttribute("Target", nil)
	setState(hollow, "Prowl")
	hollow.humanoid.WalkSpeed = (params :: Types.HazardParams).hollowWalk * hollow.def.walk
	moveToward(hollow, run.away :: Vector3, false)
end

-- Notes who has stepped off the train at this stop, and sends the teaching Crawler when due.
local function tutorialStep()
	local clock = os.clock()
	for _, player in Registry.CrewService.AlivePlayers() do
		if not Registry.CrewService.IsAboard(player) then
			if offTrainAt[player] == nil then
				offTrainAt[player] = clock
			end
			if sightingPending and clock >= sightingTryAt then
				-- a crew member off the train: the sighting appears in their sight, looking again
				-- every RetrySeconds while no dark spot is in view (lamps, walls)
				sightingTryAt = clock + T.Sighting.RetrySeconds
				if spawnSighting(player) then
					sightingPending = false
				end
			end
		end
	end
	if not scripted.pending or scripted.hollow ~= nil then
		return
	end
	local tier = tutorialTier()
	local due = (if tier then tier.grace else 0) + T.ScriptedGrab.AfterGrace
	for player, offAt in offTrainAt do
		local root = characterRoot(player)
		if
			clock - offAt >= due
			and root
			and Registry.CrewService.IsAlive(player)
			and not Registry.CrewService.IsAboard(player)
			and holderOf(player) == nil
			and not safeLightAt(root.Position)
		then
			scripted.hollow = spawnScripted(player)
			return
		end
	end
end

-- Lifecycle -----------------------------------------------------------------------------------

function HollowService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Hollows"
	folder.Parent = Workspace
end

function HollowService.Start()
	StationService.Cleared:Connect(HollowService.Clear)
	-- One press for skill check `id`, made at server time `pressedAt` on the victim's screen:
	-- judged at that instant, trusted within the ping tolerance of its arrival (judgePress).
	NetService.Handle("SkillCheck", function(player, id: number, pressedAt: number)
		local hollow = holderOf(player)
		if hollow == nil or params == nil then
			return
		end
		local hold = hollow.hold :: Hold
		if hold.diedAt then
			return
		end
		local now = serverNow()
		local ok = SkillCheck.accept(hold.check, hold.judged, id, now, hold.lastPressAt)
		hold.lastPressAt = now
		if not ok then
			return
		end
		local ping = 0
		pcall(function()
			ping = player:GetNetworkPing()
		end)
		judgeCheck(
			hollow,
			SkillCheck.judgePress(hold.check :: SkillCheck.Check, pressedAt, now, SkillCheck.tolerance(ping))
		)
	end)
	Players.PlayerRemoving:Connect(function(player)
		graceUntil[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1 / H.ThinkHz)
			if params then
				refreshSightFilter()
				Safe.call("HollowService.tutorial", tutorialStep)
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
	wandererPending = hazards.hollowCap > 0 and not hazards.dormantStart
	local tier = Tutorial.def(hazards.tutorial)
	lightScale = if tier then tier.safeLightScale else 0
	safeLights = {}
	for _, part in CollectionService:GetTagged(T.SafeLight.Tag) do
		if part:IsA("BasePart") then
			table.insert(safeLights, part)
		end
	end
	if Registry.TrainService then
		Registry.TrainService.SetSafeGlow(lightScale > 0)
	end
	table.clear(offTrainAt)
	scripted = {
		pending = tier ~= nil and tier.scriptedGrab and (hazards.stop or 1) == T.ScriptedGrab.Stop,
		hollow = nil,
	}
	-- E2's arm when it runs (hazards.sighting), else the Config/Tutorial flag
	local sightingOn = if hazards.sighting ~= nil then hazards.sighting else T.Sighting.Enabled
	sightingPending = tier ~= nil and tier.sighting and sightingOn and (hazards.stop or 1) == 1
end

-- Retain planned sleepers and fill larger buildings with distinct, clear interior spots.
function HollowService.Prepare(plan: LayoutGen.Plan)
	local p = params
	if p == nil or p.hollowCap <= 0 or p.scriptedOnly then
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
	-- sleepers share the stop's budget with the fog spawns and the wanderer
	placement:shuffle(sleepers)
	for i, sleeper in sleepers do
		if i > (if p.dormantStart then p.hollowCap else HollowBudget.sleepers(p.hollowCap)) then
			break
		end
		local height = HollowBuilder.rootHeight(sleeper.kind)
		local position = StationService.ToWorld(sleeper.x, sleeper.y + height, sleeper.z)
		local facing = StationService.ToWorld(
			sleeper.x - math.sin(math.rad(sleeper.rot)),
			sleeper.y + height,
			sleeper.z - math.cos(math.rad(sleeper.rot))
		)
		local hollow = add(CFrame.lookAt(position, facing), sleeper.kind, "Dormant", nil)
		hollow.stirAt = if p.dormantStart then math.huge else p.dwell * H.SleeperStir * rng:NextNumber(1, 1.6)
	end
end

-- Every Hollow at the stop, sleepers included: the stop's budget covers them all.
function HollowService.Count(): number
	return #hollows
end

-- Spawns one Hollow near station-local (x, z) if the cap allows and the ground holds.
-- Some climb up over the far edge out of the dark instead. `kind` forces its kind (Studio).
-- An `extra` (a timed event's) ignores the cap. Returns the new Hollow's model too.
function HollowService.TrySpawn(
	x: number,
	z: number,
	kind: string?,
	wanderer: boolean?,
	extra: boolean?
): (boolean, Model?)
	local p = params
	local plan = StationService.Plan()
	if
		p == nil
		or plan == nil
		or (
			not extra
			and HollowService.Count() >= p.hollowCap - (if wandererPending and not wanderer then 1 else 0)
		)
	then
		return false, nil
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
		return false, nil
	end
	local chosen = if kind and (Tuning.HollowKinds :: any)[kind] then kind else pickKind()
	local height = HollowBuilder.rootHeight(chosen)
	local localZ = if fromEdge then plan.depth - 3 else slab.z
	local position = StationService.ToWorld(slab.x, height, localZ)
	if safeLightAt(position) then
		return false, nil
	end
	local facing = StationService.ToWorld(slab.x, height, 0)
	local hollow =
		add(CFrame.lookAt(position, facing), chosen, "Emerge", if fromEdge then "Climb" else "Rise")
	if wanderer then
		hollow.model:SetAttribute("Wanderer", true)
		wandererPending = false
	end
	return true, hollow.model
end

-- A Surge: every Hollow at the stop wakes and hunts the nearest crew member for `seconds`.
function HollowService.Alert(seconds: number)
	alertUntil = os.clock() + seconds
	for _, hollow in hollows do
		if hollow.state == "Dormant" then
			wake(hollow)
		end
	end
end

function HollowService.EndAlert()
	alertUntil = 0
end

-- Removes the Hollow `model` unless it is mid-attack (winding up or holding someone),
-- in which case it stays and carries on as an ordinary Hollow. True if it was removed.
function HollowService.Dismiss(model: Model): boolean
	for i, hollow in hollows do
		if hollow.model == model then
			if hollow.hold or hollow.state == "Windup" then
				return false
			end
			model:Destroy()
			table.remove(hollows, i)
			return true
		end
	end
	return false
end

-- Freezes every Hollow within `radius` studs; any it was holding drops free. Returns how many.
function HollowService.Stun(position: Vector3, radius: number, seconds: number): number
	local count = 0
	for _, hollow in hollows do
		if hollow.state ~= "Dormant" and (hollow.root.Position - position).Magnitude <= radius then
			hollow.stunnedUntil = os.clock() + seconds
			hollow.noStalkUntil = hollow.stunnedUntil + Tuning.Stalk.StunExclusion
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

-- Studio: an ordinary (not wandering) Hollow of `kind` on the ground `distance` studs from `player`
-- (ahead if there is ground there, else to a side or behind), prowling, so stalks and the first-strike guard can be checked at a known range.
function HollowService.DevSpawnAt(player: Player, kind: string?, distance: number): boolean
	local root = characterRoot(player)
	if params == nil or root == nil or StationService.Plan() == nil then
		return false
	end
	local chosen = if kind and (Tuning.HollowKinds :: any)[kind] then kind else pickKind()
	local look = flat(root.CFrame.LookVector)
	local forward = if look.Magnitude > 0.1 then look.Unit else Vector3.zAxis
	local right = forward:Cross(Vector3.yAxis)
	local ground: RaycastResult? = nil
	for _, side in { forward, right, -right, -forward } do
		local guess = root.Position + side * distance
		local hit = Workspace:Raycast(guess + Vector3.yAxis * 12, -Vector3.yAxis * 40, sightParams)
		if hit and hit.Normal.Y > 0.6 and math.abs(hit.Position.Y - root.Position.Y) < 8 then
			ground = hit
			break
		end
	end
	if ground == nil then
		return false
	end
	local at = ground.Position + Vector3.yAxis * HollowBuilder.rootHeight(chosen)
	local hollow =
		add(CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)), chosen, "Prowl", nil)
	hollow.root.Anchored = false
	hollow.model:SetAttribute("DevSpawn", true)
	return true
end

-- A first run's stop 3 (Prompt 5): one Stalker that wanders and stalks, and only goes for a player
-- Stop3.AwayStuds or more from the train.
function HollowService.SpawnStalkingWanderer(plan: LayoutGen.Plan)
	for _, lane in plan.spawnLanes do
		local ok, model = HollowService.TrySpawn(lane, plan.depth / 2, T.Stop3.Kind, true)
		if ok and model then
			model:SetAttribute("StalkWanderer", true)
			model:SetAttribute("AwayStuds", T.Stop3.AwayStuds)
			return
		end
	end
end

-- Whether light keeps Hollows off `position` (a lit building, a tutorial SafeLight).
function HollowService.IsLit(position: Vector3): boolean
	return isLit(position)
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
	table.clear(budgetAt)
	table.clear(offTrainAt)
	alertUntil = 0
	params = nil
	wandererPending = false
	lightScale = 0
	scripted = { pending = false, hollow = nil }
	sightingPending = false
	if Registry.TrainService then
		Registry.TrainService.SetSafeGlow(false)
	end
end

return HollowService
