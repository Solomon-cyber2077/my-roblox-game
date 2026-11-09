--!strict
--[[
	Small life in the air of the Depot hall and the train's saloon, client side: fine dust hanging
	over the platform and down the saloon aisle, drifting slowly; and the hall's gas lamps breathing,
	a slight, slow flicker each out of step with the others. The motes take the light around them (LightInfluence 1), so they show in the lamp
	pools and vanish in the dark between, as dust does in lamplight. Under the Performance
	setting there is none.

	One invisible box over the platform in hall space (Builders/LobbyBuilder: +X along the
	platform, +Z from the track to the back wall, y = 0 the floor), from Tuning.World.LobbyOrigin,
	and one down the two saloon cars in train space (Builders/TrainInterior: x along the track,
	y = 0 the floor), from TrainService's origin at Tuning.World.FloorY. The train never moves.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local HallLife = {}

local SETTING = "GraphicsQuality"
type Air = { x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, rate: number }
local HALL: Air = { x0 = -104, x1 = 104, y0 = 1.5, y1 = 15, z0 = -4, z1 = 64, rate = 70 } -- ~700 alive
local SALOON: Air = { x0 = -66, x1 = -20, y0 = 1.5, y1 = 7.5, z0 = -4.5, z1 = 4.5, rate = 9 } -- ~90

local emitters: { ParticleEmitter } = {}
-- the hall's lamps (its lit glass inside DepotHall, not the display train's): a slow, slight breath
-- of the gas, each lamp out of step with the others
type Lamp = { light: PointLight, base: number, seed: number }
local lamps: { Lamp } = {}

-- The life pass's small emitters on server-built parts (HallWear's drip and splash, the saloon's teapot
-- steam): hiding their Detail part under Performance does not stop an emitter, so they are switched here.
local EXTRA = { Drip = true, Splash = true, TeaSteam = true }

local function performance(): boolean
	return Players.LocalPlayer:GetAttribute(SETTING) == "Performance"
end

local function apply()
	local on = not performance()
	for _, emitter in emitters do
		emitter.Enabled = on
	end
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ParticleEmitter") and EXTRA[d.Name] then
			d.Enabled = on
		end
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

local function findLamps(hall: Instance)
	local train = hall:FindFirstChild("DisplayTrain")
	for _, d in hall:GetDescendants() do
		if d:IsA("PointLight") and not (train and d:IsDescendantOf(train)) then
			table.insert(lamps, { light = d, base = d.Brightness, seed = #lamps * 1.73 })
		end
	end
end

function HallLife.Start()
	local o = Tuning.World.LobbyOrigin
	dustIn("HallDust", CFrame.new(o[1], o[2], o[3]), HALL)
	dustIn("SaloonDust", CFrame.new(0, Tuning.World.FloorY, 0), SALOON)
	Players.LocalPlayer:GetAttributeChangedSignal(SETTING):Connect(apply)
	apply()
	task.delay(8, apply) -- once the hall and train have streamed in
	task.spawn(function()
		local hall = Workspace:WaitForChild("DepotHall", 60)
		if hall == nil then
			return
		end
		task.wait(2) -- the hall's parts stream in
		findLamps(hall)
		RunService.Heartbeat:Connect(function()
			if performance() then
				return -- the lamps hold still: no per-frame writes on a phone
			end
			local now = os.clock()
			for _, lamp in lamps do
				if lamp.light.Parent then
					lamp.light.Brightness = lamp.base * (0.97 + 0.03 * math.noise(now * 1.3, lamp.seed))
				end
			end
		end)
	end)
end

return HallLife
