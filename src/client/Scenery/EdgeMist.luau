--!strict
--[[
	The void mist along the station's open edges, drawn on the client (prompts/VM5). The yard
	ends in a sheer cut into the dark; this fills the drop with mist so the edge reads as a lip
	over a sea of it, not the end of a slab:

	  sea    a flat bank just under the lip, densest against the cliff, thinning outward: a
	         smooth body with two drifting textured layers over and under it
	  veil   mist rising from below past the lip, a few studs above the ground at most and
	         fading to nothing at its top, so the sky and the trees stay in view; a smooth,
	         lower body behind it keeps the cliff face under the lip covered
	  back   a second, darker and taller rise further out, for depth

	The untextured bodies give the bank its cover (the smoke texture's own alpha thins every
	textured layer); the textured ones give it drift. Seen in Studio at hours 14, 20 and 26.

	Each edge rail (StationDressing EdgeMark, tag SinkholeEdge) carries its own: Beams between
	Attachments on the rail itself, so the mist rides the station when it moves. The texture
	scrolls on the GPU (TextureSpeed): no ParticleEmitters and no per-frame work, beyond the
	recolour and opacity changes MistController asks for. Heights and speeds vary per rail from
	its position, so the line is never even. The mist takes part of the scene's light: pale by
	day, dark in the dark, red under the blood moon.

	Rail frame: -Z toward the train, +Z over the void; y from -Size.Y / 2 at the ground.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Stations = require(Shared.Config.Stations)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local OVERLAP = 2.2 -- each beam this many rail widths wide, so neighbours blend into one bank
local BELOW = 28 -- studs the rises start under the ground
local SEA_DROP = 4 -- the sea lies this far under the ground (a second layer twice as deep)
local SEA_REACH = 80 -- and reaches this far out from the lip
local LIGHT = 0.65 -- the scene's light on it: pale by day, dark (never lost) at night
-- The preset is a hint of colour, not the colour: a flat, saturated sheet under the lip read as a
-- canal of water in daylight. Every layer is the preset taken GREY_MIX of the way to this grey.
local GREY = Color3.fromRGB(150, 156, 158)
local GREY_MIX = 0.5

export type Layer = {
	beam: Beam,
	keys: { { number } }, -- { position, base transparency }
	shade: number, -- 1 = the preset's mist colour, lower is darker
}

export type Handle = {
	folder: Folder,
	layers: { Layer },
}

local EdgeMist = {}

-- 0..1 from a rail's position: the same rail always gets the same mist.
local function hash(rail: BasePart, salt: number): number
	local p = rail.Position
	local n = math.floor(p.X * 0.731 + p.Z * 1.379 + salt * 17.13)
	return ((n * 1103515245 + 12345) % 2147483648) / 2147483648
end

-- A beam that does not face the camera spreads its width along its attachments' SecondaryAxis,
-- so that is always along the edge (the rail's X); Axis is the way the beam runs.
local function attachment(rail: BasePart, folder: Folder, position: Vector3, axis: Vector3)
	local a = Instance.new("Attachment")
	a.Name = "EdgeMist"
	a.CFrame = CFrame.fromMatrix(position, axis, Vector3.xAxis)
	a.Parent = rail
	-- the folder owns the attachment's lifetime (a rail that goes takes both with it)
	folder.Destroying:Connect(function()
		a:Destroy()
	end)
	return a
end

local function sequence(keys: { { number } }, offset: number): NumberSequence
	local points = {}
	for _, key in keys do
		-- the very ends stay clear, so no beam ever shows a hard edge
		local base = key[2]
		local value = if base >= 1 then 1 else math.clamp(base - offset, 0, 1)
		table.insert(points, NumberSequenceKeypoint.new(key[1], value))
	end
	return NumberSequence.new(points)
end

local function layer(
	folder: Folder,
	a0: Attachment,
	a1: Attachment,
	width: number,
	keys: { { number } },
	shade: number,
	textureLength: number?, -- nil: untextured, a smooth gradient that gives the bank its body
	speed: number?
): Layer
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = width
	beam.Width1 = width
	beam.FaceCamera = false
	beam.Segments = 1
	if textureLength then
		beam.Texture = SMOKE
		beam.TextureMode = Enum.TextureMode.Static
		beam.TextureLength = textureLength
		beam.TextureSpeed = speed or 0
	end
	beam.LightInfluence = LIGHT
	beam.LightEmission = 0
	beam.Transparency = sequence(keys, 0)
	beam.Parent = folder
	return { beam = beam, keys = keys, shade = shade }
end

function EdgeMist.build(rail: BasePart, parent: Instance): Handle
	local folder = Instance.new("Folder")
	folder.Name = "EdgeMist"
	local ground = -rail.Size.Y / 2
	local lip = Stations.Edge.RailBack
	local width = rail.Size.X * OVERLAP
	local up, out = Vector3.yAxis, Vector3.zAxis
	local layers: { Layer } = {}

	-- the veil: rises past the lip to 3..9 studs, thick below the lip, gone at its top
	local veilTop = 3 + 6 * hash(rail, 1)
	local veilLip = BELOW / (BELOW + veilTop)
	table.insert(
		layers,
		layer(
			folder,
			attachment(rail, folder, Vector3.new(0, ground - BELOW, lip + 1.5), up),
			attachment(rail, folder, Vector3.new(0, ground + veilTop, lip + 1.5), up),
			width,
			{ { 0, 0.3 }, { veilLip * 0.7, 0.4 }, { veilLip, 0.55 }, { 1, 1 } },
			1,
			12,
			0.05 + 0.05 * hash(rail, 2)
		)
	)

	-- its body: smooth, lower, so the cliff face under the lip is always covered
	table.insert(
		layers,
		layer(
			folder,
			attachment(rail, folder, Vector3.new(0, ground - BELOW, lip + 2), up),
			attachment(rail, folder, Vector3.new(0, ground + veilTop * 0.6, lip + 2), up),
			rail.Size.X, -- untextured bodies abut: overlapping ones band where they double up
			{ { 0, 0.37 }, { veilLip, 0.82 }, { 1, 1 } },
			0.8
		)
	)

	-- the back rise: further out, darker, taller, thinner
	local backTop = 8 + 7 * hash(rail, 3)
	local backLip = BELOW / (BELOW + backTop)
	table.insert(
		layers,
		layer(
			folder,
			attachment(rail, folder, Vector3.new(0, ground - BELOW, lip + 11), up),
			attachment(rail, folder, Vector3.new(0, ground + backTop, lip + 11), up),
			width * 1.2,
			{ { 0, 0.45 }, { backLip, 0.65 }, { 1, 1 } },
			0.7,
			20,
			0.03 + 0.03 * hash(rail, 4)
		)
	)

	-- the sea: a smooth body under the lip and two textured layers over and under it, reaching
	-- out over the drop and drifting opposite ways, so the gaps in one are filled by the other
	table.insert(
		layers,
		layer(
			folder,
			attachment(rail, folder, Vector3.new(0, ground - SEA_DROP * 1.5, lip - 1), out),
			attachment(rail, folder, Vector3.new(0, ground - SEA_DROP * 1.5, lip + SEA_REACH), out),
			rail.Size.X,
			{ { 0, 0.55 }, { 0.4, 0.75 }, { 1, 1 } },
			0.75
		)
	)
	for i, drop in { SEA_DROP, SEA_DROP * 2 } do
		table.insert(
			layers,
			layer(
				folder,
				attachment(rail, folder, Vector3.new(0, ground - drop, lip - 1), out),
				attachment(rail, folder, Vector3.new(0, ground - drop, lip + SEA_REACH), out),
				width,
				{ { 0, 0 }, { 0.35, 0.1 }, { 0.75, 0.55 }, { 1, 1 } },
				0.85 - 0.15 * (i - 1),
				22 + 8 * i,
				(if i == 1 then 1 else -1) * (0.015 + 0.02 * hash(rail, 5 + i))
			)
		)
	end

	folder.Parent = parent
	return { folder = folder, layers = layers }
end

-- The preset's mist colour, each layer at its own shade.
function EdgeMist.setColor(handle: Handle, preset: Color3)
	local mist = preset:Lerp(GREY, GREY_MIX)
	for _, l in handle.layers do
		l.beam.Color = ColorSequence.new(Color3.new(mist.R * l.shade, mist.G * l.shade, mist.B * l.shade))
	end
end

-- Thicker by `offset` (transparency taken off every key but the clear ends): the idle reaction.
function EdgeMist.setOpacityOffset(handle: Handle, offset: number)
	for _, l in handle.layers do
		l.beam.Transparency = sequence(l.keys, offset)
	end
end

function EdgeMist.destroy(handle: Handle)
	handle.folder:Destroy()
end

return EdgeMist
