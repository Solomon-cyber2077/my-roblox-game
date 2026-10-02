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
	  * dread: a Hollow close by drains the colour, hardens the contrast and pulls
	    the fog in
	  * the older local modifiers: the Depot Hall grade, fog proximity, the Last
	    Call pulse, the spectator's desaturation and the flare flash

	The night is dark and cold on purpose: low moonlight, a blue-grey haze that
	swallows the distance, colour drained out, so that lamps, fires, lit windows
	and a Hollow's eyes are what the eye goes to. It never goes black: the outdoor
	ambient keeps a moonlit floor, enough to see where to step.
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
	tint: Color3, -- the grade's colour: warm at the ends of the day, cold at night
	saturation: number,
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

-- Hours past 24 are the small hours of the next morning (see Journey.hour). The run
-- spans 18.3 (the lobby at sunset) to 30.5 (sunrise at the Terminus): Tuning.Journey.Sky.
local SKY: { SkyKey } = {
	{ -- the sun on the horizon
		hour = 18.3,
		brightness = 1.8,
		exposure = 0.1,
		ambient = rgb(66, 54, 58),
		outdoor = rgb(120, 98, 96),
		air = rgb(196, 132, 110),
		decay = rgb(100, 52, 48),
		clouds = rgb(218, 142, 120),
		rays = 0.08,
		tint = rgb(255, 238, 222),
		saturation = -0.04,
	},
	{ -- embers of the sunset
		hour = 18.9,
		brightness = 1.2,
		exposure = 0.1,
		ambient = rgb(56, 46, 56),
		outdoor = rgb(98, 80, 92),
		air = rgb(156, 102, 104),
		decay = rgb(78, 42, 52),
		clouds = rgb(176, 108, 106),
		rays = 0.05,
		tint = rgb(255, 236, 228),
		saturation = -0.08,
	},
	{ -- the last blue light
		hour = 19.6,
		brightness = 0.6,
		exposure = 0.12,
		ambient = rgb(42, 42, 56),
		outdoor = rgb(70, 72, 96),
		air = rgb(88, 86, 112),
		decay = rgb(42, 38, 60),
		clouds = rgb(98, 94, 124),
		rays = 0.01,
		tint = rgb(236, 238, 255),
		saturation = -0.12,
	},
	{ -- night
		hour = 22,
		brightness = 0.34,
		exposure = 0.18,
		ambient = rgb(30, 32, 44),
		outdoor = rgb(50, 56, 78),
		air = rgb(46, 52, 70),
		decay = rgb(20, 22, 34),
		clouds = rgb(50, 54, 72),
		rays = 0,
		tint = rgb(224, 232, 255),
		saturation = -0.18,
	},
	{ -- two in the morning, the darkest hour
		hour = 26,
		brightness = 0.3,
		exposure = 0.18,
		ambient = rgb(26, 28, 40),
		outdoor = rgb(46, 52, 72),
		air = rgb(40, 46, 64),
		decay = rgb(16, 18, 30),
		clouds = rgb(44, 48, 66),
		rays = 0,
		tint = rgb(222, 230, 255),
		saturation = -0.2,
	},
	{ -- before dawn
		hour = 28.9,
		brightness = 0.55,
		exposure = 0.16,
		ambient = rgb(40, 40, 56),
		outdoor = rgb(72, 74, 100),
		air = rgb(100, 98, 130),
		decay = rgb(54, 48, 74),
		clouds = rgb(114, 108, 144),
		rays = 0.01,
		tint = rgb(236, 236, 255),
		saturation = -0.12,
	},
	{ -- sunrise at the Terminus
		hour = 30.5,
		brightness = 2.0,
		exposure = 0.15,
		ambient = rgb(76, 64, 70),
		outdoor = rgb(152, 128, 118),
		air = rgb(228, 172, 142),
		decay = rgb(126, 84, 72),
		clouds = rgb(252, 206, 180),
		rays = 0.1,
		tint = rgb(255, 240, 226),
		saturation = -0.02,
	},
}

local LOBBY =
	Vector3.new(Tuning.World.LobbyOrigin[1], Tuning.World.LobbyOrigin[2], Tuning.World.LobbyOrigin[3])
local LOBBY_HOUR = Journey.hour(0, Tuning.Run.StationCount)
local BASE_DENSITY = 0.42
local BASE_HAZE = 2.6
local DREAD_NEAR, DREAD_FAR = 10, 60 -- a Hollow this close is full dread, this far none
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
				tint = a.tint:Lerp(b.tint, t),
				saturation = MathX.lerp(a.saturation, b.saturation, t),
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
	atmosphere.Offset = 0.25
	atmosphere.Glare = 0.2
	atmosphere.Haze = BASE_HAZE
	atmosphere.Parent = Lighting

	sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 3000
	sky.Parent = Lighting

	-- lamps, fires, lit windows and eyes bloom out of the dark
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.85
	bloom.Size = 30
	bloom.Threshold = 1.05
	bloom.Parent = Lighting

	local base = Instance.new("ColorCorrectionEffect")
	base.Name = "BaseGrade"
	base.Contrast = 0.14
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
	local dread = 0

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

		-- dread: rises quickly as a Hollow closes in, ebbs slowly once it has gone
		local nearest = if Registry.HollowAnimator then Registry.HollowAnimator.Nearest(focus) else math.huge
		local targetDread = if inLobby
			then 0
			else 1 - MathX.saturate((nearest - DREAD_NEAR) / (DREAD_FAR - DREAD_NEAR))
		dread = MathX.lerp(dread, targetDread, MathX.damp(if targetDread > dread then 0.25 else 2, dt))

		-- local grade and air
		local targetDensity, targetHaze = BASE_DENSITY + biomeDensity, BASE_HAZE + biomeHaze
		local targetSat, targetContrast, targetBrightness = key.saturation, 0, 0
		local targetTint = key.tint
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
			targetSat -= 0.25 * dread
			targetContrast += 0.1 * dread
			targetTint = targetTint:Lerp(rgb(196, 214, 255), 0.35 * dread)
			targetDensity += 0.08 * dread
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
