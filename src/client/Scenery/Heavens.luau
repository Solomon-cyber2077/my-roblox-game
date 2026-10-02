--!strict
--[[
	The sky objects the engine does not draw for us: the moon, the glow of fires on
	the horizon, the TallOnes and the lightning. Each is a BillboardGui of plain
	Frames, rounded with UICorner and shaded with UIGradient, so nothing is uploaded.

	They hang on attachments of one invisible anchor that follows the camera, set far
	beyond the furthest mountain, so they sit at infinity: the train never gets any
	closer, while hills, trees and tunnel mouths pass in front of them. BillboardGuis
	are depth tested but never fogged, which keeps the moon sharp through the haze;
	Scenery/Sky veils it where the air or the cloud should.

	  moon     a halo built up from soft rings, a 22-degree ring, a shaded disc with
	           dark maria, the eclipse shadow, an eye that is usually not there, a lid
	           that blinks, and scud drifting across its face
	  glows    three low domes of light on the horizon in the biome's glow colour,
	           flickering as fires do
	  figures  the TallOnes: three gaunt shapes standing behind the far hills, drawn
	           only while lightning is on them, plus a moment's afterimage
	  bolt     a forked lightning bolt redrawn for every strike from its seed

	Heavens.build makes the rig once; Heavens.update poses it every frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Omens = require(Shared.Logic.Omens)
local Tuning = require(Shared.Config.Tuning)
local MathX = require(Shared.Util.MathX)
local Rng = require(Shared.Util.Rng)

local Sky = require(script.Parent.Sky)

type MoonRig = {
	gui: BillboardGui,
	attachment: Attachment,
	halo: { Frame },
	ring: { Frame },
	disc: Frame,
	maria: { Frame },
	umbra: Frame,
	umbraGradient: UIGradient,
	iris: Frame,
	pupil: Frame,
	lid: Frame,
	lidGradient: UIGradient,
	scud: { Frame },
	umbraShown: number,
	sizeShown: number,
	haloShown: number,
	ringShown: number,
}

type GlowRig = { gui: BillboardGui, attachment: Attachment, layers: { Frame }, weight: number, shown: number }
type FigureRig = { gui: BillboardGui, attachment: Attachment, parts: { Frame } }
type BoltRig = {
	gui: BillboardGui,
	attachment: Attachment,
	cores: { Frame },
	glows: { Frame },
	seed: number,
}

export type Rig = {
	anchor: BasePart,
	moon: MoonRig,
	glows: { GlowRig },
	figures: { FigureRig },
	figureSeed: number,
	bolt: BoltRig,
}

export type Info = {
	now: number, -- server time
	focus: Vector3, -- the camera, which the sky follows
	omen: Omens.Omen?,
	strike: Omens.Strike?,
	drift: number, -- how fast cloud crosses the moon (follows the train's speed)
}

local Heavens = {}

local DISTANCE = 16000 -- studs: past the furthest range, inside the camera's reach
local SPAN = 4 -- the moon's billboard is this many discs across (room for the halo)
local DISC = 1 / SPAN
local CLOUD_BASE = 1100 -- studs: where bolts come down from
local WHITE = Color3.new(1, 1, 1)
local rgb = Color3.fromRGB

--[[
	The moon's halo. A frame's edge is always hard, so a few stacked discs band like a
	target. Here the discs are many, and their radii are chosen so each adds the same small
	step of glow (HALO_STEP of opacity): the light falls off as the profile below, and no
	single edge is strong enough to see. Radii are shares of the billboard; the disc's
	edge is at 0.125.
]]
local HALO_STEP = 0.014
local function haloProfile(r: number): number
	-- a bright corona hugging the disc over a wide, faint glow
	return 0.5 * math.exp(-(r - 0.125) / 0.045) + 0.12 * math.exp(-(r - 0.125) / 0.17)
end
local HALO: { { radius: number, alpha: number } } = {}
do
	local covered = haloProfile(0.5)
	local r = 0.5
	while r > 0.13 do
		-- step inward until the glow has risen by one step
		local target = covered + HALO_STEP
		local lo, hi = 0.125, r
		for _ = 1, 30 do
			local mid = (lo + hi) / 2
			if haloProfile(mid) > target then
				lo = mid
			else
				hi = mid
			end
		end
		r = (lo + hi) / 2
		-- the opacity this disc adds on top of those outside it
		table.insert(HALO, { radius = r, alpha = 1 - (1 - target) / (1 - covered) })
		covered = target
	end
end
local RING_RADIUS = 0.4 -- of the billboard: 3.2 moon radii
local RING_SEGMENTS = 48
local RING_THICKNESS = 0.06 -- broad and faint, as a real halo is
-- The maria: overlapping blots, as offsets from the centre and sizes, in shares of the
-- billboard. Two of them sit where eyes would be, which nobody quite notices.
local MARIA = {
	{ x = -0.036, y = -0.03, size = 0.062, alpha = 0.26 },
	{ x = -0.018, y = -0.042, size = 0.04, alpha = 0.18 },
	{ x = 0.034, y = -0.034, size = 0.05, alpha = 0.24 },
	{ x = 0.012, y = 0.03, size = 0.074, alpha = 0.2 },
	{ x = -0.026, y = 0.046, size = 0.044, alpha = 0.18 },
	{ x = 0.05, y = 0.022, size = 0.032, alpha = 0.2 },
	{ x = -0.058, y = 0.012, size = 0.028, alpha = 0.16 },
}
-- Scud crossing the moon's face, soft above and below and dark against the light: width,
-- height, height on the billboard, speed, alpha, phase. Each fades in and out across the
-- face, so none is ever seen against the open sky.
local SCUD = {
	{ w = 0.62, h = 0.032, y = 0.47, speed = 1, alpha = 0.34, at = 0.1 },
	{ w = 0.5, h = 0.045, y = 0.53, speed = 0.8, alpha = 0.28, at = 0.6 },
	{ w = 0.7, h = 0.026, y = 0.5, speed = 1.25, alpha = 0.32, at = 0.35 },
	{ w = 0.55, h = 0.04, y = 0.56, speed = 0.9, alpha = 0.26, at = 0.85 },
}
local SCUD_TRAVEL = { 0.2, 0.8 } -- across the billboard

local GLOWS = {
	{ azimuth = 155, width = 52, weight = 1 },
	{ azimuth = 252, width = 40, weight = 0.8 },
	{ azimuth = 324, width = 46, weight = 0.9 },
}
local GLOW_HEIGHT = 0.36 -- of the width: tall enough to show over the ridges
local GLOW_LIFT = 1.5 -- degrees the dome's base sits above the horizon line
-- Stacked domes, sized as the moon's halo is so each adds the same small step of light
-- toward the middle, and no rim shows. `u` is a dome's share of the billboard's width.
local GLOW_STEP = 0.022
local function glowProfile(u: number): number
	return 0.55 * math.exp(-u / 0.32)
end
local GLOW_LAYERS: { { w: number, h: number, alpha: number } } = {}
do
	local covered = glowProfile(1)
	local u = 1
	while u > 0.1 do
		local target = covered + GLOW_STEP
		local lo, hi = 0.05, u
		for _ = 1, 30 do
			local mid = (lo + hi) / 2
			if glowProfile(mid) > target then
				lo = mid
			else
				hi = mid
			end
		end
		u = (lo + hi) / 2
		table.insert(GLOW_LAYERS, { w = u, h = 0.25 + 0.7 * u, alpha = 1 - (1 - target) / (1 - covered) })
		covered = target
	end
end

--[[
	A TallOne, in units of its own height: x across from its centre line, y down from
	the top of the billboard, w and h the frame's size, r its turn in degrees, round
	for rounded ends. Long arms, too many joints, a crown of bare branches.
]]
local FIGURE_ASPECT = 0.42 -- billboard width over height
local FIGURE = {
	{ x = 0, y = 0.085, w = 0.046, h = 0.075, r = 0, round = true }, -- head
	{ x = -0.03, y = 0.035, w = 0.007, h = 0.085, r = -26, round = true }, -- branches
	{ x = 0.032, y = 0.032, w = 0.007, h = 0.09, r = 24, round = true },
	{ x = -0.058, y = 0.006, w = 0.005, h = 0.045, r = -58, round = true },
	{ x = 0.06, y = 0.0, w = 0.005, h = 0.05, r = 60, round = true },
	{ x = -0.008, y = 0.012, w = 0.004, h = 0.04, r = -8, round = true },
	{ x = 0, y = 0.136, w = 0.015, h = 0.04, r = 0, round = false }, -- neck
	{ x = 0, y = 0.164, w = 0.12, h = 0.024, r = -3, round = true }, -- shoulders
	{ x = 0.004, y = 0.255, w = 0.066, h = 0.19, r = 3, round = true }, -- chest
	{ x = 0.002, y = 0.36, w = 0.056, h = 0.034, r = 0, round = true }, -- hips
	{ x = -0.066, y = 0.27, w = 0.013, h = 0.2, r = 6, round = true }, -- left arm
	{ x = -0.078, y = 0.47, w = 0.011, h = 0.22, r = 2, round = true },
	{ x = -0.081, y = 0.6, w = 0.02, h = 0.06, r = 8, round = true },
	{ x = 0.066, y = 0.27, w = 0.013, h = 0.2, r = -4, round = true }, -- right arm
	{ x = 0.072, y = 0.465, w = 0.011, h = 0.21, r = -8, round = true },
	{ x = 0.084, y = 0.59, w = 0.02, h = 0.055, r = -14, round = true },
	{ x = -0.022, y = 0.55, w = 0.016, h = 0.38, r = 2, round = true }, -- legs
	{ x = -0.026, y = 0.86, w = 0.014, h = 0.28, r = -1, round = true },
	{ x = 0.024, y = 0.55, w = 0.016, h = 0.38, r = -2, round = true },
	{ x = 0.03, y = 0.86, w = 0.014, h = 0.28, r = 2, round = true },
}
local FIGURE_COLOR = rgb(6, 4, 7)
local FIGURES = 3

local BOLT_SEGMENTS = 44

local function frame(parent: Instance, z: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 1
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function round(f: Frame)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
end

local function gradient(f: Frame, rotation: number, transparency: NumberSequence): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = transparency
	g.Parent = f
	return g
end

-- Soft across its width: clear at both edges, solid along the middle.
local SOFT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 1),
})

local function billboard(anchor: BasePart, name: string): (BillboardGui, Attachment)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Parent = anchor
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Adornee = attachment
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = math.huge
	gui.ClipsDescendants = false
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = attachment
	return gui, attachment
end

-- How many studs across something `degrees` wide is at the sky's distance.
local function span(degrees: number): number
	return 2 * DISTANCE * math.tan(math.rad(degrees) / 2)
end

-- Building ----------------------------------------------------------------------------------------

-- A thin soft ring of `segments` tangent frames around the billboard's centre.
local function annulus(
	parent: Instance,
	radius: number,
	width: number,
	segments: number,
	z: number
): { Frame }
	local list: { Frame } = {}
	local chord = 2 * radius * math.sin(math.pi / segments)
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		local f = frame(parent, z)
		f.Position = UDim2.fromScale(0.5 + radius * math.cos(a), 0.5 + radius * math.sin(a))
		f.Size = UDim2.fromScale(chord, width)
		f.Rotation = math.deg(a) + 90
		gradient(f, 90, SOFT)
		table.insert(list, f)
	end
	return list
end

local function buildMoon(anchor: BasePart): MoonRig
	local gui, attachment = billboard(anchor, "Moon")
	local halo: { Frame } = {}
	for _, spec in HALO do
		local f = frame(gui, 1)
		f.Size = UDim2.fromScale(spec.radius * 2, spec.radius * 2)
		round(f)
		table.insert(halo, f)
	end
	local ring = annulus(gui, RING_RADIUS, RING_THICKNESS, RING_SEGMENTS, 2)
	local disc = frame(gui, 3)
	disc.Size = UDim2.fromScale(DISC, DISC)
	round(disc)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 135
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.55, Color3.new(0.9, 0.88, 0.88)),
		ColorSequenceKeypoint.new(1, Color3.new(0.6, 0.52, 0.52)),
	})
	shade.Parent = disc
	local maria: { Frame } = {}
	for _, spec in MARIA do
		local f = frame(gui, 4)
		f.Position = UDim2.fromScale(0.5 + spec.x, 0.5 + spec.y)
		f.Size = UDim2.fromScale(spec.size, spec.size)
		round(f)
		table.insert(maria, f)
	end
	local umbra = frame(gui, 5)
	umbra.Size = UDim2.fromScale(DISC, DISC)
	umbra.BackgroundColor3 = rgb(26, 4, 6)
	round(umbra)
	local umbraGradient = gradient(umbra, -30, NumberSequence.new(1))
	local iris = frame(gui, 6)
	iris.Size = UDim2.fromScale(DISC * 0.68, DISC * 0.68)
	iris.BackgroundColor3 = rgb(70, 8, 10)
	round(iris)
	-- the iris darkens toward its rim
	gradient(
		iris,
		90,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.65),
			NumberSequenceKeypoint.new(1, 0.2),
		})
	)
	local pupil = frame(gui, 7)
	pupil.Size = UDim2.fromScale(DISC * 0.11, DISC * 0.66)
	pupil.BackgroundColor3 = rgb(8, 0, 1)
	round(pupil)
	local lid = frame(gui, 8)
	lid.Size = UDim2.fromScale(DISC * 1.02, DISC * 1.02)
	lid.BackgroundColor3 = rgb(10, 6, 10)
	round(lid)
	local lidGradient = gradient(
		lid,
		90,
		NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.56, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	)
	local scud: { Frame } = {}
	for _, spec in SCUD do
		local f = frame(gui, 9)
		f.Size = UDim2.fromScale(spec.w, spec.h)
		round(f)
		gradient(f, 90, SOFT)
		table.insert(scud, f)
	end
	return {
		gui = gui,
		attachment = attachment,
		halo = halo,
		ring = ring,
		disc = disc,
		maria = maria,
		umbra = umbra,
		umbraGradient = umbraGradient,
		iris = iris,
		pupil = pupil,
		lid = lid,
		lidGradient = lidGradient,
		scud = scud,
		umbraShown = -1,
		sizeShown = -1,
		haloShown = -1,
		ringShown = -1,
	}
