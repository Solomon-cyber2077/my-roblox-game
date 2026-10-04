--!strict
--[[
	Everything that makes a stop a place rather than a plot of ground, built from primitives
	on StructureKit's Context (the frame stands on the ground at the piece's centre; for
	pieces with a length, ctx.width is it, running along the frame's X).

	  Trees        Oak, Pine, Poplar, Birch, DeadTree: trunks you bump into, crowns overhead
	  Boundaries   FencePicket, FenceIron, FenceRail, WallStone, Hedge: one tile long each,
	               the frame's +Z the outside
	  The platform Canopy (iron columns, a slate roof, a fretwork valance along its edge,
	               hanging lanterns and a station clock), PlatformEnd (a railing across the
	               platform's end and the old warning), Trolley, Churns, FireBuckets,
	               Timetable, Planter
	  The yard     Haystack, Cart, Pump, Wheelbarrow, Puddle, Barrels, Bonfire, Graves,
	               MineCart, Swings, Topiary, Well, PillarBox, SignalPost, Scarecrow

	Parts that touch or cross are given distinct planes, so no two visible faces ever share
	one (lune run audit).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Stations = require(Shared.Config.Stations)
local Kit = require(Shared.Visual.Kit)

export type Context = {
	parent: Model,
	base: BasePart,
	frame: CFrame,
	width: number,
	depth: number,
	palette: { ground: Color3, accent: Color3, trim: Color3, light: Color3 },
	rng: Random,
	label: string?,
}

local StationDressing = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local C = {
	bark = rgb(64, 50, 40),
	deadBark = rgb(44, 36, 30),
	birch = rgb(206, 202, 190),
	iron = rgb(36, 38, 42),
	wood = rgb(104, 78, 54),
	woodDark = rgb(70, 50, 36),
	weathered = rgb(126, 112, 96),
	paint = rgb(196, 190, 174),
	stone = rgb(132, 126, 116),
	straw = rgb(190, 160, 92),
	burlap = rgb(150, 124, 86),
	water = rgb(30, 36, 42),
	coal = rgb(30, 29, 28),
	red = rgb(168, 34, 30),
	cream = rgb(232, 224, 200),
	brass = rgb(190, 150, 80),
	galvanised = rgb(150, 156, 160),
	slate = rgb(56, 58, 64),
	glass = rgb(200, 210, 210),
}
-- Leaves at night: muted, dark, a little cold
local FOLIAGE = { rgb(50, 64, 44), rgb(58, 70, 46), rgb(44, 56, 42), rgb(66, 72, 48) }
local PINE = { rgb(36, 52, 40), rgb(42, 58, 44), rgb(32, 48, 38) }

local function f(ctx: Context, x: number, y: number, z: number): CFrame
	return ctx.frame * CFrame.new(x, y, z)
end

local function block(
	ctx: Context,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): BasePart
	return Kit.block(
		ctx.parent,
		size,
		cf,
		color,
		{ material = material or M.SmoothPlastic, collide = collide == true }
	)
end

local function wedge(
	ctx: Context,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return Kit.wedge(ctx.parent, size, cf, color, { material = material or M.SmoothPlastic, collide = false })
end

local function post(
	ctx: Context,
	height: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): BasePart
	return Kit.post(
		ctx.parent,
		height,
		diameter,
		cf,
		color,
		{ material = material, collide = collide == true }
	)
end

local function rod(
	ctx: Context,
	length: number,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
): BasePart
	return Kit.cylinder(
		ctx.parent,
		length,
		diameter,
		cf,
		color,
		{ material = material, collide = collide == true }
	)
end

local function ball(
	ctx: Context,
	diameter: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return Kit.ball(ctx.parent, diameter, cf, color, { material = material, collide = false })
end

-- A member between two points in the piece's frame.
local function member(
	ctx: Context,
	a: Vector3,
	b: Vector3,
	thick: number,
	color: Color3,
	material: Enum.Material?,
	collide: boolean?
)
	block(
		ctx,
		Vector3.new(thick, thick, (b - a).Magnitude),
		ctx.frame * Kit.between(a, b),
		color,
		material,
		collide
	)
end

local function shade(ctx: Context, color: Color3, spread: number): Color3
	return Kit.jitter(color, spread, ctx.rng:NextNumber())
end

local function pick(ctx: Context, list: { Color3 }): Color3
	return shade(ctx, list[ctx.rng:NextInteger(1, #list)], 0.08)
end

local function letter(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Font,
	canvas: Vector2
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = canvas
	gui.LightInfluence = 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.FontFace = font
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui
end

--[[
	A spire that reads as a cone from every side: two thin gables crossed at right angles.
	The second stands a twentieth of a stud higher and each back half is a touch shorter, so
	no two faces ever share a plane.
]]
local function spire(ctx: Context, at: CFrame, height: number, width: number, color: Color3)
	local t = width / 3
	for g = 0, 1 do
		local cf = at * Kit.angles(0, g * 90, 0) * CFrame.new(0, g * 0.05, 0)
		wedge(
			ctx,
			Vector3.new(t, height, width / 2),
			cf * CFrame.new(0, height / 2, -width / 4),
			color,
			M.Grass
		)
		wedge(
			ctx,
			Vector3.new(t, height - 0.05, width / 2),
			cf * CFrame.new(0, (height - 0.05) / 2, width / 4) * Kit.angles(0, 180, 0),
			color,
			M.Grass
		)
	end
end

local Builders: { [string]: (Context) -> () } = {}

-- Trees -------------------------------------------------------------------------------------------

Builders.Oak = function(ctx)
	local rng = ctx.rng
	local h = rng:NextNumber(20, 27)
	local trunkH = h * 0.5
	local r = h * 0.045
	local base = ctx.frame * Kit.angles(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
	local bark = shade(ctx, C.bark, 0.1)
	-- the trunk runs a little into the ground, under its roots
	post(ctx, trunkH + 0.4, r * 2, base * CFrame.new(0, trunkH / 2 - 0.2, 0), bark, M.Wood, true)
	-- roots flaring into the ground
	for k = 0, 3 do
		wedge(
			ctx,
			Vector3.new(0.7, 1.4, 1.4),
			base * Kit.angles(0, k * 90 + 20, 0) * CFrame.new(0, 0.7, -(r + 0.6)),
			bark,
			M.Wood
		)
	end
	for k = 1, 3 do
		local len = h * rng:NextNumber(0.24, 0.34)
		local limb = base
			* CFrame.new(0, trunkH * rng:NextNumber(0.7, 0.95), 0)
			* Kit.angles(0, k * 120 + rng:NextNumber(-20, 20), rng:NextNumber(32, 52))
		block(ctx, Vector3.new(h * 0.04, len, h * 0.04), limb * CFrame.new(0, len / 2, 0), bark, M.Wood)
	end
	local crown = h * 0.5
	local color = pick(ctx, FOLIAGE)
	ball(ctx, crown, base * CFrame.new(0, trunkH + crown * 0.3, 0), color, M.LeafyGrass)
	for k = 1, rng:NextInteger(4, 5) do
		local a = k / 5 * math.pi * 2 + rng:NextNumber(0, 0.8)
		local d = crown * rng:NextNumber(0.6, 0.78)
		ball(
			ctx,
			d,
			base
				* CFrame.new(
					math.cos(a) * crown * 0.36,
					trunkH + crown * rng:NextNumber(0.05, 0.42),
					math.sin(a) * crown * 0.36
				),
			Kit.shade(color, rng:NextNumber(0.86, 1.1)),
			M.LeafyGrass
		)
	end
end

Builders.Pine = function(ctx)
	local rng = ctx.rng
	local h = rng:NextNumber(24, 34)
	local base = ctx.frame * Kit.angles(0, rng:NextNumber(0, 90), 0)
	post(ctx, h * 0.36, h * 0.055, base * CFrame.new(0, h * 0.18, 0), shade(ctx, C.bark, 0.1), M.Wood, true)
	local color = pick(ctx, PINE)
	spire(ctx, base * CFrame.new(0, h * 0.16, 0), h * 0.46, h * 0.42, color)
	spire(
		ctx,
		base * CFrame.new(0, h * 0.4, 0) * Kit.angles(0, 45, 0),
		h * 0.4,
		h * 0.3,
		Kit.shade(color, 1.08)
	)
	spire(ctx, base * CFrame.new(0, h * 0.62, 0), h * 0.36, h * 0.18, Kit.shade(color, 1.14))
end

Builders.Poplar = function(ctx)
	local rng = ctx.rng
	local h = rng:NextNumber(26, 36)
	local base = ctx.frame
	post(ctx, h * 0.3, h * 0.05, base * CFrame.new(0, h * 0.15, 0), shade(ctx, C.bark, 0.1), M.Wood, true)
	local color = pick(ctx, FOLIAGE)
	for i = 0, 3 do
		ball(
			ctx,
			h * (0.26 - i * 0.04),
			base * CFrame.new(0, h * (0.32 + i * 0.17), 0),
			Kit.shade(color, 0.94 + i * 0.05),
			M.LeafyGrass
		)
	end
end

Builders.Birch = function(ctx)
	local rng = ctx.rng
	local h = rng:NextNumber(16, 23)
	local trunk = ctx.frame * Kit.angles(0, 0, rng:NextNumber(-5, 5))
	post(ctx, h * 0.72, h * 0.05, trunk * CFrame.new(0, h * 0.36, 0), C.birch, M.SmoothPlastic, true)
	for i = 1, 3 do
		block(
			ctx,
			Vector3.new(h * 0.056, 0.25, h * 0.056),
			trunk * CFrame.new(0, h * (0.14 + i * 0.15), 0),
			rgb(36, 34, 32)
		)
	end
	local color = Kit.shade(pick(ctx, FOLIAGE), 1.2)
	ball(ctx, h * 0.44, trunk * CFrame.new(0, h * 0.78, 0), color, M.LeafyGrass)
	ball(ctx, h * 0.3, trunk * CFrame.new(h * 0.12, h * 0.62, h * 0.06), Kit.shade(color, 0.9), M.LeafyGrass)
end

-- A gnarled dead tree: a leaning trunk, crooked limbs, twigs like fingers against the moon.
Builders.DeadTree = function(ctx)
	local rng = ctx.rng
	local h = rng:NextNumber(16, 28)
	local color = shade(ctx, C.deadBark, 0.1)
	local trunk = ctx.frame * Kit.angles(rng:NextNumber(-5, 5), 0, rng:NextNumber(-8, 8))
	block(ctx, Vector3.new(h * 0.075, h, h * 0.075), trunk * CFrame.new(0, h / 2, 0), color, M.Wood, true)
	for i = 1, rng:NextInteger(3, 4) do
		local len = h * rng:NextNumber(0.28, 0.48)
		local side = if i % 2 == 0 then 1 else -1
		local limb = trunk
			* CFrame.new(0, h * (0.42 + i * 0.12), 0)
			* Kit.angles(0, rng:NextNumber(0, 360), side * rng:NextNumber(30, 60))
		block(ctx, Vector3.new(h * 0.04, len, h * 0.04), limb * CFrame.new(0, len / 2, 0), color, M.Wood)
		block(
			ctx,
			Vector3.new(h * 0.022, len * 0.5, h * 0.022),
			limb * CFrame.new(0, len * 0.8, 0) * Kit.angles(0, 0, -side * 35) * CFrame.new(0, len * 0.25, 0),
			color,
			M.Wood
		)
	end
end

-- Boundaries -------------------------------------------------------------------------------------------

-- Posts along a run of `length`, never more than `gap` apart. A run's last post is the next
-- run's first, so each run stands its posts from its own start and leaves its end open.
local function stations(length: number, gap: number): { number }
	local n = math.max(1, math.ceil(length / gap))
	local xs: { number } = {}
	for i = 0, n - 1 do
		table.insert(xs, -length / 2 + 0.25 + i * length / n)
	end
	return xs
end

Builders.FencePicket = function(ctx)
	local length = ctx.width
	local white = shade(ctx, C.paint, 0.06)
	local posts = stations(length, 3)
	for _, x in posts do
		block(ctx, Vector3.new(0.32, 3.4, 0.32), f(ctx, x, 1.7, 0), Kit.shade(white, 0.92), M.Wood, true)
	end
	for _, y in { 1.0, 2.6 } do
		block(ctx, Vector3.new(length, 0.24, 0.16), f(ctx, 0, y, 0.25), Kit.shade(white, 0.9), M.Wood, true)
	end
	local x = -length / 2 + 0.6
	while x < length / 2 - 0.4 do
		local nearPost = false
		for _, p in posts do
			if math.abs(p - x) < 0.36 then
				nearPost = true
			end
		end
		-- a few have fallen out; the rest lean a little
		if not nearPost and ctx.rng:NextNumber() > 0.15 then
			local tall = 2.8 + ctx.rng:NextNumber() * 0.25
			block(
				ctx,
				Vector3.new(0.42, tall, 0.1),
				f(ctx, x, tall / 2 + 0.08, 0.38) * Kit.angles(0, 0, ctx.rng:NextNumber(-5, 5)),
				white,
				M.Wood
			)
		end
		x += 0.75
	end
end

Builders.FenceIron = function(ctx)
	local length = ctx.width
	for _, x in stations(length, 4) do
		block(ctx, Vector3.new(0.36, 4.0, 0.36), f(ctx, x, 2.0, 0), C.iron, M.Metal, true)
		ball(ctx, 0.5, f(ctx, x, 4.18, 0), C.iron, M.Metal)
	end
	for _, y in { 0.6, 3.4 } do
		block(ctx, Vector3.new(length, 0.16, 0.16), f(ctx, 0, y, 0.24), C.iron, M.Metal, true)
	end
	local x = -length / 2 + 0.7
	while x < length / 2 - 0.5 do
		if ctx.rng:NextNumber() > 0.08 then
			post(
				ctx,
				3.5,
				0.1,
				f(ctx, x, 1.95, 0.24) * Kit.angles(ctx.rng:NextNumber(-3, 3), 0, ctx.rng:NextNumber(-3, 3)),
				C.iron,
				M.Metal
			)
		end
		x += 1.0
	end
end

Builders.FenceRail = function(ctx)
	local length = ctx.width
	local wood = shade(ctx, C.weathered, 0.1)
	for _, x in stations(length, 4) do
		block(
			ctx,
			Vector3.new(0.5, 3.6, 0.5),
			f(ctx, x, 1.8, 0) * Kit.angles(0, 0, ctx.rng:NextNumber(-3, 3)),
			Kit.shade(wood, 0.9),
			M.Wood,
			true
		)
	end
	for i, y in { 0.9, 2.0, 3.0 } do
		if i == 2 and ctx.rng:NextNumber() < 0.4 then
			-- this rail has broken and sags to the ground
			block(
				ctx,
				Vector3.new(length * 0.5, 0.3, 0.2),
				f(ctx, -length * 0.25, y - 0.5, 0.58) * Kit.angles(0, 0, -8),
				wood,
				M.Wood,
				true
			)
		else
			block(ctx, Vector3.new(length, 0.3, 0.22), f(ctx, 0, y, 0.37), wood, M.Wood, true)
		end
	end
end

-- A dry-stone wall: two courses of uneven stones and a line of copes.
Builders.WallStone = function(ctx)
	local length = ctx.width
	local courses = {
		{ y0 = 0, h = 1.2, depth = 1.6 },
		{ y0 = 1.2, h = 1.05, depth = 1.42 },
	}
	for c, course in courses do
		local x = -length / 2
		local first = true
		while x < length / 2 - 0.05 do
			local long = math.min(ctx.rng:NextNumber(1.8, 3.2), length / 2 - x)
			if first and c == 2 then
				long = math.min(long * 0.5, length / 2 - x)
			end
			first = false
			block(
				ctx,
				Vector3.new(long - 0.04, course.h, course.depth + ctx.rng:NextNumber(-0.04, 0.04)),
				f(ctx, x + long / 2, course.y0 + course.h / 2, 0),
				shade(ctx, C.stone, 0.1),
				M.Slate,
				true
			)
			x += long
		end
	end
	block(
		ctx,
		Vector3.new(length, 0.42, 1.7),
		f(ctx, 0, 2.46, 0),
		shade(ctx, C.stone, 0.06),
		M.Concrete,
		true
	)
end

Builders.Hedge = function(ctx)
	local length = ctx.width
	local green = pick(ctx, FOLIAGE)
	block(ctx, Vector3.new(length, 3.8, 2.2), f(ctx, 0, 1.9, 0), green, M.LeafyGrass, true)
	for i = 1, 3 do
		ball(
			ctx,
			2.2 + ctx.rng:NextNumber() * 0.6,
			f(ctx, -length / 2 + length * (i - 0.5) / 3, 3.7, ctx.rng:NextNumber(-0.3, 0.3)),
			Kit.shade(green, 1.06),
			M.LeafyGrass
		)
	end
end

-- The platform ------------------------------------------------------------------------------------------

--[[
	The canopy over the middle of the platform. Its frame is the station's own (x along the
	platform, z from the edge), ctx.width its span. Iron columns at the back carry a beam and a
	slate roof that falls toward the track; a fretwork valance of wooden teeth hangs along its
	front edge; lanterns hang between the columns and the station clock in the middle.
]]
Builders.Canopy = function(ctx)
	local span = ctx.width
	local half = span / 2
	local z = Stations.CanopyColumnZ
	local backZ, frontZ = z + 2.1, 2.2
	local backY, frontY = 14.2, 12.6
	local function roofY(atZ: number): number
		return frontY + (atZ - frontZ) / (backZ - frontZ) * (backY - frontY)
	end
	local columns = Stations.canopyColumns(half)
	for _, x in columns do
		block(ctx, Vector3.new(1.4, 0.8, 1.4), f(ctx, x, 0.4, z), C.iron, M.Metal, true)
		post(ctx, 11.6, 0.8, f(ctx, x, 6.6, z), C.iron, M.Metal, true)
		post(ctx, 0.6, 1.4, f(ctx, x, 12.7, z), C.iron, M.Metal)
		-- brackets up into the roof, either way
		member(ctx, Vector3.new(x, 10.2, z), Vector3.new(x, roofY(z - 6) - 0.5, z - 6), 0.32, C.iron, M.Metal)
		member(ctx, Vector3.new(x, 11.2, z), Vector3.new(x - 3.5, roofY(z) - 0.4, z), 0.28, C.iron, M.Metal)
		member(ctx, Vector3.new(x, 11.2, z), Vector3.new(x + 3.5, roofY(z) - 0.4, z), 0.28, C.iron, M.Metal)
	end
	block(ctx, Vector3.new(span, 1.0, 1.2), f(ctx, 0, 13.5, z), C.iron, M.Metal)
	-- rafters under the slates, every twelve studs
	local rafters = math.floor(span / 12)
	for i = 0, rafters do
		local x = -half + 0.6 + i * (span - 1.2) / rafters
		member(
			ctx,
			Vector3.new(x, backY - 0.55, backZ - 0.3),
			Vector3.new(x, frontY - 0.55, frontZ + 0.3),
			0.5,
			C.woodDark,
			M.Wood
		)
	end
	local roof = block(
		ctx,
		Vector3.new(span + 2, 0.45, (Vector3.new(0, backY, backZ) - Vector3.new(0, frontY, frontZ)).Magnitude),
		ctx.frame * Kit.between(Vector3.new(0, backY, backZ), Vector3.new(0, frontY, frontZ)),
		C.slate,
		M.Slate
	)
	roof.Name = "CanopyRoof"
	block(
		ctx,
		Vector3.new(span + 2, 0.9, 0.25),
		f(ctx, 0, frontY - 0.25, frontZ - 0.15),
		ctx.palette.accent,
		M.Wood
	)
	-- the valance: a row of pointed boards painted on an invisible board along the front edge
	local valance =
		block(ctx, Vector3.new(span + 2, 1.6, 0.06), f(ctx, 0, frontY - 1.4, frontZ - 0.3), C.cream)
	valance.Transparency = 1
	valance.Name = "Valance"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 1
		gui.Parent = valance
		local band = Instance.new("Frame")
		band.BorderSizePixel = 0
		band.BackgroundColor3 = ctx.palette.accent
		band.Size = UDim2.fromScale(1, 0.42)
		band.Parent = gui
		local teeth = math.floor((span + 2) / 1.6)
		for k = 0, teeth - 1 do
			local tooth = Instance.new("Frame")
			tooth.BorderSizePixel = 0
			tooth.BackgroundColor3 = ctx.palette.accent
			tooth.AnchorPoint = Vector2.new(0.5, 0.5)
			tooth.Size = UDim2.fromOffset(22, 22)
			tooth.Position = UDim2.new(0, 32 * k + 16, 0.42, 0)
			tooth.Rotation = 45
			tooth.Parent = gui
		end
	end
	-- lanterns hung between the columns, and over the middle
	table.sort(columns)
	local spots: { number } = { 0 }
	for i = 1, #columns - 1 do
		local mid = (columns[i] + columns[i + 1]) / 2
		if math.abs(mid) > 4 then
			table.insert(spots, mid)
		end
	end
	for _, x in spots do
		local lz = 11
		local top = roofY(lz) - 0.3
		post(ctx, top - 11.6, 0.08, f(ctx, x, (top + 11.6) / 2, lz), C.iron, M.Metal)
		post(ctx, 0.3, 0.9, f(ctx, x, 11.45, lz), C.iron, M.Metal)
		Kit.post(
			ctx.parent,
			1.1,
			0.78,
			f(ctx, x, 10.75, lz),
			C.glass,
			{ material = M.Glass, transparency = 0.45, collide = false, shadow = false }
		)
		local flame = Kit.neon(
			ctx.parent,
			Vector3.one * 0.36,
			f(ctx, x, 10.7, lz),
			ctx.palette.light,
			Enum.PartType.Ball
		)
		Kit.pointLight(flame, ctx.palette.light, 1.15, 24, false)
		post(ctx, 0.2, 0.84, f(ctx, x, 10.1, lz), C.iron, M.Metal)
	end
	-- the station clock, double-faced, hung from the roof over the middle of the platform
	local cz = 7.5
	local hangTop = roofY(cz) - 0.3
	post(ctx, hangTop - 11.4, 0.18, f(ctx, 0, (hangTop + 11.4) / 2, cz), C.iron, M.Metal)
	local drum = f(ctx, 0, 10.0, cz) * Kit.angles(0, 90, 0)
	rod(ctx, 0.5, 2.6, drum, C.iron, M.Metal)
	rod(ctx, 0.4, 2.76, drum, C.brass, M.Metal)
	for _, side in { -1, 1 } do
		rod(ctx, 0.04, 2.2, drum * CFrame.new(side * 0.27, 0, 0), C.cream, M.SmoothPlastic)
		local face = drum * CFrame.new(side * 0.3, 0, 0)
		block(
			ctx,
			Vector3.new(0.02, 0.85, 0.09),
			face * CFrame.Angles(math.rad(-60), 0, 0) * CFrame.new(0, 0.42, 0),
			C.coal
		)
		block(
			ctx,
			Vector3.new(0.02, 0.6, 0.11),
			face * CFrame.Angles(math.rad(150), 0, 0) * CFrame.new(0, 0.3, 0),
			C.coal
		)
	end
end

-- The end of the platform: an iron railing across it, a red lamp, and the old warning.
Builders.PlatformEnd = function(ctx)
	local length = ctx.width
	local n = math.max(2, math.ceil(length / 2.8))
	for i = 0, n do
		local z = -length / 2 + i * length / n
		block(ctx, Vector3.new(0.32, 3.6, 0.32), f(ctx, 0, 1.8, z), C.iron, M.Metal, true)
	end
	for _, y in { 1.9, 3.45 } do
		block(ctx, Vector3.new(0.2, 0.2, length), f(ctx, 0.27, y, 0), C.iron, M.Metal, true)
	end
	-- the warning, facing back along the platform
	for _, dz in { -1.4, 1.4 } do
		post(ctx, 5.2, 0.22, f(ctx, -1.3, 2.6, 5 + dz), C.iron, M.Metal, true)
	end
	local board = block(ctx, Vector3.new(0.14, 1.9, 3.6), f(ctx, -1.48, 4.4, 5), C.cream, M.SmoothPlastic)
	letter(
		board,
		Enum.NormalId.Left,
		"PASSENGERS MUST NOT CROSS THE LINE",
		rgb(150, 30, 28),
		Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold),
		Vector2.new(360, 190)
	)
	post(ctx, 3.2, 0.3, f(ctx, -0.8, 1.6, -length / 2 + 1.6), C.iron, M.Metal, true)
	Kit.neon(ctx.parent, Vector3.new(0.5, 0.7, 0.5), f(ctx, -0.8, 3.55, -length / 2 + 1.6), rgb(200, 40, 34))
end

Builders.Trolley = function(ctx)
	local wood = shade(ctx, C.wood, 0.08)
	block(ctx, Vector3.new(5.6, 0.3, 2.6), f(ctx, 0, 1.6, 0), wood, M.WoodPlanks, true)
	for _, z in { -1.2, 1.2 } do
		block(ctx, Vector3.new(5.8, 0.24, 0.24), f(ctx, 0, 1.33, z), C.iron, M.Metal)
	end
	for _, z in { -1.45, 1.45 } do
		rod(ctx, 0.25, 2.2, f(ctx, 0.9, 1.1, z) * Kit.angles(0, 90, 0), C.iron, M.Metal)
		post(ctx, 1.25, 0.24, f(ctx, -2.3, 0.625, z * 0.8), C.iron, M.Metal)
	end
	for _, z in { -1.1, 1.1 } do
		member(ctx, Vector3.new(-2.8, 1.75, z), Vector3.new(-3.6, 3.6, z), 0.18, C.iron, M.Metal)
	end
	block(ctx, Vector3.new(0.18, 0.18, 2.4), f(ctx, -3.6, 3.6, 0), C.iron, M.Metal)
	-- trunks and a hatbox nobody came back for
	block(ctx, Vector3.new(2.6, 1.3, 1.8), f(ctx, 1.2, 2.4, 0.1), rgb(92, 56, 40), M.Leather, true)
	block(ctx, Vector3.new(2.7, 0.14, 1.9), f(ctx, 1.2, 2.8, 0.1), C.brass, M.Metal)
	block(ctx, Vector3.new(1.8, 0.9, 1.4), f(ctx, -0.9, 2.2, -0.3), rgb(70, 66, 58), M.Leather, true)
	post(ctx, 0.7, 1.1, f(ctx, 1.0, 3.4, 0.3), rgb(126, 96, 74), M.Fabric)
end

Builders.Churns = function(ctx)
	for i = 1, ctx.rng:NextInteger(3, 4) do
		local x = (i - 2.5) * 1.45 + ctx.rng:NextNumber(-0.15, 0.15)
		local z = (i % 2) * 0.6 - 0.3
		local grey = shade(ctx, C.galvanised, 0.08)
		post(ctx, 2.4, 1.3, f(ctx, x, 1.2, z), grey, M.Metal, true)
		post(ctx, 0.36, 1.0, f(ctx, x, 2.58, z), grey, M.Metal)
		post(ctx, 0.42, 0.62, f(ctx, x, 2.97, z), grey, M.Metal)
		post(ctx, 0.14, 0.8, f(ctx, x, 3.25, z), Kit.shade(grey, 0.85), M.Metal)
	end
end

Builders.FireBuckets = function(ctx)
	for _, x in { -1.8, 1.8 } do
		block(ctx, Vector3.new(0.3, 3.6, 0.32), f(ctx, x, 1.8, 0), C.red, M.Metal, true)
	end
	local bar = block(ctx, Vector3.new(4.0, 0.5, 0.25), f(ctx, 0, 3.5, 0), C.red, M.Metal)
	letter(
		bar,
		Enum.NormalId.Front,
		"FIRE",
		C.cream,
		Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold),
		Vector2.new(400, 50)
	)
	for _, x in { -1.1, 0, 1.1 } do
		post(ctx, 0.6, 0.06, f(ctx, x, 3.0, -0.3), C.iron, M.Metal)
		post(ctx, 0.95, 0.85, f(ctx, x, 2.2, -0.3), C.red, M.Metal)
	end
end

-- The timetable board: every service on it cancelled, and a poster pinned over the corner.
Builders.Timetable = function(ctx)
	for _, x in { -1.9, 1.9 } do
		post(ctx, 5.6, 0.26, f(ctx, x, 2.8, 0.1), C.woodDark, M.Wood, true)
	end
	block(ctx, Vector3.new(4.4, 3.2, 0.2), f(ctx, 0, 4.2, 0.1), C.woodDark, M.Wood)
	local sheet = block(ctx, Vector3.new(4.0, 2.8, 0.06), f(ctx, 0, 4.2, -0.03), C.cream)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 280)
	gui.LightInfluence = 1
	gui.Parent = sheet
	local lines = {
		"LAST TRAIN OUT  ·  NIGHT SERVICE",
		"DEPARTS          FOR            ",
		"18.20  Coaling Yard     CANCELLED",
		"19.05  Ashgrove         CANCELLED",
		"20.40  Brannoc          CANCELLED",
		"22.15  Gallowmere       CANCELLED",
		"02.00  ------------     DO NOT WAIT",
		"06.30  The Terminus     ON TIME",
	}
	for i, text in lines do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0.05, 0, 0, 14 + (i - 1) * 32)
		label.Size = UDim2.new(0.9, 0, 0, 26)
		label.FontFace = Font.new("rbxasset://fonts/families/SpecialElite.json")
		label.Text = text
		label.TextColor3 = if i == 1 then rgb(120, 26, 24) else rgb(40, 36, 34)
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = gui
	end
	local poster = block(
		ctx,
		Vector3.new(1.3, 1.7, 0.04),
		f(ctx, 1.45, 4.8, -0.08) * Kit.angles(0, 0, -7),
		rgb(214, 200, 168)
	)
	letter(
		poster,
		Enum.NormalId.Front,
		"HAVE YOU SEEN TOM?",
		rgb(44, 52, 92),
		Font.new("rbxasset://fonts/families/Kalam.json", Enum.FontWeight.Bold),
		Vector2.new(130, 170)
	)
end

-- A stone trough of flowers long dead.
Builders.Planter = function(ctx)
	block(ctx, Vector3.new(3.6, 1.2, 1.6), f(ctx, 0, 0.6, 0), shade(ctx, C.stone, 0.06), M.Concrete, true)
	block(ctx, Vector3.new(3.2, 0.1, 1.2), f(ctx, 0, 1.25, 0), rgb(44, 34, 28), M.Ground)
	for i = 1, 6 do
		local x = -1.3 + (i - 1) * 0.52
		local z = ctx.rng:NextNumber(-0.35, 0.35)
		local stem = f(ctx, x, 1.3, z)
			* Kit.angles(ctx.rng:NextNumber(-25, 25), 0, ctx.rng:NextNumber(-30, 30))
		block(ctx, Vector3.new(0.06, 1.2, 0.06), stem * CFrame.new(0, 0.6, 0), rgb(70, 66, 44))
		ball(ctx, 0.28, stem * CFrame.new(0, 1.15, 0), rgb(110, 44, 58), M.Fabric)
	end
end

-- The yard ------------------------------------------------------------------------------------------------

Builders.Haystack = function(ctx)
	local straw = shade(ctx, C.straw, 0.08)
	post(ctx, 3.2, 5.6, f(ctx, 0, 1.6, 0), straw, M.Grass, true)
	ball(ctx, 5.8, f(ctx, 0, 3.15, 0), Kit.shade(straw, 1.06), M.Grass)
	-- a pitchfork left leaning on it
	local fork = f(ctx, 2.4, 0, 1.2) * Kit.angles(0, 30, -22)
	block(ctx, Vector3.new(0.14, 5.0, 0.14), fork * CFrame.new(0, 2.5, 0), C.woodDark, M.Wood)
	for k = -1, 1 do
		block(ctx, Vector3.new(0.06, 0.8, 0.06), fork * CFrame.new(k * 0.18, 5.35, 0), C.iron, M.Metal)
	end
end

Builders.Cart = function(ctx)
	local wood = shade(ctx, C.weathered, 0.08)
	block(ctx, Vector3.new(6.4, 0.4, 3.6), f(ctx, 0, 2.6, 0), wood, M.WoodPlanks, true)
	for _, z in { -1.68, 1.68 } do
		block(ctx, Vector3.new(6.4, 1.1, 0.24), f(ctx, 0, 3.35, z), Kit.shade(wood, 0.92), M.WoodPlanks, true)
	end
	block(
		ctx,
		Vector3.new(0.24, 1.1, 3.12),
		f(ctx, -3.08, 3.35, 0),
		Kit.shade(wood, 0.92),
		M.WoodPlanks,
		true
	)
	for _, z in { -2.05, 2.05 } do
		rod(ctx, 0.36, 4.0, f(ctx, 0.6, 2.0, z) * Kit.angles(0, 90, 0), C.woodDark, M.Wood, true)
		rod(ctx, 0.5, 0.7, f(ctx, 0.6, 2.0, z) * Kit.angles(0, 90, 0), C.iron, M.Metal)
	end
	rod(ctx, 4.5, 0.3, f(ctx, 0.6, 2.0, 0) * Kit.angles(0, 90, 0), C.iron, M.Metal)
	-- the shafts rest on the ground where the horse once stood
	for _, z in { -1.0, 1.0 } do
		member(ctx, Vector3.new(3.1, 2.4, z), Vector3.new(7.6, 0.2, z), 0.25, C.woodDark, M.Wood)
	end
	ball(ctx, 1.3, f(ctx, -1.4, 3.4, -0.6), C.burlap, M.Fabric)
	ball(ctx, 1.1, f(ctx, -0.2, 3.3, 0.7), Kit.shade(C.burlap, 0.9), M.Fabric)
end

Builders.Pump = function(ctx)
	block(ctx, Vector3.new(3.6, 1.4, 1.8), f(ctx, 0, 0.7, 1.0), shade(ctx, C.stone, 0.06), M.Concrete, true)
	block(ctx, Vector3.new(3.2, 0.1, 1.4), f(ctx, 0, 1.32, 1.0), C.water, M.Glass).Reflectance = 0.2
	post(ctx, 4.4, 0.8, f(ctx, 0, 2.2, -0.4), C.iron, M.Metal, true)
	ball(ctx, 0.9, f(ctx, 0, 4.45, -0.4), C.iron, M.Metal)
	block(ctx, Vector3.new(0.25, 0.25, 1.1), f(ctx, 0, 3.0, 0.4), C.iron, M.Metal)
	member(ctx, Vector3.new(0, 4.2, -0.6), Vector3.new(0, 5.0, -2.8), 0.2, C.iron, M.Metal)
end

Builders.Wheelbarrow = function(ctx)
	local tray = shade(ctx, rgb(96, 72, 50), 0.08)
	block(ctx, Vector3.new(2.6, 0.8, 1.8), f(ctx, 0, 1.4, 0), tray, M.WoodPlanks, true)
	wedge(ctx, Vector3.new(1.8, 0.8, 0.9), f(ctx, 1.75, 1.4, 0) * Kit.angles(0, -90, 0), tray, M.WoodPlanks)
	rod(ctx, 0.3, 1.2, f(ctx, 2.0, 0.6, 0) * Kit.angles(0, 90, 0), C.iron, M.Metal)
	for _, z in { -0.7, 0.7 } do
		member(ctx, Vector3.new(1.9, 0.8, z), Vector3.new(-2.6, 1.6, z * 1.1), 0.16, C.woodDark, M.Wood)
		block(ctx, Vector3.new(0.14, 1.0, 0.14), f(ctx, -1.0, 0.5, z), C.woodDark, M.Wood)
	end
	ball(ctx, 0.8, f(ctx, -0.3, 2.0, 0.1), C.coal, M.Slate)
end

-- Standing water, black and still, catching the moon.
Builders.Puddle = function(ctx)
	for i = 1, ctx.rng:NextInteger(2, 3) do
		local thick = 0.04 + i * 0.012
		local part = post(
			ctx,
			thick,
			ctx.rng:NextNumber(3, 7),
			f(ctx, ctx.rng:NextNumber(-1.5, 1.5), i * 0.004 + thick / 2, ctx.rng:NextNumber(-1.5, 1.5)),
			C.water,
			M.SmoothPlastic
		)
		part.Reflectance = 0.28
	end
end

Builders.Barrels = function(ctx)
	for i = 1, 3 do
		local wood = shade(ctx, rgb(108, 74, 46), 0.1)
		if i == 3 then
			-- one on its side, rolled away
			local at = f(ctx, 1.4, 1.0, 2.0) * Kit.angles(0, ctx.rng:NextNumber(0, 60), 0)
			rod(ctx, 2.8, 2.0, at, wood, M.Wood, true)
			for _, dx in { -0.9, 0.9 } do
				rod(ctx, 0.18, 2.08, at * CFrame.new(dx, 0, 0), C.iron, M.Metal)
			end
		else
			local x = (i - 1.5) * 2.2
			post(ctx, 2.8, 2.0, f(ctx, x, 1.4, 0), wood, M.Wood, true)
			for _, y in { 0.6, 2.2 } do
				post(ctx, 0.18, 2.08, f(ctx, x, y, 0), C.iron, M.Metal)
			end
		end
	end
end

-- A dead fire: a ring of stones, charred logs, ash, and one ember that will not go out.
Builders.Bonfire = function(ctx)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		ball(
			ctx,
			0.8 + ctx.rng:NextNumber() * 0.3,
			f(ctx, math.cos(a) * 1.7, 0.25, math.sin(a) * 1.7),
			shade(ctx, C.stone, 0.1),
			M.Slate
		)
	end
	post(ctx, 0.06, 2.8, f(ctx, 0, 0.03, 0), rgb(54, 50, 48), M.Ground)
	for k = 0, 2 do
		rod(
			ctx,
			2.6,
			0.4,
			f(ctx, 0, 0.32 + k * 0.08, 0) * Kit.angles(0, k * 60, 0) * Kit.angles(0, 0, 8),
			rgb(26, 22, 20),
			M.Wood
		)
	end
	Kit.neon(ctx.parent, Vector3.one * 0.25, f(ctx, 0.2, 0.4, 0.1), rgb(255, 110, 40), Enum.PartType.Ball)
end

Builders.Graves = function(ctx)
	for i = 1, 4 do
		local x = (i - 2.5) * 2.4
		local tall = 2.0 + ctx.rng:NextNumber() * 1.0
		local stone = shade(ctx, C.stone, 0.12)
		local at = f(ctx, x, 0, ctx.rng:NextNumber(-0.4, 0.4))
			* Kit.angles(ctx.rng:NextNumber(-8, 8), ctx.rng:NextNumber(-10, 10), ctx.rng:NextNumber(-6, 6))
		block(ctx, Vector3.new(1.6, tall, 0.35), at * CFrame.new(0, tall / 2, 0), stone, M.Slate, true)
		rod(ctx, 0.3, 1.6, at * CFrame.new(0, tall, 0) * Kit.angles(0, 90, 0), stone, M.Slate)
		-- the mound in front, sunk into the ground
		ball(ctx, 2.6, at * CFrame.new(0, -0.85, -1.6), rgb(54, 46, 38), M.Ground)
	end
	block(
		ctx,
		Vector3.new(0.4, 3.6, 0.4),
		f(ctx, 5.0, 1.8, 1.2) * Kit.angles(0, 0, 6),
		C.stone,
		M.Slate,
		true
	)
	block(ctx, Vector3.new(1.8, 0.4, 0.32), f(ctx, 5.12, 2.8, 1.2) * Kit.angles(0, 0, 6), C.stone, M.Slate)
end

Builders.MineCart = function(ctx)
	for _, z in { -1.1, 1.1 } do
		block(ctx, Vector3.new(9, 0.3, 0.24), f(ctx, 0, 0.45, z), C.iron, M.Metal)
	end
	for k = -2, 2 do
		block(ctx, Vector3.new(0.8, 0.3, 3.0), f(ctx, k * 2, 0.15, 0), C.woodDark, M.Wood)
	end
	local rust = shade(ctx, rgb(116, 70, 44), 0.08)
	block(ctx, Vector3.new(3.2, 1.7, 2.1), f(ctx, 0.6, 1.95, 0), rust, M.CorrodedMetal, true)
	for _, dx in { -0.4, 1.6 } do
		for _, z in { -1.1, 1.1 } do
			rod(ctx, 0.2, 0.9, f(ctx, dx, 0.95, z) * Kit.angles(0, 90, 0), C.iron, M.Metal)
		end
	end
	for k = 1, 3 do
		ball(ctx, 1.0, f(ctx, -0.2 + k * 0.5, 2.85, (k % 2) * 0.4 - 0.2), C.coal, M.Slate)
	end
end

-- A swing frame in a yard where nobody plays; one swing still moving.
Builders.Swings = function(ctx)
	for _, x in { -3.4, 3.4 } do
		for _, z in { -1.6, 1.6 } do
			-- the two legs of each A differ a hair, so where they meet no faces coincide
			local thick = if z > 0 then 0.32 else 0.28
			member(ctx, Vector3.new(x, 0, z), Vector3.new(x, 8.0, 0), thick, C.iron, M.Metal, true)
		end
	end
	block(ctx, Vector3.new(7.2, 0.3, 0.3), f(ctx, 0, 8.1, 0), C.iron, M.Metal)
	for i, x in { -1.6, 1.6 } do
		local swing = f(ctx, x, 8.0, 0) * Kit.angles(if i == 2 then 22 else 0, 0, 0)
		for _, dx in { -0.65, 0.65 } do
			block(ctx, Vector3.new(0.05, 6.2, 0.05), swing * CFrame.new(dx, -3.1, 0), C.iron, M.Metal)
		end
		block(ctx, Vector3.new(1.5, 0.16, 0.7), swing * CFrame.new(0, -6.25, 0), C.woodDark, M.Wood)
	end
end

Builders.Topiary = function(ctx)
	block(ctx, Vector3.new(2.2, 2.0, 2.2), f(ctx, 0, 1.0, 0), shade(ctx, C.stone, 0.05), M.Concrete, true)
	local green = pick(ctx, FOLIAGE)
	ball(ctx, 3.2, f(ctx, 0, 3.4, 0), green, M.LeafyGrass)
	ball(ctx, 1.9, f(ctx, 0, 5.3, 0), Kit.shade(green, 1.06), M.LeafyGrass)
end

Builders.Well = function(ctx)
	local stone = shade(ctx, C.stone, 0.08)
	post(ctx, 2.4, 4.6, f(ctx, 0, 1.2, 0), stone, M.Slate, true)
	post(ctx, 0.04, 3.6, f(ctx, 0, 2.42, 0), C.water, M.SmoothPlastic).Reflectance = 0.3
	for _, x in { -2.5, 2.5 } do
		block(ctx, Vector3.new(0.4, 6.2, 0.4), f(ctx, x, 3.1, 0), C.woodDark, M.Wood, true)
	end
	Kit.wedge(
		ctx.parent,
		Vector3.new(6.2, 1.4, 1.8),
		f(ctx, 0, 6.9, -0.9),
		C.slate,
		{ material = M.Slate, collide = false }
	)
	Kit.wedge(
		ctx.parent,
		Vector3.new(6.2, 1.38, 1.8),
		f(ctx, 0, 6.89, 0.9) * Kit.angles(0, 180, 0),
		C.slate,
		{ material = M.Slate, collide = false }
	)
	rod(ctx, 4.6, 0.5, f(ctx, 0, 4.4, 0), C.wood, M.Wood)
	block(ctx, Vector3.new(0.06, 1.6, 0.06), f(ctx, 0.4, 3.6, 0), C.burlap, M.Fabric)
	post(ctx, 0.7, 0.7, f(ctx, 0.4, 2.8, 0.1), C.woodDark, M.Wood)
end

Builders.PillarBox = function(ctx)
	post(ctx, 4.0, 1.7, f(ctx, 0, 2.0, 0), C.red, M.Metal, true)
	post(ctx, 0.4, 2.0, f(ctx, 0, 4.2, 0), C.red, M.Metal)
	ball(ctx, 1.9, f(ctx, 0, 4.42, 0), C.red, M.Metal)
	block(ctx, Vector3.new(0.9, 0.12, 0.2), f(ctx, 0, 3.4, -0.82), C.coal)
	block(ctx, Vector3.new(0.6, 0.6, 0.06), f(ctx, 0, 2.6, -0.86), C.cream)
end

-- A semaphore signal, its arm stuck at danger.
Builders.SignalPost = function(ctx)
	block(ctx, Vector3.new(1.4, 0.8, 1.4), f(ctx, 0, 0.4, 0), C.stone, M.Concrete, true)
	post(ctx, 17, 0.6, f(ctx, 0, 9.3, 0), C.cream, M.Wood, true)
	ball(ctx, 0.8, f(ctx, 0, 18.1, 0), C.iron, M.Metal)
	local arm = block(ctx, Vector3.new(3.8, 0.7, 0.15), f(ctx, 2.1, 15.5, -0.4), C.red, M.Wood)
	arm.Name = "SignalArm"
	block(ctx, Vector3.new(0.4, 0.72, 0.2), f(ctx, 3.3, 15.5, -0.4), C.cream, M.Wood)
	block(ctx, Vector3.new(0.9, 1.4, 0.14), f(ctx, 0.2, 15.2, -0.5), C.iron, M.Metal)
	Kit.neon(ctx.parent, Vector3.new(0.4, 0.4, 0.06), f(ctx, 0.2, 15.5, -0.58), rgb(200, 40, 34))
	-- the ladder up the post
	for _, x in { -0.35, 0.35 } do
		block(ctx, Vector3.new(0.1, 14, 0.1), f(ctx, x, 7.4, 0.55), C.iron, M.Metal)
	end
	for y = 1.5, 14, 1.25 do
		block(ctx, Vector3.new(0.8, 0.08, 0.08), f(ctx, 0, y, 0.55), C.iron, M.Metal)
	end
end

Builders.Scarecrow = function(ctx)
	post(ctx, 6.4, 0.3, f(ctx, 0, 3.2, 0), C.woodDark, M.Wood, true)
	block(ctx, Vector3.new(4.2, 0.25, 0.25), f(ctx, 0, 4.6, 0), C.woodDark, M.Wood)
	local coat = shade(ctx, rgb(70, 62, 52), 0.1)
	block(ctx, Vector3.new(2.0, 2.6, 0.7), f(ctx, 0, 3.6, 0), coat, M.Fabric)
	for _, s in { -1, 1 } do
		block(ctx, Vector3.new(1.6, 0.5, 0.5), f(ctx, s * 1.5, 4.55, 0), coat, M.Fabric)
		wedge(
			ctx,
			Vector3.new(0.4, 0.7, 0.44),
			f(ctx, s * 2.3, 4.25, 0) * Kit.angles(0, 0, s * 20),
			C.straw,
			M.Grass
		)
	end
	ball(ctx, 1.3, f(ctx, 0, 5.75, 0), C.burlap, M.Fabric)
	for _, x in { -0.22, 0.22 } do
		block(ctx, Vector3.new(0.18, 0.1, 0.05), f(ctx, x, 5.85, -0.63), C.coal)
	end
	block(ctx, Vector3.new(0.5, 0.06, 0.05), f(ctx, 0, 5.5, -0.63), C.coal)
	post(ctx, 0.08, 1.9, f(ctx, 0, 6.42, 0), C.coal, M.Fabric)
	post(ctx, 0.75, 1.0, f(ctx, 0, 6.82, 0), C.coal, M.Fabric)
end

-- Builds `kind` if it is one of these; false otherwise.
function StationDressing.build(kind: string, ctx: Context): boolean
	local builder = Builders[kind]
	if builder == nil then
		return false
	end
	builder(ctx)
	return true
end

return StationDressing
