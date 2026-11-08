--!strict
--[[
	Small life in the air of the Depot hall and the train's saloon, client side: fine dust hanging
	over the platform and down the saloon aisle, drifting slowly. The motes take the light around them (LightInfluence 1), so they show in the lamp
	pools and vanish in the dark between, as dust does in lamplight. Under the Performance
	setting there is none.

	One invisible box over the platform in hall space (Builders/LobbyBuilder: +X along the
	platform, +Z from the track to the back wall, y = 0 the floor), from Tuning.World.LobbyOrigin,
	and one down the two saloon cars in train space (Builders/TrainInterior: x along the track,
	y = 0 the floor), from TrainService's origin at Tuning.World.FloorY. The train never moves.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local HallLife = {}

local SETTING = "GraphicsQuality"
type Air = { x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, rate: number }
local HALL: Air = { x0 = -104, x1 = 104, y0 = 1.5, y1 = 15, z0 = -4, z1 = 64, rate = 70 } -- ~700 alive
local SALOON: Air = { x0 = -66, x1 = -20, y0 = 1.5, y1 = 7.5, z0 = -4.5, z1 = 4.5, rate = 9 } -- ~90

local emitters: { ParticleEmitter } = {}

local function apply()
	for _, emitter in emitters do
		emitter.Enabled = Players.LocalPlayer:GetAttribute(SETTING) ~= "Performance"
	end
end

local function dustIn(name: string, origin: CFrame, air: Air)
	local box = Instance.new("Part")
	box.Name = name
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(air.x1 - air.x0, air.y1 - air.y0, air.z1 - air.z0)
	box.CFrame = origin * CFrame.new((air.x0 + air.x1) / 2, (air.y0 + air.y1) / 2, (air.z0 + air.z1) / 2)
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.Color = ColorSequence.new(Color3.fromRGB(255, 236, 200))
	dust.LightInfluence = 1
	dust.LightEmission = 0
	dust.Rate = air.rate
	dust.Lifetime = NumberRange.new(7, 12)
	dust.Speed = NumberRange.new(0.05, 0.25)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Acceleration = Vector3.new(0.04, -0.03, 0.02) -- settling, with a draught
	dust.RotSpeed = NumberRange.new(-20, 20)
	dust.Size = NumberSequence.new(0.07)
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(0.8, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Parent = box
	table.insert(emitters, dust)
	box.Parent = Workspace
end

function HallLife.Init() end

function HallLife.Start()
	local o = Tuning.World.LobbyOrigin
	dustIn("HallDust", CFrame.new(o[1], o[2], o[3]), HALL)
	dustIn("SaloonDust", CFrame.new(0, Tuning.World.FloorY, 0), SALOON)
	Players.LocalPlayer:GetAttributeChangedSignal(SETTING):Connect(apply)
	apply()
end

return HallLife