end

local function buildGlow(anchor: BasePart, index: number): GlowRig
	local spec = GLOWS[index]
	local gui, attachment = billboard(anchor, `Glow{index}`)
	local width = span(spec.width)
	gui.Size = UDim2.fromScale(width, width * GLOW_HEIGHT)
	gui.Brightness = 1.3
	attachment.Position = Sky.direction(spec.azimuth, GLOW_LIFT) * DISTANCE
	local layers: { Frame } = {}
	for _, layer in GLOW_LAYERS do
		local f = frame(gui, 1)
		f.Size = UDim2.fromScale(layer.w, layer.h)
		round(f)
		-- fading upward from the horizon line, through the middle of the billboard
		gradient(
			f,
			90,
			NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 0),
			})
		)
		table.insert(layers, f)
	end
	return { gui = gui, attachment = attachment, layers = layers, weight = spec.weight, shown = -1 }
end

local function buildFigure(anchor: BasePart, index: number): FigureRig
	local gui, attachment = billboard(anchor, `TallOne{index}`)
	local parts: { Frame } = {}
	for _, spec in FIGURE do
		local f = frame(gui, 1)
		f.Position = UDim2.fromScale(0.5 + spec.x / FIGURE_ASPECT, spec.y)
		f.Size = UDim2.fromScale(spec.w / FIGURE_ASPECT, spec.h)
		f.Rotation = spec.r
		f.BackgroundColor3 = FIGURE_COLOR
		if spec.round then
			round(f)
		end
		table.insert(parts, f)
	end
	return { gui = gui, attachment = attachment, parts = parts }
