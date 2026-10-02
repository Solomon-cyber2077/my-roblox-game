--!strict
--[[
	Routes server Fx and Notify events to UI, camera, audio and world effects,
	and turns phase changes into the alerts that frame each stop.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Items = require(Shared.Config.Items)
local Format = require(Shared.Util.Format)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Overlay = require(script.Parent.Parent.UI.Overlay)
local Spectate = require(script.Parent.Parent.UI.Spectate)
local Summary = require(script.Parent.Parent.UI.Summary)
local Theme = require(script.Parent.Parent.UI.Theme)

local FxController = {}

local effects: Folder

local function audio(cue: string, position: Vector3?)
	local controller = Registry.AudioController
	if controller then
		controller.Play(cue, position)
	end
end

local function part(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cframe
	p.Shape = shape or Enum.PartType.Block
	p.Parent = effects
	return p
end

local function burst(
	position: Vector3,
	color: Color3,
	texture: string,
	count: number,
	speed: number,
	size: number
)
	local holder = part(Vector3.one * 0.2, CFrame.new(position), color)
	holder.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.5) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 3)
end

local function flare(position: Vector3)
	local rocket =
		part(Vector3.one * 1.2, CFrame.new(position), Color3.fromRGB(255, 70, 50), Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 70, 50)
	light.Range = 60
	light.Brightness = 6
	light.Parent = rocket
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.4, 0)
	a0.Parent = rocket
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.4, 0)
	a1.Parent = rocket
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 1.2
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 120, 80), Color3.fromRGB(120, 40, 30))
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.LightEmission = 1
	trail.Parent = rocket
	local apex = position + Vector3.new(0, 140, 0)
	TweenService
		:Create(
			rocket,
			TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = apex }
		)
		:Play()
	audio("FlareLaunch", position)
	task.delay(1.6, function()
		burst(
			apex,
			Color3.fromRGB(255, 90, 60),
			"rbxasset://textures/particles/sparkles_main.dds",
			120,
			40,
			1.2
		)
		TweenService:Create(light, TweenInfo.new(3), { Brightness = 0, Range = 160 }):Play()
		TweenService:Create(
			rocket,
			TweenInfo.new(3, Enum.EasingStyle.Linear),
			{ Position = apex - Vector3.new(0, 30, 0), Transparency = 1 }
		):Play()
		audio("FlareBurst", apex)
		if Registry.AtmosphereController then
			Registry.AtmosphereController.FlareFlash()
		end
		Debris:AddItem(rocket, 3.2)
	end)
end

local function flash(position: Vector3, radius: number)
	local sphere =
		part(Vector3.one * 2, CFrame.new(position), Color3.fromRGB(255, 250, 228), Enum.PartType.Ball)
	sphere.Transparency = 0.2
	local light = Instance.new("PointLight")
	light.Range = radius * 2
	light.Brightness = 10
	light.Color = Color3.fromRGB(255, 250, 228)
	light.Parent = sphere
	TweenService:Create(
		sphere,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad),
		{ Size = Vector3.one * radius * 2, Transparency = 1 }
	):Play()
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	Debris:AddItem(sphere, 0.7)
	audio("Flash", position)
end

