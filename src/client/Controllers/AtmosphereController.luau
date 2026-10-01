--!strict
--[[
	The one owner of Lighting. Builds the sky, atmosphere, clouds, post effects
	and weather on the client, then sets them every frame from:

	  * the time of day: Logic/Journey maps run progress to an hour (dusk at the
	    lobby, night mid-run, sunrise at the Terminus); sky keys below give the
	    sun, ambient, exposure and air colours for each hour
	  * the biome under the camera (Scenery/Biomes): air tint, density and haze,
	    cloud cover, weather and storms with lightning
	  * tunnels: the sky darkens while the camera is inside a bore
	  * the older local modifiers: the Depot Hall grade, fog proximity, the Last
	    Call pulse, the spectator's desaturation and the flare flash

	Night stays readable: the outdoor ambient never drops below a blue moonlit
	floor and exposure rises after dark.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Journey = require(Shared.Logic.Journey)
local MathX = require(Shared.Util.MathX)
local Tuning = require(Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Biomes = require(script.Parent.Parent.Scenery.Biomes)

type SkyKey = {
	hour: number,
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoor: Color3,
	air: Color3, -- Atmosphere.Color
	decay: Color3, -- Atmosphere.Decay
	clouds: Color3,
	rays: number,
}

type Weather = {
	kind: string,
	fall: number, -- studs per second downward
	lifetime: number,
	emitters: { ParticleEmitter },
	parts: { BasePart },
}

local AtmosphereController = {}

local rgb = Color3.fromRGB

-- Hours past 24 are the small hours of the next morning (see Journey.hour).
local SKY: { SkyKey } = {
	{
		hour = 16.5,
		brightness = 2.8,
		exposure = 0.25,
		ambient = rgb(78, 66, 70),
		outdoor = rgb(150, 128, 118),
		air = rgb(206, 170, 140),
		decay = rgb(110, 72, 60),
		clouds = rgb(236, 214, 196),
		rays = 0.05,
	},
	{
		hour = 17.4,
		brightness = 2.6,
		exposure = 0.3,
		ambient = rgb(76, 64, 70),
		outdoor = rgb(146, 122, 116),
		air = rgb(214, 166, 136),
		decay = rgb(116, 70, 58),
		clouds = rgb(240, 196, 170),
		rays = 0.07,
	},
	{
		hour = 18.6,
		brightness = 1.6,
		exposure = 0.4,
		ambient = rgb(70, 58, 70),
		outdoor = rgb(122, 100, 112),
		air = rgb(196, 128, 116),
		decay = rgb(96, 50, 60),
		clouds = rgb(220, 140, 130),
		rays = 0.08,
	},
	{
		hour = 19.6,
		brightness = 0.9,
		exposure = 0.5,
		ambient = rgb(56, 56, 76),
		outdoor = rgb(92, 92, 124),
		air = rgb(110, 104, 140),
		decay = rgb(50, 44, 76),
		clouds = rgb(120, 110, 150),
		rays = 0.02,
	},
	{
		hour = 22,
		brightness = 0.5,
		exposure = 0.6,
		ambient = rgb(46, 50, 72),
		outdoor = rgb(78, 86, 118),
		air = rgb(64, 74, 108),
		decay = rgb(26, 30, 52),
		clouds = rgb(70, 76, 104),
		rays = 0,
	},
	{
		hour = 26,
		brightness = 0.5,
		exposure = 0.6,
		ambient = rgb(44, 48, 70),
		outdoor = rgb(78, 86, 118),
		air = rgb(60, 70, 104),
		decay = rgb(24, 28, 50),
		clouds = rgb(66, 72, 100),
		rays = 0,
	},
	{
		hour = 28.8,
		brightness = 0.8,
		exposure = 0.55,
		ambient = rgb(54, 54, 78),
		outdoor = rgb(92, 92, 126),
		air = rgb(112, 110, 150),
		decay = rgb(60, 52, 84),
		clouds = rgb(130, 120, 160),
		rays = 0.01,
	},
	{
		hour = 30.4,
		brightness = 2.2,
		exposure = 0.35,
		ambient = rgb(80, 68, 74),
		outdoor = rgb(160, 138, 128),
		air = rgb(232, 180, 150),
		decay = rgb(130, 88, 76),
		clouds = rgb(255, 212, 186),
		rays = 0.1,
	},
}

local LOBBY =
	Vector3.new(Tuning.World.LobbyOrigin[1], Tuning.World.LobbyOrigin[2], Tuning.World.LobbyOrigin[3])
local LOBBY_HOUR = SKY[2].hour
local BASE_DENSITY = 0.36
local BASE_HAZE = 2.1
local WEATHER_BAND = 290 -- weather falls in two bands beside the train, never inside the cars
local TUNNEL_OUTDOOR = rgb(18, 18, 22)

local atmosphere: Atmosphere
local sky: Sky
local clouds: Clouds
local grade: ColorCorrectionEffect
local rays: SunRaysEffect
local weathers: { [string]: Weather } = {}
local flareUntil = 0
local hour = LOBBY_HOUR
local lightning = 0 -- 0..1 flash
local nextStrike = 0

local function multiply(a: Color3, b: Color3): Color3
	return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

local function skyAt(h: number): SkyKey
	if h <= SKY[1].hour then
		return SKY[1]
	end
	for i = 2, #SKY do
		local b = SKY[i]
		if h <= b.hour then
			local a = SKY[i - 1]
			local t = (h - a.hour) / (b.hour - a.hour)
			return {
				hour = h,
				brightness = MathX.lerp(a.brightness, b.brightness, t),
				exposure = MathX.lerp(a.exposure, b.exposure, t),
				ambient = a.ambient:Lerp(b.ambient, t),
				outdoor = a.outdoor:Lerp(b.outdoor, t),
				air = a.air:Lerp(b.air, t),
				decay = a.decay:Lerp(b.decay, t),
				clouds = a.clouds:Lerp(b.clouds, t),
				rays = MathX.lerp(a.rays, b.rays, t),
			}
		end
	end
	return SKY[#SKY]
end

-- Building -----------------------------------------------------------------------------------------

local function buildLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("PostEffect") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	Lighting.GeographicLatitude = 38
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.6

	atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = BASE_DENSITY
	atmosphere.Offset = 0.22
	atmosphere.Glare = 0.35
	atmosphere.Haze = BASE_HAZE
	atmosphere.Parent = Lighting

	sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 3000
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local base = Instance.new("ColorCorrectionEffect")
	base.Name = "BaseGrade"
	base.Saturation = -0.08
	base.Contrast = 0.1
	base.Brightness = 0.01
	base.TintColor = rgb(255, 244, 232)
	base.Parent = Lighting

	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "ClientGrade"
	grade.Parent = Lighting

	rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.6
	rays.Parent = Lighting

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	clouds = Instance.new("Clouds")
	clouds.Cover = 0.6
	clouds.Density = 0.45
	clouds.Parent = terrain or Workspace
end

local function weatherEmitter(kind: string): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = kind
	emitter.Rate = 0
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.LockedToPart = false
	if kind == "Rain" then
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(rgb(196, 210, 226))
		emitter.Size = NumberSequence.new(0.14)
		emitter.Squash = NumberSequence.new(3)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
		emitter.Transparency = NumberSequence.new(0.35)
		emitter.LightEmission = 0.2
	elseif kind == "Snow" then
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(rgb(240, 244, 255))
		emitter.Size = NumberSequence.new(0.35)
		emitter.Transparency = NumberSequence.new(0.15)
		emitter.RotSpeed = NumberRange.new(-90, 90)
		emitter.SpreadAngle = Vector2.new(12, 12)
	elseif kind == "Ash" then
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(rgb(140, 130, 124))
		emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.18) })
		emitter.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		emitter.RotSpeed = NumberRange.new(-60, 60)
		emitter.SpreadAngle = Vector2.new(18, 18)
	else
		emitter.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
		emitter.Color = ColorSequence.new(rgb(255, 150, 70), rgb(200, 60, 20))
		emitter.LightEmission = 1
		emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
		emitter.SpreadAngle = Vector2.new(35, 35)
	end
	return emitter
end

local WEATHER_KINDS: { { kind: string, fall: number, lifetime: number } } = {
	{ kind = "Rain", fall = 80, lifetime = 1.1 },
	{ kind = "Snow", fall = 9, lifetime = 4 },
	{ kind = "Ash", fall = 6, lifetime = 5 },
	{ kind = "Embers", fall = 3, lifetime = 4 },
}

local function buildWeather()
	local folder = Instance.new("Folder")
	folder.Name = "Weather"
	folder.Parent = Workspace
	for _, spec in WEATHER_KINDS do
		local weather: Weather =
			{ kind = spec.kind, fall = spec.fall, lifetime = spec.lifetime, emitters = {}, parts = {} }
		for _ = 1, 2 do
			local part = Instance.new("Part")
			part.Name = spec.kind
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Size = Vector3.new(320, 1, WEATHER_BAND)
			part.Parent = folder
			local emitter = weatherEmitter(spec.kind)
			emitter.Lifetime = NumberRange.new(spec.lifetime * 0.8, spec.lifetime * 1.2)
			emitter.Parent = part
			table.insert(weather.parts, part)
			table.insert(weather.emitters, emitter)
		end
		weathers[spec.kind] = weather
	end
end

-- Weather follows the camera in two bands, one either side of the track, tilted so
-- particles stream past at the train's speed.
local function updateWeather(focus: Vector3, rates: { [string]: number }, wind: number)
	for kind, weather in weathers do
		local rate = rates[kind] or 0
		local fall = weather.fall
		local tilt = math.atan2(wind, fall)
		local velocity = math.sqrt(fall * fall + wind * wind)
		local lead = wind * weather.lifetime * 0.5
		local lift = if kind == "Embers" then -10 else 45
		for i, part in weather.parts do
			local side = if i == 1 then -1 else 1
			part.CFrame = CFrame.new(focus.X + lead, focus.Y + lift, side * (10 + WEATHER_BAND / 2))
				* CFrame.Angles(0, 0, -tilt)
			local emitter = weather.emitters[i]
			emitter.Rate = rate / 2
			emitter.Speed = NumberRange.new(velocity * 0.9, velocity * 1.1)
			if kind == "Embers" then
				emitter.Acceleration = Vector3.new(0, 7, 0)
			end
		end
	end
end

-- Lightning ----------------------------------------------------------------------------------------

local function strike()
	task.spawn(function()
		for _, pulse in { 1, 0.35, 0.8, 0 } do
			lightning = pulse
			task.wait(0.06 + math.random() * 0.05)
		end
	end)
	task.delay(0.6 + math.random() * 1.8, function()
		if Registry.AudioController then
			Registry.AudioController.Play("Thunder")
		end
	end)
end

-- Frame ----------------------------------------------------------------------------------------------

function AtmosphereController.Init()
	buildLighting()
	buildWeather()
end

function AtmosphereController.Start()
	local density, haze, saturation, contrast = BASE_DENSITY, BASE_HAZE, 0, 0
	local tint = Color3.new(1, 1, 1)
	local brightness = 0
	local darkness = 0 -- tunnel, smoothed
	local cover, cloudDensity = 0.6, 0.45
	local cloudTint = Color3.new(1, 1, 1)
	local airTint = Color3.new(1, 1, 1)
	local biomeDensity, biomeHaze = 0, 0

	RunService.RenderStepped:Connect(function(dt)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		local focus = if root then root.Position else camera.CFrame.Position
		local phase = Session.phase()
		local now = Session.now()
		local inLobby = (focus - LOBBY).Magnitude < 420

		-- time of day
		local scenery = if Registry.SceneryController then Registry.SceneryController.Context() else nil
		local stops = Registry.StateController.Get({ "run", "stopCount" }) or Tuning.Run.StationCount
		local targetHour = if inLobby or scenery == nil
			then LOBBY_HOUR
			else Journey.hour(scenery.progress, stops)
		if math.abs(targetHour - hour) > 3 then
			hour = targetHour
		else
			hour = MathX.lerp(hour, targetHour, MathX.damp(2.5, dt))
		end
		local key = skyAt(hour)

		-- the biome under the camera
		local a = Biomes.get(if scenery then scenery.biomeA else Journey.FirstBiome)
		local b = Biomes.get(if scenery then scenery.biomeB else Journey.FirstBiome)
		local w = if scenery then scenery.blend else 0
		local tunnel = if scenery and not inLobby then scenery.tunnel else 0
		local blend = MathX.damp(1.2, dt)
		airTint = airTint:Lerp(a.tint:Lerp(b.tint, w), blend)
		cloudTint = cloudTint:Lerp(a.cloudColor:Lerp(b.cloudColor, w), blend)
		biomeDensity = MathX.lerp(biomeDensity, MathX.lerp(a.density, b.density, w), blend)
		biomeHaze = MathX.lerp(biomeHaze, MathX.lerp(a.haze, b.haze, w), blend)
		cover = MathX.lerp(cover, MathX.lerp(a.cloudCover, b.cloudCover, w), blend)
		cloudDensity = MathX.lerp(cloudDensity, MathX.lerp(a.cloudDensity, b.cloudDensity, w), blend)
		darkness = MathX.lerp(darkness, tunnel, MathX.damp(0.15, dt))

		-- local grade and air
		local targetDensity, targetHaze = BASE_DENSITY + biomeDensity, BASE_HAZE + biomeHaze
		local targetSat, targetContrast, targetBrightness = 0, 0, 0
		local targetTint = Color3.new(1, 1, 1)
		if inLobby then
			targetDensity, targetHaze = 0.18, 0.8
			targetTint = rgb(255, 236, 214)
			targetSat = 0.05
			targetBrightness = -0.07
			targetContrast = 0.08
		else
			local fog = Registry.StationVisualsController and Registry.StationVisualsController.FogDepth()
			local localPos = Registry.StationVisualsController
				and Registry.StationVisualsController.ToLocal(focus)
			if fog and localPos then
				local inside = math.clamp((localPos.Z - (fog - 24)) / 30, 0, 1)
				targetDensity = MathX.lerp(targetDensity, 0.78, inside)
				targetHaze = MathX.lerp(targetHaze, 4, inside)
				targetSat -= 0.3 * inside
			end
			if phase == "LastCall" or phase == "Departure" then
				local pulse = 0.5 + 0.5 * math.sin(now * 5)
				targetTint = Color3.new(1, 0.9 - 0.06 * pulse, 0.88 - 0.08 * pulse)
				targetContrast = 0.12
			end
			targetDensity = MathX.lerp(targetDensity, 0.12, darkness)
			targetHaze = MathX.lerp(targetHaze, 0, darkness)
		end
		if Session.status() == "Eliminated" and Session.isRunActive() then
			targetSat = -0.65
		end
		if os.clock() < flareUntil then
			local k = (flareUntil - os.clock()) / 1.6
			targetTint = targetTint:Lerp(rgb(255, 150, 140), k)
			targetBrightness = 0.08 * k
		end
		targetBrightness += 0.25 * lightning

		local damp = MathX.damp(0.35, dt)
		density = MathX.lerp(density, targetDensity, damp)
		haze = MathX.lerp(haze, targetHaze, damp)
		saturation = MathX.lerp(saturation, targetSat, damp)
		contrast = MathX.lerp(contrast, targetContrast, damp)
		tint = tint:Lerp(targetTint, damp)
		brightness =
			MathX.lerp(brightness, targetBrightness, if lightning > 0 then 1 else MathX.damp(0.08, dt))

		-- Lighting itself
		local open = 1 - darkness
		Lighting.ClockTime = Journey.clock(hour)
		Lighting.Brightness = key.brightness * open + 3 * lightning
		Lighting.ExposureCompensation = key.exposure - 0.35 * darkness
		Lighting.Ambient = key.ambient:Lerp(rgb(40, 34, 32), darkness * 0.5)
		Lighting.OutdoorAmbient = key.outdoor:Lerp(TUNNEL_OUTDOOR, darkness)
		atmosphere.Density = density
		atmosphere.Haze = haze
		atmosphere.Color = multiply(key.air, airTint):Lerp(rgb(20, 18, 18), darkness)
		atmosphere.Decay = multiply(key.decay, airTint):Lerp(rgb(10, 9, 9), darkness)
		clouds.Cover = cover
		clouds.Density = cloudDensity
		clouds.Color = multiply(key.clouds, cloudTint):Lerp(Color3.new(1, 1, 1), lightning * 0.7)
		rays.Intensity = key.rays * open
		grade.Saturation = saturation
		grade.Contrast = contrast
		grade.TintColor = tint
		grade.Brightness = brightness

		-- weather, and storms where the biome has them
		local speed = if Registry.SceneryController then Registry.SceneryController.Speed() else 0
		local rates: { [string]: number } = {}
		if not inLobby then
			local exposed = open
			rates[a.weather] = (rates[a.weather] or 0) + a.weatherRate * (1 - w) * exposed
			rates[b.weather] = (rates[b.weather] or 0) + b.weatherRate * w * exposed
		end
		updateWeather(focus, rates, speed)
		local storm = (if a.storm then 1 - w else 0) + (if b.storm then w else 0)
		if storm > 0.5 and not inLobby and darkness < 0.2 and os.clock() > nextStrike then
			if nextStrike > 0 then
				strike()
			end
			nextStrike = os.clock() + 6 + math.random() * 12
		end
	end)
end

function AtmosphereController.FlareFlash()
	flareUntil = os.clock() + 1.6
end

return AtmosphereController