end

local function buildBolt(anchor: BasePart): BoltRig
	local gui, attachment = billboard(anchor, "Bolt")
	gui.Brightness = 3
	local cores: { Frame } = {}
	local glows: { Frame } = {}
	for _ = 1, BOLT_SEGMENTS do
		local glow = frame(gui, 1)
		gradient(glow, 90, SOFT)
		glow.Visible = false
		table.insert(glows, glow)
		local core = frame(gui, 2)
		core.Visible = false
		table.insert(cores, core)
	end
	return { gui = gui, attachment = attachment, cores = cores, glows = glows, seed = -1 }
end

function Heavens.build(parent: Instance): Rig
	local anchor = Instance.new("Part")
	anchor.Name = "Heavens"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = parent
	local glows: { GlowRig } = {}
	for i = 1, #GLOWS do
		table.insert(glows, buildGlow(anchor, i))
	end
	local figures: { FigureRig } = {}
	for i = 1, FIGURES do
		table.insert(figures, buildFigure(anchor, i))
	end
	return {
		anchor = anchor,
		moon = buildMoon(anchor),
		glows = glows,
		figures = figures,
		figureSeed = -1,
		bolt = buildBolt(anchor),
	}
end

-- Posing ------------------------------------------------------------------------------------------

local function setTransparency(f: Frame, alpha: number)
	f.BackgroundTransparency = 1 - math.clamp(alpha, 0, 1)
