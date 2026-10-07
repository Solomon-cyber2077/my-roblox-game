--!strict
--[[
	Furniture for the enterable buildings (Config/Buildings), assembled from
	primitives. Each builder gets a frame at the piece's centre on the floor with
	local -Z as its front (into the room) and returns its main part, which the
	search prompt hangs from when the piece is a container.

	Pieces only create parts; StationBuilder welds them to the building's slab.
	Details stand proud of the faces they sit on (never flush) so no two faces fight.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)

local FurnitureKit = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local C = {
	wood = rgb(112, 80, 54),
	woodDark = rgb(72, 50, 36),
	woodLight = rgb(150, 116, 80),
	iron = rgb(50, 50, 54),
	steel = rgb(96, 100, 100),
	brass = rgb(170, 136, 70),
	paper = rgb(222, 212, 186),
	coal = rgb(26, 25, 24),
	enamel = rgb(214, 210, 198),
	green = rgb(58, 82, 66),
	olive = rgb(92, 98, 72),
	red = rgb(140, 40, 36),
	cloth = rgb(196, 188, 168),
	canvas = rgb(150, 132, 100),
	stone = rgb(150, 144, 134),
}

export type Ctx = {
	parent: Instance,
	frame: CFrame,
	rng: Random,
	accent: Color3,
}

local function at(ctx: Ctx, x: number, y: number, z: number): CFrame
	return ctx.frame * CFrame.new(x, y, z)
end

local function box(
	ctx: Ctx,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): BasePart
	return Kit.block(ctx.parent, size, cf, color, { material = material or M.Wood, collide = collide })
end

local function legs(
	ctx: Ctx,
	w: number,
	d: number,
	h: number,
	thick: number,
	color: Color3,
	material: Enum.Material?
)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(
				ctx,
				Vector3.new(thick, h, thick),
				at(ctx, sx * (w / 2 - thick / 2), h / 2, sz * (d / 2 - thick / 2)),
				color,
				material,
				false
			)
		end
	end
end

-- A cabinet body with `rows` drawer fronts standing proud of its face.
local function cabinet(
	ctx: Ctx,
	w: number,
	h: number,
	d: number,
	color: Color3,
	material: Enum.Material,
	rows: number,
	handle: Color3
): BasePart
	local body = box(ctx, Vector3.new(w, h, d), at(ctx, 0, h / 2, 0), color, material)
	local gap = 0.12
	local each = (h - 0.4 - gap * (rows + 1)) / rows
	for i = 1, rows do
		local y = 0.2 + gap * i + each * (i - 0.5)
		box(
			ctx,
			Vector3.new(w - 0.3, each, 0.1),
			at(ctx, 0, y, -d / 2 - 0.04),
			Kit.shade(color, 0.86),
			material,
			false
		)
		box(
			ctx,
			Vector3.new(math.min(0.8, w * 0.3), 0.12, 0.1),
			at(ctx, 0, y + each * 0.2, -d / 2 - 0.13),
			handle,
			M.Metal,
			false
		)
	end
	return body
end

-- A shelf unit: back, two sides, `shelves` boards and a row of goods on each.
local function shelves(
	ctx: Ctx,
	w: number,
	h: number,
	d: number,
	color: Color3,
	count: number,
	goods: { Color3 }?
): BasePart
	local back = box(ctx, Vector3.new(w, h, 0.2), at(ctx, 0, h / 2, d / 2 - 0.1), color, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		box(ctx, Vector3.new(0.2, h, d - 0.2), at(ctx, sx * (w / 2 - 0.1), h / 2, -0.1), color, M.WoodPlanks)
	end
	local step = (h - 0.3) / count
	for i = 0, count - 1 do
		local y = 0.3 + i * step
		box(
			ctx,
			Vector3.new(w - 0.4, 0.15, d - 0.25),
			at(ctx, 0, y, -0.125),
			Kit.shade(color, 0.9),
			M.WoodPlanks,
			false
		)
		if goods then
			local fill = goods[(i % #goods) + 1]
			local height = step * (0.45 + ctx.rng:NextNumber() * 0.35)
			box(
				ctx,
				Vector3.new(w - 0.6 - ctx.rng:NextNumber() * 1.2, height, d * 0.55),
				at(ctx, (ctx.rng:NextNumber() - 0.5) * 0.4, y + 0.075 + height / 2, 0),
				fill,
				M.SmoothPlastic,
				false
			)
		end
	end
	return back
end

local Builders: { [string]: (Ctx) -> BasePart } = {}

Builders.Counter = function(ctx)
	local body = cabinet(ctx, 7, 3.6, 2.4, C.wood, M.Wood, 2, C.brass)
	box(ctx, Vector3.new(7.3, 0.25, 2.7), at(ctx, 0, 3.725, 0), C.woodDark, M.Wood)
	box(ctx, Vector3.new(0.9, 0.5, 0.7), at(ctx, 2.4, 4.1, 0.3), C.brass, M.Metal, false) -- a bell
	return body
end

Builders.Bench = function(ctx)
	local seat = box(ctx, Vector3.new(6, 0.3, 1.6), at(ctx, 0, 1.6, -0.1), C.wood, M.WoodPlanks)
	box(
		ctx,
		Vector3.new(6, 1.4, 0.2),
		at(ctx, 0, 2.7, 0.75) * Kit.angles(-8, 0, 0),
		C.wood,
		M.WoodPlanks,
		false
	)
	for _, x in { -2.6, 2.6 } do
		box(ctx, Vector3.new(0.3, 1.6, 1.5), at(ctx, x, 0.8, -0.1), C.iron, M.Metal)
	end
	return seat
end

Builders.NoticeBoard = function(ctx)
	local board = box(ctx, Vector3.new(4, 3, 0.25), at(ctx, 0, 5.4, 0), rgb(150, 112, 74), M.Fabric, false)
	box(ctx, Vector3.new(4.3, 3.3, 0.15), at(ctx, 0, 5.4, 0.18), C.woodDark, M.Wood, false)
	for i = 1, 4 do
		local w, h = 0.8 + ctx.rng:NextNumber() * 0.5, 1 + ctx.rng:NextNumber() * 0.4
		box(
			ctx,
			Vector3.new(w, h, 0.04),
			at(ctx, -1.3 + (i - 1) * 0.85, 5.3 + (ctx.rng:NextNumber() - 0.5) * 1, -0.16 - i * 0.03)
				* Kit.angles(0, 0, (ctx.rng:NextNumber() - 0.5) * 16),
			C.paper,
			M.SmoothPlastic,
			false
		)
	end
	return board
end

local CHALK = {
	"DO NOT OPEN THE DOORS AFTER DARK",
	"Lessons are cancelled.\nGo home. Go HOME.",
	"9 x 7 = 63\nthe train comes at midnight",
	"Count heads at every stop.\nCount them twice.",
	"Who is sitting in the back row?",
}

Builders.Chalkboard = function(ctx)
	local board = box(ctx, Vector3.new(9, 3.6, 0.2), at(ctx, 0, 5, 0), rgb(36, 50, 42), M.Slate, false)
	box(ctx, Vector3.new(9.4, 4, 0.12), at(ctx, 0, 5, 0.16), C.woodDark, M.Wood, false)
	box(ctx, Vector3.new(9, 0.15, 0.45), at(ctx, 0, 3.1, -0.2), C.woodDark, M.Wood, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(900, 360)
	gui.LightInfluence = 1
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.FontFace = Font.new("rbxasset://fonts/families/Kalam.json")
	label.Text = CHALK[ctx.rng:NextInteger(1, #CHALK)]
	label.TextColor3 = rgb(226, 226, 214)
	label.TextTransparency = 0.15
	label.TextScaled = true
	label.Rotation = (ctx.rng:NextNumber() - 0.5) * 6
	label.Parent = gui
	return board
end

Builders.TeacherDesk = function(ctx)
	local top = box(ctx, Vector3.new(5, 0.25, 2.6), at(ctx, 0, 3.0, 0), C.woodDark, M.Wood)
	for _, x in { -1.65, 1.65 } do
		box(ctx, Vector3.new(1.5, 2.85, 2.3), at(ctx, x, 1.43, 0.05), C.wood, M.Wood)
		box(ctx, Vector3.new(0.6, 0.12, 0.1), at(ctx, x, 2.4, -1.15), C.brass, M.Metal, false)
	end
	box(
		ctx,
		Vector3.new(1.8, 0.1, 1.3),
		at(ctx, -0.4, 3.18, 0.2) * Kit.angles(0, 12, 0),
		C.paper,
		M.SmoothPlastic,
		false
	)
	box(ctx, Vector3.new(0.6, 0.6, 0.6), at(ctx, 1.6, 3.43, 0.6), C.red, M.SmoothPlastic, false) -- an apple, long gone
	return top
end

Builders.Cupboard = function(ctx)
	local body = box(ctx, Vector3.new(3.4, 6.5, 1.8), at(ctx, 0, 3.25, 0), C.wood, M.Wood)
	for _, x in { -0.83, 0.83 } do
		box(ctx, Vector3.new(1.6, 5.8, 0.1), at(ctx, x, 3.3, -0.94), Kit.shade(C.wood, 0.85), M.Wood, false)
	end
	box(ctx, Vector3.new(3.7, 0.3, 2.0), at(ctx, 0, 6.65, 0), C.woodDark, M.Wood, false)
	return body
end

Builders.SchoolDesk = function(ctx)
	local top =
		box(ctx, Vector3.new(3, 0.2, 1.3), at(ctx, 0, 2.6, -0.45) * Kit.angles(6, 0, 0), C.woodLight, M.Wood)
	box(ctx, Vector3.new(2.6, 0.2, 0.7), at(ctx, 0, 1.6, 0.72), C.woodLight, M.Wood, false)
	for _, x in { -1.3, 1.3 } do
		box(ctx, Vector3.new(0.18, 2.5, 0.18), at(ctx, x, 1.25, -0.45), C.iron, M.Metal, false)
		box(ctx, Vector3.new(0.18, 1.5, 0.18), at(ctx, x * 0.9, 0.75, 0.72), C.iron, M.Metal, false)
	end
	return top
end

Builders.Boiler = function(ctx)
	local body = Kit.cylinder(ctx.parent, 6, 4.4, at(ctx, 0, 2.9, 0), C.iron, { material = M.Metal })
	box(ctx, Vector3.new(6.4, 0.8, 4), at(ctx, 0, 0.4, 0), rgb(70, 66, 62), M.Brick)
	box(ctx, Vector3.new(1.6, 1.4, 0.3), at(ctx, -1.4, 2.3, -2.25), rgb(30, 28, 28), M.Metal, false)
	Kit.neon(ctx.parent, Vector3.new(1.2, 0.3, 0.1), at(ctx, -1.4, 2.0, -2.43), rgb(255, 110, 40))
	Kit.post(ctx.parent, 7, 0.9, at(ctx, 2, 8.4, 0.8), C.iron, { material = M.Metal, collide = false })
	Kit.cylinder(
		ctx.parent,
		0.25,
		0.8,
		at(ctx, 0.8, 4, -2.3) * Kit.angles(0, 90, 0),
		C.brass,
		{ material = M.Metal, collide = false }
	)
	local glow = Kit.pointLight(body, rgb(255, 120, 50), 0.9, 12, false)
	glow.Name = "FurnaceGlow"
	return body
end

Builders.CoalBunker = function(ctx)
	local front = box(ctx, Vector3.new(4.5, 2.4, 0.3), at(ctx, 0, 1.2, -1.45), C.woodDark, M.WoodPlanks)
	box(ctx, Vector3.new(4.5, 3.0, 0.3), at(ctx, 0, 1.5, 1.45), C.woodDark, M.WoodPlanks)
	for _, x in { -2.1, 2.1 } do
		box(ctx, Vector3.new(0.3, 3.0, 2.6), at(ctx, x, 1.5, 0), C.woodDark, M.WoodPlanks)
	end
	box(ctx, Vector3.new(3.9, 1.9, 2.6), at(ctx, 0, 1.0, 0), C.coal, M.Slate, false)
	for i = 1, 3 do
		Kit.ball(
			ctx.parent,
			0.7 + ctx.rng:NextNumber() * 0.4,
			at(ctx, -1 + i * 0.6, 2.1, -0.3 + ctx.rng:NextNumber() * 0.6),
			C.coal,
			{ material = M.Slate, collide = false }
		)
	end
	return front
end

Builders.CoalHeap = function(ctx)
	local main =
		Kit.wedge(ctx.parent, Vector3.new(3.6, 1.8, 2), at(ctx, 0, 0.9, -1), C.coal, { material = M.Slate })
	Kit.wedge(
		ctx.parent,
		Vector3.new(3.6, 1.8, 2),
		at(ctx, 0, 0.9, 1) * Kit.angles(0, 180, 0),
		C.coal,
		{ material = M.Slate }
	)
	Kit.ball(ctx.parent, 1.6, at(ctx, 0.6, 1.4, 0.2), C.coal, { material = M.Slate, collide = false })
	Kit.ball(ctx.parent, 1.1, at(ctx, -1.2, 0.9, 0.6), C.coal, { material = M.Slate, collide = false })
	return main
end

Builders.Table = function(ctx)
	local top = box(ctx, Vector3.new(6, 0.3, 3.4), at(ctx, 0, 3.0, 0), C.wood, M.Wood)
	legs(ctx, 5.6, 3.0, 2.85, 0.3, C.woodDark)
	box(ctx, Vector3.new(1.2, 0.08, 1.2), at(ctx, -1.5, 3.19, 0.3), C.enamel, M.SmoothPlastic, false)
	Kit.post(
		ctx.parent,
		0.6,
		0.25,
		at(ctx, 1.4, 3.45, -0.4),
		C.paper,
		{ material = M.SmoothPlastic, collide = false }
	)
	return top
end

Builders.Stove = function(ctx)
	local body = Kit.post(ctx.parent, 3, 2.2, at(ctx, 0, 1.5, 0), C.iron, { material = M.Metal })
	Kit.post(ctx.parent, 8, 0.6, at(ctx, 0, 7, 0.3), C.iron, { material = M.Metal, collide = false })
	Kit.neon(ctx.parent, Vector3.new(0.9, 0.35, 0.1), at(ctx, 0, 1.1, -1.12), rgb(255, 120, 50))
	return body
end

local BOOKS = { rgb(110, 40, 36), rgb(52, 70, 92), rgb(70, 90, 60), rgb(120, 96, 60), rgb(80, 50, 70) }
Builders.Bookshelf = function(ctx)
	return shelves(ctx, 4, 7, 1.4, C.woodDark, 5, BOOKS)
end

Builders.SchoolLocker = function(ctx)
	local color = Kit.shade(ctx.accent, 0.8 + ctx.rng:NextNumber() * 0.2)
	local body = box(ctx, Vector3.new(1.8, 6.6, 1.6), at(ctx, 0, 3.3, 0), color, M.Metal)
	for i = 0, 2 do
		box(
			ctx,
			Vector3.new(1.0, 0.08, 0.06),
			at(ctx, 0, 5.6 + i * 0.25, -0.83),
			Kit.shade(color, 0.5),
			M.Metal,
			false
		)
	end
	box(ctx, Vector3.new(0.12, 0.6, 0.1), at(ctx, 0.6, 3.4, -0.85), C.steel, M.Metal, false)
	return body
end

Builders.Bed = function(ctx)
	local mattress = box(ctx, Vector3.new(3.2, 0.7, 6.6), at(ctx, 0, 1.75, 0), rgb(190, 182, 160), M.Fabric)
	box(ctx, Vector3.new(3.3, 0.25, 4), at(ctx, 0, 2.2, -1.2), Kit.shade(ctx.accent, 0.9), M.Fabric, false)
	box(ctx, Vector3.new(2.2, 0.45, 1), at(ctx, 0, 2.3, 2.6), C.cloth, M.Fabric, false)
	box(ctx, Vector3.new(3.4, 3.2, 0.2), at(ctx, 0, 1.6, 3.4), C.iron, M.Metal)
	box(ctx, Vector3.new(3.4, 2.0, 0.2), at(ctx, 0, 1.0, -3.4), C.iron, M.Metal)
	box(ctx, Vector3.new(3.2, 0.3, 6.6), at(ctx, 0, 1.25, 0), C.iron, M.Metal, false)
	return mattress
end

Builders.Bedside = function(ctx)
	local body = cabinet(ctx, 1.8, 2.4, 1.6, C.wood, M.Wood, 2, C.brass)
	Kit.post(
		ctx.parent,
		0.5,
		0.35,
		at(ctx, 0.3, 2.65, 0.2),
		C.paper,
		{ material = M.SmoothPlastic, collide = false }
	)
	return body
end

Builders.Trolley = function(ctx)
	local top = box(ctx, Vector3.new(3.4, 0.15, 2), at(ctx, 0, 3, 0), C.enamel, M.Metal)
	box(ctx, Vector3.new(3.4, 0.15, 2), at(ctx, 0, 1, 0), C.enamel, M.Metal, false)
	legs(ctx, 3.2, 1.8, 3, 0.15, C.steel, M.Metal)
	for i = 0, 3 do
		Kit.post(
			ctx.parent,
			0.7,
			0.35,
			at(ctx, -1.1 + i * 0.7, 3.42, (i % 2) * 0.5 - 0.25),
			if i % 2 == 0 then rgb(90, 60, 40) else rgb(60, 90, 80),
			{ material = M.Glass, collide = false }
		)
	end
	return top
end

Builders.MedicineCabinet = function(ctx)
	local body = box(ctx, Vector3.new(3, 5, 1.4), at(ctx, 0, 2.5, 0), C.enamel, M.Metal)
	box(ctx, Vector3.new(2.6, 2.8, 0.1), at(ctx, 0, 2.8, -0.74), rgb(170, 190, 196), M.Glass, false)
	box(ctx, Vector3.new(0.7, 0.22, 0.1), at(ctx, 0, 4.6, -0.75), C.red, M.SmoothPlastic, false)
	box(ctx, Vector3.new(0.22, 0.7, 0.1), at(ctx, 0, 4.6, -0.78), C.red, M.SmoothPlastic, false)
	return body
end

Builders.Desk = function(ctx)
	local top = box(ctx, Vector3.new(5, 0.25, 2.6), at(ctx, 0, 3.0, 0), C.woodDark, M.Wood)
	box(ctx, Vector3.new(3.6, 0.06, 1.8), at(ctx, 0, 3.15, 0), C.green, M.Leather, false)
	for _, x in { -1.65, 1.65 } do
		box(ctx, Vector3.new(1.5, 2.85, 2.3), at(ctx, x, 1.43, 0.05), C.wood, M.Wood)
	end
	Kit.post(ctx.parent, 1.4, 0.2, at(ctx, 1.7, 3.85, 0.6), C.brass, { material = M.Metal, collide = false })
	box(ctx, Vector3.new(0.9, 0.5, 0.9), at(ctx, 1.7, 4.7, 0.6), C.green, M.Glass, false)
	return top
end

Builders.FilingCabinet = function(ctx)
	return cabinet(ctx, 2, 4.4, 2.2, C.olive, M.Metal, 3, C.steel)
end

Builders.Safe = function(ctx)
	box(ctx, Vector3.new(2.9, 0.4, 2.7), at(ctx, 0, 0.2, 0), C.iron, M.Metal)
	local body = box(ctx, Vector3.new(2.8, 3.2, 2.6), at(ctx, 0, 2.0, 0), rgb(40, 44, 42), M.Metal)
	Kit.cylinder(
		ctx.parent,
		0.2,
		0.9,
		at(ctx, -0.4, 2.3, -1.4) * Kit.angles(0, 90, 0),
		C.brass,
		{ material = M.Metal, collide = false }
	)
	box(ctx, Vector3.new(0.15, 0.9, 0.15), at(ctx, 0.7, 2.0, -1.4), C.brass, M.Metal, false)
	return body
end

Builders.Range = function(ctx)
	local body = box(ctx, Vector3.new(6, 3, 2.8), at(ctx, 0, 1.5, 0), C.iron, M.Metal)
	box(ctx, Vector3.new(6.2, 0.2, 3), at(ctx, 0, 3.1, 0), rgb(36, 36, 38), M.Metal)
	for _, x in { -1.5, 1.5 } do
		box(ctx, Vector3.new(2, 1.6, 0.12), at(ctx, x, 1.4, -1.45), rgb(64, 62, 60), M.Metal, false)
		box(ctx, Vector3.new(0.8, 0.12, 0.12), at(ctx, x, 2.0, -1.56), C.brass, M.Metal, false)
	end
	box(ctx, Vector3.new(6, 2.4, 0.2), at(ctx, 0, 4.4, 1.3), rgb(150, 140, 120), M.Brick, false)
	Kit.post(
		ctx.parent,
		1.0,
		1.6,
		at(ctx, -1.5, 3.7, 0.3),
		rgb(110, 110, 110),
		{ material = M.Metal, collide = false }
	)
	return body
end

local TINS = { rgb(150, 60, 40), rgb(70, 110, 90), rgb(190, 160, 80), rgb(90, 80, 120) }
Builders.Pantry = function(ctx)
	return shelves(ctx, 4, 6.5, 1.6, C.wood, 4, TINS)
end

Builders.ShopShelf = function(ctx)
	return shelves(ctx, 4, 6, 1.6, C.woodLight, 4, TINS)
end

Builders.Wardrobe = function(ctx)
	local body = box(ctx, Vector3.new(3.8, 7.5, 2), at(ctx, 0, 3.75, 0), C.woodDark, M.Wood)
	for _, x in { -0.93, 0.93 } do
		box(
			ctx,
			Vector3.new(1.8, 6.6, 0.1),
			at(ctx, x, 3.9, -1.04),
			Kit.shade(C.woodDark, 1.15),
			M.Wood,
			false
		)
	end
	box(ctx, Vector3.new(4.1, 0.4, 2.2), at(ctx, 0, 7.7, 0), C.woodDark, M.Wood, false)
	return body
end

Builders.Trunk = function(ctx)
	local body = box(ctx, Vector3.new(3, 1.8, 1.8), at(ctx, 0, 0.9, 0), rgb(92, 64, 44), M.Leather)
	for _, x in { -0.9, 0.9 } do
		box(ctx, Vector3.new(0.25, 1.9, 1.9), at(ctx, x, 0.9, 0), rgb(54, 40, 30), M.Leather, false)
	end
	box(ctx, Vector3.new(0.4, 0.4, 0.1), at(ctx, 0, 1.4, -0.95), C.brass, M.Metal, false)
	return body
end

Builders.Barrels = function(ctx)
	local main =
		Kit.post(ctx.parent, 3.2, 2.4, at(ctx, -0.8, 1.6, -0.6), rgb(100, 70, 46), { material = M.Wood })
	-- a shorter barrel beside it, so the two lids are not in one plane
	Kit.post(ctx.parent, 2.9, 2.4, at(ctx, 1.1, 1.45, 0.4), rgb(92, 66, 44), { material = M.Wood })
	Kit.post(
		ctx.parent,
		2.6,
		2.2,
		at(ctx, -0.6, 1.3, 1.3) * Kit.angles(0, 0, 4),
		rgb(108, 76, 50),
		{ material = M.Wood }
	)
	return main
end

Builders.Pigeonholes = function(ctx)
	local back = box(ctx, Vector3.new(4, 6, 0.2), at(ctx, 0, 3, 0.5), C.woodDark, M.Wood)
	for i = 0, 4 do
		box(ctx, Vector3.new(4, 0.12, 1.0), at(ctx, 0, 1.2 + i * 1.1, -0.1), C.wood, M.Wood, false)
	end
	for _, x in { -1.95, 1.95 } do
		box(ctx, Vector3.new(0.12, 6, 1.0), at(ctx, x, 3, -0.1), C.wood, M.Wood, false)
	end
	for i = 0, 3 do
		box(
			ctx,
			Vector3.new(3.2, 0.5, 0.5),
			at(ctx, (ctx.rng:NextNumber() - 0.5) * 0.4, 1.55 + i * 1.1, -0.05),
			C.paper,
			M.SmoothPlastic,
			false
		)
	end
	return back
end

Builders.MailSacks = function(ctx)
	local main = Kit.ball(ctx.parent, 2.2, at(ctx, -0.6, 1.0, 0.2), C.canvas, { material = M.Fabric })
	Kit.ball(ctx.parent, 1.9, at(ctx, 0.9, 0.9, -0.4), Kit.shade(C.canvas, 0.9), { material = M.Fabric })
	Kit.ball(
		ctx.parent,
		1.6,
		at(ctx, 0.2, 2.0, 0.3),
		Kit.shade(C.canvas, 1.08),
		{ material = M.Fabric, collide = false }
	)
	box(ctx, Vector3.new(0.5, 0.35, 0.05), at(ctx, -0.6, 1.4, -0.92), C.paper, M.SmoothPlastic, false)
	return main
end

Builders.Shelving = function(ctx)
	for _, x in { -2.35, 2.35 } do
		for _, z in { -0.85, 0.85 } do
			box(ctx, Vector3.new(0.2, 7, 0.2), at(ctx, x, 3.5, z), C.steel, M.Metal, false)
		end
	end
	local main: BasePart? = nil
	for i = 0, 3 do
		local shelf = box(ctx, Vector3.new(5, 0.15, 2), at(ctx, 0, 0.6 + i * 1.9, 0), C.steel, M.Metal)
		main = main or shelf
		if ctx.rng:NextNumber() < 0.8 then
			local s = 1 + ctx.rng:NextNumber() * 0.5
			box(
				ctx,
				Vector3.new(s * 1.4, s, s),
				at(ctx, (ctx.rng:NextNumber() - 0.5) * 2.4, 0.675 + i * 1.9 + s / 2, 0),
				rgb(140, 110, 72),
				M.Cardboard,
				false
			)
		end
	end
	return main :: BasePart
end

Builders.Altar = function(ctx)
	local block = box(ctx, Vector3.new(6, 3.4, 2.6), at(ctx, 0, 1.7, 0), C.stone, M.Limestone)
	box(ctx, Vector3.new(6.2, 0.1, 2.8), at(ctx, 0, 3.45, 0), C.cloth, M.Fabric, false)
	box(ctx, Vector3.new(4.4, 2.4, 0.08), at(ctx, 0, 2.2, -1.36), rgb(120, 30, 36), M.Fabric, false)
	for _, x in { -2.2, 2.2 } do
		Kit.post(ctx.parent, 1.2, 0.3, at(ctx, x, 4.1, 0.4), C.brass, { material = M.Metal, collide = false })
	end
	box(ctx, Vector3.new(0.5, 4, 0.3), at(ctx, 0, 7.5, 1.0), C.brass, M.Metal, false)
	box(ctx, Vector3.new(2.4, 0.5, 0.36), at(ctx, 0, 8.3, 1.0), C.brass, M.Metal, false)
	return block
end

Builders.Pew = function(ctx)
	local seat = box(ctx, Vector3.new(7.4, 0.3, 1.4), at(ctx, 0, 1.6, -0.3), C.woodDark, M.Wood)
	box(
		ctx,
		Vector3.new(7.4, 2.2, 0.25),
		at(ctx, 0, 2.7, 0.55) * Kit.angles(-6, 0, 0),
		C.woodDark,
		M.Wood,
		false
	)
	for _, x in { -3.85, 3.85 } do
		box(ctx, Vector3.new(0.3, 3.4, 2), at(ctx, x, 1.7, 0), Kit.shade(C.woodDark, 0.9), M.Wood)
	end
	return seat
end

Builders.PoorBox = function(ctx)
	Kit.post(ctx.parent, 2.6, 0.5, at(ctx, 0, 1.3, 0), C.woodDark, { material = M.Wood })
	local body = box(ctx, Vector3.new(1.4, 1.1, 1.4), at(ctx, 0, 3.15, 0), C.wood, M.Wood)
	box(ctx, Vector3.new(0.6, 0.08, 0.1), at(ctx, 0, 3.5, -0.75), C.iron, M.Metal, false)
	return body
end

Builders.Crates = function(ctx)
	local main = box(
		ctx,
		Vector3.new(2.6, 2.6, 2.6),
		at(ctx, -0.6, 1.3, 0.4) * Kit.angles(0, 8, 0),
		rgb(124, 92, 60),
		M.WoodPlanks
	)
	box(
		ctx,
		Vector3.new(2.2, 2.2, 2.2),
		at(ctx, 0.9, 1.1, -0.7) * Kit.angles(0, -14, 0),
		rgb(112, 84, 56),
		M.WoodPlanks
	)
	box(
		ctx,
		Vector3.new(1.8, 1.8, 1.8),
		at(ctx, -0.4, 3.5, 0.3) * Kit.angles(0, 30, 0),
		rgb(130, 98, 64),
		M.WoodPlanks
	)
	return main
end

Builders.Workbench = function(ctx)
	local top = box(ctx, Vector3.new(6, 0.4, 2.6), at(ctx, 0, 3.0, 0), C.woodDark, M.Wood)
	legs(ctx, 5.8, 2.4, 2.8, 0.4, C.woodDark)
	box(ctx, Vector3.new(6, 3, 0.2), at(ctx, 0, 5.4, 1.2), rgb(120, 104, 80), M.WoodPlanks, false)
	box(ctx, Vector3.new(0.8, 0.7, 0.9), at(ctx, -2.3, 3.55, -0.8), C.steel, M.Metal, false)
	for i = 0, 3 do
		box(
			ctx,
			Vector3.new(0.18, 1.2, 0.1),
			at(ctx, -1.5 + i * 1, 5.6, 1.06) * Kit.angles(0, 0, (i - 1.5) * 12),
			C.steel,
			M.Metal,
			false
		)
	end
	return top
end

Builders.Lathe = function(ctx)
	local base = box(ctx, Vector3.new(6, 2.6, 2.2), at(ctx, 0, 1.3, 0), rgb(70, 86, 78), M.Metal)
	box(ctx, Vector3.new(5.6, 0.6, 1.2), at(ctx, 0, 2.9, 0), C.steel, M.Metal)
	box(ctx, Vector3.new(1.4, 1.6, 1.6), at(ctx, -2, 3.9, 0), rgb(70, 86, 78), M.Metal)
	box(ctx, Vector3.new(0.9, 1.2, 1.0), at(ctx, 2, 3.7, 0), rgb(70, 86, 78), M.Metal)
	return base
end

Builders.LampRack = function(ctx)
	local back = box(ctx, Vector3.new(4, 5, 0.2), at(ctx, 0, 2.5, 0.5), C.wood, M.Wood)
	for row = 0, 1 do
		box(ctx, Vector3.new(4, 0.15, 1.0), at(ctx, 0, 2 + row * 2, 0), C.wood, M.Wood, false)
		for i = 0, 3 do
			Kit.post(
				ctx.parent,
				0.9,
				0.5,
				at(ctx, -1.5 + i, 2.55 + row * 2, -0.1),
				C.brass,
				{ material = M.Metal, collide = false }
			)
		end
	end
	return back
end

-- Builds a piece and returns its main part (where a search prompt would hang).
-- A storm lantern left burning on an upturned crate by the way in.
Builders.Lantern = function(ctx)
	local crate = box(ctx, Vector3.new(1.3, 1.6, 1.3), at(ctx, 0, 0.8, 0), C.woodLight, M.WoodPlanks)
	Kit.post(ctx.parent, 0.15, 0.7, at(ctx, 0, 1.675, 0), C.iron, { material = M.Metal, collide = false })
	local glass = box(ctx, Vector3.new(0.5, 0.7, 0.5), at(ctx, 0, 2.1, 0), rgb(255, 200, 130), M.Neon, false)
	glass.CastShadow = false
	Kit.post(ctx.parent, 0.15, 0.6, at(ctx, 0, 2.525, 0), C.iron, { material = M.Metal, collide = false })
	box(ctx, Vector3.new(0.06, 0.4, 0.5), at(ctx, 0, 2.8, 0), C.iron, M.Metal, false)
	local light = Kit.pointLight(glass, rgb(255, 196, 130), 0.9, 16, false)
	light:SetAttribute("Base", 0.9)
	return crate
end

function FurnitureKit.build(kind: string, ctx: Ctx): BasePart
	local builder = Builders[kind]
	assert(builder, `no furniture builder for {kind}`)
	return builder(ctx)
end

function FurnitureKit.has(kind: string): boolean
	return Builders[kind] ~= nil
end

return FurnitureKit
