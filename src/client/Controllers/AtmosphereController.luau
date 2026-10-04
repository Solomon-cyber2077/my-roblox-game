--!strict
--[[
	The one owner of Lighting. Builds the sky, atmosphere, clouds, post effects,
	weather and the sky objects (Scenery/Heavens) on the client, then every frame:

	  * gathers what the sky depends on: the hour (Logic/Journey maps run progress to
	    dusk at the lobby, night mid-run and sunrise at the Terminus), the biome mix
	    under the camera, a tunnel's dark, a station's fog bank, Last Call, dread (a
	    Hollow close by), the spectator's view and a flare's flash
	  * asks Logic/Omens what the sky is doing at this server time: an omen, a
	    lightning strike. Every client gets the same answer, so the whole crew sees
	    the same blink and the same bolt, and hears its thunder after the same delay
	  * composes and eases the look (Scenery/Sky) and applies it to Lighting, the
	    Atmosphere, the Clouds, Workspace.GlobalWind, the grade and the sky objects

	Scenery/Sky holds the look itself: a night that deepens to a blood moon at two
	in the morning, fires on the horizon, the moonlight turning red. It never goes
	black: the outdoor ambient keeps a floor, enough to see where to step.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Audio = require(Shared.Config.Audio)
local Journey = require(Shared.Logic.Journey)
local Omens = require(Shared.Logic.Omens)
local MathX = require(Shared.Util.MathX)
local Safe = require(Shared.Util.Safe)
local Tuning = require(Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Biomes = require(script.Parent.Parent.Scenery.Biomes)
local Heavens = require(script.Parent.Parent.Scenery.Heavens)
local Sky = require(script.Parent.Parent.Scenery.Sky)
local Overlay = require(script.Parent.Parent.UI.Overlay)

type Weather = {
	kind: string,
	fall: number, -- studs per second downward
	lifetime: number,
	emitters: { ParticleEmitter },
	parts: { BasePart },
}

local AtmosphereController = {}

local rgb = Color3.fromRGB

local LOBBY =
	Vector3.new(Tuning.World.LobbyOrigin[1], Tuning.World.LobbyOrigin[2], Tuning.World.LobbyOrigin[3])
local LOBBY_HOUR = Journey.hour(0, Tuning.Run.StationCount)
local DREAD_NEAR, DREAD_FAR = 10, 75 -- a Hollow this close is full dread, this far none
local WEATHER_BAND = 290 -- weather falls in two bands beside the train, never inside the cars
local WEATHER_NIGHT = 0.6 -- weather thickens by this share at the darkest hour
local STAR_STEP = 25 -- StarCount rebuilds the star field, so it moves in steps
local S = Tuning.Sky
local STUDIO = RunService:IsStudio()

local atmosphere: Atmosphere
local skyBox: Sky
local clouds: Clouds
local bloom: BloomEffect
local grade: ColorCorrectionEffect
local rays: SunRaysEffect
local focus: DepthOfFieldEffect
local heavens: Heavens.Rig
local weathers: { [string]: Weather } = {}

-- The near rain: showers drift through the run from its seed, so every client is rained
-- on at the same moments. It falls in a square around the camera, splashes at the feet,
-- and stops (and goes muffled) under any roof: a car, a building, a tunnel.
local RAIN_AREA = 110
local RAIN_FALL = 95
local rainFolder: Folder
local rainPart: BasePart
local rainEmitter: ParticleEmitter
local splashPart: BasePart
local splashEmitter: ParticleEmitter
local rainSound: Sound
local rainMuffle: EqualizerSoundEffect
local shelterParams = RaycastParams.new()
shelterParams.FilterType = Enum.RaycastFilterType.Exclude
shelterParams.IgnoreWater = true
local sheltered = false
local shelterCheckAt = 0
local rainNow = 0
local rainShown = 0
local flareUntil = 0
local hour = LOBBY_HOUR
local omenNow: Omens.Omen? = nil
local darkNow = 0
local moonNow: Sky.Moon? = nil

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
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.25
	atmosphere.Glare = 0.2
	atmosphere.Haze = 2
	atmosphere.Parent = Lighting

	skyBox = Instance.new("Sky")
	skyBox.SunAngularSize = 14
	skyBox.MoonAngularSize = 0 -- Scenery/Heavens draws the moon
	skyBox.StarCount = 0
	skyBox.Parent = Lighting

	-- lamps, fires, eyes and the moon bloom out of the dark (Scenery/Sky sets how much)
	bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 24
	bloom.Threshold = 1.3
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

	-- dread narrows the eye: past the nearest few studs the world goes soft
	focus = Instance.new("DepthOfFieldEffect")
	focus.FocusDistance = 14
	focus.InFocusRadius = 26
	focus.NearIntensity = 0
	focus.FarIntensity = 0
	focus.Enabled = false
	focus.Parent = Lighting

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	clouds = Instance.new("Clouds")
	clouds.Cover = 0.6
	clouds.Density = 0.45
	clouds.Parent = terrain or Workspace

	local folder = Instance.new("Folder")
	folder.Name = "Heavens"
	folder.Parent = Workspace
	heavens = Heavens.build(folder)
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

local function rainLayer(name: string, size: Vector3): (BasePart, ParticleEmitter)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.Parent = rainFolder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Rate = 0
	emitter.LockedToPart = false
	emitter.Parent = part
	return part, emitter
end

local function buildRain()
	rainFolder = Instance.new("Folder")
	rainFolder.Name = "Rain"
	rainFolder.Parent = Workspace

	rainPart, rainEmitter = rainLayer("Showers", Vector3.new(RAIN_AREA, 1, RAIN_AREA))
	rainEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rainEmitter.EmissionDirection = Enum.NormalId.Bottom
	rainEmitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	rainEmitter.Color = ColorSequence.new(rgb(186, 198, 214))
	rainEmitter.Size = NumberSequence.new(0.09)
	rainEmitter.Squash = NumberSequence.new(7)
	rainEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.15, 0.3),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	rainEmitter.LightEmission = 0.15
	rainEmitter.LightInfluence = 0.8
	rainEmitter.Lifetime = NumberRange.new(0.55, 0.7)
	rainEmitter.Speed = NumberRange.new(RAIN_FALL * 0.95, RAIN_FALL * 1.05)

	splashPart, splashEmitter = rainLayer("Splashes", Vector3.new(46, 0.2, 46))
	splashEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	splashEmitter.EmissionDirection = Enum.NormalId.Top
	splashEmitter.Color = ColorSequence.new(rgb(206, 216, 228))
	splashEmitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.32) })
	splashEmitter.Squash = NumberSequence.new(-0.6)
	splashEmitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	splashEmitter.Lifetime = NumberRange.new(0.12, 0.22)
	splashEmitter.Speed = NumberRange.new(2, 5)
	splashEmitter.SpreadAngle = Vector2.new(60, 60)
	splashEmitter.Acceleration = Vector3.new(0, -30, 0)

	local cue = Audio.Rain
	rainSound = Instance.new("Sound")
	rainSound.Name = "Rain"
	rainSound.SoundId = `rbxassetid://{cue.id}`
	rainSound.Looped = true
	rainSound.Volume = 0
	rainSound.PlaybackSpeed = cue.pitch or 1
	rainSound.Parent = rainFolder
	rainMuffle = Instance.new("EqualizerSoundEffect")
	rainMuffle.LowGain = 2
	rainMuffle.MidGain = -4
	rainMuffle.HighGain = 0
	rainMuffle.Parent = rainSound
	rainSound:Play()