end

-- A fingerprint of a colour and an opacity: a group of frames is only rewritten when it changes.
local function look(color: Color3, alpha: number): number
	return math.floor(math.clamp(alpha, 0, 2) * 400 + 0.5) * 16777216
		+ math.floor(color.R * 255 + 0.5) * 65536
		+ math.floor(color.G * 255 + 0.5) * 256
		+ math.floor(color.B * 255 + 0.5)
end

local function poseMoon(m: MoonRig, state: Sky.State, info: Info)
	local moon = state.moon
	local visible = if state.hidden then 0 else moon.visible
	m.gui.Enabled = visible > 0.005
	if not m.gui.Enabled then
		return
	end
	m.attachment.Position = moon.direction * DISTANCE
	-- resizing lays out every frame inside, so only when the moon has grown or shrunk visibly
	local size = math.floor(moon.size * 50 + 0.5) / 50
	if size ~= m.sizeShown then
		m.sizeShown = size
		local side = span(size) * SPAN
		m.gui.Size = UDim2.fromScale(side, side)
	end
	-- a throb swells the light (one property) rather than the halo's steps
	m.gui.Brightness = moon.brightness * (1 + 0.5 * moon.throb)

	-- behind cloud the disc fades and the glow spreads; a shut lid takes the glow with it
	local glow = visible * (0.75 + 0.5 * moon.veil) * (1 - 0.75 * moon.lid) * (1 + 0.25 * moon.throb)
	local haloLook = look(moon.glow, glow)
	if haloLook ~= m.haloShown then
		m.haloShown = haloLook
		for i, disc in m.halo do
			disc.BackgroundColor3 = moon.glow
			setTransparency(disc, HALO[i].alpha * glow)
		end
	end
	local ringAlpha = visible * moon.ring * 0.1 * (1 - 0.6 * moon.lid) * (1 - 0.4 * moon.veil)
	local ringColor = moon.glow:Lerp(WHITE, 0.25)
	local ringLook = look(ringColor, ringAlpha)
	if ringLook ~= m.ringShown then
		m.ringShown = ringLook
		for _, segment in m.ring do
			segment.BackgroundColor3 = ringColor
			setTransparency(segment, ringAlpha)
		end
	end

	local disc = visible * (1 - 0.6 * moon.veil)
	m.disc.BackgroundColor3 = moon.color
	setTransparency(m.disc, disc)
	local dim = Color3.new(moon.color.R * 0.55, moon.color.G * 0.5, moon.color.B * 0.5)
	for i, mare in m.maria do
		mare.BackgroundColor3 = dim
		setTransparency(mare, MARIA[i].alpha * disc)
	end
	-- the eclipse shadow sweeps in from the lower left with a soft edge
	local umbra = math.floor(moon.umbra * 100 + 0.5) / 100
	if umbra ~= m.umbraShown then
		m.umbraShown = umbra
		local edge = math.clamp(umbra, 0.02, 0.96)
		m.umbraGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(math.max(edge - 0.12, 0.01), 0.12),
			NumberSequenceKeypoint.new(math.min(edge + 0.1, 0.99), 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	setTransparency(m.umbra, if umbra > 0.01 then disc else 0)

	-- the Eye: an iris darkens and a slit opens, breathing with the throb
	setTransparency(m.iris, 0.7 * moon.pupil * disc)
	setTransparency(m.pupil, 0.95 * moon.pupil * disc)
	m.pupil.Size = UDim2.fromScale(DISC * (0.09 + 0.06 * moon.throb), DISC * 0.66)

	-- the lid comes down from the top, over the disc's own outline
	m.lidGradient.Offset = Vector2.new(0, -0.56 + 1.12 * moon.lid)
	m.lid.BackgroundColor3 = state.decay:Lerp(Color3.new(0, 0, 0), 0.5)
	setTransparency(m.lid, if moon.lid > 0.001 then visible else 0)

	-- scud across the face, faster as the train runs, dark against the light behind it
	local scudColor = state.clouds:Lerp(Color3.new(0, 0, 0), 0.55)
	local cloud = visible * (0.35 + 0.65 * state.cover)
	local from, to = SCUD_TRAVEL[1], SCUD_TRAVEL[2]
	for i, wisp in m.scud do
		local spec = SCUD[i]
		local along = (spec.at + info.now * 0.012 * spec.speed * info.drift) % 1
		wisp.Position = UDim2.fromScale(from + (to - from) * along, spec.y)
		wisp.BackgroundColor3 = scudColor
		setTransparency(wisp, spec.alpha * cloud * math.sin(along * math.pi))
	end
end

local function poseGlows(rig: Rig, state: Sky.State, info: Info)
	local strength = if state.hidden then 0 else state.glow
	for i, g in rig.glows do
		g.gui.Enabled = strength > 0.005
		if g.gui.Enabled then
			local flicker = 0.8 + 0.2 * math.noise(info.now * 0.4, i * 3.7, 0.5)
			local alpha = strength * flicker * g.weight
			local shown = look(state.glowColor, alpha)
			if shown ~= g.shown then
				g.shown = shown
				for j, layer in g.layers do
					layer.BackgroundColor3 = state.glowColor
					setTransparency(layer, GLOW_LAYERS[j].alpha * alpha)
				end
			end
		end
	end
end

local function placeFigures(rig: Rig, seed: number)
	rig.figureSeed = seed
	local rng = Rng.new(seed)
	for i, figure in rig.figures do
		-- away from the moon: behind the train and on the far side
		local azimuth = 150 + (i - 1) * 62 + rng:range(-18, 18)
		local height = rng:range(13, 21)
		local tall = span(height)
		figure.gui.Size = UDim2.fromScale(tall * FIGURE_ASPECT, tall)
		figure.attachment.Position = Sky.direction(azimuth, height / 2 - 1.5) * DISTANCE
	end
end

local function poseFigures(rig: Rig, state: Sky.State, info: Info)
	local omen = info.omen
	local reveal = 0
	if omen and omen.kind == "TallOnes" and not state.hidden then
		if omen.seed ~= rig.figureSeed then
			placeFigures(rig, omen.seed)
		end
		-- seen in the flash, and for a heartbeat after it
		local after = 0
		for _, mark in Tuning.Sky.RevealAt do
			local since = info.now - (omen.start + mark * omen.duration)
			if since >= 0 then
				after = math.max(after, 1 - MathX.saturate((since - 0.15) / 0.9))
			end
		end
		-- solid through the whole flicker, never quite black: they stand far off, in the haze
		reveal = math.max(math.min(state.flash * 2.2, 0.92), 0.22 * after)
	end
	local color = FIGURE_COLOR:Lerp(state.air, 0.22)
	for _, figure in rig.figures do
		figure.gui.Enabled = reveal > 0.01
		if figure.gui.Enabled then
			for _, part in figure.parts do
				part.BackgroundColor3 = color
				setTransparency(part, reveal)
			end
		end
	end
end

-- Segments of a forked bolt in the billboard's unit square: from the cloud base down.
function Heavens.boltShape(seed: number): { { number } }
	local rng = Rng.new(seed)
	local segments: { { number } } = {}
	local main: { { number } } = {}
	local x, y = 0.5 + rng:range(-0.08, 0.08), 0.02
	local drift = rng:range(-0.012, 0.012)
	local steps = 15
	for s = 1, steps do
		local nx = math.clamp(x + drift + rng:range(-0.045, 0.045), 0.12, 0.88)
		local ny = if s == steps then 0.98 else math.min(y + 0.064 * rng:range(0.75, 1.25), 0.96)
		table.insert(segments, { x, y, nx, ny, 1 })
		table.insert(main, { nx, ny })
		x, y = nx, ny
	end
	for _ = 1, rng:int(2, 3) do
		local from = main[rng:int(2, 9)]
		local bx, by = from[1], from[2]
		local side = rng:sign()
		for _ = 1, rng:int(3, 6) do
			local nx = math.clamp(bx + side * rng:range(0.02, 0.06), 0.04, 0.96)
			local ny = math.min(by + rng:range(0.03, 0.07), 0.96)
			table.insert(segments, { bx, by, nx, ny, 0.5 })
			bx, by = nx, ny
		end
	end
	return segments
end

local function shapeBolt(bolt: BoltRig, strike: Omens.Strike)
	bolt.seed = strike.seed
	local segments = Heavens.boltShape(strike.seed)
	for i = 1, BOLT_SEGMENTS do
		local seg = segments[i]
		local core, glow = bolt.cores[i], bolt.glows[i]
		core.Visible = seg ~= nil
		glow.Visible = seg ~= nil
		if seg then
			local dx, dy = seg[3] - seg[1], seg[4] - seg[2]
			local length = math.sqrt(dx * dx + dy * dy)
			local mid = UDim2.fromScale((seg[1] + seg[3]) / 2, (seg[2] + seg[4]) / 2)
			local turn = math.deg(math.atan2(dy, dx))
			local thick = 0.0045 * seg[5]
			core.Position, core.Rotation = mid, turn
			core.Size = UDim2.fromScale(length + thick, thick)
			glow.Position, glow.Rotation = mid, turn
			glow.Size = UDim2.fromScale(length + thick * 4, thick * 9)
		end
	end
	-- nearer strikes stand taller; the foot of every bolt sinks just behind the horizon
	local height = math.deg(math.atan(CLOUD_BASE / strike.distance)) * 1.15 + 2
	local side = span(height)
	bolt.gui.Size = UDim2.fromScale(side, side)
	bolt.attachment.Position = Sky.direction(math.deg(strike.azimuth), height / 2 - 1.5) * DISTANCE
end

local function poseBolt(rig: Rig, state: Sky.State, info: Info)
	local bolt = rig.bolt
	local strike = info.strike
	bolt.gui.Enabled = strike ~= nil and state.flash > 0.03 and not state.hidden
	if strike == nil or not bolt.gui.Enabled then
		return
	end
	if strike.seed ~= bolt.seed then
		shapeBolt(bolt, strike)
	end
	local core = if strike.red then rgb(255, 120, 110) else rgb(236, 232, 255)
	local halo = if strike.red then rgb(255, 30, 24) else rgb(150, 140, 255)
	for i = 1, BOLT_SEGMENTS do
		bolt.cores[i].BackgroundColor3 = core
		setTransparency(bolt.cores[i], state.flash * 1.8)
		bolt.glows[i].BackgroundColor3 = halo
		setTransparency(bolt.glows[i], state.flash * 0.45)
	end
end

-- Poses the whole rig for this frame. `state` is Sky.finish's output.
function Heavens.update(rig: Rig, state: Sky.State, info: Info)
	rig.anchor.CFrame = CFrame.new(info.focus)
	poseMoon(rig.moon, state, info)
	poseGlows(rig, state, info)
	poseFigures(rig, state, info)
	poseBolt(rig, state, info)
end

Heavens.Distance = DISTANCE

return Heavens
