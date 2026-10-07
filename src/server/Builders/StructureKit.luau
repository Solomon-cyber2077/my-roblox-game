--!strict
--[[
	Station buildings, containers and props, assembled from primitives.

	Every builder receives a Context: the model to build into, the slab part to
	weld to (so the piece falls with its ground), a frame at the piece's centre on
	the ground (local -Z faces the train), its footprint, the station palette and
	a Random for variation. Builders only create parts; StationBuilder welds them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)

local StationDressing = require(script.Parent.StationDressing)

export type Palette = { ground: Color3, accent: Color3, trim: Color3, light: Color3 }

export type Context = {
	parent: Model,
	base: BasePart,
	frame: CFrame,
	width: number, -- along local X
	depth: number, -- along local Z
	palette: Palette,
	rng: Random,
	label: string?,
}

local StructureKit = {}

local C = {
	brick = Color3.fromRGB(122, 74, 58),
	brickDark = Color3.fromRGB(92, 56, 44),
	stone = Color3.fromRGB(176, 166, 150),
	slate = Color3.fromRGB(58, 60, 66),
	wood = Color3.fromRGB(110, 80, 54),
	woodDark = Color3.fromRGB(70, 50, 36),
	iron = Color3.fromRGB(52, 52, 56),
	rust = Color3.fromRGB(116, 70, 44),
	coal = Color3.fromRGB(28, 27, 26),
	glassWarm = Color3.fromRGB(222, 160, 98), -- lit from inside, too dim to glare
	glass = Color3.fromRGB(150, 170, 180),
	canvasA = Color3.fromRGB(150, 44, 48),
	canvasB = Color3.fromRGB(226, 214, 186),
	water = Color3.fromRGB(40, 48, 52),
}

local function f(ctx: Context, x: number, y: number, z: number): CFrame
	return ctx.frame * CFrame.new(x, y, z)
end

local function pitchedRoof(
	ctx: Context,
	width: number,
	depth: number,
	top: number,
	rise: number,
	color: Color3,
	material: Enum.Material
)
	Kit.wedge(
		ctx.parent,
		Vector3.new(width, rise, depth / 2),
		f(ctx, 0, top + rise / 2, -depth / 4),
		color,
		{ material = material }
	)
	Kit.wedge(
		ctx.parent,
		Vector3.new(width, rise, depth / 2),
		f(ctx, 0, top + rise / 2, depth / 4) * Kit.angles(0, 180, 0),
		color,
		{ material = material }
	)
end

local function windowRow(ctx: Context, width: number, faceZ: number, y: number, count: number, lit: boolean)
	local pitch = width / count
	for i = 1, count do
		local x = -width / 2 + pitch * (i - 0.5)
		Kit.block(ctx.parent, Vector3.new(2.6, 3.4, 0.3), f(ctx, x, y, faceZ), C.stone, { collide = false })
		Kit.block(
			ctx.parent,
			Vector3.new(2.0, 2.8, 0.35),
			f(ctx, x, y, faceZ),
			if lit then C.glassWarm else C.glass,
			{
				material = if lit then Enum.Material.Neon else Enum.Material.Glass,
				transparency = if lit then 0.45 else 0.3,
				collide = false,
				shadow = false,
			}
		)
	end
end

-- Buildings -------------------------------------------------------------------------

local Builders: { [string]: (Context) -> () } = {}

Builders.StationHouse = function(ctx)
	local w, d, h = ctx.width - 3, ctx.depth - 4, 12
	Kit.block(
		ctx.parent,
		Vector3.new(w + 1, 1, d + 1),
		f(ctx, 0, 0.5, 0),
		C.stone,
		{ material = Enum.Material.Concrete }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(w, h, d),
		f(ctx, 0, 1 + h / 2, 0),
		C.brick,
		{ material = Enum.Material.Brick }
	)
	for _, z in { -d / 2 - 0.15, d / 2 + 0.15 } do
		windowRow(ctx, w - 6, z, 7, 4, true)
	end
	Kit.block(
		ctx.parent,
		Vector3.new(3.6, 6.5, 0.4),
		f(ctx, 0, 4.25, -d / 2 - 0.2),
		C.woodDark,
		{ material = Enum.Material.Wood, collide = false }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(w + 4, 0.4, 5),
		f(ctx, 0, 8.4, -d / 2 - 2.4) * Kit.angles(-8, 0, 0),
		ctx.palette.accent,
		{ material = Enum.Material.Metal }
	)
	for _, x in { -w / 2 + 1, w / 2 - 1 } do
		Kit.post(
			ctx.parent,
			7.6,
			0.5,
			f(ctx, x, 4.4, -d / 2 - 4.6),
			C.iron,
			{ material = Enum.Material.Metal }
		)
	end
	pitchedRoof(ctx, w + 1.6, d + 1.6, 1 + h, 5, C.slate, Enum.Material.Slate)
	Kit.block(
		ctx.parent,
		Vector3.new(2, 6, 2),
		f(ctx, w / 3, h + 5, d / 6),
		C.brickDark,
		{ material = Enum.Material.Brick }
	)
	local clock = Kit.cylinder(
		ctx.parent,
		0.4,
		3.2,
		f(ctx, 0, h - 1.2, -d / 2 - 0.3) * Kit.angles(0, 90, 0),
		Color3.fromRGB(236, 226, 200),
		{ collide = false }
	)
	Kit.cylinder(ctx.parent, 0.3, 3.6, clock.CFrame * CFrame.new(-0.07, 0, 0), C.iron, { collide = false })
end

Builders.Shed = function(ctx)
	local w, d, h = ctx.width - 3, ctx.depth - 3, 8 + ctx.rng:NextNumber() * 2
	Kit.block(
		ctx.parent,
		Vector3.new(w, h, d),
		f(ctx, 0, h / 2, 0),
		C.rust,
		{ material = Enum.Material.CorrodedMetal }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(w * 0.55, h * 0.75, 0.4),
		f(ctx, 0, h * 0.375, -d / 2 - 0.2),
		C.woodDark,
		{ material = Enum.Material.WoodPlanks, collide = false }
	)
	Kit.wedge(
		ctx.parent,
		Vector3.new(w + 1, 2.5, d + 1),
		f(ctx, 0, h + 1.25, 0),
		C.iron,
		{ material = Enum.Material.CorrodedMetal }
	)
end

Builders.WaterTower = function(ctx)
	local legH = 13
	for _, x in { -4, 4 } do
		for _, z in { -4, 4 } do
			Kit.post(
				ctx.parent,
				legH,
				0.9,
				f(ctx, x, legH / 2, z),
				C.woodDark,
				{ material = Enum.Material.Wood }
			)
		end
	end
	Kit.block(
		ctx.parent,
		Vector3.new(10, 0.6, 10),
		f(ctx, 0, legH, 0),
		C.woodDark,
		{ material = Enum.Material.WoodPlanks }
	)
	Kit.post(ctx.parent, 8, 11, f(ctx, 0, legH + 4.3, 0), C.wood, { material = Enum.Material.WoodPlanks })
	for _, y in { legH + 1.5, legH + 4.3, legH + 7.1 } do
		Kit.post(
			ctx.parent,
			0.3,
			11.3,
			f(ctx, 0, y, 0),
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	Kit.post(ctx.parent, 0.8, 12, f(ctx, 0, legH + 8.7, 0), C.slate, { material = Enum.Material.Slate })
	Kit.block(
		ctx.parent,
		Vector3.new(0.8, 0.8, 7),
		f(ctx, 0, legH + 1, -6.5) * Kit.angles(-20, 0, 0),
		C.iron,
		{ material = Enum.Material.Metal, collide = false }
	)
end

Builders.CoalTower = function(ctx)
	local h = 20
	for _, x in { -8, 8 } do
		for _, z in { -8, 8 } do
			Kit.block(
				ctx.parent,
				Vector3.new(1.2, h, 1.2),
				f(ctx, x, h / 2, z),
				C.woodDark,
				{ material = Enum.Material.Wood }
			)
		end
		Kit.block(
			ctx.parent,
			Vector3.new(0.6, 0.6, 22),
			f(ctx, x, h * 0.45, 0) * Kit.angles(38, 0, 0),
			C.woodDark,
			{ material = Enum.Material.Wood, collide = false }
		)
	end
	Kit.block(
		ctx.parent,
		Vector3.new(18, 9, 18),
		f(ctx, 0, h + 3.5, 0),
		C.wood,
		{ material = Enum.Material.WoodPlanks }
	)
	Kit.wedge(
		ctx.parent,
		Vector3.new(18, 3, 18),
		f(ctx, 0, h + 9.5, 0),
		C.slate,
		{ material = Enum.Material.Slate }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(3, 1.4, 9),
		f(ctx, 0, h - 2.5, -11) * Kit.angles(-28, 0, 0),
		C.iron,
		{ material = Enum.Material.CorrodedMetal }
	)
	for i = 1, 6 do
		Kit.ball(
			ctx.parent,
			2 + ctx.rng:NextNumber() * 2,
			f(ctx, ctx.rng:NextNumber() * 6 - 3, 1, ctx.rng:NextNumber() * 6 - 3),
			C.coal,
			{ material = Enum.Material.Slate }
		)
		local _ = i
	end
end

Builders.CoalHeap = function(ctx)
	for i = 1, 13 do
		local radius = 1 - i / 16
		local x = (ctx.rng:NextNumber() - 0.5) * ctx.width * 0.7 * radius
		local z = (ctx.rng:NextNumber() - 0.5) * ctx.depth * 0.7 * radius
		local size = 4 + ctx.rng:NextNumber() * 4 * radius + 2
		Kit.ball(
			ctx.parent,
			size,
			f(ctx, x, size * 0.3 + (i / 13) * 3, z),
			Kit.shade(C.coal, 0.85 + ctx.rng:NextNumber() * 0.35),
			{ material = Enum.Material.Slate }
		)
	end
end

Builders.Hopper = function(ctx)
	local w, d = ctx.width - 3, ctx.depth - 4
	for _, x in { -w / 2 + 0.6, w / 2 - 0.6 } do
		for _, z in { -d / 2 + 0.6, d / 2 - 0.6 } do
			Kit.block(
				ctx.parent,
				Vector3.new(0.8, 7, 0.8),
				f(ctx, x, 3.5, z),
				C.iron,
				{ material = Enum.Material.Metal }
			)
		end
	end
	Kit.block(
		ctx.parent,
		Vector3.new(w, 4, d),
		f(ctx, 0, 9, 0),
		C.rust,
		{ material = Enum.Material.CorrodedMetal }
	)
	Kit.wedge(
		ctx.parent,
		Vector3.new(w, 2.5, d / 2),
		f(ctx, 0, 5.75, -d / 4) * Kit.angles(180, 180, 0),
		C.rust,
		{ material = Enum.Material.CorrodedMetal }
	)
	Kit.wedge(
		ctx.parent,
		Vector3.new(w, 2.5, d / 2),
		f(ctx, 0, 5.75, d / 4) * Kit.angles(180, 0, 0),
		C.rust,
		{ material = Enum.Material.CorrodedMetal }
	)
	for i = 1, 4 do
		Kit.ball(
			ctx.parent,
			2.4,
			f(ctx, (i - 2.5) * 1.6, 11.2, 0),
			C.coal,
			{ material = Enum.Material.Slate, collide = false }
		)
	end
end

Builders.Workshop = function(ctx)
	local w, d, h = ctx.width - 3, ctx.depth - 3, 11
	Kit.block(
		ctx.parent,
		Vector3.new(w, h, d),
		f(ctx, 0, h / 2, 0),
		C.brickDark,
		{ material = Enum.Material.Brick }
	)
	windowRow(ctx, w - 4, -d / 2 - 0.15, 6.5, 5, ctx.rng:NextNumber() > 0.4)
	Kit.block(
		ctx.parent,
		Vector3.new(8, 8, 0.4),
		f(ctx, w / 2 - 7, 4, -d / 2 - 0.2),
		C.woodDark,
		{ material = Enum.Material.WoodPlanks, collide = false }
	)
	local teeth = 3
	for i = 1, teeth do
		local z = -d / 2 + d * (i - 0.5) / teeth
		Kit.wedge(
			ctx.parent,
			Vector3.new(w, 4, d / teeth),
			f(ctx, 0, h + 2, z) * Kit.angles(0, 180, 0),
			C.slate,
			{ material = Enum.Material.Slate }
		)
		Kit.block(
			ctx.parent,
			Vector3.new(w - 1, 3.4, 0.25),
			f(ctx, 0, h + 1.8, z - d / teeth / 2 + 0.2),
			C.glass,
			{
				material = Enum.Material.Glass,
				transparency = 0.4,
				collide = false,
			}
		)
	end
	Kit.post(
		ctx.parent,
		10,
		1.6,
		f(ctx, -w / 2 + 3, h + 5, d / 2 - 3),
		C.brick,
		{ material = Enum.Material.Brick }
	)
end

Builders.SignalBox = function(ctx)
	local w, d = ctx.width - 5, ctx.depth - 6
	Kit.block(
		ctx.parent,
		Vector3.new(w, 7, d),
		f(ctx, 0, 3.5, 0),
		C.brick,
		{ material = Enum.Material.Brick }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(w + 1.4, 0.6, d + 1.4),
		f(ctx, 0, 7.3, 0),
		C.woodDark,
		{ material = Enum.Material.Wood }
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.block(
				ctx.parent,
				Vector3.new(0.6, 6, 0.6),
				f(ctx, sx * (w / 2 + 0.3), 10.6, sz * (d / 2 + 0.3)),
				ctx.palette.accent,
				{ collide = false }
			)
		end
	end
	for _, z in { -d / 2 - 0.4, d / 2 + 0.4 } do
		Kit.block(
			ctx.parent,
			Vector3.new(w, 4.4, 0.25),
			f(ctx, 0, 10.6, z),
			C.glassWarm,
			{ material = Enum.Material.Neon, transparency = 0.55, collide = false }
		)
	end
	for _, x in { -w / 2 - 0.4, w / 2 + 0.4 } do
		Kit.block(
			ctx.parent,
			Vector3.new(0.25, 4.4, d),
			f(ctx, x, 10.6, 0),
			C.glassWarm,
			{ material = Enum.Material.Neon, transparency = 0.55, collide = false }
		)
	end
	Kit.block(
		ctx.parent,
		Vector3.new(w + 1.4, 1.4, d + 1.4),
		f(ctx, 0, 8.3, 0),
		ctx.palette.accent,
		{ material = Enum.Material.WoodPlanks }
	)
	pitchedRoof(ctx, w + 2.4, d + 2.4, 13.6, 3, C.slate, Enum.Material.Slate)
	Kit.block(
		ctx.parent,
		Vector3.new(2.4, 0.4, 8),
		f(ctx, w / 2 + 1.6, 3.7, -1) * Kit.angles(-42, 0, 0),
		C.woodDark,
		{ material = Enum.Material.Wood }
	)
end

Builders.CableDrums = function(ctx)
	for i = 1, 2 + (if ctx.rng:NextNumber() > 0.5 then 1 else 0) do
		local x = (i - 2) * 3.4
		local drum = Kit.cylinder(
			ctx.parent,
			2.6,
			5,
			f(ctx, x, 2.5, (ctx.rng:NextNumber() - 0.5) * 3) * Kit.angles(0, 90, 0),
			C.wood,
			{ material = Enum.Material.WoodPlanks }
		)
		Kit.cylinder(
			ctx.parent,
			2.7,
			3.4,
			drum.CFrame,
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
end

Builders.Stall = function(ctx)
	local w, d = ctx.width - 3, ctx.depth - 5
	Kit.block(
		ctx.parent,
		Vector3.new(w, 0.4, d),
		f(ctx, 0, 3, 0),
		C.wood,
		{ material = Enum.Material.WoodPlanks }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(w - 0.4, 2.8, d - 0.4),
		f(ctx, 0, 1.4, 0),
		C.woodDark,
		{ material = Enum.Material.WoodPlanks }
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.post(
				ctx.parent,
				7.5,
				0.35,
				f(ctx, sx * (w / 2 - 0.3), 3.75, sz * (d / 2 - 0.3)),
				C.woodDark,
				{ material = Enum.Material.Wood, collide = false }
			)
		end
	end
	local stripes = 5
	for i = 1, stripes do
		local x = -w / 2 + w * (i - 0.5) / stripes
		Kit.block(
			ctx.parent,
			Vector3.new(w / stripes, 0.2, d + 1.6),
			f(ctx, x, 7.6, 0) * Kit.angles(-10, 0, 0),
			if i % 2 == 0 then C.canvasA else C.canvasB,
			{ material = Enum.Material.Fabric, collide = false }
		)
	end
	for _ = 1, 5 do
		local good = Kit.block(
			ctx.parent,
			Vector3.new(
				0.6 + ctx.rng:NextNumber(),
				0.5 + ctx.rng:NextNumber() * 0.8,
				0.6 + ctx.rng:NextNumber()
			),
			f(ctx, (ctx.rng:NextNumber() - 0.5) * (w - 1.5), 3.6, (ctx.rng:NextNumber() - 0.5) * (d - 1.5)),
			Color3.fromHSV(ctx.rng:NextNumber(), 0.35, 0.55),
			{ material = Enum.Material.Fabric, collide = false }
		)
		local _ = good
	end
end

Builders.Fountain = function(ctx)
	Kit.post(ctx.parent, 2, 18, f(ctx, 0, 1, 0), C.stone, { material = Enum.Material.Marble })
	Kit.post(
		ctx.parent,
		0.3,
		16,
		f(ctx, 0, 1.9, 0),
		C.water,
		{ material = Enum.Material.Glass, transparency = 0.3, collide = false }
	)
	Kit.post(ctx.parent, 6, 2, f(ctx, 0, 4, 0), C.stone, { material = Enum.Material.Marble })
	Kit.post(ctx.parent, 0.8, 6, f(ctx, 0, 7.2, 0), C.stone, { material = Enum.Material.Marble })
	Kit.ball(ctx.parent, 2, f(ctx, 0, 8.2, 0), ctx.palette.accent, { material = Enum.Material.Metal })
end

Builders.Headframe = function(ctx)
	local h = 30
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.block(
				ctx.parent,
				Vector3.new(1, h + 2, 1),
				f(ctx, sx * 7, h / 2, sz * 7) * Kit.angles(sz * 8, 0, -sx * 8),
				C.iron,
				{ material = Enum.Material.Metal }
			)
		end
		for y = 6, h - 4, 8 do
			Kit.block(
				ctx.parent,
				Vector3.new(0.4, 0.4, 14 - y * 0.25),
				f(ctx, sx * (7 - y * 0.13), y, 0),
				C.iron,
				{ material = Enum.Material.Metal, collide = false }
			)
		end
	end
	Kit.block(
		ctx.parent,
		Vector3.new(8, 1, 8),
		f(ctx, 0, h, 0),
		C.iron,
		{ material = Enum.Material.DiamondPlate }
	)
	for _, z in { -1.8, 1.8 } do
		local wheel = Kit.cylinder(
			ctx.parent,
			0.6,
			9,
			f(ctx, 0, h + 4, z) * Kit.angles(0, 90, 0),
			C.rust,
			{ material = Enum.Material.CorrodedMetal, collide = false }
		)
		Kit.cylinder(
			ctx.parent,
			0.7,
			1.6,
			wheel.CFrame,
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	Kit.block(
		ctx.parent,
		Vector3.new(10, 8, 8),
		f(ctx, 0, 4, 10),
		C.brickDark,
		{ material = Enum.Material.Brick }
	)
	Kit.wedge(
		ctx.parent,
		Vector3.new(10, 3, 8),
		f(ctx, 0, 9.5, 10) * Kit.angles(0, 180, 0),
		C.slate,
		{ material = Enum.Material.Slate }
	)
end

Builders.TunnelMouth = function(ctx)
	local w, d = ctx.width, ctx.depth
	for i = 1, 9 do
		local x = -w / 2 + w * (i - 0.5) / 9
		local hgt = 16 + ctx.rng:NextNumber() * 10
		Kit.block(
			ctx.parent,
			Vector3.new(w / 9 + 2, hgt, d - 4),
			f(ctx, x, hgt / 2, 2) * Kit.angles(0, ctx.rng:NextNumber() * 10 - 5, ctx.rng:NextNumber() * 6 - 3),
			Kit.shade(Color3.fromRGB(70, 62, 56), 0.8 + ctx.rng:NextNumber() * 0.3),
			{ material = Enum.Material.Rock }
		)
	end
	Kit.block(
		ctx.parent,
		Vector3.new(12, 11, 2),
		f(ctx, 0, 5.5, -d / 2 + 2.2),
		Color3.new(),
		{ material = Enum.Material.SmoothPlastic, collide = false }
	)
	for _, x in { -6.5, 6.5 } do
		Kit.block(
			ctx.parent,
			Vector3.new(1.4, 12, 1.4),
			f(ctx, x, 6, -d / 2 + 1.2),
			C.woodDark,
			{ material = Enum.Material.Wood }
		)
	end
	Kit.block(
		ctx.parent,
		Vector3.new(15, 1.6, 1.6),
		f(ctx, 0, 12, -d / 2 + 1.2),
		C.woodDark,
		{ material = Enum.Material.Wood }
	)
	local lamp =
		Kit.neon(ctx.parent, Vector3.new(0.8, 1, 0.8), f(ctx, 0, 10.6, -d / 2 + 0.2), ctx.palette.light)
	Kit.pointLight(lamp, ctx.palette.light, 1.2, 18, false)
end

Builders.Concourse = function(ctx)
	local w, d, h = ctx.width - 4, ctx.depth - 4, 16
	for x = -w / 2, w / 2, w / 6 do
		for _, z in { -d / 2, d / 2 } do
			Kit.post(ctx.parent, h, 1.4, f(ctx, x, h / 2, z), C.iron, { material = Enum.Material.Metal })
			Kit.post(ctx.parent, 1, 2.2, f(ctx, x, 0.5, z), C.stone, { material = Enum.Material.Marble })
		end
	end
	Kit.block(
		ctx.parent,
		Vector3.new(w + 2, 1, d + 2),
		f(ctx, 0, h + 0.5, 0),
		C.iron,
		{ material = Enum.Material.Metal }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(w - 4, 0.4, d - 4),
		f(ctx, 0, h + 1.2, 0),
		C.glass,
		{ material = Enum.Material.Glass, transparency = 0.5, collide = false }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(8, 14, 8),
		f(ctx, 0, h + 8, d / 2 - 4),
		C.stone,
		{ material = Enum.Material.Marble }
	)
	local clock = Kit.cylinder(
		ctx.parent,
		0.4,
		5.4,
		f(ctx, 0, h + 11, d / 2 - 8.25) * Kit.angles(0, 90, 0),
		Color3.fromRGB(240, 232, 210),
		{ collide = false }
	)
	Kit.cylinder(
		ctx.parent,
		0.3,
		6,
		clock.CFrame * CFrame.new(-0.06, 0, 0),
		ctx.palette.accent,
		{ material = Enum.Material.Metal, collide = false }
	)
	for _, x in { -w / 3, 0, w / 3 } do
		local lamp =
			Kit.neon(ctx.parent, Vector3.new(1.4, 0.4, 1.4), f(ctx, x, h - 0.6, 0), ctx.palette.light)
		Kit.pointLight(lamp, ctx.palette.light, 1.6, 30, false)
	end
end

function StructureKit.building(kind: string, ctx: Context)
	local builder = Builders[kind]
	if builder then
		builder(ctx)
	end
end

-- Containers --------------------------------------------------------------------------

local ContainerBuilders: { [string]: (Context) -> BasePart } = {}

ContainerBuilders.Crate = function(ctx)
	local box = Kit.block(
		ctx.parent,
		Vector3.new(3, 2.4, 2.4),
		f(ctx, 0, 1.2, 0),
		Color3.fromRGB(134, 98, 62),
		{ material = Enum.Material.WoodPlanks }
	)
	for _, y in { 0.2, 2.2 } do
		Kit.block(
			ctx.parent,
			Vector3.new(3.06, 0.22, 2.46),
			f(ctx, 0, y, 0),
			C.woodDark,
			{ material = Enum.Material.Wood, collide = false }
		)
	end
	-- the upright slat is a touch deeper than the bands so their faces never share a plane
	Kit.block(
		ctx.parent,
		Vector3.new(0.22, 2.46, 2.5),
		f(ctx, 0, 1.2, 0),
		C.woodDark,
		{ material = Enum.Material.Wood, collide = false }
	)
	return box
end

ContainerBuilders.Locker = function(ctx)
	local body = Kit.block(
		ctx.parent,
		Vector3.new(2.6, 6, 1.8),
		f(ctx, 0, 3, 0),
		Color3.fromRGB(70, 92, 96),
		{ material = Enum.Material.Metal }
	)
	for i = 1, 3 do
		Kit.block(
			ctx.parent,
			Vector3.new(1.4, 0.12, 0.06),
			f(ctx, 0, 4.6 + i * 0.3, -0.92),
			C.iron,
			{ collide = false }
		)
	end
	Kit.block(
		ctx.parent,
		Vector3.new(0.12, 0.8, 0.12),
		f(ctx, 0.9, 3, -0.95),
		Color3.fromRGB(201, 160, 82),
		{ material = Enum.Material.Metal, collide = false }
	)
	return body
end

ContainerBuilders.CoalBin = function(ctx)
	local base = Kit.block(
		ctx.parent,
		Vector3.new(4.4, 0.4, 3.2),
		f(ctx, 0, 0.2, 0),
		C.iron,
		{ material = Enum.Material.CorrodedMetal }
	)
	for _, x in { -2.1, 2.1 } do
		Kit.block(
			ctx.parent,
			Vector3.new(0.3, 2.4, 3.1),
			f(ctx, x, 1.4, 0),
			C.rust,
			{ material = Enum.Material.CorrodedMetal }
		)
	end
	-- end walls sit between the side walls, a little lower, so the corners are clean
	for _, z in { -1.5, 1.5 } do
		Kit.block(
			ctx.parent,
			Vector3.new(3.9, 2.3, 0.3),
			f(ctx, 0, 1.35, z),
			C.rust,
			{ material = Enum.Material.CorrodedMetal }
		)
	end
	for i = 1, 5 do
		Kit.ball(
			ctx.parent,
			1.4 + ctx.rng:NextNumber() * 0.6,
			f(ctx, (i - 3) * 0.75, 2.1 + ctx.rng:NextNumber() * 0.3, (ctx.rng:NextNumber() - 0.5) * 1.4),
			C.coal,
			{ material = Enum.Material.Slate, collide = false }
		)
	end
	return base
end

ContainerBuilders.ToolChest = function(ctx)
	local body = Kit.block(
		ctx.parent,
		Vector3.new(3.2, 1.9, 1.9),
		f(ctx, 0, 0.95, 0),
		Color3.fromRGB(150, 44, 40),
		{ material = Enum.Material.Metal }
	)
	Kit.block(ctx.parent, Vector3.new(3.26, 0.1, 1.96), f(ctx, 0, 1.5, 0), C.iron, { collide = false })
	Kit.block(
		ctx.parent,
		Vector3.new(1.2, 0.16, 0.16),
		f(ctx, 0, 2.0, 0),
		C.iron,
		{ material = Enum.Material.Metal, collide = false }
	)
	return body
end

ContainerBuilders.Vault = function(ctx)
	local body = Kit.block(
		ctx.parent,
		Vector3.new(3.4, 4.2, 3),
		f(ctx, 0, 2.1, 0),
		Color3.fromRGB(34, 36, 40),
		{ material = Enum.Material.Metal }
	)
	local dial = Kit.cylinder(
		ctx.parent,
		0.3,
		1.3,
		f(ctx, 0, 2.6, -1.55) * Kit.angles(0, 90, 0),
		Color3.fromRGB(201, 160, 82),
		{ material = Enum.Material.Metal, collide = false }
	)
	Kit.cylinder(ctx.parent, 0.32, 0.4, dial.CFrame, C.iron, { collide = false })
	for _, x in { -1.4, 1.4 } do
		for _, y in { 0.5, 3.7 } do
			Kit.ball(
				ctx.parent,
				0.25,
				f(ctx, x, y, -1.52),
				Color3.fromRGB(201, 160, 82),
				{ material = Enum.Material.Metal, collide = false }
			)
		end
	end
	Kit.block(ctx.parent, Vector3.new(0.2, 1.2, 0.2), f(ctx, 1.1, 1.8, -1.6), C.iron, { collide = false })
	return body
end

-- Returns the part the search prompt hangs from.
function StructureKit.container(kind: string, ctx: Context): BasePart
	local builder = ContainerBuilders[kind] or ContainerBuilders.Crate
	return builder(ctx)
end

-- Props ---------------------------------------------------------------------------------

local Props: { [string]: (Context) -> () } = {}

Props.Lamp = function(ctx)
	Kit.block(
		ctx.parent,
		Vector3.new(1.2, 0.6, 1.2),
		f(ctx, 0, 0.3, 0),
		C.iron,
		{ material = Enum.Material.Metal }
	)
	Kit.post(ctx.parent, 9, 0.4, f(ctx, 0, 4.8, 0), C.iron, { material = Enum.Material.Metal })
	Kit.block(
		ctx.parent,
		Vector3.new(1.3, 0.3, 1.3),
		f(ctx, 0, 9.4, 0),
		C.iron,
		{ material = Enum.Material.Metal, collide = false }
	)
	local lens = Kit.neon(ctx.parent, Vector3.new(0.9, 1.2, 0.9), f(ctx, 0, 10.1, 0), ctx.palette.light)
	Kit.block(
		ctx.parent,
		Vector3.new(1.4, 0.35, 1.4),
		f(ctx, 0, 10.85, 0),
		C.iron,
		{ material = Enum.Material.Metal, collide = false }
	)
	Kit.pointLight(lens, ctx.palette.light, 1.3, 24, false)
end

Props.Bench = function(ctx)
	Kit.block(
		ctx.parent,
		Vector3.new(5, 0.3, 1.6),
		f(ctx, 0, 1.6, 0),
		C.wood,
		{ material = Enum.Material.WoodPlanks }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(5, 1.4, 0.25),
		f(ctx, 0, 2.6, 0.75) * Kit.angles(-8, 0, 0),
		C.wood,
		{ material = Enum.Material.WoodPlanks, collide = false }
	)
	for _, x in { -2.1, 2.1 } do
		Kit.block(
			ctx.parent,
			Vector3.new(0.3, 1.6, 1.5),
			f(ctx, x, 0.8, 0),
			C.iron,
			{ material = Enum.Material.Metal }
		)
	end
end

Props.Sign = function(ctx)
	for _, x in { -6, 6 } do
		Kit.post(ctx.parent, 8, 0.4, f(ctx, x, 4, 0), C.iron, { material = Enum.Material.Metal })
	end
	local board = Kit.block(
		ctx.parent,
		Vector3.new(14, 2.6, 0.4),
		f(ctx, 0, 6.6, 0),
		Color3.fromRGB(28, 36, 52),
		{ material = Enum.Material.SmoothPlastic, collide = false }
	)
	Kit.block(
		ctx.parent,
		Vector3.new(14.4, 3, 0.3),
		f(ctx, 0, 6.6, 0),
		Color3.fromRGB(236, 226, 200),
		{ collide = false }
	)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(700, 130)
		gui.LightInfluence = 0.2
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold)
		label.Text = string.upper(ctx.label or "")
		label.TextColor3 = Color3.fromRGB(240, 232, 210)
		label.TextScaled = true
		label.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.14, 0)
		pad.PaddingBottom = UDim.new(0.14, 0)
		pad.PaddingLeft = UDim.new(0.04, 0)
		pad.PaddingRight = UDim.new(0.04, 0)
		pad.Parent = label
	end
end

Props.DecorCrates = function(ctx)
	for i = 1, 2 + (if ctx.rng:NextNumber() > 0.5 then 1 else 0) do
		local s = 1.8 + ctx.rng:NextNumber() * 1.2
		-- the second ground crate stands a touch short, so two equal crates never share a top
		local h = if i == 2 then s - 0.03 else s
		Kit.block(
			ctx.parent,
			Vector3.new(s, h, s),
			f(ctx, (i - 2) * 2.4, h / 2 + (if i == 3 then 2.02 else 0), ctx.rng:NextNumber() - 0.5)
				* Kit.angles(0, ctx.rng:NextNumber() * 40, 0),
			Color3.fromRGB(118, 88, 58),
			{ material = Enum.Material.WoodPlanks }
		)
	end
end

Props.Railing = function(ctx)
	for _, x in { -5, 0, 5 } do
		if ctx.rng:NextNumber() > 0.2 then
			Kit.block(
				ctx.parent,
				Vector3.new(0.35, 3.4, 0.35),
				f(ctx, x, 1.7, 0) * Kit.angles(ctx.rng:NextNumber() * 14 - 7, 0, 0),
				C.iron,
				{ material = Enum.Material.Metal }
			)
		end
	end
	Kit.block(
		ctx.parent,
		Vector3.new(11 * (0.6 + ctx.rng:NextNumber() * 0.4), 0.25, 0.25),
		f(ctx, 0, 3.2, 0) * Kit.angles(0, 0, ctx.rng:NextNumber() * 10 - 5),
		C.iron,
		{ material = Enum.Material.Metal }
	)
end

-- Station props: the few here, and the trees, boundaries, platform and yard (StationDressing).
function StructureKit.prop(kind: string, ctx: Context)
	local builder = Props[kind]
	if builder then
		builder(ctx)
	else
		StationDressing.build(kind, ctx)
	end
end

return StructureKit
