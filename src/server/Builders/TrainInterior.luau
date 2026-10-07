--!strict
--[[
	What makes the train a place to ride in: TrainBuilder puts up the shell (walls,
	linings, windows, ceilings, racks), this furnishes it, in the same train space (x along
	the track, +X the locomotive, y = 0 the floor, +Z the platform side).

	  Crew saloon  bays of facing velvet window seats (one each, every one sittable)
	               round wall tables with lamps, paintings of the
	               line on the end walls
	  Guard's van  a pot-bellied stove, a wing chair on a rug, the guard's
	               cat asleep on a cushion, a bunk, the guard's desk and lamp, a lantern
	  Workshop     a lathe, a stool at the
	               bench and a lamp over it
	  Footplate    the furnace: a firebox front with its fire-hole doors swung open on the
	               fire, flames and sparks, the gauges, water glasses, regulator and
	               reverser, the crew's seats, spilt coal and a shovel

	Every door has an enamel sign over it saying where it leads, as exit signs do, and every
	car hangs its own name from the ceiling; outside, each car carries its name on a board
	along the cant rail and the engine carries hers on a brass plate.

	Seats are Seat parts (Kit.seat) that TrainService puts a Sit prompt on. Parts that
	touch or cross are given distinct planes, so no two visible faces ever share one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)

export type Dims = {
	lineIn: number, -- inner face of the side linings (|z|)
	ceiling: number, -- underside of the ceiling lining
	doorTop: number,
	sideDoorTop: number, -- head of the carriages' sliding doors
}

export type Furnished = {
	seats: { Seat },
}

local TrainInterior = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local C = {
	woodDark = rgb(74, 46, 30),
	wood = rgb(110, 76, 50),
	polish = rgb(96, 58, 36),
	velvet = rgb(122, 38, 40),
	velvetGreen = rgb(54, 86, 66),
	lace = rgb(236, 230, 214),
	brass = rgb(201, 160, 82),
	iron = rgb(44, 44, 48),
	ironLight = rgb(70, 70, 74),
	shade = rgb(226, 196, 140),
	warm = rgb(255, 206, 150),
	fire = rgb(255, 120, 40),
	ember = rgb(255, 170, 70),
	coal = rgb(28, 27, 26),
	enamel = rgb(30, 66, 48),
	cream = rgb(238, 230, 206),
	gilt = rgb(218, 180, 100),
	board = rgb(30, 28, 28),
	leather = rgb(96, 58, 40),
	copper = rgb(176, 102, 62),
	brick = rgb(128, 52, 40),
	rug = rgb(120, 36, 34),
	rugGold = rgb(176, 132, 62),
	ginger = rgb(198, 122, 62),
	gingerDark = rgb(146, 82, 40),
	navy = rgb(36, 42, 64),
}

local SIGN_FONT = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold)
local BOARD_FONT = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local PLATE_FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)

-- Lettering on one face of a part.
local function letter(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	font: Font,
	canvas: Vector2,
	light: number
)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = canvas
	gui.LightInfluence = light
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.74)
	label.Position = UDim2.fromScale(0.05, 0.13)
	label.FontFace = font
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui
end

-- A little oil painting of the line, laid out on a 240 x 180 grid and drawn at PAINT_SCALE: a
-- three-tone sky with streaked clouds and stars (or a skein of birds), the sun or a cratered moon
-- in its halo, two ranges of peaks (the far one snow-capped, the near one lit along a flank), a
-- lake with the orb's light broken on it, a stone viaduct with a train crossing it under its own
-- smoke, and in front pines, a semaphore signal and telegraph poles strung with sagging wires,
-- all under a warm varnish that darkens to the edges. Returns the painting's title.
local PAINT_SCALE = 2
local PAINTINGS = {
	{
		title = "DUSK AT THE VIADUCT",
		top = rgb(78, 48, 92),
		mid = rgb(226, 116, 78),
		horizon = rgb(252, 198, 124),
		peaks = rgb(116, 66, 90),
		land = rgb(32, 22, 30),
		water = rgb(140, 76, 88),
		orb = rgb(255, 224, 156),
		orbY = 96,
		orbSize = 28,
		moon = false,
		lamps = true,
	},
	{
		title = "THE HIGH LINE AT NOON",
		top = rgb(78, 132, 178),
		mid = rgb(150, 192, 214),
		horizon = rgb(240, 226, 192),
		peaks = rgb(108, 132, 158),
		land = rgb(38, 60, 44),
		water = rgb(86, 136, 162),
		orb = rgb(255, 246, 214),
		orbY = 30,
		orbSize = 18,
		moon = false,
		lamps = false,
	},
	{
		title = "UNDER THE AMBER MOON",
		top = rgb(10, 12, 30),
		mid = rgb(38, 32, 66),
		horizon = rgb(108, 58, 74),
		peaks = rgb(42, 36, 64),
		land = rgb(9, 9, 15),
		water = rgb(32, 28, 54),
		orb = rgb(240, 136, 76),
		orbY = 44,
		orbSize = 24,
		moon = true,
		lamps = true,
	},
	{
		title = "LAST LIGHT OVER THE PASS",
		top = rgb(36, 46, 78),
		mid = rgb(102, 100, 138),
		horizon = rgb(204, 166, 166),
		peaks = rgb(80, 82, 112),
		land = rgb(22, 26, 28),
		water = rgb(88, 88, 120),
		orb = rgb(244, 236, 218),
		orbY = 38,
		orbSize = 18,
		moon = true,
		lamps = true,
	},
}