end

-- How hard it rains at this point of the run, 0..1. Fronts drift past as the run goes on,
-- the same for every client because they come from the seed and the run's progress.
local function rainAt(seed: number, progress: number, dark: number): number
	local front = math.noise(progress * 0.85 + (seed % 997) * 0.013, 0.37)
	return MathX.saturate((front + 0.06) * 2.8) * (0.6 + 0.4 * dark)
end

local function updateRain(dt: number, camera: Vector3, ground: number, rain: number, wind: number)
	local clock = os.clock()
	if clock >= shelterCheckAt then
		shelterCheckAt = clock + 0.2
		local character = Players.LocalPlayer.Character
		local ignore: { Instance } = { rainFolder }
		if character then
			table.insert(ignore, character)
		end
		for _, name in { "Hollows", "Heavens", "Weather" } do
			local folder = Workspace:FindFirstChild(name)
			if folder then
				table.insert(ignore, folder)
			end
		end
		shelterParams.FilterDescendantsInstances = ignore
		sheltered = Workspace:Raycast(camera, Vector3.new(0, 90, 0), shelterParams) ~= nil
	end
	rainShown = MathX.lerp(rainShown, rain, MathX.damp(1.5, dt))
	local near = if sheltered then 0 else rainShown
	local tilt = math.atan2(wind, RAIN_FALL)
	rainPart.CFrame = CFrame.new(camera.X + wind * 0.3, camera.Y + 30, camera.Z) * CFrame.Angles(0, 0, -tilt)
	rainEmitter.Rate = 1100 * near
	splashPart.CFrame = CFrame.new(camera.X, ground + 0.15, camera.Z)
	splashEmitter.Rate = if wind > 20 then 0 else 240 * near
	rainSound.Volume = Audio.Rain.volume * rainShown * (if sheltered then 0.55 else 1)
	rainMuffle.HighGain = if sheltered then -30 else 0
	-- a wet sheen on every surface while it pours
	Lighting.EnvironmentSpecularScale = 0.6 + 0.45 * rainShown
