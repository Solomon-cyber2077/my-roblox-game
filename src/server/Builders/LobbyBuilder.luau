--!strict
--[[
	The Depot Hall: a Victorian train shed where players wait between runs.

	  * an arched roof on iron trusses: slate over the eaves, dirty glazing over
	    the middle on purlins and glazing bars, glazed gables at both ends
	  * the platform (a two-tone tiled floor with a compass rosette) and, across
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

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)
local TrainBuilder = require(script.Parent.TrainBuilder)

export type Built = {
	model: Model,
	spawnPoints: { CFrame },
	board: BasePart,
	outfitter: BasePart,
	ledger: BasePart,
	displayTrain: Model,
}

local LobbyBuilder = {}

local C = {
	marble = Color3.fromRGB(214, 204, 186),
	marbleDark = Color3.fromRGB(150, 128, 104),
	brick = Color3.fromRGB(122, 74, 58),
	brickDark = Color3.fromRGB(92, 56, 46),
	stone = Color3.fromRGB(176, 166, 148),
	iron = Color3.fromRGB(38, 44, 42),
	ironLight = Color3.fromRGB(58, 66, 62),
	slate = Color3.fromRGB(56, 58, 64),
	glass = Color3.fromRGB(150, 170, 168),
	night = Color3.fromRGB(46, 58, 80),
	warm = Color3.fromRGB(255, 206, 140),
	board = Color3.fromRGB(22, 26, 34),
	brass = Color3.fromRGB(201, 160, 82),
	canvas = Color3.fromRGB(132, 46, 52),
	cream = Color3.fromRGB(236, 226, 200),
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
	gui.LightInfluence = 0.15
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

	-- Platform floor: two-tone tiles and a compass rosette ---------------------------------
	local tileX, tileZ = (2 * HALF_X - 2) / 20, (BACK_Z - EDGE_Z) / 8
	for i = 0, 19 do
		for j = 0, 7 do
			local x = -HALF_X + 1 + (i + 0.5) * tileX
			local z = EDGE_Z + (j + 0.5) * tileZ
			local dark = (i + j) % 2 == 0
			block(
				Vector3.new(tileX, 1, tileZ),
				at(x, -0.5, z),
				Kit.jitter(if dark then C.marbleDark else C.marble, 0.03, ((i * 7 + j * 13) % 10) / 10),
				Enum.Material.Marble
			)
		end
	end
	local rosette = Vector3.new(0, 0, 24)
	local rings = {
		{ diameter = 30, color = C.marbleDark },
		{ diameter = 26, color = C.cream },
		{ diameter = 20, color = C.brass },
		{ diameter = 18, color = C.marbleDark },
	}
	for ring, spec in rings do
		local disc = Kit.cylinder(
			model,
			0.04 * ring,
			spec.diameter,
			at(rosette.X, 0.02 * ring, rosette.Z) * Kit.angles(0, 0, 90),
			spec.color,
			{
				material = if spec.color == C.brass then Enum.Material.Metal else Enum.Material.Marble,
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
			if k % 2 == 0 then C.brass else C.cream,
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
	-- seen from the platform, the display train's cabin lamps need no shadows
	for _, descendant in display.model:GetDescendants() do
		if descendant:IsA("PointLight") then
			descendant.Shadows = false
		end
	end
	for _, blocker in display.doorBlockers do
		blocker.CanCollide = true
	end

	-- Walls ----------------------------------------------------------------------------------------
	-- back wall with tall lit windows, the ticket office and the departure board
	block(
		Vector3.new(2 * HALF_X + 4, WALL_TOP + 8, 2),
		at(0, (WALL_TOP + 8) / 2 - 8, BACK_Z + 1),
		C.brick,
		Enum.Material.Brick
	)
	block(Vector3.new(2 * HALF_X, 1.2, 0.6), at(0, 0.6, BACK_Z - 0.3), C.stone, Enum.Material.Concrete)
	for _, x in { -90, -66, 66, 90 } do
		decor(Vector3.new(11, 15, 0.3), at(x, 18, BACK_Z - 0.15), C.iron, Enum.Material.Metal)
		decor(Vector3.new(10, 14, 0.3), at(x, 18, BACK_Z - 0.4), C.warm, Enum.Material.Neon).Transparency =
			0.5
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
		Kit.pointLight(lamp, C.warm, 1.5, 46, (x + 99) % 44 == 0)
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
	label(plate, Enum.NormalId.Front, "DEPARTURES", Color3.fromRGB(240, 232, 210))
	-- clock: brass rim, ivory face, iron hands at ten to midnight
	local clockAt = at(0, 31.6, BACK_Z - 0.6) * Kit.angles(0, 90, 0)
	Kit.cylinder(model, 0.6, 5.4, clockAt, C.brass, { material = Enum.Material.Metal, collide = false })
	Kit.cylinder(
		model,
		0.7,
		4.8,
		clockAt * CFrame.new(-0.04, 0, 0),
		C.cream,
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
		decor(Vector3.new(12, 5, 0.3), at(x, 6.8, BACK_Z - 1.5), C.warm, Enum.Material.Neon).Transparency =
			0.45
		decor(Vector3.new(14, 0.5, 1.2), at(x, 4.1, BACK_Z - 1.8), C.brass, Enum.Material.Metal)
		local sign = decor(Vector3.new(12, 1.8, 0.3), at(x, 10.2, BACK_Z - 1.55), C.board)
		label(sign, Enum.NormalId.Front, "TICKETS", Color3.fromRGB(240, 210, 150))
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
			if i % 2 == 0 then C.canvas else Color3.fromRGB(226, 214, 186),
			Enum.Material.Fabric
		)
	end
	local outfitterSign = decor(Vector3.new(12, 2.4, 0.4), at(kx, 13.2, kz - 1.8), C.board)
	label(outfitterSign, Enum.NormalId.Front, "OUTFITTER", Color3.fromRGB(240, 210, 150))
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
	Kit.pointLight(kioskLamp, C.warm, 1.4, 22, false)

	-- Ledger board ----------------------------------------------------------------------------------------------
	local lx, lz = -54, 36
	block(Vector3.new(14, 10, 1), at(lx, 6, lz + 4), C.wood, Enum.Material.WoodPlanks)
	local ledgerFace = decor(Vector3.new(12.6, 8.6, 0.3), at(lx, 6, lz + 3.35), Color3.fromRGB(236, 226, 200))
	label(ledgerFace, Enum.NormalId.Front, "LINE MASTERY", Color3.fromRGB(40, 34, 28))
	for _, x in { -6.6, 6.6 } do
		Kit.post(model, 12, 0.5, at(lx + x, 6, lz + 4.4), C.iron, { material = Enum.Material.Metal })
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

	-- Posters on the end walls ------------------------------------------------------------------------------
	local posters = {
		{ "LAST TRAIN OUT", "Board before the light fails." },
		{ "MIND THE FOG", "What walks in it does not tire." },
		{ "BRING BACK COAL", "No coal, no train. No train, no tomorrow." },
		{ "THE TERMINUS", "Ten stops. One sunrise." },
	}
	for i, poster in posters do
		local side = if i <= 2 then -1 else 1
		local z = if i % 2 == 0 then 10 else 40
		local x = side * (HALF_X - 0.3)
		local framePart = decor(Vector3.new(0.3, 9.4, 7.4), at(x, 8, z), C.iron, Enum.Material.Metal)
		framePart.Name = "PosterFrame"
		local paper = decor(
			Vector3.new(0.2, 9, 7),
			at(x - side * 0.2, 8, z),
			Color3.fromRGB(214, 196, 160),
			Enum.Material.SmoothPlastic
		)
		label(
			paper,
			if side > 0 then Enum.NormalId.Left else Enum.NormalId.Right,
			`{poster[1]}\n{poster[2]}`,
			Color3.fromRGB(70, 36, 30),
			Vector2.new(300, 380)
		)
	end

	-- Lamplight: platform standards along the edge and sconces on the back wall ---------------------------
	for x = -88, 88, BAY do
		local base = at(x, 0, EDGE_Z + 4)
		Kit.block(
			model,
			Vector3.new(1.4, 1, 1.4),
			base * CFrame.new(0, 0.5, 0),
			C.iron,
			{ material = Enum.Material.Metal }
		)
		Kit.post(model, 10, 0.4, base * CFrame.new(0, 6, 0), C.iron, { material = Enum.Material.Metal })
		Kit.block(
			model,
			Vector3.new(1.3, 0.25, 1.3),
			base * CFrame.new(0, 11.1, 0),
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
		local lantern = Kit.neon(model, Vector3.new(1, 1.4, 1), base * CFrame.new(0, 11.95, 0), C.warm)
		lantern.Transparency = 0.15
		Kit.block(
			model,
			Vector3.new(1.5, 0.3, 1.5),
			base * CFrame.new(0, 12.8, 0),
			C.iron,
			{ material = Enum.Material.Metal, collide = false }
		)
		Kit.pointLight(lantern, C.warm, 1.3, 24, false)
	end
	for _, x in { -78, -54, 54, 78 } do
		decor(Vector3.new(0.6, 1.4, 0.5), at(x, 13, BACK_Z - 0.25), C.brass, Enum.Material.Metal)
		decor(Vector3.new(0.3, 0.3, 1.2), at(x, 13.4, BACK_Z - 0.9), C.brass, Enum.Material.Metal)
		local globe =
			Kit.neon(model, Vector3.new(1, 1, 1), at(x, 13.4, BACK_Z - 1.9), C.warm, Enum.PartType.Ball)
		Kit.pointLight(globe, C.warm, 0.9, 18, false)
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
	}
end

return LobbyBuilder