local function paint(canvas: BasePart, face: Enum.NormalId, style: number): string
	local spec = PAINTINGS[(style - 1) % #PAINTINGS + 1]
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(240, 180) * PAINT_SCALE
	gui.LightInfluence = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = canvas
	-- the same brushwork for the same style every time (Park-Miller)
	local seed = style * 48271 % 2147483647
	local function rand(): number
		seed = seed * 16807 % 2147483647
		return seed / 2147483647
	end
	local function shape(
		x: number,
		y: number,
		w: number,
		h: number,
		color: Color3,
		z: number,
		alpha: number?
	): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(x * PAINT_SCALE, y * PAINT_SCALE)
		f.Size = UDim2.fromOffset(w * PAINT_SCALE, h * PAINT_SCALE)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = alpha or 0
		f.BorderSizePixel = 0
		f.ZIndex = z
		f.Parent = gui
		return f
	end
	local function round(f: Frame): Frame
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		return f
	end
	local function dot(x: number, y: number, d: number, color: Color3, z: number, alpha: number?): Frame
		return round(shape(x, y, d, d, color, z, alpha))
	end
	local function line(
		x0: number,
		y0: number,
		x1: number,
		y1: number,
		thick: number,
		color: Color3,
		z: number,
		alpha: number?
	)
		local dx, dy = x1 - x0, y1 - y0
		local f = shape((x0 + x1) / 2, (y0 + y1) / 2, math.sqrt(dx * dx + dy * dy), thick, color, z, alpha)
		f.Rotation = math.deg(math.atan2(dy, dx))
	end
	-- a summit: a square turned on its corner, its top `size * 0.7071` above `y`
	local function peak(x: number, y: number, size: number, color: Color3, z: number, alpha: number?)
		shape(x, y, size, size, color, z, alpha).Rotation = 45
	end
	local function gradient(f: Frame, rotation: number, color: ColorSequence?, alpha: NumberSequence?)
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		if color then
			g.Color = color
		end
		if alpha then
			g.Transparency = alpha
		end
		g.Parent = f
	end
	local white = Color3.new(1, 1, 1)
	local black = Color3.new(0, 0, 0)
	local HORIZON = 112 -- the lake's far shore
	local DECK = 103 -- the viaduct's rail level

	-- the sky, the stars or the birds
	gradient(
		shape(120, 90, 240, 180, white, 1),
		90,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, spec.top),
			ColorSequenceKeypoint.new(0.4, spec.mid),
			ColorSequenceKeypoint.new(HORIZON / 180, spec.horizon),
			ColorSequenceKeypoint.new(1, spec.horizon),
		})
	)
	local ox, oy, od = 172, spec.orbY, spec.orbSize
	if spec.moon then
		for _ = 1, 24 do
			local x, y = 4 + rand() * 232, 4 + rand() * 70
			local d = if rand() > 0.82 then 1.6 else 1
			if (x - ox) ^ 2 + (y - oy) ^ 2 > (od * 1.3) ^ 2 then
				dot(x, y, d, white, 2, 0.15 + rand() * 0.5)
			end
		end
	else
		local ink = spec.land:Lerp(spec.mid, 0.25)
		for i = 1, 4 do
			local bx, by = 46 + i * 9 + rand() * 6, 34 + i * 3 + rand() * 4
			line(bx - 2.6, by - 1.4, bx, by, 0.8, ink, 6)
			line(bx, by, bx + 2.6, by - 1.4, 0.8, ink, 6)
		end
	end
	-- the orb in its halo; the moon gets her seas
	for i, k in { 2.8, 2.0, 1.45 } do
		dot(ox, oy, od * k, spec.orb, 3, ({ 0.9, 0.82, 0.68 })[i])
	end
	dot(ox, oy, od, spec.orb, 4)
	if spec.moon then
		local sea = spec.orb:Lerp(black, 0.22)
		for _, c in { { -0.2, -0.14, 0.24 }, { 0.17, 0.1, 0.18 }, { -0.06, 0.24, 0.13 }, { 0.22, -0.2, 0.1 } } do
			dot(ox + c[1] * od, oy + c[2] * od, c[3] * od, sea, 5, 0.45)
		end
	end
	-- clouds in long streaks, each with its lit underside
	for i = 1, 6 do
		local cx, cy = 10 + rand() * 220, 12 + rand() * 66
		local w, h = 28 + rand() * 52, 2.4 + rand() * 2.6
		local body = if spec.moon
			then spec.top:Lerp(spec.mid, 0.7)
			else spec.mid:Lerp(spec.orb, 0.25 + rand() * 0.3)
		round(shape(cx, cy, w, h, body, 6, 0.2 + rand() * 0.3))
		round(shape(cx + w * 0.06, cy + h * 0.55, w * 0.72, 1.1, spec.orb, 6, 0.55 + i * 0.03))
	end

	-- the far range with snow on its summits, the near range lit along one flank
	local haze = spec.peaks:Lerp(spec.horizon, 0.45)
	local snow = spec.orb:Lerp(white, 0.4):Lerp(spec.horizon, 0.3)
	for _, p in { { 10, 62 }, { 46, 80 }, { 84, 58 }, { 120, 86 }, { 158, 64 }, { 196, 82 }, { 234, 60 } } do
		local s = p[2]
		peak(p[1], HORIZON + 2, s, haze, 7)
		local cap = s * 0.26
		peak(p[1], HORIZON + 2 - (s - cap) * 0.7071, cap, snow, 8, 0.1)
	end
	local rim = spec.peaks:Lerp(spec.orb, 0.45)
	for _, p in { { 26, 46 }, { 70, 38 }, { 104, 50 }, { 142, 36 }, { 182, 48 }, { 222, 40 } } do
		local s = p[2]
		local top = HORIZON + 4 - s * 0.7071
		peak(p[1], HORIZON + 4, s, spec.peaks, 9)
		line(p[1] - s * 0.25, top + s * 0.25, p[1], top, 1, rim, 9, 0.35)
	end

	-- the lake: the far shore and its trees, the orb's light broken on the water, ripples
	gradient(
		shape(120, HORIZON + 10, 240, 20, white, 10),
		90,
		ColorSequence.new(spec.water:Lerp(spec.horizon, 0.35), spec.water:Lerp(black, 0.25))
	)
	local shore = spec.land:Lerp(spec.peaks, 0.45)
	shape(120, HORIZON + 0.6, 240, 2, shore, 11)
	for i = 0, 23 do
		local th = 1.5 + rand() * 2.5
		shape(i * 10 + rand() * 6, HORIZON - th / 2, 1.4, th, shore, 11)
	end
	for i = 0, 5 do
		shape(
			ox + (rand() - 0.5) * 2,
			HORIZON + 3 + i * 2.6,
			od * (1.1 - i * 0.15),
			0.9,
			spec.orb,
			11,
			0.3 + i * 0.1
		)
	end
	local ripple = spec.water:Lerp(spec.horizon, 0.55)
	for _ = 1, 10 do
		shape(rand() * 240, HORIZON + 3 + rand() * 16, 5 + rand() * 14, 0.6, ripple, 11, 0.45)
	end

	-- the viaduct: its deck and parapet, piers springing into arches, lit down one edge
	local stone = spec.land:Lerp(spec.peaks, 0.35)
	shape(120, DECK + 2, 240, 4, stone, 12)
	shape(120, DECK + 0.3, 240, 0.6, spec.orb, 12, 0.55)
	for i = 0, 9 do
		local px = 10 + i * 25
		shape(px, DECK + 16, 5, 28, stone, 12)
		peak(px - 3, DECK + 5.5, 6, stone, 12)
		peak(px + 3, DECK + 5.5, 6, stone, 12)
		shape(px - 2.1, DECK + 17, 0.8, 26, spec.orb, 12, 0.75)
	end

	-- the train crossing it, heading left: the engine, her tender and three coaches
	local iron = spec.land:Lerp(black, 0.35)
	local wheel = iron:Lerp(black, 0.4)
	local roof = spec.land:Lerp(spec.orb, 0.16)
	local glow = rgb(255, 210, 130)
	shape(78, DECK - 3.5, 18, 5, iron, 13) -- boiler
	shape(68.6, DECK - 3.6, 2.6, 5.6, iron:Lerp(black, 0.3), 13) -- smokebox
	shape(71.5, DECK - 7.6, 2.2, 3.6, iron, 13) -- chimney
	shape(71.5, DECK - 9.4, 3.2, 0.9, iron, 13) -- its cap
	round(shape(78.5, DECK - 6.4, 2.8, 2, iron, 13)) -- dome
	shape(89.5, DECK - 5, 6.4, 9, iron, 13) -- cab
	shape(89.5, DECK - 9.8, 7.8, 1, roof, 13)
	shape(90, DECK - 6.4, 2.4, 2.4, if spec.lamps then glow else roof, 14)
	shape(98.5, DECK - 3.2, 9.4, 5.6, iron, 13) -- tender
	for _, wx in { 72, 76, 80, 84, 88, 95, 101 } do
		dot(wx, DECK - 0.8, 2.4, wheel, 14)
	end
	line(64, DECK - 0.6, 67.6, DECK - 1.8, 0.8, iron, 13) -- the pilot
	if spec.lamps then
		dot(67, DECK - 4.6, 1.8, glow, 14)
		gradient(shape(54, DECK - 4.4, 24, 3.4, glow, 13, 0.5), 0, nil, NumberSequence.new(1, 0))
	end
	local coach = iron:Lerp(spec.land, 0.5)
	local pane = spec.water:Lerp(white, 0.3)
	for c = 0, 2 do
		local cx = 112.5 + c * 19
		shape(cx, DECK - 3.6, 17, 6.2, coach, 13)
		shape(cx, DECK - 7, 17.6, 1.2, roof, 13)
		for j = 0, 4 do
			local lit = spec.lamps and (j + c) % 4 ~= 0
			shape(
				cx - 6 + j * 3,
				DECK - 4.4,
				1.7,
				1.9,
				if lit then glow else pane,
				14,
				if lit then 0 else 0.35
			)
		end
		dot(cx - 5.5, DECK - 0.5, 2, wheel, 14)
		dot(cx + 5.5, DECK - 0.5, 2, wheel, 14)
		shape(cx - 9.6, DECK - 2.4, 2.2, 0.7, iron, 13) -- the coupling
	end
	-- her smoke, blown back along the train
	local smoke = if spec.moon then spec.peaks:Lerp(spec.orb, 0.25) else spec.mid:Lerp(spec.horizon, 0.5)
	for i = 1, 9 do
		dot(
			72 + i * 5.6 + (rand() - 0.5) * 2,
			DECK - 10 - i * 2 - i * i * 0.12,
			3 + i * 1.5,
			smoke,
			14,
			0.25 + i * 0.07
		)
	end

	-- pines standing behind the near banks
	local function pine(x: number, foot: number, h: number, color: Color3, z: number)
		shape(x, foot - h * 0.1, math.max(h * 0.06, 0.8), h * 0.2, color, z)
		for t = 0, 3 do
			peak(x, foot - h * 0.2 - t * h * 0.17, h * (0.36 - t * 0.065), color, z)
		end
	end
	local needles = spec.land:Lerp(spec.peaks, 0.15)
	for _, t in
		{
			{ 8, 128, 24 },
			{ 17, 129, 30 },
			{ 50, 134, 20 },
			{ 196, 137, 26 },
			{ 206, 136, 32 },
			{ 230, 133, 22 },
		}
	do
		pine(t[1], t[2], t[3], needles, 14)
	end
	-- the near banks, lit along their crests, and the grass in front
	local crest = spec.land:Lerp(spec.orb, 0.3)
	for _, b in { { 30, 146, 120, 8 }, { 120, 154, 130, -4 }, { 214, 150, 120, -6 } } do
		shape(b[1], b[2], b[3], 40, spec.land, 15).Rotation = b[4]
		local r = math.rad(b[4])
		shape(b[1] + math.sin(r) * 20, b[2] - math.cos(r) * 20, b[3], 1, crest, 15, 0.35).Rotation = b[4]
	end
	shape(120, 166, 240, 28, spec.land, 15)
	local blade = spec.land:Lerp(spec.peaks, 0.3)
	for _ = 1, 18 do
		local gx, gy = rand() * 240, 150 + rand() * 28
		line(gx, gy, gx + (rand() - 0.5) * 3, gy - 3 - rand() * 3, 0.7, blade, 16)
	end
	-- two big pines at the edges, cut by the frame
	pine(4, 194, 72, spec.land:Lerp(black, 0.2), 16)
	pine(237, 190, 60, spec.land:Lerp(black, 0.2), 16)

	-- the semaphore signal, its arm at danger and its lamp lit
	shape(34, 141, 1.6, 26, iron, 16)
	dot(34, 127.6, 1.8, iron, 16)
	shape(34, 154, 4, 1.2, iron, 16)
	shape(34, 136, 3.6, 4.6, iron, 16)
	local red = rgb(255, 70, 50)
	dot(34, 135.4, 1.6, if spec.lamps then red else red:Lerp(black, 0.4), 17)
	if spec.lamps then
		dot(34, 135.4, 5.5, red, 17, 0.72)
	end
	line(35, 131, 45, 128.5, 2, rgb(176, 40, 34), 16)
	line(41.2, 129.5, 43.4, 128.95, 2.05, rgb(236, 228, 210), 16)

	-- telegraph poles going away to the right, their wires sagging between them
	local poles = { { 146, 158, 36 }, { 180, 150, 28 }, { 208, 144, 22 } }
	local ends = {}
	for i, p in poles do
		local x, foot, h = p[1], p[2], p[3]
		local arm = h * 0.13
		shape(x, foot - h / 2, 0.6 + h * 0.03, h, iron, 16)
		shape(x, foot - h + 2.5, arm * 2, 1, iron, 16)
		dot(x - arm + 0.5, foot - h + 1.6, 1, iron, 16)
		dot(x + arm - 0.5, foot - h + 1.6, 1, iron, 16)
		ends[i] = { x - arm + 0.5, x + arm - 0.5, foot - h + 2 }
	end
	local wire = iron:Lerp(spec.orb, 0.2)
	for i = 1, #ends - 1 do
		local a, b = ends[i], ends[i + 1]
		for k = 1, 2 do
			local x0, x1 = a[k], b[k]
			local mx, my = (x0 + x1) / 2, (a[3] + b[3]) / 2 + 1.6
			line(x0, a[3], mx, my, 0.5, wire, 17, 0.2)
			line(mx, my, x1, b[3], 0.5, wire, 17, 0.2)
		end
	end
	for k = 1, 2 do
		line(ends[#ends][k], ends[#ends][3], 244, ends[#ends][3] + 1.5, 0.5, wire, 17, 0.2)
	end

	-- the varnish, warm all over and darkening to the edges
	shape(120, 90, 240, 180, rgb(255, 214, 150), 18, 0.88)
	local edge = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.16, 1),
		NumberSequenceKeypoint.new(0.84, 1),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	gradient(shape(120, 90, 240, 180, black, 19), 0, nil, edge)
	gradient(shape(120, 90, 240, 180, black, 19), 90, nil, edge)
	return spec.title
end

function TrainInterior.furnish(model: Model, origin: CFrame, dims: Dims): Furnished
	local seats: { Seat } = {}
	local LI = dims.lineIn
	local CEIL = dims.ceiling
	-- enamel signs over the sliding doors sit clear of their brass heads
	local SIDE_SIGN_Y = dims.sideDoorTop + 0.62

	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local function solid(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		return Kit.block(model, size, cf, color, { material = material or M.SmoothPlastic })
	end
	local function decor(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		return Kit.block(
			model,
			size,
			cf,
			color,
			{ material = material or M.SmoothPlastic, collide = false, shadow = false }
		)
	end
	local function post(
		height: number,
		diameter: number,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		collide: boolean?
	): BasePart
		return Kit.post(
			model,
			height,
			diameter,
			cf,
			color,
			{ material = material, collide = collide == true, shadow = false }
		)
	end
	local function disc(
		thick: number,
		diameter: number,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?
	): BasePart
		-- a cylinder lying flat, its round faces up and down
		return Kit.post(
			model,
			thick,
			diameter,
			cf,
			color,
			{ material = material, collide = false, shadow = false }
		)
	end
	local function ball(diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		return Kit.ball(model, diameter, cf, color, { material = material, collide = false, shadow = false })
	end
	local function seat(size: Vector3, cf: CFrame, color: Color3, name: string, hidden: boolean?): Seat
		local s = Kit.seat(model, size, cf, color, {
			material = M.Fabric,
			transparency = if hidden then 1 else 0,
			shadow = not hidden,
		})
		s:SetAttribute("SeatName", name)
		table.insert(seats, s)
		return s
	end
	-- A plate or board facing along `normal` (horizontal), its lettering on the side that faces out.
	local function plate(
		center: Vector3,
		normal: Vector3,
		size: Vector3,
		color: Color3,
		material: Enum.Material,
		text: string,
		ink: Color3,
		font: Font,
		light: number
	): BasePart
		local part = decor(size, origin * CFrame.lookAt(center, center + normal), color, material)
		letter(part, Enum.NormalId.Front, text, ink, font, Vector2.new(size.X * 100, size.Y * 100), light)
		return part
	end
	-- An enamel sign over a door, saying where it leads (as an exit sign would).
	local function doorSign(center: Vector3, normal: Vector3, text: string)
		local face = plate(
			center,
			normal,
			Vector3.new(3.4, 0.62, 0.14),
			C.enamel,
			M.SmoothPlastic,
			text,
			C.cream,
			SIGN_FONT,
			0.3
		)
		face.Name = "DoorSign"
		-- a cream border, a hair proud of the enamel
		local frame = decor(
			Vector3.new(3.56, 0.74, 0.1),
			origin * CFrame.lookAt(center - normal * 0.08, center - normal * 0.08 + normal),
			C.cream,
			M.SmoothPlastic
		)
		frame.Name = "DoorSignRim"
	end
	-- A car's name, hung across the aisle from the ceiling, readable from both ends.
	local function nameboard(x: number, text: string, low: number?)
		local y = low or 7.25
		local board = decor(Vector3.new(0.14, 0.72, 3.8), at(x, y, 0), C.board, M.Wood)
		board.Name = "Nameboard"
		for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
			letter(board, face, text, C.gilt, BOARD_FONT, Vector2.new(380, 72), 0.5)
		end
		for _, z in { -1.5, 1.5 } do
			decor(Vector3.new(0.06, CEIL - y - 0.36, 0.06), at(x, (CEIL + y + 0.36) / 2, z), C.brass, M.Metal)
		end
	end
	local function picture(x: number, z: number, inward: number, style: number)
		local frame = decor(Vector3.new(0.12, 1.9, 2.5), at(x + inward * 0.07, 5.55, z), C.woodDark, M.Wood)
		frame.Name = "PictureFrame"
		-- a gilt slip round the canvas, standing a hair off the frame's face
		local slip = decor(Vector3.new(0.07, 1.68, 2.28), at(x + inward * 0.12, 5.55, z), C.gilt, M.Metal)
		slip.Name = "PictureSlip"
		local canvas =
			decor(Vector3.new(0.05, 1.56, 2.16), at(x + inward * 0.155, 5.55, z), C.cream, M.SmoothPlastic)
		canvas.Name = "Painting"
		local title = paint(canvas, if inward > 0 then Enum.NormalId.Right else Enum.NormalId.Left, style)
		-- its title on a brass plaque screwed to the lining under the frame
		local plaque = plate(
			Vector3.new(x + inward * 0.035, 4.42, z),
			Vector3.new(inward, 0, 0),
			Vector3.new(1.3, 0.2, 0.05),
			C.brass,
			M.Metal,
			title,
			C.board,
			PLATE_FONT,
			1
		)
		plaque.Name = "PicturePlaque"
	end

	-- Crew saloon ---------------------------------------------------------------------------------

	-- A velvet window seat for one against wall `side` (1 platform, -1 far), its sitter facing
	-- `facing` (1 = +X). The aisle side is left open for the runner and the crew walking it.
	local BENCH_W = 2.3
	local BENCH_Z = 5.62 - BENCH_W / 2 -- the seat's middle, its outer end a hand off the lining
	local function bench(x: number, side: number, facing: number)
		local yaw = if facing > 0 then -90 else 90
		local zc = side * BENCH_Z
		solid(Vector3.new(2.3, 1.25, BENCH_W), at(x - facing * 0.25, 0.625, zc), C.woodDark, M.Wood)
		seat(Vector3.new(1.75, 0.45, 1.8), at(x, 1.475, zc) * Kit.angles(0, yaw, 0), C.velvet, "Saloon seat")
		local back = at(x - facing * 1.15, 2.7, zc) * Kit.angles(0, 0, facing * 8)
		solid(Vector3.new(0.5, 2.9, BENCH_W), back, C.velvet, M.Fabric)
		decor(Vector3.new(0.55, 0.15, BENCH_W + 0.08), back * CFrame.new(0, 1.5, 0), C.woodDark, M.Wood)
		decor(Vector3.new(0.06, 0.78, 1.25), back * CFrame.new(facing * 0.28, 0.9, 0), C.lace, M.Fabric)
		-- the armrest at the aisle end, on a turned leg
		local az = side * (BENCH_Z - BENCH_W / 2 + 0.15)
		solid(Vector3.new(1.8, 0.22, 0.28), at(x, 2.25, az), C.woodDark, M.Wood)
		decor(Vector3.new(0.2, 0.89, 0.2), at(x + facing * 0.68, 1.695, az), C.woodDark, M.Wood)
	end

	local function bay(x0: number, side: number)
		bench(x0 + 1.55, side, 1)
		bench(x0 + 5.75, side, -1)
		local tx = x0 + 3.65
		-- the table, wall-hung with a brass pedestal at the aisle end
		solid(Vector3.new(1.8, 0.16, 2.5), at(tx, 2.88, side * 4.3), C.polish, M.Wood)
		post(2.7, 0.3, at(tx, 1.35, side * 3.4), C.brass, M.Metal, true)
		disc(0.08, 1.0, at(tx, 0.04, side * 3.4), C.brass, M.Metal)
		decor(Vector3.new(0.6, 0.06, 0.6), at(tx, 2.77, side * 3.4), C.brass, M.Metal)
		-- its lamp: a brass column under a silk shade
		disc(0.08, 0.6, at(tx, 3.0, side * 5.0), C.brass, M.Metal)
		post(0.8, 0.1, at(tx, 3.44, side * 5.0), C.brass, M.Metal)
		post(0.5, 0.95, at(tx, 4.05, side * 5.0), C.shade, M.Fabric)
		local bulb = Kit.neon(model, Vector3.one * 0.3, at(tx, 3.85, side * 5.0), C.warm, Enum.PartType.Ball)
		Kit.pointLight(bulb, C.warm, 0.6, 11, false)
	end

	-- two bays on the far side of each saloon car; on the platform side a bay and the doors
	for _, spot in
		{
			{ x = -62.0, side = 1 },
			{ x = -62.0, side = -1 },
			{ x = -54.0, side = -1 },
			{ x = -40.0, side = -1 },
			{ x = -32.0, side = -1 },
		}
	do
		bay(spot.x, spot.side)
	end
	-- paintings of the line either side of each gangway door
	picture(-62.38, 4.0, 1, 1)
	picture(-62.38, -4.0, 1, 2)
	picture(-23.62, 4.0, -1, 3)
	picture(-23.62, -4.0, -1, 4)
	picture(-45.12, 4.0, -1, 3)
	picture(-45.12, -4.0, -1, 4)
	picture(-41.88, 4.0, 1, 1)
	picture(-41.88, -4.0, 1, 2)
	doorSign(Vector3.new(-62.29, 7.66, 0), Vector3.new(1, 0, 0), "GUARD'S VAN")
	doorSign(Vector3.new(-45.21, 7.66, 0), Vector3.new(-1, 0, 0), "SALOON")
	doorSign(Vector3.new(-41.79, 7.66, 0), Vector3.new(1, 0, 0), "SALOON")
	doorSign(Vector3.new(-23.71, 7.66, 0), Vector3.new(-1, 0, 0), "WORKSHOP")
	doorSign(Vector3.new(-49.75, SIDE_SIGN_Y, LI - 0.29), Vector3.new(0, 0, -1), "PLATFORM")
	doorSign(Vector3.new(-36.25, SIDE_SIGN_Y, LI - 0.29), Vector3.new(0, 0, -1), "PLATFORM")
	nameboard(-55.6, "CREW SALOON")
	nameboard(-30.0, "CREW SALOON")

	-- Guard's van ------------------------------------------------------------------------------------

	-- the pot-bellied stove in the corner
	local sx, sz = -68.7, -4.1
	decor(Vector3.new(3.6, 0.1, 3.4), at(sx, 0.05, sz), rgb(150, 70, 52), M.Brick)
	disc(0.25, 2.2, at(sx, 0.225, sz), C.iron, M.Metal)
	post(2.3, 2.0, at(sx, 1.5, sz), C.iron, M.Metal, true)
	disc(0.4, 2.3, at(sx, 1.35, sz), C.ironLight, M.Metal)
	disc(0.15, 2.25, at(sx, 2.725, sz), C.ironLight, M.Metal)
	local glow = Kit.neon(model, Vector3.new(0.9, 0.55, 0.1), at(sx, 1.0, sz + 0.98), C.fire)
	glow.Name = "StoveGlow"
	Kit.pointLight(glow, C.fire, 1.0, 13, false)
	post(6.03, 0.55, at(sx, 5.815, sz), C.iron, M.Metal)
	-- the fender in front of it, and the coal scuttle
	decor(Vector3.new(2.8, 0.1, 0.1), at(sx, 0.85, sz + 1.62), C.brass, M.Metal)
	for _, dx in { -1.35, 1.35 } do
		decor(Vector3.new(0.1, 0.8, 0.1), at(sx + dx, 0.45, sz + 1.62), C.brass, M.Metal)
	end
	solid(Vector3.new(1.0, 0.9, 1.2), at(sx - 2.3, 0.45, -5.15), C.iron, M.Metal)
	for i = 1, 3 do
		ball(0.42, at(sx - 2.55 + i * 0.22, 0.98, -5.15 + (i % 2) * 0.2), C.coal, M.Slate)
	end
	-- the rug and the wing chair drawn up to the fire
	-- (each layer a hair thicker than the carpet runner and the one under it)
	decor(Vector3.new(5.0, 0.07, 4.2), at(-73.0, 0.035, -2.4), C.rug, M.Fabric)
	decor(Vector3.new(4.2, 0.08, 3.4), at(-73.0, 0.04, -2.4), C.rugGold, M.Fabric)
	decor(Vector3.new(3.4, 0.09, 2.6), at(-73.0, 0.045, -2.4), C.rug, M.Fabric)
	-- the wing chair, built a size down (S) so it keeps to the corner
	local function armchair(cx: number, cz: number, yaw: number)
		local S = 0.88
		local f = at(cx, 0, cz) * Kit.angles(0, yaw, 0)
		local function o(x: number, y: number, z: number): CFrame
			return f * CFrame.new(x * S, y * S, z * S)
		end
		solid(Vector3.new(2.6, 1.3, 2.4) * S, o(0, 0.95, 0.1), C.velvetGreen, M.Fabric)
		for _, lx in { -1.05, 1.05 } do
			for _, lz in { -0.95, 1.05 } do
				post(0.3 * S, 0.3 * S, o(lx, 0.15, lz), C.woodDark, M.Wood)
			end
		end
		seat(Vector3.new(2.0, 0.45, 2.0) * S, o(0, 1.825, -0.05), Kit.shade(C.velvetGreen, 1.12), "Armchair")
		local back = o(0, 3.0, 1.0) * Kit.angles(8, 0, 0)
		solid(Vector3.new(2.6, 2.6, 0.6) * S, back, C.velvetGreen, M.Fabric)
		decor(Vector3.new(1.4, 0.8, 0.06) * S, back * CFrame.new(0, 0.85 * S, -0.33 * S), C.lace, M.Fabric)
		for _, side in { -1, 1 } do
			solid(Vector3.new(0.5, 1.4, 1.0) * S, o(side * 1.02, 3.55, 0.55), C.velvetGreen, M.Fabric)
			solid(
				Vector3.new(0.55, 0.9, 2.3) * S,
				o(side * 1.3, 2.05, 0.05),
				Kit.shade(C.velvetGreen, 0.9),
				M.Fabric
			)
		end
	end
	armchair(-72.6, -4.0, -90)
	-- the side table beside it
	post(2.3, 0.3, at(-71.4, 1.15, -1.7), C.woodDark, M.Wood, true)
	disc(0.14, 1.4, at(-71.4, 2.37, -1.7), C.polish, M.Wood)
	-- the guard's cat, asleep on her cushion by the fire
	local cat = Vector3.new(-71.0, 0, -3.25)
	disc(0.32, 1.5, at(cat.X, 0.24, cat.Z), rgb(150, 40, 46), M.Fabric)
	local body = Kit.cylinder(
		model,
		1.15,
		0.72,
		at(cat.X, 0.72, cat.Z) * Kit.angles(0, 20, 0),
		C.ginger,
		{ material = M.Fabric, collide = false, shadow = false }
	)
	body.Name = "Cat"
	for i = -1, 1 do
		Kit.cylinder(
			model,
			0.1,
			0.76,
			at(cat.X, 0.72, cat.Z) * Kit.angles(0, 20, 0) * CFrame.new(i * 0.3, 0, 0),
			C.gingerDark,
			{ material = M.Fabric, collide = false, shadow = false }
		)
	end
	local head = at(cat.X, 0.72, cat.Z) * Kit.angles(0, 20, 0) * CFrame.new(0.66, 0.08, 0.12)
	ball(0.56, head, C.ginger, M.Fabric)
	for _, ear in { -1, 1 } do
		Kit.wedge(
			model,
			Vector3.new(0.1, 0.2, 0.16),
			head * CFrame.new(0.02, 0.3, ear * 0.14) * Kit.angles(0, 90, 0),
			C.gingerDark,
			{ material = M.Fabric, collide = false, shadow = false }
		)
	end
	Kit.cylinder(
		model,
		0.95,
		0.16,
		at(cat.X, 0.72, cat.Z) * Kit.angles(0, 20, 0) * CFrame.new(-0.1, -0.24, 0.4) * Kit.angles(0, -12, 0),
		C.gingerDark,
		{ material = M.Fabric, collide = false, shadow = false }
	)
	-- the bunk along the far wall at the back, and the guard's desk across from it
	solid(Vector3.new(8.0, 1.1, 2.26), at(-85.2, 0.55, -4.53), C.woodDark, M.Wood)
	solid(Vector3.new(7.8, 0.5, 2.1), at(-85.2, 1.35, -4.53), rgb(214, 204, 186), M.Fabric)
	decor(Vector3.new(5.2, 0.14, 2.16), at(-84.0, 1.67, -4.53), rgb(126, 46, 44), M.Fabric)
	decor(Vector3.new(1.3, 0.4, 1.6), at(-88.25, 1.8, -4.5), C.cream, M.Fabric)
	for _, x in { -84.4, -82.4 } do
		seat(Vector3.new(1.9, 0.3, 1.2), at(x, 1.75, -3.95) * Kit.angles(0, 180, 0), C.cream, "Bunk", true)
	end
	solid(Vector3.new(4.0, 0.16, 1.76), at(-87.2, 3.0, 4.78), C.polish, M.Wood)
	solid(Vector3.new(1.6, 2.92, 1.6), at(-88.3, 1.46, 4.8), C.woodDark, M.Wood)
	post(2.92, 0.22, at(-85.5, 1.46, 4.8), C.woodDark, M.Wood, true)
	decor(Vector3.new(0.75, 0.1, 1.0), at(-87.75, 3.13, 4.7) * Kit.angles(0, 0, 6), C.cream, M.SmoothPlastic)
	decor(Vector3.new(0.75, 0.1, 1.0), at(-87.0, 3.13, 4.7) * Kit.angles(0, 0, -6), C.cream, M.SmoothPlastic)
	disc(0.08, 0.5, at(-86.0, 3.12, 5.2), C.brass, M.Metal)
	post(0.6, 0.08, at(-86.0, 3.46, 5.2), C.brass, M.Metal)
	local banker = Kit.neon(model, Vector3.new(0.9, 0.24, 0.5), at(-86.0, 3.86, 5.05), rgb(70, 150, 96))
	banker.Name = "DeskLamp"
	Kit.pointLight(banker, C.warm, 0.55, 9, false)
	post(2.05, 0.3, at(-87.0, 1.025, 2.6), C.woodDark, M.Wood, true)
	seat(Vector3.new(1.3, 0.25, 1.3), at(-87.0, 2.175, 2.6) * Kit.angles(0, 180, 0), C.leather, "Stool")
	-- the flags in their holder by the back door, the guard's coat on its peg
	for i, color in { rgb(196, 40, 36), rgb(52, 140, 72) } do
		post(3.2, 0.1, at(-88.8, 1.6, 2.7 + i * 0.35), C.wood, M.Wood)
		decor(Vector3.new(0.5, 0.9, 0.08), at(-88.8, 2.9, 2.95 + i * 0.35), color, M.Fabric)
	end
	decor(Vector3.new(0.16, 0.16, 2.4), at(-66.74, 6.1, 4.2), C.woodDark, M.Wood)
	decor(Vector3.new(0.5, 2.7, 1.2), at(-67.0, 4.55, 3.9), C.navy, M.Fabric)
	disc(0.4, 0.9, at(-67.0, 6.35, 4.9), C.navy, M.Fabric)
	decor(Vector3.new(0.5, 0.06, 1.0), at(-67.0, 6.2, 4.9), C.board, M.SmoothPlastic)
	-- a lantern hung over the chairs
	post(1.4, 0.06, at(-71.4, CEIL - 0.7, -2.4), C.iron, M.Metal)
	disc(0.22, 0.7, at(-71.4, CEIL - 1.51, -2.4), C.brass, M.Metal)
	Kit.post(
		model,
		0.8,
		0.55,
		at(-71.4, CEIL - 2.02, -2.4),
		rgb(200, 210, 210),
		{ material = M.Glass, transparency = 0.45, collide = false, shadow = false }
	)
	local flame =
		Kit.neon(model, Vector3.one * 0.2, at(-71.4, CEIL - 2.05, -2.4), C.ember, Enum.PartType.Ball)
	flame.Name = "LanternFlame"
	Kit.pointLight(flame, C.warm, 0.7, 14, false)
	disc(0.12, 0.62, at(-71.4, CEIL - 2.48, -2.4), C.brass, M.Metal)
	doorSign(Vector3.new(-66.71, 7.66, 0), Vector3.new(-1, 0, 0), "CREW SALOON")
	doorSign(Vector3.new(-89.29, 7.66, 0), Vector3.new(1, 0, 0), "SIGNAL MAST")
	doorSign(Vector3.new(-78, SIDE_SIGN_Y, LI - 0.29), Vector3.new(0, 0, -1), "PLATFORM")
	nameboard(-78.6, "GUARD'S VAN", 6.95)

	-- Workshop -------------------------------------------------------------------------------------

	-- a lamp over the bench
	post(1.6, 0.06, at(-6.0, CEIL - 0.8, -4.0), C.iron, M.Metal)
	post(0.45, 1.3, at(-6.0, CEIL - 1.82, -4.0), rgb(46, 82, 62), M.Metal)
	local benchLamp =
		Kit.neon(model, Vector3.one * 0.32, at(-6.0, CEIL - 2.08, -4.0), C.warm, Enum.PartType.Ball)
	benchLamp.Name = "BenchLamp"
	Kit.pointLight(benchLamp, rgb(255, 232, 196), 0.8, 13, false)
	-- the lathe
	for _, x in { -16.9, -12.1 } do
		solid(Vector3.new(1.2, 2.6, 1.4), at(x, 1.3, -4.7), C.ironLight, M.Metal)
	end
	solid(Vector3.new(6.0, 0.5, 1.2), at(-14.5, 2.85, -4.7), C.iron, M.Metal)
	solid(Vector3.new(1.6, 1.6, 1.3), at(-16.5, 3.9, -4.7), rgb(52, 80, 72), M.Metal)
	Kit.cylinder(
		model,
		0.5,
		1.0,
		at(-15.45, 3.9, -4.7),
		C.ironLight,
		{ material = M.Metal, collide = false, shadow = false }
	)
	Kit.cylinder(
		model,
		3.0,
		0.32,
		at(-13.7, 3.9, -4.7),
		C.brass,
		{ material = M.Metal, collide = false, shadow = false }
	)
	solid(Vector3.new(0.9, 1.1, 1.0), at(-11.9, 3.65, -4.7), rgb(52, 80, 72), M.Metal)
	decor(Vector3.new(1.0, 0.5, 1.1), at(-14.1, 3.35, -4.45), C.iron, M.Metal)
	Kit.cylinder(
		model,
		0.14,
		0.8,
		at(-14.1, 3.05, -3.85) * Kit.angles(0, 90, 0),
		C.ironLight,
		{ material = M.Metal, collide = false, shadow = false }
	)
	-- a stool at the bench
	post(2.2, 0.35, at(-5.2, 1.1, -2.3), C.woodDark, M.Wood, true)
	seat(Vector3.new(1.3, 0.25, 1.3), at(-5.2, 2.325, -2.3), C.leather, "Stool")
	plate(
		Vector3.new(-6.8, 7.85, -(LI - 0.09)),
		Vector3.new(0, 0, 1),
		Vector3.new(8.6, 0.6, 0.1),
		C.board,
		M.Wood,
		"WORKSHOP  ·  FIT UPGRADES HERE",
		C.gilt,
		BOARD_FONT,
		0.5
	)
	doorSign(Vector3.new(-19.29, 7.66, 0), Vector3.new(1, 0, 0), "CREW SALOON")
	doorSign(Vector3.new(-2.21, 7.66, 0), Vector3.new(-1, 0, 0), "STORES")
	doorSign(Vector3.new(2.21, 7.66, 0), Vector3.new(1, 0, 0), "WORKSHOP")
	doorSign(Vector3.new(-6.25, SIDE_SIGN_Y, LI - 0.29), Vector3.new(0, 0, -1), "PLATFORM")
	doorSign(Vector3.new(6.25, SIDE_SIGN_Y, LI - 0.29), Vector3.new(0, 0, -1), "PLATFORM")
	nameboard(-15.0, "WORKSHOP")
	nameboard(13.0, "STORES")
	-- a map of the line on the blind front wall
	picture(19.38, 3.0, -1, 2)
	plate(
		Vector3.new(19.3, 7.6, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(5.6, 0.62, 0.1),
		C.board,
		M.Wood,
		"NO PASSENGERS BEYOND THIS POINT",
		C.gilt,
		BOARD_FONT,
		0.5
	)

	-- Footplate: the furnace ---------------------------------------------------------------------

	-- the firebox front, built round its fire-hole (z -1..1, y 1.5..3.1)
	local fx = 63.1
	solid(Vector3.new(0.6, 1.5, 5.8), at(fx, 0.75, 0), C.iron, M.Metal)
	solid(Vector3.new(0.6, 1.3, 5.8), at(fx, 3.75, 0), C.iron, M.Metal)
	for _, side in { -1, 1 } do
		solid(Vector3.new(0.6, 1.6, 1.9), at(fx, 2.3, side * 1.95), C.iron, M.Metal)
	end
	-- rivets round the plate
	for i = 0, 9 do
		local z = -2.6 + i * 0.58
		ball(0.16, at(fx - 0.31, 4.22, z), C.ironLight, M.Metal)
		ball(0.16, at(fx - 0.31, 0.22, z), C.ironLight, M.Metal)
	end
	-- the fire inside: a bed of coals glowing behind the hole, the brick arch over it
	local fire = Kit.neon(model, Vector3.new(0.1, 1.5, 1.9), at(fx + 0.23, 2.3, 0), C.fire)
	fire.Name = "Firebox"
	Kit.pointLight(fire, C.fire, 2.2, 16, true)
	decor(Vector3.new(0.5, 0.25, 1.96), at(fx + 0.02, 2.97, 0), C.brick, M.Brick)
	local flames = decor(Vector3.new(0.3, 0.3, 1.6), at(fx + 0.05, 1.7, 0), C.fire, M.SmoothPlastic)
	flames.Transparency = 1
	flames.Name = "FireFlame"
	local tongue = Instance.new("ParticleEmitter")
	tongue.Name = "Flames"
	tongue.Texture = "rbxasset://textures/particles/fire_main.dds"
	tongue.Color = ColorSequence.new(rgb(255, 196, 96), rgb(220, 60, 24))
	tongue.LightEmission = 1
	tongue.Rate = 18
	tongue.Lifetime = NumberRange.new(0.3, 0.55)
	tongue.Speed = NumberRange.new(1.2, 2.6)
	tongue.SpreadAngle = Vector2.new(18, 18)
	tongue.EmissionDirection = Enum.NormalId.Top
	tongue.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.1) })
	tongue.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	tongue.Parent = flames
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
	sparks.Color = ColorSequence.new(C.ember)
	sparks.LightEmission = 1
	sparks.Rate = 4
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Speed = NumberRange.new(1.5, 3.5)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.EmissionDirection = Enum.NormalId.Left
	sparks.Acceleration = Vector3.new(0, 3, 0)
	sparks.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = flames
	-- the fire-hole doors, swung open on the fire
	for _, side in { -1, 1 } do
		local angle = side * 100
		local hinge = Vector3.new(fx - 0.38, 2.3, side * 1.05)
		local open =
			Vector3.new(-math.sin(math.rad(math.abs(angle))), 0, side * -math.cos(math.rad(math.abs(angle))))
		local door = solid(
			Vector3.new(0.14, 1.5, 1.0),
			origin * CFrame.new(hinge + open * 0.52) * Kit.angles(0, angle, 0),
			C.ironLight,
			M.Metal
		)
		door.Name = "FireDoor"
		decor(
			Vector3.new(0.3, 0.12, 0.12),
			origin * CFrame.new(hinge + open * 0.9 + Vector3.new(0, 0.2, 0)) * Kit.angles(0, angle, 0),
			C.brass,
			M.Metal
		)
	end
	-- the deflector lip over the hole, and the brass ledge along the top of the plate
	decor(Vector3.new(0.5, 0.12, 2.2), at(fx - 0.46, 3.22, 0) * Kit.angles(0, 0, -25), C.ironLight, M.Metal)
	decor(Vector3.new(0.2, 0.15, 5.9), at(fx - 0.36, 4.47, 0), C.brass, M.Metal)
	-- the backhead over it: the boiler's gauges, glasses and regulator
	local bx = 63.25
	solid(Vector3.new(0.3, 3.8, 6.0), at(bx, 6.42, 0), C.iron, M.Metal)
	local function gauge(z: number, y: number, size: number, needle: number)
		Kit.cylinder(
			model,
			0.3,
			size,
			at(bx - 0.3, y, z),
			C.brass,
			{ material = M.Metal, collide = false, shadow = false }
		)
		Kit.cylinder(
			model,
			0.05,
			size - 0.2,
			at(bx - 0.475, y, z),
			C.cream,
			{ collide = false, shadow = false }
		)
		decor(
			Vector3.new(0.03, size * 0.36, 0.05),
			at(bx - 0.515, y, z) * CFrame.Angles(math.rad(needle), 0, 0) * CFrame.new(0, size * 0.18, 0),
			C.board
		)
	end
	gauge(-0.9, 7.4, 1.5, -40)
	gauge(0.95, 7.4, 1.0, 25)
	for _, side in { -1, 1 } do
		local z = side * 2.2
		disc(0.3, 0.4, at(bx - 0.32, 6.5, z), C.brass, M.Metal)
		disc(0.3, 0.4, at(bx - 0.32, 4.95, z), C.brass, M.Metal)
		Kit.post(
			model,
			1.25,
			0.22,
			at(bx - 0.32, 5.725, z),
			rgb(200, 220, 220),
			{ material = M.Glass, transparency = 0.4, collide = false, shadow = false }
		)
		post(0.6, 0.14, at(bx - 0.32, 5.4, z), rgb(110, 140, 156), M.Glass)
		-- the injector pipes running down beside the firebox
		post(4.4, 0.22, at(bx - 0.25, 2.2, side * 3.12), C.copper, M.Metal)
	end
	Kit.block(
		model,
		Vector3.new(0.14, 0.14, 2.4),
		origin * Kit.between(Vector3.new(bx - 0.4, 8.0, 0.1), Vector3.new(bx - 0.62, 7.0, 2.1)),
		C.brass,
		{ material = M.Metal, collide = false, shadow = false }
	)
	ball(0.26, at(bx - 0.62, 7.0, 2.1), C.brass, M.Metal)
	local gaugeLamp = Kit.neon(model, Vector3.new(0.3, 0.2, 0.5), at(bx - 0.4, 8.55, 0), C.warm)
	gaugeLamp.Name = "GaugeLamp"
	Kit.pointLight(gaugeLamp, C.warm, 0.45, 7, false)
	-- brass labels on the backhead
	for _, label in
		{
			{ text = "FIREBOX", y = 4.8, z = 0, w = 1.8 },
			{ text = "BOILER", y = 6.45, z = -0.9, w = 1.1 },
			{ text = "WATER", y = 4.55, z = -2.2, w = 0.8 },
			{ text = "WATER", y = 4.55, z = 2.2, w = 0.8 },
			{ text = "REGULATOR", y = 8.35, z = 1.4, w = 1.3 },
		}
	do
		plate(
			Vector3.new(bx - 0.18, label.y, label.z),
			Vector3.new(-1, 0, 0),
			Vector3.new(label.w, 0.3, 0.05),
			C.brass,
			M.Metal,
			label.text,
			C.board,
			PLATE_FONT,
			1
		)
	end
	-- the reverser on its pedestal and the brake handle, on the driver's side
	solid(Vector3.new(0.8, 2.6, 0.8), at(61.2, 1.3, -4.7), C.iron, M.Metal)
	Kit.cylinder(
		model,
		0.14,
		1.4,
		at(60.75, 3.0, -4.7),
		C.ironLight,
		{ material = M.Metal, collide = false, shadow = false }
	)
	ball(0.2, at(60.65, 3.55, -4.7), C.brass, M.Metal)
	plate(
		Vector3.new(60.79, 2.2, -4.7),
		Vector3.new(-1, 0, 0),
		Vector3.new(0.7, 0.24, 0.05),
		C.brass,
		M.Metal,
		"REVERSER",
		C.board,
		PLATE_FONT,
		1
	)
	decor(Vector3.new(0.14, 1.4, 0.14), at(62.2, 4.1, -5.6) * Kit.angles(0, 0, 20), C.ironLight, M.Metal)
	-- the whistle chain from the roof
	post(1.7, 0.05, at(61.4, 8.45, -2.6), C.iron, M.Metal)
	post(0.4, 0.14, at(61.4, 7.4, -2.6), C.wood, M.Wood)
	-- the crew's tip-up seats on the cab sides
	for _, side in { -1, 1 } do
		solid(Vector3.new(1.2, 0.5, 0.3), at(61.0, 1.95, side * 5.82), C.woodDark, M.Wood)
		seat(
			Vector3.new(1.3, 0.25, 1.2),
			at(61.0, 2.3, side * 5.15) * Kit.angles(0, -90, 0),
			C.wood,
			if side < 0 then "Driver's seat" else "Fireman's seat"
		)
	end
	-- coal spilt from the tender, and the fireman's shovel against the firebox
	for i = 0, 7 do
		local size = 0.5 + (i % 3) * 0.25
		ball(size, at(52.9 + (i % 4) * 0.55, size * 0.35, -1.6 + i * 0.42), C.coal, M.Slate)
	end
	Kit.cylinder(
		model,
		3.2,
		0.16,
		at(61.9, 1.9, 2.95) * Kit.angles(0, 0, 62),
		C.wood,
		{ material = M.Wood, collide = false, shadow = false }
	)
	decor(Vector3.new(0.9, 0.08, 1.1), at(62.45, 0.42, 2.95) * Kit.angles(0, 0, 62), C.ironLight, M.Metal)
	doorSign(Vector3.new(58, 7.66, 5.87), Vector3.new(0, 0, -1), "PLATFORM")
	nameboard(55.6, "FOOTPLATE")

	-- Outside: boards along each car's cant rail, the engine's name on her cab ----------------------

	local function carBoard(x: number, length: number, text: string)
		for _, side in { -1, 1 } do
			local center = Vector3.new(x, 8.15, side * 6.64)
			plate(
				center,
				Vector3.new(0, 0, side),
				Vector3.new(length, 0.62, 0.12),
				C.board,
				M.Wood,
				text,
				C.gilt,
				BOARD_FONT,
				0.6
			)
		end
	end
	carBoard(-78, 11, "GUARD'S VAN")
	carBoard(-53.75, 14, "LAST TRAIN OUT")
	carBoard(-32.25, 14, "CREW SALOON")
	carBoard(-10.75, 12, "WORKSHOP")
	carBoard(10.75, 12, "STORES")
	for _, side in { -1, 1 } do
		-- the tender's lettering, gilt straight on the paint
		local lettering = decor(Vector3.new(16, 1.8, 0.05), at(36, 3.5, side * 6.53), C.gilt, M.SmoothPlastic)
		lettering.Transparency = 1
		lettering.Name = "TenderLettering"
		letter(
			lettering,
			if side > 0 then Enum.NormalId.Back else Enum.NormalId.Front,
			"LAST TRAIN OUT",
			C.gilt,
			BOARD_FONT,
			Vector2.new(1600, 180),
			0.7
		)
		-- the engine's brass nameplate on her cab side
		local namePlate = plate(
			Vector3.new(54.3, 4.8, side * 6.54),
			Vector3.new(0, 0, side),
			Vector3.new(3.0, 0.9, 0.08),
			C.brass,
			M.Metal,
			"LAST LIGHT  No. 1931",
			rgb(110, 26, 24),
			PLATE_FONT,
			1
		)
		namePlate.Name = "Nameplate"
	end

	return { seats = seats }
end

return TrainInterior