end

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
local function updateWeather(around: Vector3, rates: { [string]: number }, wind: number)
	for kind, weather in weathers do
		local rate = rates[kind] or 0
		local fall = weather.fall
		local tilt = math.atan2(wind, fall)
		local velocity = math.sqrt(fall * fall + wind * wind)
		local lead = wind * weather.lifetime * 0.5
		local lift = if kind == "Embers" then -10 else 45
		for i, part in weather.parts do
			local side = if i == 1 then -1 else 1
			part.CFrame = CFrame.new(around.X + lead, around.Y + lift, side * (10 + WEATHER_BAND / 2))
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

-- Applying -----------------------------------------------------------------------------------------

local starsShown = -STAR_STEP
local windShown = Vector3.zero

local function apply(state: Sky.State)
	Lighting.ClockTime = state.clock
	Lighting.Brightness = state.brightness
	Lighting.ExposureCompensation = state.exposure
	Lighting.Ambient = state.ambient
	Lighting.OutdoorAmbient = state.outdoor
	Lighting.ColorShift_Top = state.shift
	atmosphere.Density = state.density
	atmosphere.Haze = state.haze
	atmosphere.Glare = state.glare
	atmosphere.Color = state.air
	atmosphere.Decay = state.decay
	clouds.Cover = state.cover
	clouds.Density = state.cloudDensity
	clouds.Color = state.clouds
	rays.Intensity = state.rays
	grade.Saturation = state.saturation
	grade.Contrast = state.contrast
	grade.TintColor = state.tint
	grade.Brightness = state.lift
	focus.Enabled = state.blur > 0.01
	focus.FarIntensity = state.blur
	bloom.Intensity = state.bloom
	bloom.Threshold = state.bloomThreshold
	bloom.Size = math.floor(state.bloomSize + 0.5)
	if math.abs(state.stars - starsShown) >= STAR_STEP then
		starsShown = state.stars
		skyBox.StarCount = math.floor(state.stars)
	end
end

