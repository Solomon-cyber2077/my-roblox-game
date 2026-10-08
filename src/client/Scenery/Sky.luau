--!strict
--[[
	The sky as data and math: what the light, the air, the clouds and the moon should
	be for an hour of the run, a biome mix and the moment's dread and omens.
	AtmosphereController feeds it every frame and applies the result to Lighting and to
	the sky objects (Scenery/Heavens); `lune run preview` evaluates the same functions to
	draw the sky outside Roblox.

	The night is meant to weigh on the crew:

	  * dusk falls bruised: a blood-orange horizon under a low, dark deck, then a violet
	    last light
	  * about eight the moon rises over the platform side, huge and amber. It turns
	    copper, then blood red as an eclipse shadow creeps across it; at two in the
	    morning it hangs deep red inside a halo ring and the stars have nearly all gone
	    out. Before dawn it pales to bone and sinks.
	  * its light turns red with it (ColorShift_Top) and reddens the haze and the
	    underside of the clouds
	  * fires and furnaces (and in the high country something colder) light the night
	    horizon, so the ranges stand black against a glow
	  * omens (Logic/Omens) bend all of it for a few seconds: the moon blinks, opens an
	    eye, bleeds; every sound and star goes out; lightning shows what stands out there

	Sunrise at the Terminus is the relief, and is left warm and clear.

	Hours past 24 are the small hours of the next morning (Logic/Journey.hour).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Journey = require(Shared.Logic.Journey)
local Omens = require(Shared.Logic.Omens)
local MathX = require(Shared.Util.MathX)

local Biomes = require(script.Parent.Biomes)

export type Key = {
	hour: number,
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoor: Color3,
	shift: Color3, -- Lighting.ColorShift_Top: light added on faces toward the sun or moon
	air: Color3, -- Atmosphere.Color
	decay: Color3, -- Atmosphere.Decay
	clouds: Color3,
	rays: number,
	tint: Color3, -- the grade: warm at the ends of the night, cold in it
	saturation: number,
	haze: number, -- Atmosphere.Haze before the biome's
	density: number, -- Atmosphere.Density before the biome's
	cover: number, -- added to the biome's cloud cover: the night closes in
	stars: number,
	glow: number, -- how much of the biome's horizon glow shows (none by day)
}

type MoonKey = {
	hour: number,
	elevation: number, -- degrees above the horizon
	azimuth: number, -- degrees from ahead (+X) toward the platform side (+Z)
	size: number, -- degrees across the disc
	color: Color3,
	glow: Color3,
	brightness: number, -- BillboardGui.Brightness: past 1 it blooms
	umbra: number, -- 0..1 of the disc under the eclipse shadow
	ring: number, -- 0..1 the halo ring
}

export type Moon = {
	visible: number, -- 0..1
	direction: Vector3,
	size: number,
	color: Color3,
	glow: Color3,
	brightness: number,
	umbra: number,
	ring: number,
	veil: number, -- 0..1 cloud drawn over it
	lid: number, -- 0 open .. 1 shut: the Blink
	pupil: number, -- 0..1: the Eye
	throb: number, -- 0..1 pulse of its glow
}

export type State = {
	clock: number, -- Lighting.ClockTime
	dark: number, -- 0..1 how deep into the night
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoor: Color3,
	shift: Color3,
	density: number,
	haze: number,
	glare: number,
	air: Color3,
	decay: Color3,
	cover: number,
	cloudDensity: number,
	clouds: Color3,
	rays: number,
	stars: number,
	saturation: number,
	contrast: number,
	tint: Color3,
	lift: number, -- grade brightness
	blur: number, -- depth of field past the focus: dread narrows the eye
	glow: number,
	glowColor: Color3,
	flash: number, -- lightning 0..1
	flashColor: Color3,
	bloom: number, -- BloomEffect.Intensity
	bloomThreshold: number, -- BloomEffect.Threshold: only light brighter than this blooms
	bloomSize: number, -- BloomEffect.Size
	moon: Moon,
	hidden: boolean, -- no sky objects (the Depot Hall)
}

export type Inputs = {
	hour: number,
	a: Biomes.Def,
	b: Biomes.Def,
	w: number, -- weight of b
	lobby: boolean,
	fog: number, -- 0..1 how far into a station's fog the camera is
	alarm: number?, -- Last Call and Departure: the alarm pulse 0..1
	dread: number, -- 0..1 a Hollow close by
	eliminated: boolean,
	flare: number, -- 0..1 a flare's flash, fading
	omen: Omens.Omen?,
	now: number, -- server time, for pulses
}

local rgb = Color3.fromRGB

local Sky = {}

local KEYS: { Key } = {
	{ -- the lobby: the sun on the horizon, bleeding into a low deck
		hour = 18.3,
		brightness = 1.6,
		exposure = 0.08,
		ambient = rgb(62, 48, 54),
		outdoor = rgb(116, 88, 88),
		shift = rgb(110, 70, 50),
		air = rgb(208, 112, 76),
		decay = rgb(84, 40, 58),
		clouds = rgb(196, 102, 90),
		rays = 0.1,
		tint = rgb(255, 234, 216),
		saturation = -0.02,
		haze = 2.2,
		density = 0.4,
		cover = 0.06,
		stars = 0,
		glow = 0,
	},
	{ -- embers of the sunset
		hour = 18.9,
		brightness = 1.25,
		exposure = 0.16,
		ambient = rgb(62, 50, 62),
		outdoor = rgb(116, 90, 104),
		shift = rgb(100, 52, 46),
		air = rgb(162, 70, 58),
		decay = rgb(54, 26, 46),
		clouds = rgb(150, 64, 70),
		rays = 0.05,
		tint = rgb(255, 228, 224),
		saturation = -0.06,
		haze = 2.0,
		density = 0.42,
		cover = 0.06,
		stars = 0,
		glow = 0.1,
	},
	{ -- the last light, a bruise
		hour = 19.6,
		brightness = 0.95,
		exposure = 0.26,
		ambient = rgb(62, 58, 80),
		outdoor = rgb(104, 98, 132),
		shift = rgb(60, 50, 80),
		air = rgb(92, 62, 98),
		decay = rgb(34, 24, 48),
		clouds = rgb(78, 58, 88),
		rays = 0.01,
		tint = rgb(234, 232, 255),
		saturation = -0.06,
		haze = 1.8,
		density = 0.44,
		cover = 0.08,
		stars = 150,
		glow = 0.4,
	},
	{ -- night, the moon up and amber
		hour = 22,
		brightness = 0.8,
		exposure = 0.34,
		ambient = rgb(60, 56, 74),
		outdoor = rgb(110, 100, 124),
		shift = rgb(120, 80, 64),
		air = rgb(60, 44, 54),
		decay = rgb(24, 20, 32),
		clouds = rgb(56, 44, 56),
		rays = 0,
		tint = rgb(228, 226, 255),
		saturation = -0.1,
		haze = 1.5,
		density = 0.44,
		cover = 0.1,
		stars = 450,
		glow = 0.85,
	},
	{ -- two in the morning: the blood moon, the darkest hour
		hour = 26,
		brightness = 0.75,
		exposure = 0.34,
		ambient = rgb(66, 52, 62),
		outdoor = rgb(122, 94, 106),
		shift = rgb(150, 60, 52),
		air = rgb(66, 32, 40),
		decay = rgb(26, 14, 22),
		clouds = rgb(54, 30, 38),
		rays = 0,
		tint = rgb(238, 220, 228),
		saturation = -0.1,
		haze = 1.4,
		density = 0.46,
		cover = 0.14,
		stars = 100,
		glow = 1,
	},
	{ -- before dawn, the moon gone pale and low
		hour = 28.9,
		brightness = 0.95,
		exposure = 0.3,
		ambient = rgb(64, 64, 86),
		outdoor = rgb(112, 112, 144),
		shift = rgb(60, 60, 80),
		air = rgb(96, 90, 118),
		decay = rgb(46, 40, 64),
		clouds = rgb(104, 98, 128),
		rays = 0.01,
		tint = rgb(236, 236, 255),
		saturation = -0.12,
		haze = 1.9,
		density = 0.46,
		cover = 0.06,
		stars = 250,
		glow = 0.3,
	},
	{ -- sunrise at the Terminus: the relief
		hour = 30.5,
		brightness = 2.0,
		exposure = 0.15,
		ambient = rgb(76, 64, 70),
		outdoor = rgb(152, 128, 118),
		shift = rgb(90, 70, 50),
		air = rgb(228, 172, 142),
		decay = rgb(126, 84, 72),
		clouds = rgb(252, 206, 180),
		rays = 0.1,
		tint = rgb(255, 240, 226),
		saturation = -0.02,
		haze = 2.4,
		density = 0.38,
		cover = -0.05,
		stars = 0,
		glow = 0,
	},
}

--[[
	The moon's night. A full moon rises as the sun sets, so it is already climbing,
	huge and amber, when the train makes its first stop. It rides over the stations'
	side of the line (+Z) and stands high enough to clear their roofs and the trees on
	their far edge. It turns copper as it climbs; from midnight the eclipse creeps across
	it until at two it hangs blood red in its ring; then it pales and sinks into the dawn.
	The HUD's night dial names these phases (Sky.Phases).
]]
local MOON: { MoonKey } = {
	{
		hour = 18.2,
		elevation = -2,
		azimuth = 62,
		size = 11.5,
		color = rgb(244, 160, 84),
		glow = rgb(206, 110, 58),
		brightness = 1.45,
		umbra = 0,
		ring = 0,
	},
	{
		hour = 18.9, -- the first stop: just over the trees
		elevation = 11,
		azimuth = 68,
		size = 11,
		color = rgb(240, 148, 76),
		glow = rgb(200, 100, 54),
		brightness = 1.5,
		umbra = 0,
		ring = 0,
	},
	{
		hour = 19.6, -- the second stop
		elevation = 16,
		azimuth = 72,
		size = 10.5,
		color = rgb(236, 136, 70),
		glow = rgb(196, 92, 50),
		brightness = 1.5,
		umbra = 0,
		ring = 0,
	},
	{
		hour = 21.4,
		elevation = 22,
		azimuth = 78,
		size = 9.8,
		color = rgb(226, 112, 58),
		glow = rgb(184, 80, 46),
		brightness = 1.5,
		umbra = 0,
		ring = 0.1,
	},
	{
		hour = 23,
		elevation = 26,
		azimuth = 84,
		size = 9.2,
		color = rgb(210, 90, 56),
		glow = rgb(166, 52, 36),
		brightness = 1.55,
		umbra = 0.15,
		ring = 0.3,
	},
	{
		hour = 24.6,
		elevation = 29,
		azimuth = 90,
		size = 8.8,
		color = rgb(190, 54, 42),
		glow = rgb(152, 32, 26),
		brightness = 1.6,
		umbra = 0.45,
		ring = 0.7,
	},
	{
		hour = 26, -- two in the morning: the blood moon
		elevation = 30,
		azimuth = 96,
		size = 8.6,
		color = rgb(170, 38, 32),
		glow = rgb(140, 22, 20),
		brightness = 1.65,
		umbra = 0.62,
		ring = 1,
	},
	{
		hour = 27.6,
		elevation = 23,
		azimuth = 104,
		size = 9,
		color = rgb(186, 76, 58),
		glow = rgb(142, 54, 46),
		brightness = 1.55,
		umbra = 0.3,
		ring = 0.5,
	},
	{
		hour = 29,
		elevation = 10,
		azimuth = 112,
		size = 9.8,
		color = rgb(216, 198, 186),
		glow = rgb(150, 140, 150),
		brightness = 1.45,
		umbra = 0,
		ring = 0,
	},
	{
		hour = 29.9,
		elevation = -3,
		azimuth = 117,
		size = 10.2,
		color = rgb(214, 200, 190),
		glow = rgb(140, 130, 140),
		brightness = 1.3,
		umbra = 0,
		ring = 0,
	},
}

-- What the night dial calls each stretch of the night, from the hour it starts.
Sky.Phases = table.freeze({
	{ from = -math.huge, name = "SUNSET" },
	{ from = 18.2, name = "MOONRISE" },
	{ from = 19.2, name = "AMBER MOON" },
	{ from = 21.6, name = "COPPER MOON" },
	{ from = 23.4, name = "ECLIPSE" },
	{ from = 25.3, name = "BLOOD MOON" },
	{ from = 26.9, name = "MOON WANING" },
	{ from = 28.6, name = "PALE MOON" },
	{ from = 29.9, name = "DAWN" },
})

-- The phase of the night at `hour`, and the next one with the hour it starts (nil at dawn).
function Sky.phase(hour: number): (string, string?, number?)
	local phases = Sky.Phases
	for i = #phases, 1, -1 do
		if hour >= phases[i].from then
			local following = phases[i + 1]
			return phases[i].name,
				if following then following.name else nil,
				if following then following.from else nil
		end
	end
	return phases[1].name, phases[2].name, phases[2].from
end

local BLOOD = rgb(255, 34, 26) -- the Bleed: the moon, its light, its bolt
local BLOOD_GLOW = rgb(200, 16, 12)
local BLOOD_AIR = rgb(96, 14, 14)
local BLOOD_CLOUD = rgb(92, 16, 18)
local BLOOD_DECAY = rgb(26, 4, 8)
local DREAD_TINT = rgb(196, 214, 255)
local FLASH = rgb(206, 204, 255)
local TUNNEL_OUTDOOR = rgb(40, 38, 44)
local DREAD = { saturation = 0.5, contrast = 0.2, tint = 0.5, density = 0.16, haze = 0.8, exposure = 0.05 }
local BLOOM = { intensity = 0.55, threshold = 1.3, size = 24 }
-- dimmed to ~55% (was 0.7, -0.14, 108/96/88, 114/100/92); the lamps still light the floor
local LOBBY = {
	brightness = 0.3, -- the low sun through the glazing
	exposure = -0.6,
	ambient = rgb(54, 55, 58), -- same light as before, less amber, so whites and greys stay true
	outdoor = rgb(58, 58, 62),
	bloom = 0.25,
	bloomThreshold = 1.8,
	bloomSize = 16,
}

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

local function multiply(a: Color3, b: Color3): Color3
	return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

-- The sky key for a continuous hour, interpolated between the table's keys.
function Sky.key(hour: number): Key
	if hour <= KEYS[1].hour then
		return KEYS[1]
	end
	for i = 2, #KEYS do
		local b = KEYS[i]
		if hour <= b.hour then
			local a = KEYS[i - 1]
			local t = (hour - a.hour) / (b.hour - a.hour)
			local lerp = MathX.lerp
			return {
				hour = hour,
				brightness = lerp(a.brightness, b.brightness, t),
				exposure = lerp(a.exposure, b.exposure, t),
				ambient = lerpColor(a.ambient, b.ambient, t),
				outdoor = lerpColor(a.outdoor, b.outdoor, t),
				shift = lerpColor(a.shift, b.shift, t),
				air = lerpColor(a.air, b.air, t),
				decay = lerpColor(a.decay, b.decay, t),
				clouds = lerpColor(a.clouds, b.clouds, t),
				rays = lerp(a.rays, b.rays, t),
				tint = lerpColor(a.tint, b.tint, t),
				saturation = lerp(a.saturation, b.saturation, t),
				haze = lerp(a.haze, b.haze, t),
				density = lerp(a.density, b.density, t),
				cover = lerp(a.cover, b.cover, t),
				stars = lerp(a.stars, b.stars, t),
				glow = lerp(a.glow, b.glow, t),
			}
		end
	end
	return KEYS[#KEYS]
end

-- How deep into the night an hour is: 0 at dusk and dawn, 1 at the darkest hour.
function Sky.darkness(hour: number): number
	if hour <= 26 then
		return MathX.smoothstep(19.4, 25.2, hour)
	end
	return 1 - MathX.smoothstep(27.4, 29.8, hour)
end

-- A direction from an azimuth (degrees from +X toward +Z) and an elevation (degrees).
function Sky.direction(azimuth: number, elevation: number): Vector3
	local az, el = math.rad(azimuth), math.rad(elevation)
	return Vector3.new(math.cos(el) * math.cos(az), math.sin(el), math.cos(el) * math.sin(az))
end

-- Where the moon is and how it looks at an hour, before clouds and omens.
function Sky.moon(hour: number): Moon
	local first, last = MOON[1], MOON[#MOON]
	local a, b, t = first, first, 0
	if hour >= last.hour then
		a, b = last, last
	elseif hour > first.hour then
		for i = 2, #MOON do
			if hour <= MOON[i].hour then
				a, b = MOON[i - 1], MOON[i]
				t = (hour - a.hour) / (b.hour - a.hour)
				break
			end
		end
	end
	local lerp = MathX.lerp
	local visible = MathX.smoothstep(first.hour, first.hour + 0.4, hour)
		* (1 - MathX.smoothstep(last.hour - 0.4, last.hour, hour))
	return {
		visible = visible,
		direction = Sky.direction(lerp(a.azimuth, b.azimuth, t), lerp(a.elevation, b.elevation, t)),
		size = lerp(a.size, b.size, t),
		color = lerpColor(a.color, b.color, t),
		glow = lerpColor(a.glow, b.glow, t),
		brightness = lerp(a.brightness, b.brightness, t),
		umbra = lerp(a.umbra, b.umbra, t),
		ring = lerp(a.ring, b.ring, t),
		veil = 0,
		lid = 0,
		pupil = 0,
		throb = 0,
	}
end

-- 0 -> 1 -> 0 over an omen: in by `rise`, out from `fall`.
local function envelope(progress: number, rise: number, fall: number): number
	return MathX.smoothstep(0, rise, progress) * (1 - MathX.smoothstep(fall, 1, progress))
end

-- What the sky should be, before smoothing, tunnels and lightning (Sky.finish).
function Sky.compose(i: Inputs): State
	local key = Sky.key(i.hour)
	local dark = Sky.darkness(i.hour)
	local a, b, w = i.a, i.b, i.w
	local lerp = MathX.lerp
	local omen = i.omen
	local kind = if omen then omen.kind else nil
	local progress = if omen then omen.progress else 0

	local moon = Sky.moon(i.hour)
	local bleed = if kind == "Bleed" then envelope(progress, 0.3, 0.7) else 0
	local hush = if kind == "Hush" then envelope(progress, 0.15, 0.8) else 0
	if kind == "Blink" then
		-- shut over a third of a second, held, then slowly open again
		moon.lid = MathX.smoothstep(0.1, 0.24, progress) * (1 - MathX.smoothstep(0.46, 0.8, progress))
	elseif kind == "Eye" then
		moon.pupil = envelope(progress, 0.22, 0.8)
		moon.throb = moon.pupil * (0.5 + 0.5 * math.sin(i.now * math.pi * 2.2))
	elseif kind == "TallOnes" then
		moon.brightness *= 0.6
	end
	if bleed > 0 then
		moon.color = moon.color:Lerp(BLOOD, 0.75 * bleed)
		moon.glow = moon.glow:Lerp(BLOOD_GLOW, 0.8 * bleed)
		moon.brightness *= 1 + 0.6 * bleed
		moon.umbra *= 1 - bleed
		moon.throb = math.max(moon.throb, bleed * (0.5 + 0.5 * math.sin(i.now * math.pi * 1.6)))
	end
	moon.brightness *= 1 - 0.5 * hush

	local cover = math.clamp(lerp(a.cloudCover, b.cloudCover, w) + key.cover, 0, 0.97)
	moon.veil = MathX.saturate((cover - 0.55) / 0.4)
	-- how strongly the moon colours the night: up, clear of cloud, and deep in it
	local moonlight = moon.visible * (1 - 0.5 * moon.veil) * dark
	-- the sky objects are never fogged by the engine, so a station's fog bank hides them here
	moon.visible *= 1 - 0.85 * i.fog
	local glow = lerp(a.glow, b.glow, w) * key.glow * (1 - 0.7 * hush) * (1 - 0.8 * i.fog)
	local glowColor = a.glowColor:Lerp(b.glowColor, w)

	local air = multiply(key.air, a.tint:Lerp(b.tint, w))
		:Lerp(moon.glow, 0.15 * moonlight)
		:Lerp(glowColor, 0.05 * glow)
	local decay = multiply(key.decay, a.tint:Lerp(b.tint, w))
	-- the deck's underside catches the moon and, where there are fires, burns with them
	local clouds = multiply(key.clouds, a.cloudColor:Lerp(b.cloudColor, w))
		:Lerp(moon.glow, 0.2 * moonlight)
		:Lerp(glowColor, 0.2 * glow)
	local shift = key.shift:Lerp(moon.glow, 0.3 * moonlight)
	if bleed > 0 then
		air = air:Lerp(BLOOD_AIR, 0.6 * bleed)
		decay = decay:Lerp(BLOOD_DECAY, 0.4 * bleed)
		clouds = clouds:Lerp(BLOOD_CLOUD, 0.6 * bleed)
		shift = shift:Lerp(BLOOD, 0.7 * bleed)
	end

	local state: State = {
		clock = Journey.clock(i.hour),
		dark = dark,
		brightness = key.brightness,
		exposure = key.exposure,
		ambient = key.ambient,
		outdoor = key.outdoor,
		shift = shift,
		density = key.density + lerp(a.density, b.density, w),
		haze = key.haze + 0.6 * lerp(a.haze, b.haze, w),
		glare = 0.2 * (1 - dark),
		air = air,
		decay = decay,
		cover = cover,
		cloudDensity = math.clamp(lerp(a.cloudDensity, b.cloudDensity, w) + 0.12 * dark, 0, 1),
		clouds = clouds,
		rays = key.rays,
		stars = key.stars * (1 - hush),
		saturation = key.saturation,
		contrast = 0,
		tint = key.tint,
		lift = 0,
		blur = 0,
		glow = glow,
		glowColor = glowColor,
		flash = 0,
		flashColor = FLASH,
		-- lamps, fires and the moon glow, but only what is really bright: a lit sign or a
		-- window must never smear into the text around it
		bloom = BLOOM.intensity,
		bloomThreshold = BLOOM.threshold,
		bloomSize = BLOOM.size,
		moon = moon,
		hidden = i.lobby,
	}

	if i.lobby then
		--[[
			The Depot Hall: warm, soft and even. The ambient carries most of the light, the
			lamps only warm it, so every corner reads (and every poster) with no hot spot
			anywhere and nothing blooming but the bulbs themselves.
		]]
		state.brightness = LOBBY.brightness
		state.exposure = LOBBY.exposure
		state.ambient = LOBBY.ambient
		state.outdoor = LOBBY.outdoor
		state.density, state.haze = 0.18, 0.8
		state.tint = rgb(255, 238, 222)
		state.saturation = 0.04
		state.lift = -0.02
		state.contrast = 0.04
		state.bloom, state.bloomThreshold, state.bloomSize =
			LOBBY.bloom, LOBBY.bloomThreshold, LOBBY.bloomSize
	else
		state.density = lerp(state.density, 0.78, i.fog)
		state.haze = lerp(state.haze, 4, i.fog)
		state.saturation -= 0.3 * i.fog
		if i.alarm then
			state.tint = Color3.new(1, 0.9 - 0.06 * i.alarm, 0.88 - 0.08 * i.alarm)
			state.contrast = 0.12
		end
		-- dread: a Hollow close by drains the colour, hardens the light and closes the air in
		local d = i.dread
		state.saturation -= DREAD.saturation * d
		state.contrast += DREAD.contrast * d
		state.tint = state.tint:Lerp(DREAD_TINT, DREAD.tint * d)
		state.density += DREAD.density * d
		state.haze += DREAD.haze * d
		state.exposure -= DREAD.exposure * d
		state.blur = 0.3 * d
		if bleed > 0 then
			state.saturation += 0.2 * bleed
			state.contrast += 0.08 * bleed
			state.tint = state.tint:Lerp(rgb(255, 206, 200), 0.45 * bleed)
		end
	end
	if i.eliminated then
		state.saturation = -0.65
	end
	if i.flare > 0 then
		state.tint = state.tint:Lerp(rgb(255, 150, 140), i.flare)
		state.lift = 0.08 * i.flare
	end
	return state
end

local SMOOTH_COLORS = { "ambient", "outdoor", "shift", "air", "decay", "clouds", "tint", "glowColor" }
local SMOOTH_NUMBERS = {
	"brightness",
	"exposure",
	"density",
	"haze",
	"cover",
	"cloudDensity",
	"saturation",
	"contrast",
	"lift",
	"blur",
	"glow",
	"stars",
	"bloom",
	"bloomThreshold",
	"bloomSize",
}

-- Eases `current` toward `target`; the moon, the clock and the omens follow at once.
function Sky.approach(current: State?, target: State, dt: number): State
	if current == nil then
		return target
	end
	local k = MathX.damp(0.35, dt)
	local out = table.clone(target)
	local from = current :: any
	local into = out :: any
	for _, name in SMOOTH_NUMBERS do
		into[name] = MathX.lerp(from[name], into[name], k)
	end
	for _, name in SMOOTH_COLORS do
		into[name] = (from[name] :: Color3):Lerp(into[name], k)
	end
	return out
end

--[[
	Workspace.GlobalWind, which drives the cloud deck: it streams back past the train
	(slower than the land, being far higher up) with a slow sideways weather of its own,
	so even at a stop the sky never holds still.
]]
function Sky.wind(speed: number, now: number): Vector3
	return Vector3.new(-(8 + 0.35 * speed), 0, 4 + 3 * math.sin(now * 0.07))
end

--[[
	The state as it is drawn: a tunnel's dark (0..1, smoothed by the caller) shuts out
	the sky, and lightning (0..1) lights the clouds, the haze and the world.
]]
function Sky.finish(state: State, tunnel: number, flash: number, red: boolean): State
	local out = table.clone(state)
	local open = 1 - tunnel
	local color = if red then BLOOD else FLASH
	out.brightness = state.brightness * open + 3 * flash
	out.exposure = state.exposure - 0.18 * tunnel
	out.ambient = state.ambient:Lerp(rgb(40, 34, 32), tunnel * 0.5)
	out.outdoor = state.outdoor:Lerp(TUNNEL_OUTDOOR, tunnel)
	out.density = MathX.lerp(state.density, 0.12, tunnel)
	out.haze = MathX.lerp(state.haze, 0, tunnel)
	out.air = state.air:Lerp(rgb(20, 18, 18), tunnel):Lerp(color, 0.45 * flash)
	out.decay = state.decay:Lerp(rgb(10, 9, 9), tunnel):Lerp(color, 0.25 * flash)
	out.clouds = state.clouds:Lerp(if red then BLOOD else Color3.new(1, 1, 1), 0.7 * flash)
	out.shift = state.shift:Lerp(color, flash)
	out.rays = state.rays * open
	out.lift = state.lift + 0.25 * flash
	out.flash = flash
	out.flashColor = color
	out.bloom = state.bloom + 0.4 * flash
	return out
end

return Sky
