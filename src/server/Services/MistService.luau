--!strict
--[[
	The void mist's server side (prompts/VM2, VM3; rules in Logic/VoidMist):
	  * fall rescue: each living crew member off the train keeps a last safe spot (grounded, out of
	    the edge mist), sampled every SafeSampleInterval in station-local space because the station
	    moves; anyone KillDrop under the station ground is put back there with RescueDamage
	  * edge mist damage: the BufferDepth strip in front of each sinkhole rail hurts after
	    EntryGrace, DamagePerSecond in TickInterval ticks; never on top of the fog's own damage
	  * the player attribute MistZone: "Edge", "Fog" or nil, for the client and debugging
	The rail itself (StationDressing EdgeMark, WallHeight tall) is the hard stop; the client's
	VoidCurrentController is only feel. The server never sets crew velocity except to zero it once
	on a rescue teleport.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local TutorialConfig = require(Shared.Config.Tutorial)
local VoidMist = require(Shared.Logic.VoidMist)
local Safe = require(Shared.Util.Safe)
local Registry = require(script.Parent.Parent.Registry)

local V = Tuning.VoidMist

local MistService = {}

type Track = {
	character: Model?,
	safe: Vector3?, -- station-local
	enteredAt: number?, -- in the edge mist since
}

local tracks: { [Player]: Track } = {}
local zones: { VoidMist.Zone } = {}
local zonesFor: Model? = nil -- the station model the zones were read from
local sampleAt = 0
local tickAt = 0

-- The edge zones of the station standing now, in station-local space.
local function refreshZones()
	local built = Registry.StationService.Built()
	local model = built and built.model
	if model == zonesFor then
		return
	end
	zonesFor = model
	table.clear(zones)
	if model == nil then
		return
	end
	local frame = Registry.StationService.Frame()
	for _, rail in CollectionService:GetTagged(TutorialConfig.EdgeTag) do
		if rail:IsA("BasePart") and rail:IsDescendantOf(model) then
			local at = frame:PointToObjectSpace(rail.Position)
			local facing = frame:VectorToObjectSpace(rail.CFrame.LookVector)
			table.insert(zones, VoidMist.zone(at.X, at.Z, facing.X, facing.Z, rail.Size.X))
		end
	end
end

local function inEdge(x: number, z: number): boolean
	for _, zone in zones do
		if VoidMist.isInside(zone, x, z) then
			return true
		end
	end
	return false
end

local function trackOf(player: Player): Track
	local track = tracks[player]
	if track == nil then
		track = { character = nil }
		tracks[player] = track
	end
	return track
end

local function clear(player: Player)
	tracks[player] = nil
	player:SetAttribute("MistZone", nil)
end

-- Off the train, alive and on a standing station: (character, root, humanoid) or nil.
local function onStation(player: Player): (Model?, BasePart?, Humanoid?)
	if not Registry.StationService.IsActive() or Registry.CrewService.IsAboard(player) then
		return nil, nil, nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or root == nil or humanoid == nil or humanoid.Health <= 0 or root.Anchored then
		return nil, nil, nil
	end
	return character, root, humanoid
end

local function rescue(player: Player, character: Model, root: BasePart, humanoid: Humanoid)
	local track = trackOf(player)
	local target = if track.safe
		then CFrame.new(Registry.StationService.ToWorld(track.safe.X, track.safe.Y + 3, track.safe.Z))
		else Registry.StationService.StragglerSpawn()
	local here = Registry.StationService.ToLocal(root.Position) -- where they fell, for the log
	character:PivotTo(target)
	root.AssemblyLinearVelocity = Vector3.zero
	track.enteredAt = nil
	if not Registry.DevService.IsGod(player) then
		Registry.CrewService.TagDamage(character, "Fog")
		humanoid:TakeDamage(V.RescueDamage)
	end
	Registry.NetService.Fire("Fx", player, "MistRescue", {})
	local pingMs = player:GetNetworkPing() * 1000
	warn(
		`[VoidMist] rescued {player.Name} fallen at local ({math.floor(here.X)}, {math.floor(here.Z)}), ping {math.floor(
			pingMs
		)} ms`
	)
	Registry.TelemetryService.MistRescue(player, pingMs)
end

local function step()
	refreshZones()
	local now = os.clock()
	local sample = now >= sampleAt
	if sample then
		sampleAt = now + V.SafeSampleInterval
	end
	local tick = now >= tickAt
	if tick then
		tickAt = now + V.TickInterval
	end
	local fog = if tick then Registry.HazardDirector.FogFront() else nil
	local alive = Registry.CrewService.AlivePlayers()
	local aliveSet: { [Player]: boolean } = {}
	for _, player in alive do
		aliveSet[player] = true
	end
	for player in tracks do
		if not aliveSet[player] then
			clear(player)
		end
	end
	for _, player in alive do
		local character, root, humanoid = onStation(player)
		if character == nil or root == nil or humanoid == nil then
			if tracks[player] then
				clear(player)
			end
			continue
		end
		local track = trackOf(player)
		if track.character ~= character then
			clear(player)
			track = trackOf(player)
			track.character = character
		end
		local here = Registry.StationService.ToLocal(root.Position)
		if here.Y < -V.KillDrop then
			rescue(player, character, root, humanoid)
			continue
		end
		local edge = inEdge(here.X, here.Z)
		if sample and not edge and humanoid.FloorMaterial ~= Enum.Material.Air then
			track.safe = here
		end
		if tick then
			local fogged = fog ~= nil and here.Z > fog
			player:SetAttribute("MistZone", if fogged then "Fog" elseif edge then "Edge" else nil)
			if not edge then
				track.enteredAt = nil
			elseif track.enteredAt == nil then
				track.enteredAt = now
			elseif
				not fogged
				and now - track.enteredAt >= V.EntryGrace
				and not Registry.DevService.IsGod(player)
			then
				-- the fog's own damage (HazardDirector) already covers anyone past its front
				Registry.CrewService.TagDamage(character, "Fog")
				humanoid:TakeDamage(V.DamagePerSecond * V.TickInterval)
				Registry.NetService.Fire("Fx", player, "FogTick", {})
			end
		end
	end
end

function MistService.Init() end

function MistService.Start()
	RunService.Heartbeat:Connect(function()
		Safe.call("MistService.step", step)
	end)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
end

return MistService