local function onFx(kind: string, data: { [string]: any }?)
	local d: { [string]: any } = data or {}
	if kind == "Deposit" then
		if (d.coal or 0) > 0 then
			Overlay.popup(`+{d.coal} COAL`, Theme.Color.brassLight)
		end
		if (d.parts or 0) > 0 then
			Overlay.popup(`+{d.parts} PARTS`, Theme.Color.parts)
		end
		if (d.relicBrass or 0) > 0 then
			Overlay.popup(`+{d.relicBrass} BRASS BANKED`, Theme.Color.go)
		end
		audio("Deposit")
	elseif kind == "Found" then
		local names = {}
		for _, itemId in d.items or {} do
			table.insert(names, Items[itemId] and Items[itemId].name or itemId)
		end
		if #names > 0 then
			Overlay.popup(table.concat(names, " · "), Theme.Color.paper)
		end
		if d.leftovers and #d.leftovers > 0 then
			Overlay.feed(
				"Warning",
				`Backpack full: {#d.leftovers} item{if #d.leftovers > 1 then "s" else ""} left on the ground.`
			)
		end
		audio("Loot")
	elseif kind == "Heal" then
		Overlay.pulse(Theme.Color.go, 0.5, 0.8)
		audio("Heal")
	elseif kind == "Flash" then
		flash(d.position, d.radius or 18)
	elseif kind == "Hit" then
		Overlay.pulse(Theme.Color.signal, 0.75, 0.6)
		Registry.CameraController.Shake(if d.knockback then 1.2 else 0.7)
		Registry.MovementController.ApplyHitSlow()
		if typeof(d.knockback) == "Vector3" then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.AssemblyLinearVelocity += d.knockback
			end
		end
		audio("Hit")
	elseif kind == "FogTick" then
		Overlay.pulse(Color3.fromRGB(110, 120, 104), 0.35, 0.4)
	elseif kind == "HollowSpawn" then
		burst(
			d.position,
			Color3.fromRGB(24, 22, 26),
			"rbxasset://textures/particles/smoke_main.dds",
			24,
			6,
			3
		)
		audio("HollowSpawn", d.position)
	elseif kind == "Sound" then
		audio(d.cue, d.position)
	elseif kind == "HollowStrike" then
		audio("HollowStrike", d.position)
	elseif kind == "Eliminated" then
		Spectate.showElimination(d.cause, d.canRescue == true)
		Registry.CameraController.Shake(0.5)
		audio("Eliminated")
	elseif kind == "Rescued" then
		Overlay.blink(0.4)
		task.delay(0.8, function()
			Overlay.alert("BACK ON THE LINE. RUN!", Theme.Color.sky, 3)
		end)
		Spectate.hide()
	elseif kind == "Flare" then
		flare(d.position)
	elseif kind == "Clutch" then
		if d.userId == Players.LocalPlayer.UserId then
			Overlay.alert("BY A WHISKER!", Theme.Color.brassLight, 2.2)
			audio("Clutch")
		end
	elseif kind == "Purchased" then
		local def = Cosmetics.ById[d.id or ""]
		Overlay.alert(`ADDED: {string.upper(def and def.name or "ITEM")}`, Theme.Color.brassLight, 2)
		audio("Purchase")
	elseif kind == "RunSummary" then
		task.delay(1.2, function()
			Summary.show(d)
		end)
	end
end

local ALERT_KINDS: { [string]: Color3 } = {
	Alarm = Theme.Color.signal,
	Rescue = Theme.Color.sky,
}

local function onNotify(kind: string, text: string)
	Overlay.feed(kind, text)
	if ALERT_KINDS[kind] and Session.isMember() then
		Overlay.alert(string.upper(text), ALERT_KINDS[kind], 2.6)
	end
	if kind == "Alarm" then
		audio("Alarm")
	elseif kind == "Elimination" then
		audio("Toll")
	end
end

local lastPhase = ""

local function onPhase(phase: string?)
	if phase == nil or phase == lastPhase then
		return
	end
	local previous = lastPhase
	lastPhase = phase
	if previous == "" then
		return
	end
	local member = Session.isMember()
	if phase == "Boarding" and member then
		Overlay.blink(1.2)
		audio("Whistle")
	elseif phase == "Lobby" and previous == "RunEnd" then
		Overlay.blink(0.8)
	end
	if not member then
		return
	end
	local station = Registry.StateController.Get({ "run", "station" })
	if phase == "Junction" then
		Overlay.alert("JUNCTION AHEAD: CHOOSE A LINE", Theme.Color.brassLight, 2.6)
	elseif phase == "Arrival" then
		Overlay.alert(string.upper(station and station.name or "STATION"), Theme.Color.paper, 3)
		audio("Brakes")
	elseif phase == "Dwell" then
		Overlay.alert(`DOORS OPEN  ·  {Format.clock(station and station.dwell or 0)}`, Theme.Color.go, 2.6)
		audio("DoorsOpen")
	elseif phase == "LastCall" then
		Overlay.alert("LAST CALL", Theme.Color.signal, 3)
		audio("Whistle")
	elseif phase == "Departure" then
		local status = Session.status()
		if status == "Afield" or status == "Straggler" then
			Overlay.alert("THE TRAIN IS LEAVING. RUN!", Theme.Color.signal, 3)
		else
			Overlay.alert("DOORS CLOSING", Theme.Color.caution, 2)
		end
		audio("Departure")
		Registry.CameraController.Shake(0.35)
	elseif phase == "Terminus" then
		Overlay.alert("TERMINUS. YOU MADE IT.", Theme.Color.go, 4)
		audio("Victory")
	end
end

function FxController.Init()
	effects = Instance.new("Folder")
	effects.Name = "ClientEffects"
	effects.Parent = Workspace
end

function FxController.Start()
	Net.On("Fx", onFx)
	Net.On("Notify", onNotify)
	Registry.StateController.Observe("public", { "run", "phase" }, onPhase)
end

return FxController
