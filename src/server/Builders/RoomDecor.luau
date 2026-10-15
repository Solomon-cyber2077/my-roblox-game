--!strict
--[[
	What hangs on the walls of a station's main building (BuildingGen.decor plans where): a
	mahogany drop-dial clock stopped at twenty to ten, gilt-framed pictures gone dark,
	framed texts, unlit gas brackets, hat pegs with a bowler and a coat left behind, and
	shelves of books and bottles. All of it is non-colliding.

	Each piece's frame stands on the wall's inner face at its centre height: local -Z faces
	into the room, +Z is the wall.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BuildingGen = require(Shared.Logic.BuildingGen)
local Kit = require(Shared.Visual.Kit)

local StationDressing = require(script.Parent.StationDressing)

local RoomDecor = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local OFF = 0.03 -- every piece's back stands this far off the wall

local MAHOGANY = rgb(78, 38, 26)
local GILT = rgb(176, 140, 70)
local BRASS = rgb(190, 150, 80)
local CREAM = rgb(222, 210, 180)
local INK = rgb(30, 26, 24)
local CANVAS = { rgb(46, 42, 32), rgb(38, 44, 40), rgb(54, 40, 34), rgb(34, 36, 46) }
local BOOKS = { rgb(92, 30, 28), rgb(36, 52, 40), rgb(40, 40, 70), rgb(96, 70, 40), rgb(60, 24, 34) }
local GARAMOND = Font.new(Font.fromEnum(Enum.Font.Garamond).Family, Enum.FontWeight.Bold)
-- framed texts and notices; they hint, never explain (LORE.md)
local TEXTS = {
	"THOU GOD\nSEEST ME",
	"BY ORDER.\nPassengers must not\ncross the line\nexcept by the bridge.",
	"PRAY FOR THEM\nTHAT TRAVEL\nBY NIGHT",
	"LOST PROPERTY\nis to be claimed\nwithin seven days.\nBy Order.",
	"THE NIGHT IS\nFAR SPENT",
}

local function piece(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return Kit.block(parent, size, cf, color, { material = material or M.SmoothPlastic, collide = false })
end

-- A block of depth `d` with its back on the wall, `z` further out.
local function flat(
	parent: Instance,
	frame: CFrame,
	size: Vector3,
	x: number,
	y: number,
	z: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	return piece(parent, size, frame * CFrame.new(x, y, -(OFF + z + size.Z / 2)), color, material)
end

local function label(part: BasePart, text: string, canvas: Vector2)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = canvas
	gui.LightInfluence = 1
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.84, 0.8)
	t.Position = UDim2.fromScale(0.08, 0.1)
	t.FontFace = GARAMOND
	t.Text = text
	t.TextColor3 = INK
	t.TextScaled = true
	t.TextWrapped = true
	t.Parent = gui
end

local Builders: { [string]: (Model, CFrame, Random) -> () } = {}

-- A drop-dial clock: a round mahogany case and brass bezel over a box with the pendulum's window.
Builders.WallClock = function(parent, frame, _rng)
	local axis = frame * Kit.angles(0, 90, 0) -- the cylinders' axis out of the wall
	Kit.cylinder(
		parent,
		0.3,
		1.9,
		axis * CFrame.new(OFF + 0.15, 0, 0),
		MAHOGANY,
		{ material = M.Wood, collide = false }
	)
	Kit.cylinder(
		parent,
		0.34,
		1.72,
		axis * CFrame.new(OFF + 0.18, 0, 0),
		BRASS,
		{ material = M.Metal, collide = false }
	)
	local face = Kit.cylinder(
		parent,
		0.38,
		1.52,
		axis * CFrame.new(OFF + 0.21, 0, 0),
		CREAM,
		{ material = M.SmoothPlastic, collide = false }
	)
	StationDressing.clockDial(face, Enum.NormalId.Right) -- the axis runs out into the room
	flat(parent, frame, Vector3.new(1.1, 1.3, 0.26), 0, -1.45, 0.012, MAHOGANY, M.Wood)
	flat(parent, frame, Vector3.new(0.5, 0.6, 0.04), 0, -1.5, 0.26, rgb(20, 18, 18), M.Glass)
	flat(parent, frame, Vector3.new(0.22, 0.22, 0.03), 0, -1.6, 0.3, BRASS, M.Metal)
end

-- A gilt frame round a painting gone dark: a landscape, or a sitter in black.
Builders.Picture = function(parent, frame, rng)
	local w = 2.6
	flat(parent, frame, Vector3.new(w, 1.9, 0.12), 0, 0, 0, Kit.jitter(GILT, 0.1, rng:NextNumber()), M.Metal)
	local ground = CANVAS[rng:NextInteger(1, #CANVAS)]
	flat(parent, frame, Vector3.new(w - 0.36, 1.54, 0.04), 0, 0, 0.12, ground)
	if rng:NextNumber() < 0.5 then
		-- a sky over a dark field
		flat(parent, frame, Vector3.new(w - 0.42, 0.62, 0.02), 0, 0.42, 0.16, Kit.shade(ground, 1.9))
		flat(parent, frame, Vector3.new(0.5, 0.5, 0.02), 0.5, 0.42, 0.18, rgb(168, 120, 70))
	else
		-- a portrait: a pale face over a dark coat
		flat(parent, frame, Vector3.new(0.9, 0.6, 0.02), 0, -0.45, 0.16, rgb(24, 22, 22))
		flat(parent, frame, Vector3.new(0.42, 0.52, 0.02), 0, 0.2, 0.16, rgb(176, 146, 120))
	end
end

-- A framed text or a notice under glass.
Builders.Text = function(parent, frame, rng)
	flat(parent, frame, Vector3.new(2.2, 1.6, 0.1), 0, 0, 0, rgb(28, 24, 22), M.Wood)
	local sheet = flat(
		parent,
		frame,
		Vector3.new(1.86, 1.26, 0.03),
		0,
		0,
		0.1,
		Kit.shade(CREAM, rng:NextNumber(0.75, 0.95))
	)
	label(sheet, TEXTS[rng:NextInteger(1, #TEXTS)], Vector2.new(186, 126))
end

-- An unlit gas bracket: a brass rose, a swan-neck arm and a frosted globe.
Builders.GasBracket = function(parent, frame, _rng)
	flat(parent, frame, Vector3.new(0.4, 0.6, 0.08), 0, 0, 0, BRASS, M.Metal)
	flat(parent, frame, Vector3.new(0.12, 0.12, 0.7), 0, -0.1, 0.08, BRASS, M.Metal)
	flat(parent, frame, Vector3.new(0.12, 0.4, 0.12), 0, 0.1, 0.66, BRASS, M.Metal)
	local globe = flat(parent, frame, Vector3.new(0.5, 0.56, 0.5), 0, 0.56, 0.47, rgb(220, 214, 200), M.Glass)
	globe.Transparency = 0.35
end

-- A rail of hat pegs, a bowler on one and a coat left hanging on another.
Builders.HatPegs = function(parent, frame, rng)
	flat(parent, frame, Vector3.new(2.8, 0.34, 0.12), 0, 0, 0, MAHOGANY, M.Wood)
	for _, x in { -1.05, -0.35, 0.35, 1.05 } do
		flat(parent, frame, Vector3.new(0.1, 0.1, 0.36), x, 0, 0.12, BRASS, M.Metal)
	end
	local hat = rng:NextInteger(1, 2) == 1
	local hx = if hat then -1.05 else 1.05
	flat(parent, frame, Vector3.new(0.86, 0.06, 0.8), hx, 0.1, 0.06, INK, M.Fabric)
	flat(parent, frame, Vector3.new(0.52, 0.36, 0.5), hx, 0.31, 0.2, INK, M.Fabric)
	flat(parent, frame, Vector3.new(0.95, 2.6, 0.32), -hx * 0.33, -1.35, 0.14, rgb(46, 40, 38), M.Fabric)
end

-- A shelf on two iron brackets: cloth-bound books and a few bottles.
Builders.WallShelf = function(parent, frame, rng)
	flat(parent, frame, Vector3.new(3.2, 0.14, 0.72), 0, 0, 0, rgb(96, 70, 48), M.WoodPlanks)
	for _, x in { -1.2, 1.2 } do
		flat(parent, frame, Vector3.new(0.1, 0.5, 0.5), x, -0.33, 0, rgb(36, 36, 40), M.Metal)
	end
	local x = -1.45
	while x < 0.6 do
		local w = rng:NextNumber(0.14, 0.24)
		local h = rng:NextNumber(0.6, 0.9)
		flat(
			parent,
			frame,
			Vector3.new(w, h, rng:NextNumber(0.42, 0.56)),
			x + w / 2,
			0.07 + h / 2,
			0.06,
			BOOKS[rng:NextInteger(1, #BOOKS)],
			M.Fabric
		)
		x += w + 0.02
	end
	for k = 0, 2 do
		local glass = if k == 1 then rgb(40, 64, 40) else rgb(76, 44, 24)
		Kit.post(
			parent,
			0.7,
			0.26,
			frame * CFrame.new(0.95 + k * 0.32, 0.42, -(OFF + 0.3)),
			glass,
			{ material = M.Glass, collide = false }
		)
	end
end

-- Builds every piece of `decor` into `parent`; `origin` is the building's origin on its floor.
function RoomDecor.build(
	parent: Model,
	origin: CFrame,
	plan: BuildingGen.Plan,
	decor: { BuildingGen.Decor },
	seed: number
)
	local rng = Random.new(seed % 2147483647)
	for _, d in decor do
		local room = BuildingGen.room(plan, d.room)
		local floorY = if room then room.y else 0
		local frame = origin * CFrame.new(d.x, floorY + d.y, d.z) * Kit.angles(0, d.rot, 0)
		local builder = Builders[d.kind]
		if builder then
			builder(parent, frame, rng)
		end
	end
end

return RoomDecor
