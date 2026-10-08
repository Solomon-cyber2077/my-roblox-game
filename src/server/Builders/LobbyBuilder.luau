--!strict
--[[
	The Depot Hall: a Victorian train shed where players wait between runs.

	  * an arched roof on iron trusses: slate over the eaves, dirty glazing over
	    the middle on purlins and glazing bars, glazed gables at both ends
	  * the platform (stone flags, a quarry-tile walk and a rosette) and, across
	    the edge, the display train on its own road between the platform and a
	    tall-windowed far wall; the road runs out through dark portals
	  * the departure board (ready status), the Outfitter kiosk (shop), the
	    Ledger board (milestones), benches, luggage, posters and a clock
	  * warm lamplight: platform lamp standards, wall sconces and pendants, a
	    few of them casting shadows

	Local axes: +X along the platform, +Z from the track toward the back wall,
	y = 0 is the platform surface. Parts that cross are given distinct
	thicknesses so no two visible faces ever share a plane (lune run audit).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require(ReplicatedStorage.Shared.Config.Audio)
local Kit = require(ReplicatedStorage.Shared.Visual.Kit)
local PosterArt = require(script.Parent.PosterArt)
local TrainBuilder = require(script.Parent.TrainBuilder)

export type Built = {
	model: Model,
	spawnPoints: { CFrame },
	board: BasePart,
	outfitter: BasePart,
	ledger: BasePart,
	displayTrain: Model,
	displayCabins: { Cabin },
}

export type Cabin = TrainBuilder.Cabin

local LobbyBuilder = {}

local C = {
	marble = Color3.fromRGB(176, 182, 184), -- grey-veined counter tops
	paving = Color3.fromRGB(86, 94, 104), -- the platform's blue-grey stone flags (cool, so the lamps cannot turn them buff)
	slateDark = Color3.fromRGB(38, 40, 44), -- borders, joints and the rosette's rings
	quarry = Color3.fromRGB(84, 38, 34), -- oxblood quarry tiles along the walk
	glazed = Color3.fromRGB(34, 76, 62), -- the green glazed-tile dado
	bullnose = Color3.fromRGB(92, 32, 30), -- the dado's capping tiles
	brick = Color3.fromRGB(104, 60, 48), -- sooty London stock
	brickDark = Color3.fromRGB(80, 46, 38),
	stone = Color3.fromRGB(156, 154, 148),
	iron = Color3.fromRGB(38, 44, 42),
	ironLight = Color3.fromRGB(58, 66, 62),
	slate = Color3.fromRGB(56, 58, 64),
	glass = Color3.fromRGB(150, 170, 168),
	night = Color3.fromRGB(46, 58, 80),
	warm = Color3.fromRGB(255, 206, 140),
	flame = Color3.fromRGB(236, 142, 64), -- lamp glass: neon blooms toward white, so it starts deep amber
	dusk = Color3.fromRGB(200, 128, 66), -- lit glass: amber, too dim to glare (paler reads as cream)
	fill = Color3.fromRGB(255, 236, 218), -- lamplight, but not orange: surfaces keep their colour
	board = Color3.fromRGB(22, 26, 34),
	brass = Color3.fromRGB(201, 160, 82),
	canvas = Color3.fromRGB(132, 46, 52),
	porcelain = Color3.fromRGB(220, 228, 232), -- cups, plates, piano keys, the clock face: a cold white
	gilt = Color3.fromRGB(214, 172, 92), -- gold-leaf lettering
	wood = Color3.fromRGB(110, 80, 54),
	slats = Color3.fromRGB(128, 92, 58),
	ballast = Color3.fromRGB(70, 66, 62),
	void = Color3.fromRGB(8, 8, 10),
}

-- Hall dimensions.
local HALF_X = 112 -- inner face of the end walls
local BACK_Z = 72 -- inner face of the back wall
local FRONT_Z = -46 -- inner face of the far wall across the display road
local EDGE_Z = -21 -- platform edge
local TRACK_Z = -28
local SPRING = 22 -- height where the roof arch springs from the walls
local RISE = 24
local WALL_TOP = 36
local SEGMENTS = 12
local BAY = 22 -- truss spacing along the hall

local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, canvas: Vector2?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = canvas or Vector2.new(800, 160)
	gui.LightInfluence = 0.55
	gui.Parent = part
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold)
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextScaled = true
	textLabel.TextWrapped = true
	textLabel.Parent = gui
end

-- Height of the roof arch at z.
local function archY(z: number): number
	local t = (z - FRONT_Z) / (BACK_Z - FRONT_Z)
	return SPRING + RISE * math.sin(math.pi * math.clamp(t, 0, 1))
end

function LobbyBuilder.build(origin: CFrame, parent: Instance): Built
	local model = Kit.model("DepotHall")
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local function block(
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?,
		options: Kit.Options?
	): BasePart
		local opts: Kit.Options = options or {}
		return Kit.block(model, size, cf, color, {
			material = material or opts.material,
			collide = opts.collide,
			shadow = opts.shadow,
			transparency = opts.transparency,
			reflectance = opts.reflectance,
		})
	end
	local function decor(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		return block(size, cf, color, material, { collide = false, shadow = false })
	end
	-- A straight member between two points in hall space.
	local function member(
		a: Vector3,
		b: Vector3,
		width: number,
		depth: number,
		color: Color3,
		collide: boolean?
	)
		block(
			Vector3.new(width, depth, (b - a).Magnitude),
			origin * Kit.between(a, b),
			color,
			Enum.Material.Metal,
			{ collide = collide == true, shadow = true }
		)
	end

	-- Platform floor: stone flags laid in bays between granite joints under the columns, a slate
	-- border along the walls and an oxblood quarry-tile walk down the hall with the rosette in it
	local WALK0, WALK1 = 20, 28
	local floorX0, floorX1 = -HALF_X + 1, HALF_X - 1
	local BORDER = 3
	block(
		Vector3.new(floorX1 - floorX0, 1, BORDER),
		at(0, -0.5, BACK_Z - BORDER / 2),
		C.slateDark,
		Enum.Material.Slate
	)
	for _, side in { -1, 1 } do
		block(
			Vector3.new(BORDER, 1, BACK_Z - BORDER - EDGE_Z),
			at(side * (HALF_X - 1 - BORDER / 2), -0.5, (EDGE_Z + BACK_Z - BORDER) / 2),
			C.slateDark,
			Enum.Material.Slate
		)
	end
	local fx0, fx1 = floorX0 + BORDER, floorX1 - BORDER
	block(
		Vector3.new(fx1 - fx0, 1, WALK1 - WALK0),
		at(0, -0.5, (WALK0 + WALK1) / 2),
		C.quarry,
		Enum.Material.CeramicTiles
	)
	local rosette = Vector3.new(0, 0, 24)
	local rings = {
		{ diameter = 30, color = C.slateDark, material = Enum.Material.Slate },
		{ diameter = 26, color = C.glazed, material = Enum.Material.Slate },
		{ diameter = 20, color = C.brass, material = Enum.Material.Metal },
		{ diameter = 18, color = C.slateDark, material = Enum.Material.Slate },
	}
	for _, z in { WALK0 + 0.25, WALK1 - 0.25 } do
		local halfWidth = 0.15
		local nearestZ = math.max(math.abs(z - rosette.Z) - halfWidth, 0)
		local cutoff = math.sqrt((rings[1].diameter / 2) ^ 2 - nearestZ ^ 2)
		for _, bounds in { { fx0, rosette.X - cutoff }, { rosette.X + cutoff, fx1 } } do
			local x0, x1 = bounds[1], bounds[2]
			if x1 > x0 then
				decor(
					Vector3.new(x1 - x0, 0.04, 0.3),
					at((x0 + x1) / 2, 0.02, z),
					C.brass,
					Enum.Material.Metal
				)
			end
		end
	end
	local JOINT = 0.8
	local joints: { number } = {}
	for x = -99, 99, BAY do
		table.insert(joints, x)
	end
	for _, zone in { { EDGE_Z, WALK0 }, { WALK1, BACK_Z - BORDER } } do
		local za, zb = zone[1], zone[2]
		local from = fx0
		for k = 1, #joints + 1 do
			local to = if k <= #joints then joints[k] - JOINT / 2 else fx1
			block(
				Vector3.new(to - from, 1, zb - za),
				at((from + to) / 2, -0.5, (za + zb) / 2),
				Kit.jitter(C.paving, 0.05, ((k * 7) % 10) / 10),
				Enum.Material.Slate
			)
			if k <= #joints then
				block(
					Vector3.new(JOINT, 1, zb - za),
					at(joints[k], -0.5, (za + zb) / 2),
					C.slateDark,
					Enum.Material.Slate
				)
				from = joints[k] + JOINT / 2
			end
		end
	end
	for ring, spec in rings do
		local disc = Kit.cylinder(
			model,
			0.04 * ring,
			spec.diameter,
			at(rosette.X, 0.02 * ring, rosette.Z) * Kit.angles(0, 0, 90),
			spec.color,
			{
				material = spec.material,
				collide = false,
				shadow = false,
			}
		)
		disc.Name = "Rosette"
	end
	for k = 0, 3 do
		local length = if k % 2 == 0 then 17 else 11
		decor(
			Vector3.new(length, 0.2 + 0.02 * k, 1.1),
			at(rosette.X, 0.1 + 0.01 * k, rosette.Z) * Kit.angles(0, k * 45, 0) * Kit.angles(0, 0, 0),
			if k % 2 == 0 then C.brass else C.glazed,
			Enum.Material.Metal
		)
	end

	-- Platform edge: coping, the yellow line and the brick face down to the road
	block(Vector3.new(2 * HALF_X, 0.3, 1.4), at(0, 0.15, EDGE_Z + 0.7), C.stone, Enum.Material.Concrete)
	decor(Vector3.new(2 * HALF_X, 0.06, 0.7), at(0, 0.03, EDGE_Z + 2.4), Color3.fromRGB(226, 182, 58))
	block(Vector3.new(2 * HALF_X, 7.25, 0.6), at(0, -7.25 / 2, EDGE_Z - 0.3), C.brick, Enum.Material.Brick)

	-- The display road -----------------------------------------------------------------------------
	local roadDepth = (EDGE_Z - 0.6) - FRONT_Z
	block(
		Vector3.new(2 * HALF_X, 1.2, roadDepth),
		at(0, -7.85, FRONT_Z + roadDepth / 2),
		C.brickDark,
		Enum.Material.Brick
	)
	-- ballast up to the platform face, which it tucks under
	local ballastFar, ballastNear = TRACK_Z - 7, EDGE_Z - 0.6
	block(
		Vector3.new(2 * HALF_X, 1, ballastNear - ballastFar),
		at(0, -6.75, (ballastFar + ballastNear) / 2),
		C.ballast,
		Enum.Material.Pebble
	)
	for x = -HALF_X + 1.5, HALF_X - 1.5, 3 do
		decor(Vector3.new(1.3, 0.5, 9), at(x, -6.0, TRACK_Z), Color3.fromRGB(74, 56, 40), Enum.Material.Wood)
	end
	for _, side in { -1, 1 } do
		decor(
			Vector3.new(2 * HALF_X + 60, 0.55, 0.5),
			at(0, -5.475, TRACK_Z + side * 2.6),
			Color3.fromRGB(120, 116, 112),
			Enum.Material.Metal
		)
	end
	local display = TrainBuilder.build(at(0, 0, TRACK_Z), model)
	display.model.Name = "DisplayTrain"
	-- seen from the platform, the display train's cabin lamps need no shadows, and its little
	-- table and desk lamps none at all: the ceiling globes light its windows
	for _, descendant in display.model:GetDescendants() do
		if descendant:IsA("PointLight") then
			descendant.Shadows = false
			if descendant.Range <= 11 then
				descendant.Enabled = false
			end
		end
	end
	for _, blocker in display.doorBlockers do
		blocker.CanCollide = true
	end
	-- invisible barriers fill the open gaps between the display train's cars, from the ballast up
	-- to the roofline, so nobody walks or drops between them; their tops are flush with the roofs
	-- to walk across. Gangways are closed too: each car is its own boarding room, entered only by
	-- its door prompt (CarService), and the brake van's rear doorway is shut off its tail platform.
	local GAP_BOTTOM, GAP_TOP = -6, 9.8
	local function gapBarrier(x0: number, x1: number, z0: number, z1: number)
		local barrier = block(
			Vector3.new(x1 - x0, GAP_TOP - GAP_BOTTOM, z1 - z0),
			at((x0 + x1) / 2, (GAP_TOP + GAP_BOTTOM) / 2, TRACK_Z + (z0 + z1) / 2),
			Color3.new(),
			nil,
			{ transparency = 1, shadow = false }
		)
		barrier.Name = "GapBarrier"
		barrier.CanQuery = false
		barrier.CanTouch = false
	end
	for _, gap in { { -66, -63 }, { -44.5, -41.5 }, { -23, -20 }, { -1.5, 1.5 }, { 20, 23 }, { 49, 52 } } do
		gapBarrier(gap[1], gap[2], -6.5, 6.5)
	end
	gapBarrier(-90.6, -90, -2.5, 2.5)

	-- Walls ----------------------------------------------------------------------------------------
	-- back wall with tall lit windows, the ticket office and the departure board
	block(
		Vector3.new(2 * HALF_X + 4, WALL_TOP + 8, 2),
		at(0, (WALL_TOP + 8) / 2 - 8, BACK_Z + 1),
		C.brick,
		Enum.Material.Brick
	)
	block(Vector3.new(2 * HALF_X, 1.2, 0.6), at(0, 0.6, BACK_Z - 0.3), C.stone, Enum.Material.Concrete)
	-- a dado of green glazed tiles above the plinth, capped by a row of oxblood bullnose, on the back
	-- wall and along both end walls of the platform (a hair off the brick, so nothing set against
	-- the wall shares its plane)
	local DADO_LOW, DADO_TOP = 1.2, 5.2
	decor(
		Vector3.new(2 * HALF_X, DADO_TOP - DADO_LOW, 0.15),
		at(0, (DADO_LOW + DADO_TOP) / 2, BACK_Z - 0.095),
		C.glazed,
		Enum.Material.CeramicTiles
	)
	decor(
		Vector3.new(2 * HALF_X, 0.4, 0.3),
		at(0, DADO_TOP + 0.2, BACK_Z - 0.17),
		C.bullnose,
		Enum.Material.Glass
	)
	for _, side in { -1, 1 } do
		decor(
			Vector3.new(0.15, DADO_TOP - DADO_LOW, BACK_Z - 0.17 - EDGE_Z),
			at(side * (HALF_X - 0.095), (DADO_LOW + DADO_TOP) / 2, (EDGE_Z + BACK_Z - 0.17) / 2),
			C.glazed,
			Enum.Material.CeramicTiles
		)
		decor(
			Vector3.new(0.3, 0.4, BACK_Z - 0.32 - EDGE_Z),
			at(side * (HALF_X - 0.17), DADO_TOP + 0.2, (EDGE_Z + BACK_Z - 0.32) / 2),
			C.bullnose,
			Enum.Material.Glass
		)
	end
	for _, x in { -90, -66, 66, 90 } do
		decor(Vector3.new(11, 15, 0.3), at(x, 18, BACK_Z - 0.15), C.iron, Enum.Material.Metal)
		decor(Vector3.new(10, 14, 0.3), at(x, 18, BACK_Z - 0.4), C.dusk, Enum.Material.Neon).Transparency =
			0.62
		for k = -1, 1 do
			decor(Vector3.new(0.25, 14, 0.2), at(x + k * 2.6, 18, BACK_Z - 0.62), C.iron, Enum.Material.Metal)
		end
		decor(Vector3.new(12, 1.2, 0.8), at(x, 25.8, BACK_Z - 0.4), C.stone, Enum.Material.Limestone)
	end
	-- the far wall across the road, its windows showing the night outside
	local farHeight = WALL_TOP + 12
	block(
		Vector3.new(2 * HALF_X + 4, farHeight, 2),
		at(0, farHeight / 2 - 12, FRONT_Z - 1),
		C.brick,
		Enum.Material.Brick
	)
	for x = -99, 99, BAY do
		decor(Vector3.new(9, 13, 0.3), at(x, 8.5, FRONT_Z + 0.15), C.iron, Enum.Material.Metal)
		decor(Vector3.new(8, 12, 0.3), at(x, 8.5, FRONT_Z + 0.4), C.night, Enum.Material.Neon).Transparency =
			0.35
		for k = -1, 1, 2 do
			decor(
				Vector3.new(0.25, 12, 0.2),
				at(x + k * 1.6, 8.5, FRONT_Z + 0.62),
				C.iron,
				Enum.Material.Metal
			)
		end
		decor(Vector3.new(10, 1.2, 0.8), at(x, 15.6, FRONT_Z + 0.4), C.stone, Enum.Material.Limestone)
	end
	-- end walls, with an arched portal where the display road runs out into the dark
	local portalLow, portalHigh = -7.25, 17
	local portalZ0, portalZ1 = TRACK_Z - 8, EDGE_Z - 0.6
	for _, side in { -1, 1 } do
		local x = side * (HALF_X + 1)
		-- platform part of the wall
		block(
			Vector3.new(2, WALL_TOP, BACK_Z - EDGE_Z),
			at(x, WALL_TOP / 2, (BACK_Z + EDGE_Z) / 2),
			C.brick,
			Enum.Material.Brick
		)
		-- road part: either side of the portal and over it
		block(
			Vector3.new(2, WALL_TOP + 12, portalZ0 - FRONT_Z),
			at(x, (WALL_TOP + 12) / 2 - 12, (portalZ0 + FRONT_Z) / 2),
			C.brick,
			Enum.Material.Brick
		)
		block(
			Vector3.new(2, 12 - 7.25, EDGE_Z - portalZ1),
			at(x, -12 + (12 - 7.25) / 2, (EDGE_Z + portalZ1) / 2),
			C.brick,
			Enum.Material.Brick
		)
		block(
			Vector3.new(2, 7.25 + WALL_TOP, EDGE_Z - portalZ1),
			at(x, (WALL_TOP - 7.25) / 2, (EDGE_Z + portalZ1) / 2),
			C.brick,
			Enum.Material.Brick
		)
		block(
			Vector3.new(2, WALL_TOP - portalHigh, portalZ1 - portalZ0),
			at(x, (WALL_TOP + portalHigh) / 2, (portalZ0 + portalZ1) / 2),
			C.brick,
			Enum.Material.Brick
		)
		decor(
			Vector3.new(2.6, 1.8, portalZ1 - portalZ0 + 3),
			at(x, portalHigh + 0.7, (portalZ0 + portalZ1) / 2),
			C.stone,
			Enum.Material.Limestone
		)
		-- the tunnel beyond: dark walls fading into nothing
		local depth = 50
		local tx = side * (HALF_X + 2 + depth / 2)
		local tunnelWidth = portalZ1 - portalZ0
		local tz = (portalZ0 + portalZ1) / 2
		decor(
			Vector3.new(depth, 1, tunnelWidth + 2),
			at(tx, portalLow - 0.5, tz),
			C.void,
			Enum.Material.Slate
		)
		decor(
			Vector3.new(depth, 1, tunnelWidth + 2),
			at(tx, portalHigh + 0.5, tz),
			C.void,
			Enum.Material.Slate
		)
		for _, wz in { portalZ0 - 0.5, portalZ1 + 0.5 } do
			decor(
				Vector3.new(depth, portalHigh - portalLow, 1),
				at(tx, (portalHigh + portalLow) / 2, wz),
				C.void,
				Enum.Material.Slate
			)
		end
		decor(
			Vector3.new(1, portalHigh - portalLow, tunnelWidth),
			at(side * (HALF_X + 2 + depth), (portalHigh + portalLow) / 2, tz),
			Color3.new(),
			Enum.Material.SmoothPlastic
		)
	end
	-- invisible bounds keep players on the platform and the road
	local bounds: { { size: Vector3, cframe: CFrame } } = {
		{ size = Vector3.new(2 * HALF_X + 10, 80, 2), cframe = at(0, 40, FRONT_Z - 0.5) },
		{ size = Vector3.new(2 * HALF_X + 10, 80, 2), cframe = at(0, 40, BACK_Z + 0.5) },
		{
			size = Vector3.new(2, 80, BACK_Z - FRONT_Z + 10),
			cframe = at(-HALF_X - 0.5, 40, (BACK_Z + FRONT_Z) / 2),
		},
		{
			size = Vector3.new(2, 80, BACK_Z - FRONT_Z + 10),
			cframe = at(HALF_X + 0.5, 40, (BACK_Z + FRONT_Z) / 2),
		},
		{
			size = Vector3.new(2 * HALF_X + 10, 2, BACK_Z - FRONT_Z + 10),
			cframe = at(0, archY(12) + 4, (BACK_Z + FRONT_Z) / 2),
		},
	}
	for _, bound in bounds do
		block(bound.size, bound.cframe, Color3.new(), nil, { transparency = 1, shadow = false })
	end

	-- Columns and trusses ------------------------------------------------------------------------
	local points: { Vector3 } = {}
	for i = 0, SEGMENTS do
		local z = FRONT_Z + (BACK_Z - FRONT_Z) * i / SEGMENTS
		table.insert(points, Vector3.new(0, archY(z), z))
	end
	for x = -99, 99, BAY do
		-- cast-iron columns on the platform: plinth, fluted shaft, collar and capital
		for _, z in { -14, 44 } do
			block(Vector3.new(2.6, 1.4, 2.6), at(x, 0.7, z), C.iron, Enum.Material.Metal)
			Kit.post(
				model,
				SPRING - 2.6,
				1.3,
				at(x, 1.4 + (SPRING - 2.6) / 2, z),
				C.iron,
				{ material = Enum.Material.Metal }
			)
			Kit.post(
				model,
				0.5,
				1.7,
				at(x, 5, z),
				C.brass,
				{ material = Enum.Material.Metal, collide = false }
			)
			Kit.post(
				model,
				1.2,
				2.2,
				at(x, SPRING - 0.6, z),
				C.ironLight,
				{ material = Enum.Material.Metal, collide = false }
			)
			-- curved brackets up into the truss
			for _, dz in { -1, 1 } do
				member(
					Vector3.new(x, SPRING - 6, z),
					Vector3.new(x, SPRING + 0.4, z + dz * 6),
					0.42,
					0.42,
					C.iron
				)
			end
		end
		-- the truss: an arched rib, a lower chord and braces between them
		for i = 1, SEGMENTS do
			local a, b = points[i], points[i + 1]
			local thick = if i % 2 == 0 then 0.8 else 0.76
			member(Vector3.new(x, a.Y, a.Z), Vector3.new(x, b.Y, b.Z), thick, thick, C.iron)
		end
		member(
			Vector3.new(x, SPRING + 0.6, FRONT_Z + 1),
			Vector3.new(x, SPRING + 0.6, BACK_Z - 1),
			0.5,
			0.5,
			C.iron
		)
		for i = 2, SEGMENTS, 2 do
			local p = points[i]
			if p.Y > SPRING + 2 then
				member(
					Vector3.new(x, SPRING + 0.9, p.Z),
					Vector3.new(x, p.Y - 0.5, p.Z),
					0.3,
					0.3,
					C.ironLight
				)
			end
		end
		-- a pendant lamp hanging from the tie: chain, brass shade, glowing globe
		local pendantZ = 15
		decor(
			Vector3.new(0.12, SPRING + 0.3 - 19.5, 0.12),
			at(x, (SPRING + 0.3 + 19.5) / 2, pendantZ),
			C.iron,
			Enum.Material.Metal
		)
		Kit.cylinder(
			model,
			0.7,
			3,
			at(x, 19.2, pendantZ) * Kit.angles(0, 0, 90),
			C.brass,
			{ material = Enum.Material.Metal, collide = false }
		)
		local lamp =
			Kit.neon(model, Vector3.new(1.4, 1.4, 1.4), at(x, 18.4, pendantZ), C.warm, Enum.PartType.Ball)
		Kit.pointLight(lamp, C.warm, 0.7, 38, (x + 99) % 44 == 0)
	end
	-- purlins along the hall at every rib joint, carrying the roof
	for i = 2, SEGMENTS do
		local p = points[i]
		block(
			Vector3.new(2 * HALF_X, 0.5, 0.5),
			at(0, p.Y + 0.15, p.Z),
			C.iron,
			Enum.Material.Metal,
			{ collide = false, shadow = true }
		)
	end

	-- Fill: soft lights high between the trusses wash the whole hall evenly, so the lamps below
	-- only warm it and no corner or poster sits in a hot spot
	for _, x in { -66, -22, 22, 66 } do
		local fill = block(
			Vector3.one,
			at(x, 30, 13),
			C.fill,
			nil,
			{ transparency = 1, collide = false, shadow = false }
		)
		fill.Name = "FillLight"
		Kit.pointLight(fill, C.fill, 0.85, 60, false)
	end
	-- a back row reaches the departure board and back wall, out of range of the row above
	for _, x in { -44, 0, 44 } do
		local fill = block(
			Vector3.one,
			at(x, 26, BACK_Z - 20),
			C.fill,
			nil,
			{ transparency = 1, collide = false, shadow = false }
		)
		fill.Name = "FillLight"
		Kit.pointLight(fill, C.fill, 0.85, 45, false)
	end

	-- Roof: slate over the eaves, dirty glass over the middle on glazing bars --------------------------
	for i = 1, SEGMENTS do
		local a, b = points[i], points[i + 1]
		local glazed = i > 2 and i <= SEGMENTS - 2
		local pa, pb = Vector3.new(0, a.Y + 0.65, a.Z), Vector3.new(0, b.Y + 0.65, b.Z)
		local panel = block(
			Vector3.new(2 * HALF_X + 2, 0.3, (pb - pa).Magnitude + 0.05),
			origin * Kit.between(pa, pb),
			if glazed then C.glass else C.slate,
			if glazed then Enum.Material.Glass else Enum.Material.RoofShingles,
			{ collide = false, shadow = not glazed, transparency = if glazed then 0.45 else 0 }
		)
		panel.Name = if glazed then "Glazing" else "Slates"
		if glazed then
			for x = -HALF_X + BAY / 4, HALF_X - BAY / 4, BAY / 2 do
				member(
					Vector3.new(x, a.Y + 0.42, a.Z),
					Vector3.new(x, b.Y + 0.42, b.Z),
					0.22,
					0.18,
					C.ironLight
				)
			end
		end
	end
	block(
		Vector3.new(2 * HALF_X + 2.4, 0.7, 2.2),
		at(0, SPRING + RISE + 1.1, (FRONT_Z + BACK_Z) / 2),
		C.slate,
		Enum.Material.Metal,
		{ collide = false }
	)
	-- glazed gables above the end walls, framed by an end truss
	for _, side in { -1, 1 } do
		local x = side * (HALF_X - 0.4)
		for i = 1, SEGMENTS do
			local a, b = points[i], points[i + 1]
			local lo = math.min(a.Y, b.Y)
			if lo > WALL_TOP then
				local width = b.Z - a.Z
				local zc = (a.Z + b.Z) / 2
				block(
					Vector3.new(0.3, lo - WALL_TOP, width),
					at(x, (lo + WALL_TOP) / 2, zc),
					C.glass,
					Enum.Material.Glass,
					{ collide = false, shadow = false, transparency = 0.45 }
				)
				local rise = math.abs(b.Y - a.Y)
				if rise > 0.05 then
					-- the sloped top of the bay: a wedge whose tall side faces the higher end
					local yaw = if b.Y > a.Y then 0 else 180
					Kit.wedge(
						model,
						Vector3.new(0.3, rise, width),
						at(x, lo + rise / 2, zc) * Kit.angles(0, yaw, 0),
						C.glass,
						{
							material = Enum.Material.Glass,
							collide = false,
							shadow = false,
							transparency = 0.45,
						}
					)
				end
				-- the mullion stands proud of the glass on both faces and runs up into the truss
				member(
					Vector3.new(x, WALL_TOP, zc),
					Vector3.new(x, (a.Y + b.Y) / 2, zc),
					0.4,
					0.26,
					C.ironLight
				)
			end
		end
		for i = 1, SEGMENTS do
			local a, b = points[i], points[i + 1]
			local thick = if i % 2 == 0 then 0.9 else 0.86
			member(Vector3.new(x, a.Y, a.Z), Vector3.new(x, b.Y, b.Z), thick, thick, C.iron)
		end
		block(
			Vector3.new(0.94, 0.94, BACK_Z - FRONT_Z),
			at(x, WALL_TOP + 0.37, (FRONT_Z + BACK_Z) / 2),
			C.iron,
			Enum.Material.Metal,
			{ collide = false }
		)
	end

	-- Departure board, clock and ticket office -----------------------------------------------------------
	block(Vector3.new(44, 17, 1), at(0, 17, BACK_Z - 0.5), C.iron, Enum.Material.Metal)
	local board = block(Vector3.new(42, 15, 0.6), at(0, 17, BACK_Z - 1.3), C.board, nil, { collide = false })
	board.Name = "DepartureBoard"
	block(
		Vector3.new(16, 3, 0.8),
		at(0, 27.2, BACK_Z - 0.4),
		C.brass,
		Enum.Material.Metal,
		{ collide = false }
	)
	local plate =
		block(Vector3.new(15, 2.4, 0.4), at(0, 27.2, BACK_Z - 1.0), C.board, nil, { collide = false })
	label(plate, Enum.NormalId.Front, "DEPARTURES", C.porcelain)
	-- clock: brass rim, white enamel face, iron hands at ten to midnight
	local clockAt = at(0, 31.6, BACK_Z - 0.6) * Kit.angles(0, 90, 0)
	Kit.cylinder(model, 0.6, 5.4, clockAt, C.brass, { material = Enum.Material.Metal, collide = false })
	Kit.cylinder(
		model,
		0.7,
		4.8,
		clockAt * CFrame.new(-0.04, 0, 0),
		C.porcelain,
		{ material = Enum.Material.SmoothPlastic, collide = false }
	)
	-- the face points into the hall along the frame's +X
	local face = clockAt * CFrame.new(0.36, 0, 0)
	for hour = 0, 11 do
		local angle = math.rad(hour * 30)
		decor(
			Vector3.new(0.1, 0.42, 0.14),
			face * CFrame.new(0, math.cos(angle) * 2.0, math.sin(angle) * 2.0) * CFrame.Angles(-angle, 0, 0),
			C.iron,
			Enum.Material.Metal
		)
	end
	decor(
		Vector3.new(0.12, 1.5, 0.2),
		face * CFrame.new(0.04, 0, 0) * CFrame.Angles(math.rad(5), 0, 0) * CFrame.new(0, 0.75, 0),
		C.iron,
		Enum.Material.Metal
	)
	decor(
		Vector3.new(0.12, 2.0, 0.16),
		face * CFrame.new(0.1, 0, 0) * CFrame.Angles(math.rad(60), 0, 0) * CFrame.new(0, 1.0, 0),
		C.iron,
		Enum.Material.Metal
	)
	-- ticket office windows either side of the board
	for _, x in { -36, 36 } do
		block(Vector3.new(16, 11, 1.4), at(x, 5.5, BACK_Z - 0.7), C.wood, Enum.Material.WoodPlanks)
		decor(Vector3.new(12, 5, 0.3), at(x, 6.8, BACK_Z - 1.5), C.dusk, Enum.Material.Neon).Transparency =
			0.55
		decor(Vector3.new(14, 0.5, 1.2), at(x, 4.1, BACK_Z - 1.8), C.brass, Enum.Material.Metal)
		local sign = decor(Vector3.new(12, 1.8, 0.3), at(x, 10.2, BACK_Z - 1.55), C.board)
		label(sign, Enum.NormalId.Front, "TICKETS", C.gilt)
	end

	-- Outfitter kiosk -------------------------------------------------------------------------------------
	local kx, kz = 54, 36
	block(Vector3.new(14, 4, 4), at(kx, 2, kz), C.wood, Enum.Material.WoodPlanks)
	block(Vector3.new(14.6, 0.4, 4.6), at(kx, 4.2, kz), C.brass, Enum.Material.Metal)
	block(Vector3.new(14, 9, 1), at(kx, 4.5, kz + 6), C.wood, Enum.Material.WoodPlanks)
	for _, x in { -6.5, 6.5 } do
		Kit.post(model, 11, 0.6, at(kx + x, 5.5, kz - 1.5), C.iron, { material = Enum.Material.Metal })
	end
	for i = 0, 6 do
		decor(
			Vector3.new(2, 0.3 + (i % 2) * 0.04, 8),
			at(kx - 6 + i * 2, 11.2 + (i % 2) * 0.02, kz + 2) * Kit.angles(-12, 0, 0),
			if i % 2 == 0 then C.canvas else C.glazed,
			Enum.Material.Fabric
		)
	end
	local outfitterSign = decor(Vector3.new(12, 2.4, 0.4), at(kx, 13.2, kz - 1.8), C.board)
	label(outfitterSign, Enum.NormalId.Front, "OUTFITTER", C.gilt)
	local outfitter = block(
		Vector3.new(12, 6, 4),
		at(kx, 3, kz - 2.5),
		Color3.new(),
		nil,
		{ transparency = 1, collide = false, shadow = false }
	)
	outfitter.Name = "OutfitterPrompt"
	for i = 1, 4 do
		Kit.post(
			model,
			0.8,
			1.2,
			at(kx - 6 + i * 2.4, 6.4, kz + 5.2),
			Color3.fromHSV(i / 5, 0.45, 0.7),
			{ collide = false }
		)
	end
	local kioskLamp = Kit.neon(model, Vector3.new(1, 1, 1), at(kx, 10, kz), C.warm, Enum.PartType.Ball)
	Kit.pointLight(kioskLamp, C.warm, 0.75, 22, false)

	-- Line Mastery: an honours board in a carved frame, the line painted on it in gilt -----------------
	local lx, lz = -54, 36
	block(Vector3.new(18, 13, 1.2), at(lx, 8.5, lz + 4.2), C.wood, Enum.Material.Wood)
	block(Vector3.new(19.4, 1, 1.6), at(lx, 15.5, lz + 4.2), Kit.shade(C.wood, 0.8), Enum.Material.Wood)
	block(Vector3.new(12, 1.4, 1.4), at(lx, 16.7, lz + 4.2), Kit.shade(C.wood, 0.8), Enum.Material.Wood)
	Kit.ball(model, 1.2, at(lx, 18, lz + 4.2), C.brass, { material = Enum.Material.Metal, collide = false })
	for _, x in { -8.4, 8.4 } do
		Kit.post(model, 15, 0.7, at(lx + x, 7.5, lz + 4.4), C.iron, { material = Enum.Material.Metal })
	end
	local ledgerFace = decor(
		Vector3.new(16.6, 11.4, 0.3),
		at(lx, 8.5, lz + 3.45),
		Color3.fromRGB(28, 50, 42),
		Enum.Material.Fabric
	)
	for _, y in { -5.85, 5.85 } do
		decor(Vector3.new(16.9, 0.3, 0.2), at(lx, 8.5 + y, lz + 3.25), C.brass, Enum.Material.Metal)
	end
	for _, x in { -8.4, 8.4 } do
		decor(Vector3.new(0.3, 11.4, 0.24), at(lx + x, 8.5, lz + 3.23), C.brass, Enum.Material.Metal)
	end
	do
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(1000, 690)
		gui.LightInfluence = 0.85
		gui.Parent = ledgerFace
		local gold = Color3.fromRGB(232, 196, 118)
		local pale = C.porcelain
		local function text(content: string, font: Font, color: Color3, pos: UDim2, size: UDim2)
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Position = pos
			t.Size = size
			t.FontFace = font
			t.Text = content
			t.TextColor3 = color
			t.TextScaled = true
			t.Parent = gui
			return t
		end
		text(
			"LINE MASTERY",
			Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold),
			gold,
			UDim2.fromScale(0.08, 0.04),
			UDim2.fromScale(0.84, 0.17)
		)
		text(
			"Every stop you master is painted here in gold",
			Font.new(
				"rbxasset://fonts/families/Merriweather.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Italic
			),
			pale,
			UDim2.fromScale(0.15, 0.22),
			UDim2.fromScale(0.7, 0.07)
		)
		-- the line itself, wandering across the board from the depot to the sea
		local stops = { "Depot", "Halt", "Coaling Yard", "Ashgrove", "Signal Works", "Brannoc", "Market" }
		table.insert(stops, "Viaduct")
		table.insert(stops, "Gallowmere")
		table.insert(stops, "Minehead")
		table.insert(stops, "Terminus")
		local route: { Vector2 } = {}
		for i = 1, #stops do
			local u = (i - 1) / (#stops - 1)
			table.insert(route, Vector2.new(80 + u * 840, 430 + math.sin(u * math.pi * 2.6) * 95))
		end
		for i = 1, #route - 1 do
			local a, b = route[i], route[i + 1]
			local mid = (a + b) / 2
			local seg = Instance.new("Frame")
			seg.AnchorPoint = Vector2.new(0.5, 0.5)
			seg.Position = UDim2.fromOffset(mid.X, mid.Y)
			seg.Size = UDim2.fromOffset((b - a).Magnitude + 4, 8)
			seg.Rotation = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
			seg.BackgroundColor3 = pale
			seg.BorderSizePixel = 0
			seg.Parent = gui
		end
		for i, p in route do
			local last = i == #route
			local dot = Instance.new("Frame")
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromOffset(p.X, p.Y)
			dot.Size = UDim2.fromOffset(if last then 44 else 28, if last then 44 else 28)
			dot.BackgroundColor3 = if last or i == 1 then gold else Color3.fromRGB(28, 50, 42)
			dot.Parent = gui
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = dot
			local ring = Instance.new("UIStroke")
			ring.Color = pale
			ring.Thickness = 5
			ring.Parent = dot
			local below = i % 2 == 0
			text(
				string.upper(stops[i]),
				Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium),
				if last then gold else pale,
				UDim2.fromOffset(p.X - 70, p.Y + (if below then 26 else -62)),
				UDim2.fromOffset(140, 34)
			)
		end
		text(
			"Ask the Ledger at the desk below",
			Font.new("rbxasset://fonts/families/SpecialElite.json"),
			Color3.fromRGB(150, 164, 170),
			UDim2.fromScale(0.25, 0.9),
			UDim2.fromScale(0.5, 0.06)
		)
	end
	-- two gooseneck lamps lean over the board
	for _, x in { -5, 5 } do
		decor(Vector3.new(0.3, 0.3, 2.2), at(lx + x, 15.2, lz + 2.6), C.brass, Enum.Material.Metal)
		decor(
			Vector3.new(1.4, 0.5, 0.9),
			at(lx + x, 14.95, lz + 1.6),
			Color3.fromRGB(40, 62, 52),
			Enum.Material.Metal
		)
		local bulb = Kit.neon(
			model,
			Vector3.new(0.6, 0.6, 0.6),
			at(lx + x, 14.5, lz + 1.6),
			C.warm,
			Enum.PartType.Ball
		)
		Kit.pointLight(bulb, C.warm, 0.55, 14, false)
	end
	local ledger = block(
		Vector3.new(12, 6, 4),
		at(lx, 3, lz + 1),
		Color3.new(),
		nil,
		{ transparency = 1, collide = false, shadow = false }
	)
	ledger.Name = "LedgerPrompt"

	-- Benches: cast-iron ends, slatted seat and back -----------------------------------------------------------
	local function bench(x: number, z: number, facing: number)
		local frame = at(x, 0, z) * Kit.angles(0, if facing > 0 then 0 else 180, 0)
		local function part(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
			Kit.block(model, size, frame * cf, color, { material = material, collide = true, shadow = true })
		end
		for _, sx in { -4.75, 4.75 } do
			part(Vector3.new(0.3, 1.6, 0.3), CFrame.new(sx, 0.8, -0.75), C.iron, Enum.Material.Metal)
			part(
				Vector3.new(0.32, 3.7, 0.3),
				CFrame.new(sx, 1.85, 0.95) * Kit.angles(-12, 0, 0),
				C.iron,
				Enum.Material.Metal
			)
			part(Vector3.new(0.26, 0.24, 1.9), CFrame.new(sx, 1.47, 0), C.iron, Enum.Material.Metal)
			part(Vector3.new(0.36, 0.18, 1.7), CFrame.new(sx, 2.55, -0.25), C.iron, Enum.Material.Metal)
			part(Vector3.new(0.22, 0.95, 0.22), CFrame.new(sx, 2.0, -0.8), C.iron, Enum.Material.Metal)
		end
		for k = -1, 1 do
			part(
				Vector3.new(9.2, 0.15, 0.48),
				CFrame.new(0, 1.665, k * 0.56),
				Kit.shade(C.slats, 1 + k * 0.04),
				Enum.Material.WoodPlanks
			)
		end
		for k = 0, 2 do
			local y = 2.25 + k * 0.6
			part(
				Vector3.new(9.2, 0.42, 0.14),
				CFrame.new(0, y, 1.08 + (y - 1.75) * math.tan(math.rad(12))) * Kit.angles(-12, 0, 0),
				Kit.shade(C.slats, 0.96 + k * 0.04),
				Enum.Material.WoodPlanks
			)
		end
	end
	for _, x in { -80, -30, 30, 80 } do
		bench(x, 8, 1)
		bench(x, 52, -1)
	end

	-- Luggage and trolleys ---------------------------------------------------------------------------------
	for i, x in { -18, 20 } do
		block(Vector3.new(6, 1, 3), at(x, 1.4, 58), C.iron, Enum.Material.Metal)
		for _, wx in { -2.4, 2.4 } do
			Kit.cylinder(
				model,
				2.4,
				1.2,
				at(x + wx, 0.6, 58) * Kit.angles(0, 90, 0),
				C.iron,
				{ material = Enum.Material.Metal, collide = false }
			)
		end
		for j = 0, 2 do
			block(
				Vector3.new(2.2 - j * 0.1, 1.6 - j * 0.12, 1.8 - j * 0.08),
				at(x - 2 + j * 2, 2.7 - j * 0.06 + j * 0.0, 58) * Kit.angles(0, (i + j) * 9, 0),
				Color3.fromHSV((i * 3 + j) / 9, 0.4, 0.45),
				Enum.Material.Leather
			)
		end
	end

	-- Posters on the end walls, above the dado: a travel bill, a bye-law, a propaganda bill, a typed
	-- regulation, a lost-brother appeal and a night warning (PosterArt draws each one). Framed
	-- prints sit in iron frames; the appeal is a notebook page pinned straight to the tiles' cap.
	local slots = { { -1, -4 }, { -1, 12 }, { -1, 40 }, { 1, -4 }, { 1, 12 }, { 1, 40 } }
	for i, kind in PosterArt.Kinds do
		local side, z = slots[i][1], slots[i][2]
		local x = side * (HALF_X - 0.3)
		local posterFace = if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right
		local paper
		if kind == "brother" then
			paper = decor(
				Vector3.new(0.06, 6.6, 5.1),
				at(side * (HALF_X - 0.05), 9.6, z),
				PosterArt.paper(kind),
				Enum.Material.SmoothPlastic
			)
			Kit.ball(
				model,
				0.32,
				at(side * (HALF_X - 0.16), 12.5, z),
				C.canvas,
				{ material = Enum.Material.SmoothPlastic, collide = false, shadow = false }
			)
		else
			local framePart = decor(Vector3.new(0.3, 9.4, 7.4), at(x, 10.6, z), C.iron, Enum.Material.Metal)
			framePart.Name = "PosterFrame"
			paper = decor(
				Vector3.new(0.2, 9, 7),
				at(x - side * 0.2, 10.6, z),
				PosterArt.paper(kind),
				Enum.Material.SmoothPlastic
			)
		end
		paper.Name = "Poster"
		local gui = Instance.new("SurfaceGui")
		gui.Face = posterFace
		-- printed paper: lit by the hall, but not all the way, so the lamps' amber does not turn
		-- every white to cream (and it still never glows)
		gui.LightInfluence = 0.7
		gui.Parent = paper
		PosterArt.draw(gui, kind)
	end

	-- The waiting corner at the west end: a stove, armchairs on a rug, books and a palm ----------------
	local wx, wz = -98, 50
	decor(Vector3.new(16, 0.08, 18), at(wx, 0.04, wz), Color3.fromRGB(110, 36, 34), Enum.Material.Fabric)
	decor(Vector3.new(13, 0.1, 15), at(wx, 0.05, wz), Color3.fromRGB(150, 110, 60), Enum.Material.Fabric)
	-- the stove: squat cast iron with a glowing grate, its flue climbing into the dark
	local stoveAt = at(wx - 10, 0, wz)
	Kit.post(model, 3.6, 3.2, stoveAt * CFrame.new(0, 1.8, 0), C.iron, { material = Enum.Material.Metal })
	block(Vector3.new(3.8, 0.4, 3.8), stoveAt * CFrame.new(0, 3.8, 0), C.ironLight, Enum.Material.Metal)
	Kit.post(
		model,
		26,
		0.9,
		stoveAt * CFrame.new(0, 17, 0),
		C.iron,
		{ material = Enum.Material.Metal, collide = false }
	)
	local grate = Kit.neon(
		model,
		Vector3.new(0.1, 0.8, 1.4),
		stoveAt * CFrame.new(1.62, 1.4, 0),
		Color3.fromRGB(255, 120, 50)
	)
	Kit.pointLight(grate, Color3.fromRGB(255, 150, 80), 0.9, 18, false)
	local chairColor = Color3.fromRGB(70, 92, 76)
	local function armchair(x: number, z: number, yaw: number, wide: number)
		local f = at(x, 0, z) * Kit.angles(0, yaw, 0)
		block(Vector3.new(wide, 1.3, 2.8), f * CFrame.new(0, 0.95, 0), chairColor, Enum.Material.Fabric)
		block(
			Vector3.new(wide - 0.6, 0.35, 2.3),
			f * CFrame.new(0, 1.77, -0.1),
			Kit.shade(chairColor, 1.15),
			Enum.Material.Fabric
		)
		block(
			Vector3.new(wide + 0.2, 3.2, 0.7),
			f * CFrame.new(0, 2.0, 1.25),
			chairColor,
			Enum.Material.Fabric
		)
		for _, s in { -1, 1 } do
			block(
				Vector3.new(0.6, 1.0, 2.9),
				f * CFrame.new(s * (wide / 2 + 0.3), 2.0, -0.05),
				Kit.shade(chairColor, 0.9),
				Enum.Material.Fabric
			)
		end
		for _, s in { -1, 1 } do
			for _, t in { -1, 1 } do
				decor(
					Vector3.new(0.3, 0.3, 0.3),
					f * CFrame.new(s * (wide / 2 - 0.3), 0.15, t * 1.1),
					C.wood,
					Enum.Material.Wood
				)
			end
		end
	end
	armchair(wx - 3, wz - 5, 90, 3)
	armchair(wx - 3, wz + 5, 90, 3)
	armchair(wx + 4, wz, 90, 7)
	-- a side table with a lamp between the chairs, and a pot of tea gone cold
	Kit.post(model, 2.4, 0.4, at(wx - 3, 1.2, wz), C.wood, { material = Enum.Material.Wood })
	Kit.cylinder(
		model,
		0.2,
		2.2,
		at(wx - 3, 2.5, wz) * Kit.angles(0, 0, 90),
		C.wood,
		{ material = Enum.Material.Wood }
	)
	Kit.post(
		model,
		1.6,
		0.2,
		at(wx - 3, 3.4, wz + 0.4),
		C.brass,
		{ material = Enum.Material.Metal, collide = false }
	)
	local shade = Kit.post(
		model,
		0.9,
		1.3,
		at(wx - 3, 4.45, wz + 0.4),
		Color3.fromRGB(34, 92, 70),
		{ material = Enum.Material.Glass, collide = false }
	)
	Kit.pointLight(shade, C.warm, 0.55, 16, false)
	Kit.ball(
		model,
		0.7,
		at(wx - 3, 2.95, wz - 0.5),
		C.porcelain,
		{ material = Enum.Material.SmoothPlastic, collide = false }
	)
	-- a bookcase against the end wall and a palm by the stove
	local caseAt = at(-HALF_X + 1.1, 0, wz + 13) * Kit.angles(0, -90, 0)
	block(Vector3.new(8, 9, 2), caseAt * CFrame.new(0, 4.5, 0), C.wood, Enum.Material.Wood)
	for row = 0, 3 do
		decor(
			Vector3.new(7 - (row % 2) * 0.6, 1.5, 1.2),
			caseAt * CFrame.new(0, 1.4 + row * 2.1, -0.5),
			Color3.fromHSV((row * 0.23) % 1, 0.45, 0.45),
			Enum.Material.SmoothPlastic
		)
	end
	local potAt = at(wx - 10, 0, wz + 10)
	Kit.post(
		model,
		2.4,
		2.6,
		potAt * CFrame.new(0, 1.2, 0),
		Color3.fromRGB(150, 80, 56),
		{ material = Enum.Material.Brick }
	)
	for k = 0, 6 do
		Kit.wedge(
			model,
			Vector3.new(0.4, 0.6, 4.2),
			potAt
				* CFrame.new(0, 3.4, 0)
				* Kit.angles(0, k * 51, 0)
				* Kit.angles(-28 - (k % 3) * 9, 0, 0)
				* CFrame.new(0, 0, -2.1),
			Color3.fromRGB(60, 104, 60),
			{ material = Enum.Material.LeafyGrass, collide = false }
		)
	end

	-- The tea room at the east end: soup on the stove, nobody leaves hungry -----------------------------
	local tx, tz = 100, 48
	block(Vector3.new(3, 3.6, 16), at(tx + 6, 1.8, tz), C.wood, Enum.Material.WoodPlanks)
	block(Vector3.new(3.6, 0.3, 16.6), at(tx + 6, 3.75, tz), C.marble, Enum.Material.Marble)
	block(Vector3.new(0.3, 2.6, 15), at(tx + 4.35, 1.6, tz), Kit.shade(C.wood, 0.8), Enum.Material.Wood)
	local urn = Kit.post(
		model,
		2.4,
		1.6,
		at(tx + 6, 5.1, tz - 4),
		C.brass,
		{ material = Enum.Material.Metal, collide = false }
	)
	Kit.ball(
		model,
		1.0,
		at(tx + 6, 6.5, tz - 4),
		C.brass,
		{ material = Enum.Material.Metal, collide = false }
	)
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230))
	steam.Rate = 3
	steam.Lifetime = NumberRange.new(1.5, 2.5)
	steam.Speed = NumberRange.new(1, 2)
	steam.EmissionDirection = Enum.NormalId.Top
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 2) })
	steam.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	steam.Parent = urn
	for k = 0, 3 do
		Kit.post(
			model,
			0.6,
			0.6,
			at(tx + 5.4, 4.2, tz - 1 + k * 1.1),
			C.porcelain,
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
	end
	for _, dz in { 3, 6 } do
		Kit.post(
			model,
			0.2,
			1.8,
			at(tx + 6, 4.0, tz + dz),
			C.porcelain,
			{ material = Enum.Material.Marble, collide = false }
		)
		Kit.ball(
			model,
			1.0,
			at(tx + 6, 4.4, tz + dz),
			Color3.fromRGB(150, 70, 60),
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
		Kit.ball(
			model,
			1.7,
			at(tx + 6, 4.6, tz + dz),
			C.glass,
			{ material = Enum.Material.Glass, collide = false, transparency = 0.6 }
		)
	end
	local menu = decor(
		Vector3.new(0.2, 6, 8),
		at(HALF_X - 0.25, 8.5, tz),
		Color3.fromRGB(30, 40, 34),
		Enum.Material.Slate
	)
	do
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Left
		gui.CanvasSize = Vector2.new(640, 480)
		gui.LightInfluence = 0.9
		gui.Parent = menu
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.9, 0.9)
		t.Position = UDim2.fromScale(0.05, 0.05)
		t.FontFace = Font.new("rbxasset://fonts/families/Kalam.json", Enum.FontWeight.Bold)
		t.Text =
			"TEA ROOM\nTea ............ 1d\nHot soup ........ 2d\nA kind word ..... free\nCourage .. ask Mrs. Pell"
		t.TextColor3 = Color3.fromRGB(226, 232, 234)
		t.TextScaled = true
		t.Parent = gui
	end
	local pendant =
		Kit.neon(model, Vector3.new(0.8, 0.8, 0.8), at(tx + 4, 11, tz), C.warm, Enum.PartType.Ball)
	Kit.post(model, 9, 0.12, at(tx + 4, 16, tz), C.iron, { material = Enum.Material.Metal, collide = false })
	Kit.pointLight(pendant, C.warm, 0.65, 20, false)
	for _, dz in { -6, 6 } do
		local tableAt = at(tx - 6, 0, tz + dz)
		Kit.post(model, 2.8, 0.5, tableAt * CFrame.new(0, 1.4, 0), C.iron, { material = Enum.Material.Metal })
		Kit.cylinder(
			model,
			0.25,
			3.6,
			tableAt * CFrame.new(0, 2.92, 0) * Kit.angles(0, 0, 90),
			C.marble,
			{ material = Enum.Material.Marble }
		)
		for _, s in { -1, 1 } do
			local seat = tableAt * CFrame.new(s * 2.8, 0, 0)
			Kit.post(
				model,
				1.9,
				0.3,
				seat * CFrame.new(0, 0.95, 0),
				C.iron,
				{ material = Enum.Material.Metal }
			)
			Kit.cylinder(
				model,
				0.25,
				1.6,
				seat * CFrame.new(0, 2.0, 0) * Kit.angles(0, 0, 90),
				C.wood,
				{ material = Enum.Material.Wood }
			)
			block(
				Vector3.new(0.25, 2.2, 1.4),
				seat * CFrame.new(s * 0.75, 3.2, 0),
				C.wood,
				Enum.Material.Wood,
				{ collide = false }
			)
		end
	end

	-- An upright piano by the trolleys, its lid up as though someone just stopped playing -----------
	local pianoAt = at(-4, 0, 66)
	block(
		Vector3.new(6, 4.6, 2.2),
		pianoAt * CFrame.new(0, 2.3, 0.4),
		Color3.fromRGB(46, 30, 24),
		Enum.Material.Wood
	)
	block(
		Vector3.new(5.6, 0.35, 1.2),
		pianoAt * CFrame.new(0, 2.65, -1.25),
		Color3.fromRGB(46, 30, 24),
		Enum.Material.Wood
	)
	decor(
		Vector3.new(5.2, 0.12, 0.8),
		pianoAt * CFrame.new(0, 2.88, -1.35),
		C.porcelain,
		Enum.Material.SmoothPlastic
	)
	decor(
		Vector3.new(4.8, 0.1, 0.38),
		pianoAt * CFrame.new(0, 2.98, -1.15),
		Color3.fromRGB(20, 18, 18),
		Enum.Material.SmoothPlastic
	)
	block(
		Vector3.new(4, 0.3, 1.4),
		pianoAt * CFrame.new(0, 1.8, -3.2),
		Color3.fromRGB(46, 30, 24),
		Enum.Material.Wood
	)
	for _, s in { -1, 1 } do
		decor(
			Vector3.new(0.3, 1.65, 0.3),
			pianoAt * CFrame.new(s * 1.7, 0.83, -3.2),
			C.iron,
			Enum.Material.Metal
		)
		Kit.post(
			model,
			1,
			0.25,
			pianoAt * CFrame.new(s * 2.4, 5.1, 0.6),
			C.brass,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	-- Gnossienne No. 3 plays from inside the case; PianoNotes floats notes off the same spot
	local voice = block(
		Vector3.new(0.4, 0.4, 0.4),
		pianoAt * CFrame.new(0, 3.6, -0.2),
		C.porcelain,
		nil,
		{ collide = false, shadow = false, transparency = 1 }
	)
	voice.Name = "PianoVoice"
	voice.CanQuery = false
	voice:AddTag("PianoVoice")
	local cue = Audio.LobbyPiano
	local music = Instance.new("Sound")
	music.Name = "Gnossienne"
	music.SoundId = `rbxassetid://{cue.id}`
	music.Volume = cue.volume
	music.Looped = true
	music.RollOffMode = Enum.RollOffMode.InverseTapered
	-- the same volume everywhere in the hall: the farthest corner is ~161 studs from the piano
	music.RollOffMinDistance = 170
	music.RollOffMaxDistance = 180
	music.Playing = true
	music.Parent = voice

	-- The crew's notice board on the back wall: notes left by the ones who came before, on whatever
	-- paper was to hand (the line's grey-green card, blue-ruled pad, pink carbon, brown wrapping) --
	local NOTE_PAPERS = {
		Color3.fromRGB(166, 192, 182),
		Color3.fromRGB(184, 204, 222),
		Color3.fromRGB(206, 170, 182),
		Color3.fromRGB(140, 108, 78),
		Color3.fromRGB(190, 206, 218),
	}
	local nbx = -66
	block(
		Vector3.new(9, 6, 0.4),
		at(nbx, 6.5, BACK_Z - 0.2),
		Color3.fromRGB(150, 112, 74),
		Enum.Material.Fabric
	)
	block(Vector3.new(9.6, 6.6, 0.25), at(nbx, 6.5, BACK_Z - 0.125 + 0.02), C.wood, Enum.Material.Wood)
	local notes = {
		{ "Whoever keeps leaving the lamp on in the guard's van: thank you. - R.", "PatrickHand" },
		{ "Crew wanted. Must run fast, carry coal and not ask what is in the fog.", "SpecialElite" },
		{ "Mrs. Pell's soup: Tuesdays.\nIt is always Tuesday now.", "IndieFlower" },
		{
			"If you hear knocking under the floor it's the pipes. It's the pipes. IT'S THE PIPES.",
			"PermanentMarker",
		},
		{ "Bring back one thing that isn't coal. A flower. A book. Anything.", "Kalam" },
		{ "Scrap opens doors. Literally. Pry the locks, mind what's behind them.", "PatrickHand" },
	}
	for i, note in notes do
		local col, row = (i - 1) % 3, (i - 1) // 3
		local paper = decor(
			Vector3.new(2.6, 2.4, 0.06),
			at(nbx - 2.9 + col * 2.9, 5.2 + row * 2.7, BACK_Z - 0.45 - i * 0.02)
				* Kit.angles(0, 0, (((i * 37) % 11) - 5) * 1.5),
			NOTE_PAPERS[(i - 1) % #NOTE_PAPERS + 1],
			Enum.Material.SmoothPlastic
		)
		Kit.ball(
			model,
			0.22,
			paper.CFrame * CFrame.new(0, 0.95, -0.08),
			C.canvas,
			{ material = Enum.Material.SmoothPlastic, collide = false, shadow = false }
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(260, 240)
		gui.LightInfluence = 1
		gui.Parent = paper
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.88, 0.88)
		t.Position = UDim2.fromScale(0.06, 0.06)
		t.FontFace = Font.new(`rbxasset://fonts/families/{note[2]}.json`)
		t.Text = note[1]
		t.TextColor3 = if i == 4 then Color3.fromRGB(22, 20, 22) else Color3.fromRGB(34, 40, 70)
		t.TextScaled = true
		t.TextWrapped = true
		t.Parent = gui
	end

	-- Lamplight: lanterns hung from the platform-edge columns and sconces on the back wall ---------------
	-- each column carries two, one either side on an iron arm that turns down at its tip, so the
	-- platform below stays clear for the boarding doors
	for x = -99, 99, BAY do
		for _, side in { -1, 1 } do
			local tip = at(x + side * 2.4, 0, -14)
			Kit.block(
				model,
				Vector3.new(2.05, 0.25, 0.25),
				at(x + side * 1.475, 13.6, -14),
				C.iron,
				{ material = Enum.Material.Metal, collide = false }
			)
			Kit.post(
				model,
				0.6,
				0.25,
				tip * CFrame.new(0, 13.25, 0),
				C.iron,
				{ material = Enum.Material.Metal, collide = false }
			)
			Kit.block(
				model,
				Vector3.new(1.3, 0.25, 1.3),
				tip * CFrame.new(0, 11.1, 0),
				C.iron,
				{ material = Enum.Material.Metal, collide = false }
			)
			local lantern = Kit.neon(model, Vector3.new(1, 1.4, 1), tip * CFrame.new(0, 11.95, 0), C.flame)
			lantern.Transparency = 0.15
			Kit.block(
				model,
				Vector3.new(1.5, 0.3, 1.5),
				tip * CFrame.new(0, 12.8, 0),
				C.iron,
				{ material = Enum.Material.Metal, collide = false }
			)
			Kit.pointLight(lantern, C.warm, 0.75, 22, false)
		end
	end
	for _, x in { -78, -54, 54, 78 } do
		decor(Vector3.new(0.6, 1.4, 0.5), at(x, 13, BACK_Z - 0.25), C.brass, Enum.Material.Metal)
		decor(Vector3.new(0.3, 0.3, 1.2), at(x, 13.4, BACK_Z - 0.9), C.brass, Enum.Material.Metal)
		local globe =
			Kit.neon(model, Vector3.new(1, 1, 1), at(x, 13.4, BACK_Z - 1.9), C.flame, Enum.PartType.Ball)
		Kit.pointLight(globe, C.warm, 0.55, 18, false)
	end

	local spawnPoints: { CFrame } = {}
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		table.insert(spawnPoints, at(math.cos(angle) * 14, 3, 24 + math.sin(angle) * 9))
	end

	Kit.setCollisionGroup(model, "Default")
	Kit.setCollisionGroup(display.model, "Train")
	model.Parent = parent

	return {
		model = model,
		spawnPoints = spawnPoints,
		board = board,
		outfitter = outfitter,
		ledger = ledger,
		displayTrain = display.model,
		displayCabins = display.cabins,
	}
end

return LobbyBuilder
