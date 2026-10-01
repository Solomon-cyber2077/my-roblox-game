--!strict
--[[
	Hollows: the creatures that walk out of the fog. One think loop drives all of
	them at ThinkHz. They cannot be killed, only outrun or stunned, and they never
	enter the lit band beside the train (the safe band, widened by Floodlamps).

	States
	  Prowl     no target: drift toward a random point between the light and the fog
	  Hunt      chase the nearest visible crew member off the train; strike in range
	  Repelled  the target stands in the light: hold at its edge
	  Stunned   frozen by a Flashbulb
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local LayoutGen = require(Shared.Logic.LayoutGen)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local HollowBuilder = require(script.Parent.Parent.Builders.HollowBuilder)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StationService = require(script.Parent.StationService)

type Hollow = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	state: string,
	lastStrike: number,
	stunnedUntil: number,
	wanderUntil: number,
	lastPosition: Vector3,
	stuckSince: number,
}

local HollowService = {}

local hollows: { Hollow } = {}
local params: Types.HazardParams? = nil
local folder: Folder
local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function canSee(from: Vector3, to: Vector3): boolean
	local filter: { Instance } = { folder }
	for _, player in game:GetService("Players"):GetPlayers() do
		if player.Character then
			table.insert(filter, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = filter
	local result = Workspace:Raycast(from + Vector3.new(0, 2, 0), (to - from), rayParams)
	return result == nil
end

local function safeEdge(): number
	local p = params :: Types.HazardParams
	return p.safeBand + Tuning.Hollow.SafeMargin
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

local function strike(hollow: Hollow, player: Player)
	local p = params :: Types.HazardParams
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	hollow.lastStrike = os.clock()
	if Registry.DevService.IsGod(player) then
		return
	end
	character:SetAttribute("LastDamageSource", "Hollow")
	humanoid:TakeDamage(p.hollowDamage)
	NetService.Fire("Fx", player, "Hit", { from = hollow.root.Position, damage = p.hollowDamage })
	NetService.FireAll("Fx", "HollowStrike", { position = hollow.root.Position })
end

local function think(hollow: Hollow)
	local p = params :: Types.HazardParams
	local position = hollow.root.Position
	local clock = os.clock()

	if clock < hollow.stunnedUntil then
		hollow.state = "Stunned"
		hollow.humanoid.WalkSpeed = 0
		hollow.humanoid:MoveTo(position)
		return
	end

	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	for _, player in Registry.CrewService.AlivePlayers() do
		if not Registry.CrewService.IsAboard(player) then
			local root = characterRoot(player)
			if root then
				local distance = (root.Position - position).Magnitude
				if distance < Tuning.Hollow.SightRange and distance < bestDistance then
					if distance <= Tuning.Hollow.AwarenessRange or canSee(position, root.Position) then
						best, bestRoot, bestDistance = player, root, distance
					end
				end
			end
		end
	end

	local edge = safeEdge()
	local ownLocal = StationService.ToLocal(position)
	if ownLocal.Z < edge then
		-- Pushed into the light somehow: back out first.
		hollow.humanoid.WalkSpeed = p.hollowWalk
		hollow.humanoid:MoveTo(StationService.ToWorld(ownLocal.X, 3, edge + 8))
		hollow.state = "Repelled"
		return
	end

	if best and bestRoot then
		local targetLocal = StationService.ToLocal(bestRoot.Position)
		if targetLocal.Z < edge then
			hollow.state = "Repelled"
			hollow.humanoid.WalkSpeed = p.hollowWalk
			hollow.humanoid:MoveTo(StationService.ToWorld(targetLocal.X, 3, edge + 2))
		else
			hollow.state = "Hunt"
			hollow.humanoid.WalkSpeed = p.hollowChase
			hollow.humanoid:MoveTo(bestRoot.Position)
			if
				bestDistance <= Tuning.Hollow.StrikeRange
				and clock - hollow.lastStrike >= Tuning.Hollow.StrikeCooldown
			then
				strike(hollow, best)
			end
		end
	else
		hollow.state = "Prowl"
		hollow.humanoid.WalkSpeed = p.hollowWalk
		if clock >= hollow.wanderUntil then
			local point = wanderPoint()
			if point then
				hollow.humanoid:MoveTo(point)
			end
			hollow.wanderUntil = clock + rng:NextNumber(3, 6)
		end
	end

	-- Stuck on a building corner: sidestep.
	if (position - hollow.lastPosition).Magnitude < 0.4 and hollow.state ~= "Repelled" then
		if clock - hollow.stuckSince > 1.2 then
			local side = hollow.root.CFrame.RightVector * (if rng:NextNumber() > 0.5 then 8 else -8)
			hollow.humanoid:MoveTo(position + side)
			hollow.stuckSince = clock
		end
	else
		hollow.stuckSince = clock
	end
	hollow.lastPosition = position
end

function HollowService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Hollows"
	folder.Parent = Workspace
end

function HollowService.Start()
	StationService.Cleared:Connect(HollowService.Clear)
	task.spawn(function()
		while true do
			task.wait(1 / Tuning.Hollow.ThinkHz)
			if params then
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

function HollowService.Count(): number
	return #hollows
end

-- Spawns one Hollow near station-local (x, z) if the cap allows and the ground holds.
function HollowService.TrySpawn(x: number, z: number): boolean
	local p = params
	local plan = StationService.Plan()
	if p == nil or plan == nil or #hollows >= p.hollowCap then
		return false
	end
	local slab = LayoutGen.slabAt(plan, x, z)
	local tries = 0
	while (slab == nil or slab.kind ~= "Floor" or StationService.IsCollapsed(slab.id)) and tries < 8 do
		tries += 1
		z -= plan.tile
		x += rng:NextNumber(-6, 6)
		slab = LayoutGen.slabAt(plan, x, z)
	end
	if slab == nil or slab.kind ~= "Floor" or z < safeEdge() + 10 then
		return false
	end
	local position = StationService.ToWorld(slab.x, 4.6, slab.z)
	local model, humanoid =
		HollowBuilder.build(CFrame.lookAt(position, Vector3.new(position.X, position.Y, 0)))
	model.Parent = folder
	local root = model.PrimaryPart :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	humanoid.WalkSpeed = p.hollowWalk
	table.insert(hollows, {
		model = model,
		humanoid = humanoid,
		root = root,
		state = "Prowl",
		lastStrike = 0,
		stunnedUntil = 0,
		wanderUntil = 0,
		lastPosition = position,
		stuckSince = os.clock(),
	})
	NetService.FireAll("Fx", "HollowSpawn", { position = position })
	return true
end

-- Freezes every Hollow within `radius` studs. Returns how many were caught.
function HollowService.Stun(position: Vector3, radius: number, seconds: number): number
	local count = 0
	for _, hollow in hollows do
		if (hollow.root.Position - position).Magnitude <= radius then
			hollow.stunnedUntil = os.clock() + seconds
			hollow.model:SetAttribute("StunnedUntil", Workspace:GetServerTimeNow() + seconds)
			count += 1
		end
	end
	return count
end

function HollowService.Clear()
	for _, hollow in hollows do
		hollow.model:Destroy()
	end
	table.clear(hollows)
	params = nil
end

return HollowService
