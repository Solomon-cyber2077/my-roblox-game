--!strict
--[[
	What makes the train a place to ride in: TrainBuilder puts up the shell (walls,
	linings, windows, ceilings, racks), this furnishes it, in the same train space (x along
	the track, +X the locomotive, y = 0 the floor, +Z the platform side).

	  Crew saloon  bays of facing velvet banquettes (two seats each, every one sittable)
	               round wall tables with lamps, luggage on the racks, paintings of the
	               line on the end walls
	  Guard's van  a pot-bellied stove with a kettle, two wing chairs on a rug, the guard's
	               cat asleep on a cushion, a bunk, the guard's desk and lamp, a lantern
	  Workshop     a lathe, a drawer cabinet, an anvil under a chain hoist, a stool at the
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

-- A little painting of the line: a sky, a horizon, and a moon or a sun.
local PAINTINGS = {
	{ top = rgb(238, 150, 86), bottom = rgb(92, 48, 86), land = rgb(36, 28, 34), orb = rgb(255, 214, 140) },
	{
		top = rgb(244, 214, 160),
		bottom = rgb(96, 140, 168),
		land = rgb(40, 58, 70),
		orb = rgb(255, 236, 190),
	},
	{ top = rgb(26, 30, 58), bottom = rgb(70, 50, 82), land = rgb(14, 12, 18), orb = rgb(236, 128, 70) },
	{ top = rgb(60, 70, 96), bottom = rgb(170, 140, 150), land = rgb(30, 34, 30), orb = rgb(240, 232, 214) },
}

local function paint(canvas: BasePart, face: Enum.NormalId, style: number)
	local spec = PAINTINGS[(style - 1) % #PAINTINGS + 1]
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(240, 180)
	gui.LightInfluence = 1
	gui.Parent = canvas
	local sky = Instance.new("Frame")
	sky.Size = UDim2.fromScale(1, 1)
	sky.BorderSizePixel = 0
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(spec.top, spec.bottom)
	gradient.Parent = sky
	local orb = Instance.new("Frame")
	orb.AnchorPoint = Vector2.new(0.5, 0.5)
	orb.Position = UDim2.fromScale(0.68, 0.42)
	orb.Size = UDim2.fromOffset(46, 46)
	orb.BorderSizePixel = 0
	orb.BackgroundColor3 = spec.orb
	orb.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = orb
	for i, hill in { { 0.25, 0.68, 0.7 }, { 0.75, 0.74, 0.9 } } do
		local land = Instance.new("Frame")
		land.AnchorPoint = Vector2.new(0.5, 0)
		land.Position = UDim2.fromScale(hill[1], hill[2])
		land.Size = UDim2.fromScale(hill[3], 0.6)
		land.BorderSizePixel = 0
		land.BackgroundColor3 = spec.land
		land.ZIndex = 2 + i
		land.Parent = gui
		local hump = Instance.new("UICorner")
		hump.CornerRadius = UDim.new(0.5, 0)
		hump.Parent = land
	end
end

function TrainInterior.furnish(model: Model, origin: CFrame, dims: Dims): Furnished
	local seats: { Seat } = {}
	local LI = dims.lineIn
	local CEIL = dims.ceiling

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
		local canvas =
			decor(Vector3.new(0.05, 1.56, 2.16), at(x + inward * 0.155, 5.55, z), C.cream, M.SmoothPlastic)
		canvas.Name = "Painting"
		paint(canvas, if inward > 0 then Enum.NormalId.Right else Enum.NormalId.Left, style)
	end

	-- Crew saloon ---------------------------------------------------------------------------------

	-- A velvet banquette for two against wall `side` (1 platform, -1 far), its sitters facing `facing` (1 = +X).
	local BENCH_Z = 3.56 -- the bench's middle, out from the aisle
	local BENCH_W = 4.12
	local function bench(x: number, side: number, facing: number)
		local yaw = if facing > 0 then -90 else 90
		local zc = side * BENCH_Z
		solid(Vector3.new(2.55, 1.4, BENCH_W), at(x - facing * 0.275, 0.7, zc), C.woodDark, M.Wood)
		for k = -1, 1, 2 do
			seat(
				Vector3.new(1.95, 0.5, 2.0),
				at(x, 1.65, zc + k * 1.03) * Kit.angles(0, yaw, 0),
				C.velvet,
				"Saloon seat"
			)
		end
		local back = at(x - facing * 1.275, 3.0, zc) * Kit.angles(0, 0, facing * 8)
		solid(Vector3.new(0.55, 3.2, BENCH_W), back, C.velvet, M.Fabric)
		decor(Vector3.new(0.6, 0.16, BENCH_W + 0.08), back * CFrame.new(0, 1.66, 0), C.woodDark, M.Wood)
		for k = -1, 1, 2 do
			decor(
				Vector3.new(0.06, 0.85, 1.4),
				back * CFrame.new(facing * 0.305, 1.0, k * 1.03),
				C.lace,
				M.Fabric
			)
		end
		-- the armrest at the aisle end
		solid(Vector3.new(2.0, 0.24, 0.3), at(x, 2.45, side * 1.66), C.woodDark, M.Wood)
		decor(Vector3.new(0.22, 0.56, 0.22), at(x + facing * 0.75, 2.05, side * 1.66), C.woodDark, M.Wood)
	end

	local TABLE_THINGS = { "Cup", "Book", "Cup", "Candle" }
	local function bay(x0: number, side: number, index: number)
		bench(x0 + 1.55, side, 1)
		bench(x0 + 5.75, side, -1)
		local tx = x0 + 3.65
		-- the table, wall-hung with a brass pedestal at the aisle end
		solid(Vector3.new(2.0, 0.16, 3.3), at(tx, 3.08, side * 3.95), C.polish, M.Wood)
		post(2.9, 0.3, at(tx, 1.45, side * 2.75), C.brass, M.Metal, true)
		disc(0.08, 1.0, at(tx, 0.04, side * 2.75), C.brass, M.Metal)
		decor(Vector3.new(0.6, 0.06, 0.6), at(tx, 2.97, side * 2.75), C.brass, M.Metal)
		-- its lamp: a brass column under a silk shade
		disc(0.08, 0.6, at(tx, 3.2, side * 5.0), C.brass, M.Metal)
		post(0.8, 0.1, at(tx, 3.64, side * 5.0), C.brass, M.Metal)
		post(0.5, 0.95, at(tx, 4.25, side * 5.0), C.shade, M.Fabric)
		local bulb = Kit.neon(model, Vector3.one * 0.3, at(tx, 4.05, side * 5.0), C.warm, Enum.PartType.Ball)
		Kit.pointLight(bulb, C.warm, 0.6, 11, false)
		local thing = TABLE_THINGS[(index - 1) % #TABLE_THINGS + 1]
		if thing == "Cup" then
			disc(0.04, 0.7, at(tx - 0.4, 3.18, side * 3.2), C.cream, M.SmoothPlastic)
			post(0.4, 0.36, at(tx - 0.4, 3.4, side * 3.2), C.cream, M.SmoothPlastic)
		elseif thing == "Book" then
			decor(
				Vector3.new(0.9, 0.18, 0.66),
				at(tx + 0.25, 3.25, side * 3.55) * Kit.angles(0, 15, 0),
				rgb(70, 40, 44),
				M.SmoothPlastic
			)
		else
			post(0.7, 0.18, at(tx + 0.3, 3.51, side * 3.4), C.cream, M.SmoothPlastic)
			disc(0.06, 0.5, at(tx + 0.3, 3.19, side * 3.4), C.brass, M.Metal)
		end
	end

	-- four bays a side, the door and the route table between them
	local bayIndex = 0
	for _, x0 in { -62.0, -54.0, -40.0, -32.0 } do
		for _, side in { 1, -1 } do
			bayIndex += 1
			bay(x0, side, bayIndex)
		end
	end
	-- luggage on the racks
	for i, spot in
		{
			{ x = -60, side = 1 },
			{ x = -51.5, side = -1 },
			{ x = -45.5, side = 1 },
			{ x = -37, side = -1 },
			{ x = -29.5, side = 1 },
			{ x = -26.2, side = -1 },
		}
	do
		local width = 1.4 + (i % 3) * 0.3
		decor(
			Vector3.new(width, 0.62, 0.9),
			at(spot.x, 8.11, spot.side * (LI - 0.975)) * Kit.angles(0, (i % 2) * 6 - 3, 0),
			if i % 2 == 0 then C.leather else rgb(70, 64, 54),
			M.Leather
		)
		decor(Vector3.new(0.5, 0.08, 0.1), at(spot.x, 8.47, spot.side * (LI - 0.975)), C.brass, M.Metal)
	end
	disc(0.5, 0.8, at(-33.6, 8.06, -(LI - 0.975)), rgb(120, 96, 70), M.Fabric) -- a hat box
	-- paintings of the line either side of each gangway door
	picture(-62.38, 4.0, 1, 1)
	picture(-62.38, -4.0, 1, 2)
	picture(-23.62, 4.0, -1, 3)
	picture(-23.62, -4.0, -1, 4)
	doorSign(Vector3.new(-62.29, 7.66, 0), Vector3.new(1, 0, 0), "GUARD'S VAN")
	doorSign(Vector3.new(-23.71, 7.66, 0), Vector3.new(-1, 0, 0), "WORKSHOP")
	doorSign(Vector3.new(-43, 7.66, LI - 0.29), Vector3.new(0, 0, -1), "PLATFORM")
	nameboard(-49.6, "CREW SALOON")
	-- the route table's brass label
	plate(
		Vector3.new(-43, 3.05, -1.4),
		Vector3.new(0, 0, 1),
		Vector3.new(2.4, 0.3, 0.06),
		C.brass,
		M.Metal,
		"ROUTE TABLE",
		C.board,
		PLATE_FONT,
		1
	)

	-- Guard's van ------------------------------------------------------------------------------------

	-- the pot-bellied stove in the corner, its kettle on the boil
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
	post(0.7, 0.85, at(sx + 0.15, 3.15, sz + 0.25), rgb(40, 38, 40), M.Metal)
	ball(0.22, at(sx + 0.15, 3.56, sz + 0.25), C.brass, M.Metal)
	decor(
		Vector3.new(0.16, 0.16, 0.6),
		at(sx + 0.15, 3.3, sz + 0.75) * Kit.angles(-35, 0, 0),
		rgb(40, 38, 40),
		M.Metal
	)
	decor(Vector3.new(0.7, 0.08, 0.08), at(sx + 0.15, 3.72, sz + 0.25), C.brass, M.Metal)
	-- the fender in front of it, and the coal scuttle
	decor(Vector3.new(2.8, 0.1, 0.1), at(sx, 0.85, sz + 1.62), C.brass, M.Metal)
	for _, dx in { -1.35, 1.35 } do
		decor(Vector3.new(0.1, 0.8, 0.1), at(sx + dx, 0.45, sz + 1.62), C.brass, M.Metal)
	end
	solid(Vector3.new(1.0, 0.9, 1.2), at(sx - 2.3, 0.45, -5.15), C.iron, M.Metal)
	for i = 1, 3 do
		ball(0.42, at(sx - 2.55 + i * 0.22, 0.98, -5.15 + (i % 2) * 0.2), C.coal, M.Slate)
	end
	-- the rug and two wing chairs drawn up to the fire
	-- (each layer a hair thicker than the carpet runner and the one under it)
	decor(Vector3.new(5.0, 0.07, 4.2), at(-73.0, 0.035, -2.4), C.rug, M.Fabric)
	decor(Vector3.new(4.2, 0.08, 3.4), at(-73.0, 0.04, -2.4), C.rugGold, M.Fabric)
	decor(Vector3.new(3.4, 0.09, 2.6), at(-73.0, 0.045, -2.4), C.rug, M.Fabric)
	local function armchair(cx: number, cz: number, yaw: number)
		local f = at(cx, 0, cz) * Kit.angles(0, yaw, 0)
		solid(Vector3.new(2.6, 1.3, 2.4), f * CFrame.new(0, 0.95, 0.1), C.velvetGreen, M.Fabric)
		for _, lx in { -1.05, 1.05 } do
			for _, lz in { -0.95, 1.05 } do
				post(0.3, 0.3, f * CFrame.new(lx, 0.15, lz), C.woodDark, M.Wood)
			end
		end
		seat(
			Vector3.new(2.0, 0.45, 2.0),
			f * CFrame.new(0, 1.825, -0.05),
			Kit.shade(C.velvetGreen, 1.12),
			"Armchair"
		)
		local back = f * CFrame.new(0, 3.0, 1.0) * Kit.angles(8, 0, 0)
		solid(Vector3.new(2.6, 2.6, 0.6), back, C.velvetGreen, M.Fabric)
		decor(Vector3.new(1.4, 0.8, 0.06), back * CFrame.new(0, 0.85, -0.33), C.lace, M.Fabric)
		for _, side in { -1, 1 } do
			solid(
				Vector3.new(0.5, 1.4, 1.0),
				f * CFrame.new(side * 1.02, 3.55, 0.55),
				C.velvetGreen,
				M.Fabric
			)
			solid(
				Vector3.new(0.55, 0.9, 2.3),
				f * CFrame.new(side * 1.3, 2.05, 0.05),
				Kit.shade(C.velvetGreen, 0.9),
				M.Fabric
			)
		end
	end
	armchair(-72.6, -4.0, -90)
	armchair(-69.2, -0.9, 0)
	-- the side table between them: a pot of tea and two cups
	post(2.3, 0.3, at(-71.4, 1.15, -1.7), C.woodDark, M.Wood, true)
	disc(0.14, 1.4, at(-71.4, 2.37, -1.7), C.polish, M.Wood)
	ball(0.62, at(-71.4, 2.72, -1.6), rgb(232, 222, 200), M.SmoothPlastic)
	for _, dz in { -0.45, 0.4 } do
		post(0.26, 0.24, at(-71.0, 2.57, -1.7 + dz), C.cream, M.SmoothPlastic)
	end
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
	doorSign(Vector3.new(-78, 7.66, LI - 0.29), Vector3.new(0, 0, -1), "PLATFORM")
	nameboard(-78.6, "GUARD'S VAN", 6.95)

	-- Workshop -------------------------------------------------------------------------------------

	-- a lamp over the bench
	post(1.6, 0.06, at(0.8, CEIL - 0.8, -4.0), C.iron, M.Metal)
	post(0.45, 1.3, at(0.8, CEIL - 1.82, -4.0), rgb(46, 82, 62), M.Metal)
	local benchLamp =
		Kit.neon(model, Vector3.one * 0.32, at(0.8, CEIL - 2.08, -4.0), C.warm, Enum.PartType.Ball)
	benchLamp.Name = "BenchLamp"
	Kit.pointLight(benchLamp, rgb(255, 232, 196), 0.8, 13, false)
	-- the lathe
	for _, x in { -11.4, -6.6 } do
		solid(Vector3.new(1.2, 2.6, 1.4), at(x, 1.3, -4.7), C.ironLight, M.Metal)
	end
	solid(Vector3.new(6.0, 0.5, 1.2), at(-9.0, 2.85, -4.7), C.iron, M.Metal)
	solid(Vector3.new(1.6, 1.6, 1.3), at(-11.0, 3.9, -4.7), rgb(52, 80, 72), M.Metal)
	Kit.cylinder(
		model,
		0.5,
		1.0,
		at(-9.95, 3.9, -4.7),
		C.ironLight,
		{ material = M.Metal, collide = false, shadow = false }
	)
	Kit.cylinder(
		model,
		3.0,
		0.32,
		at(-8.2, 3.9, -4.7),
		C.brass,
		{ material = M.Metal, collide = false, shadow = false }
	)
	solid(Vector3.new(0.9, 1.1, 1.0), at(-6.4, 3.65, -4.7), rgb(52, 80, 72), M.Metal)
	decor(Vector3.new(1.0, 0.5, 1.1), at(-8.6, 3.35, -4.45), C.iron, M.Metal)
	Kit.cylinder(
		model,
		0.14,
		0.8,
		at(-8.6, 3.05, -3.85) * Kit.angles(0, 90, 0),
		C.ironLight,
		{ material = M.Metal, collide = false, shadow = false }
	)
	-- a cabinet of small drawers against the platform wall
	solid(Vector3.new(4.0, 3.4, 1.1), at(-13.0, 1.7, LI - 0.6), C.wood, M.Wood)
	for row = 0, 3 do
		for col = 0, 3 do
			local dx, dy = -13.0 - 1.5 + col, 0.55 + row * 0.8
			decor(Vector3.new(0.86, 0.62, 0.05), at(dx, dy, LI - 1.175), C.woodDark, M.Wood)
			ball(0.1, at(dx, dy, LI - 1.22), C.brass, M.Metal)
		end
	end
	-- a stool at the bench
	post(2.2, 0.35, at(1.6, 1.1, -2.3), C.woodDark, M.Wood, true)
	seat(Vector3.new(1.3, 0.25, 1.3), at(1.6, 2.325, -2.3), C.leather, "Stool")
	-- the anvil on its stump, under a chain hoist
	post(1.6, 1.4, at(6.6, 0.8, -2.8), C.wood, M.Wood, true)
	solid(Vector3.new(1.0, 0.4, 0.62), at(6.6, 1.8, -2.8), C.iron, M.Metal)
	solid(Vector3.new(1.6, 0.56, 0.7), at(6.6, 2.28, -2.8), C.iron, M.Metal)
	Kit.wedge(
		model,
		Vector3.new(0.6, 0.5, 0.7),
		at(7.7, 2.28, -2.8) * Kit.angles(0, -90, 0),
		C.iron,
		{ material = M.Metal, collide = false, shadow = false }
	)
	post(CEIL - 4.6, 0.08, at(6.6, (CEIL + 4.6) / 2, -2.8), C.iron, M.Metal)
	decor(Vector3.new(0.5, 0.5, 0.18), at(6.6, 4.35, -2.8), C.iron, M.Metal)
	-- a spare wheel leaning on the wall
	Kit.cylinder(
		model,
		0.5,
		3.4,
		at(16.8, 1.75, LI - 0.5) * Kit.angles(0, 90, 0) * Kit.angles(0, 0, -6),
		C.iron,
		{ material = M.Metal, collide = false, shadow = false }
	)
	plate(
		Vector3.new(0, 8.25, -(LI - 0.09)),
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
	doorSign(Vector3.new(0, 7.66, LI - 0.29), Vector3.new(0, 0, -1), "PLATFORM")
	nameboard(-6.6, "WORKSHOP")
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
	carBoard(-43, 22, "LAST TRAIN OUT  ·  CREW SALOON")
	carBoard(0, 15, "WORKSHOP")
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