-- Studio's developer console (DevService) can pin the hour, call an omen or throw a bolt.
local function devOverrides(now: number): (number?, Omens.Omen?, Omens.Strike?)
	if not STUDIO then
		return nil, nil, nil
	end
	local pinned = ReplicatedStorage:GetAttribute("DevSkyHour")
	local omen: Omens.Omen? = nil
	local called = ReplicatedStorage:GetAttribute("DevOmen")
	if type(called) == "string" then
		local kind, at = string.match(called, "^(%a+)@([%d%.]+)$")
		local start = tonumber(at)
		for _, spec in S.Omens do
			if kind == spec.kind and start and now >= start and now < start + spec.duration then
				omen = {
					kind = spec.kind :: Omens.Kind,
					start = start,
					duration = spec.duration,
					progress = (now - start) / spec.duration,
					seed = math.floor(start),
				}
			end
		end
	end
	local strike: Omens.Strike? = nil
	local thrown = ReplicatedStorage:GetAttribute("DevStrike")
	if type(thrown) == "number" and now >= thrown and now < thrown + S.StrikeSeconds then
		strike = {
			start = thrown,
			seed = math.floor(thrown * 100),
			pulses = { { at = 0, width = 0.1, peak = 1 }, { at = 0.22, width = 0.09, peak = 0.7 } },
			distance = 2200,
			azimuth = (thrown * 7.3) % (math.pi * 2),
			red = false,
		}
	end
	return if type(pinned) == "number" then pinned else nil, omen, strike
end

-- Frame ----------------------------------------------------------------------------------------------

function AtmosphereController.Init()
	buildLighting()
	buildWeather()
	buildRain()
end

function AtmosphereController.Start()
	local current: Sky.State? = nil
	local darkness = 0 -- a tunnel's dark, smoothed
	local dread = 0
	local lastStrike = -math.huge

	local function frame(dt: number)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		local around = if root then root.Position else camera.CFrame.Position
		local phase = Session.phase()
		local now = Session.now()
		local inLobby = (around - LOBBY).Magnitude < 420

		-- time of day
		local pinned, devOmen, devStrike = devOverrides(now)
		local scenery = if Registry.SceneryController then Registry.SceneryController.Context() else nil
		local stops = Registry.StateController.Get({ "run", "stopCount" }) or Tuning.Run.StationCount
		local targetHour = if pinned
			then pinned
			elseif inLobby or scenery == nil then LOBBY_HOUR
			else Journey.hour(scenery.skyProgress, stops)
		if math.abs(targetHour - hour) > 3 then
			hour = targetHour
		else
			hour = MathX.lerp(hour, targetHour, MathX.damp(2.5, dt))
		end
		local dark = if inLobby then 0 else Sky.darkness(hour)
		darkNow = dark

		-- the biome under the camera, and a tunnel's dark
		local a = Biomes.get(if scenery then scenery.biomeA else Journey.FirstBiome)
		local b = Biomes.get(if scenery then scenery.biomeB else Journey.FirstBiome)
		local w = if scenery then scenery.blend else 0
		local tunnel = if scenery and not inLobby then scenery.tunnel else 0
		darkness = MathX.lerp(darkness, tunnel, MathX.damp(0.15, dt))

		-- dread: rises quickly as a Hollow closes in, ebbs slowly once it has gone
		local nearest = if Registry.HollowAnimator then Registry.HollowAnimator.Nearest(around) else math.huge
		local targetDread = if inLobby
			then 0
			else 1 - MathX.saturate((nearest - DREAD_NEAR) / (DREAD_FAR - DREAD_NEAR))
		dread = MathX.lerp(dread, targetDread, MathX.damp(if targetDread > dread then 0.25 else 2, dt))
		Overlay.dread(dread)

		-- a station's fog bank closing over the camera
		local fog = 0
		if not inLobby then
			local depth = Registry.StationVisualsController and Registry.StationVisualsController.FogDepth()
			local localPos = Registry.StationVisualsController
				and Registry.StationVisualsController.ToLocal(around)
			if depth and localPos then
				fog = math.clamp((localPos.Z - (depth - 24)) / 30, 0, 1)
			end
		end

		-- what the sky is doing now, the same on every client
		local seed = Registry.StateController.Get({ "run", "seed" }) or 0
		local omen = devOmen or (if inLobby then nil else Omens.at(seed, now, dark))
		omenNow = omen
		rainNow = if inLobby or scenery == nil
			then 0
			else rainAt(seed, scenery.progress, dark) * (1 - darkness)
		local storm = math.max(MathX.lerp(a.storm, b.storm, w), S.DryLightning * dark, 0.45 * rainNow)
		local strike = devStrike or Omens.omenStrike(omen, now) or Omens.strike(seed, now, storm)
		if inLobby or darkness > 0.5 then
			strike = nil
		end
		if strike and strike.start ~= lastStrike then
			lastStrike = strike.start
			local near = 1
				- MathX.saturate((strike.distance - S.StrikeRange[1]) / (S.StrikeRange[2] - S.StrikeRange[1]))
			task.delay(Omens.thunderDelay(strike), function()
				if Registry.AudioController then
					Registry.AudioController.Play("Thunder", nil, 0.55 + 0.65 * near, 0.85 + 0.3 * near)
				end
			end)
		end
		local flash = Omens.flash(strike, now)

		local flare = 0
		if os.clock() < flareUntil then
			flare = (flareUntil - os.clock()) / 1.6
		end
		local alarm = if phase == "LastCall" or phase == "Departure"
			then 0.5 + 0.5 * math.sin(now * 5)
			else nil

		local target = Sky.compose({
			hour = hour,
			a = a,
			b = b,
			w = w,
			lobby = inLobby,
			fog = fog,
			alarm = alarm,
			dread = dread,
			eliminated = Session.status() == "Eliminated" and Session.isRunActive(),
			flare = flare,
			omen = omen,
			now = now,
		})
		current = Sky.approach(current, target, dt)
		local drawn = Sky.finish(current :: Sky.State, darkness, flash, strike ~= nil and strike.red)
		apply(drawn)
		moonNow = if drawn.hidden then nil else drawn.moon

		-- the deck streams back over the train; the moon's scud runs with it
		local speed = if Registry.SceneryController then Registry.SceneryController.Speed() else 0
		local wind = Sky.wind(speed, now)
		if (wind - windShown).Magnitude > 0.5 then
			windShown = wind
			Workspace.GlobalWind = wind
		end
		Heavens.update(heavens, drawn, {
			now = now,
			focus = camera.CFrame.Position,
			omen = omen,
			strike = strike,
			drift = 1 + 2 * math.min(speed / Tuning.Motion.CruiseSpeed, 1),
		})

		-- weather, thicker deep in the night
		local rates: { [string]: number } = {}
		if not inLobby then
			local exposed = (1 - darkness) * (1 + WEATHER_NIGHT * dark)
			rates[a.weather] = (rates[a.weather] or 0) + a.weatherRate * (1 - w) * exposed
			rates[b.weather] = (rates[b.weather] or 0) + b.weatherRate * w * exposed
		end
		updateWeather(around, rates, speed)
		local ground = if root then root.Position.Y - 3 else camera.CFrame.Position.Y - 5
		updateRain(dt, camera.CFrame.Position, ground, rainNow, speed)
	end

	RunService.RenderStepped:Connect(function(dt)
		Safe.call("Atmosphere", frame, dt)
	end)
end

function AtmosphereController.FlareFlash()
	flareUntil = os.clock() + 1.6
end

-- The omen under way, if any (the soundscape follows it).
function AtmosphereController.Omen(): Omens.Omen?
	return omenNow
end

-- How hard it is raining on the run right now, 0..1 (sheltered or not).
function AtmosphereController.Rain(): number
	return rainNow
end

-- How deep into the night the camera's run is: 0 at dusk and dawn, 1 at the darkest hour.
function AtmosphereController.Dark(): number
	return darkNow
end

-- The hour the sky is showing (past 24 is the small hours), for the HUD's night dial.
function AtmosphereController.Hour(): number
	return hour
end

-- Where the moon hangs and how it looks right now, after omens and cloud (the train camera frames it).
function AtmosphereController.Moon(): Sky.Moon?
	return moonNow
end

return AtmosphereController
