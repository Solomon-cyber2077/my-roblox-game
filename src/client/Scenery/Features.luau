--!strict
--[[
	Set pieces and station sinkholes. Each one is its own chunk whose origin is
	the piece's start (land x), so local x runs from 0 to the piece's length.

	  Tunnel       rock cuttings, stone portals, a lined bore with lamps every
	               40 studs, and the hill it runs through
	  Gorge        canyon walls out to the mid field, a river far below, mist,
	               and either a through-truss girder bridge or a stone viaduct
	  BurningTown  streets of burning and burnt-out houses and a church
	  Halt         an abandoned halt with a Hollow standing on the platform
	  Wreck        a derailed train on its side
	  Gantry       a signal gantry over the track at y 16
	  HollowField  a field of still Hollows with glowing eyes
	  Graveyard, Lake, Crossing
	  Sinkhole     the void a station docks over: rim cliffs, an ember-lit abyss
	               and mist layers (a harbour at the Terminus)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Journey = require(Shared.Logic.Journey)
local Kit = require(Shared.Visual.Kit)
local Rng = require(Shared.Util.Rng)
local Tuning = require(Shared.Config.Tuning)

local Bands = require(script.Parent.Bands)
local Biomes = require(script.Parent.Biomes)
local Props = require(script.Parent.Props)
local World = require(script.Parent.World)

local Features = {}

local GROUND = Bands.Ground
local FORMATION = Bands.Formation
local ABYSS = Tuning.World.AbyssY - 12
local GORGE_FLOOR = -330
local BORE = 9.5 -- tunnel wall inner face, |z|
local BORE_TOP = 15

local M = Enum.Material
local rgb = Color3.fromRGB
local STONE = rgb(116, 108, 98)
local IRON = rgb(46, 44, 46)

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): BasePart
	return Kit.block(
		parent,
		size,
		cf,
		color,
		{ material = material, collide = false, shadow = shadow == true }
	)
end

local function wedge(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): BasePart
	return Kit.wedge(
		parent,
		size,
		cf,
		color,
		{ material = material, collide = false, shadow = shadow == true }
	)
end

-- A thin member from a to b (girders, wires, braces).
local function beam(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
)
	part(
		parent,
		Vector3.new(thickness, thickness, (b - a).Magnitude),
		Kit.between(a, b),
		color,
		material or M.Metal
	)
end

-- Height of the embankment slope at |z| (it falls from the formation at 8 to the ground at 18).
local function embankmentY(z: number): number
	return FORMATION - (math.abs(z) - 8) * (FORMATION - GROUND) / 10
end

local function occluder(p: BasePart): BasePart
	p:SetAttribute("Occluder", true)
	return p
end

-- Ground within a set piece (a hill, a cliff): things may stand sunk into it (lune run audit).
local function earth(p: BasePart): BasePart
	p:SetAttribute("Earth", true)
	return p
end

-- Ground already spoken for in a set piece: circles { x, z, radius }.
type Taken = { { number } }

--[[
	Up to `count` spots from `sample` for things of `radius`, each clear of every
	circle in `taken` (which it then joins), each built with `place`. Gives up
	after four tries a spot.
]]
local function scatter(
	taken: Taken,
	count: number,
	radius: number,
	sample: () -> (number, number),
	place: (number, number) -> ()
)
	local placed = 0
	for _ = 1, count * 4 do
		if placed >= count then
			break
		end
		local x, z = sample()
		local clear = true
		for _, spot in taken do
			if (spot[1] - x) ^ 2 + (spot[2] - z) ^ 2 < (spot[3] + radius) ^ 2 then
				clear = false
				break
			end
		end
		if clear then
			table.insert(taken, { x, z, radius })
			placed += 1
			place(x, z)
		end
	end
end

local function translucent(parent: Instance, size: Vector3, cf: CFrame, color: Color3, transparency: number)
	local p = part(parent, size, cf, color, M.SmoothPlastic)
	p.Transparency = transparency
end

local function emitter(parent: Instance, size: Vector3, cf: CFrame): BasePart
	return Kit.block(parent, size, cf, Color3.new(), { collide = false, shadow = false, transparency = 1 })
end

local function ctxFor(x: number, rng: Rng.Rng, shadow: boolean): Props.Ctx
	return { rng = rng, biome = World.pick(x, rng), shadow = shadow }
end

--[[
	Flat patches lying on the ground (scorch marks, trampled grass), placed so no
	two overlap: up to `count` rectangles of width `w` by `w * aspect`, at random
	in x 0..len and |z| zNear..zFar on `side`, each turned at random.
]]
local function patches(
	model: Model,
	rng: Rng.Rng,
	count: number,
	len: number,
	side: number,
	zNear: number,
	zFar: number,
	wMin: number,
	wMax: number,
	aspect: number,
	color: Color3,
	material: Enum.Material
)
	local placed: { { x: number, z: number, r: number } } = {}
	for _ = 1, count * 3 do
		if #placed >= count then
			break
		end
		local w = rng:range(wMin, wMax)
		local r = w * math.sqrt(1 + aspect * aspect) / 2 -- half the diagonal
		local x, z = rng:range(0, len), side * rng:range(zNear, zFar)
		local clear = true
		for _, other in placed do
			if (other.x - x) ^ 2 + (other.z - z) ^ 2 < (other.r + r) ^ 2 then
				clear = false
				break
			end
		end
		if clear then
			table.insert(placed, { x = x, z = z, r = r })
			part(
				model,
				Vector3.new(w, 0.2, w * aspect),
				CFrame.new(x, GROUND + 0.1, z) * Kit.angles(0, rng:range(0, 90), 0),
				color,
				material
			)
		end
	end
end

-- Tunnel -----------------------------------------------------------------------------------------

local function tunnel(model: Model, piece: Journey.Piece, rng: Rng.Rng)
	local len = piece.length
	local p1 = Tuning.Journey.TunnelCutting
	local p2 = len - p1
	local def = World.dominant(piece.at + len / 2)
	local rock = Kit.jitter(def.rock, 0.06, rng:next())
	local dark = Kit.shade(rock, 0.55)

	-- cuttings: rock walls rising toward each portal
	for _, cutting in { { x = p1 / 2, yaw = 90 }, { x = len - p1 / 2, yaw = -90 } } do
		for _, side in { -1, 1 } do
			earth(
				wedge(
					model,
					Vector3.new(24, 34, p1),
					CFrame.new(cutting.x, GROUND + 17, side * (BORE + 12)) * Kit.angles(0, cutting.yaw, 0),
					rock,
					M.Slate,
					true
				)
			)
		end
	end

	--[[
		The hill the bore runs through. Its core rests on the bore's ceiling and
		ends just inside the portals, so the portal faces stand clear; its flanks
		run on past them beside the cuttings. Behind the lining a fill closes the
		gap between the lining and the flanks.
	]]
	local hillTop = 67
	local hillLen = p2 - p1 + 20
	local hillX = len / 2
	earth(
		part(
			model,
			Vector3.new(p2 - p1 + 4, hillTop - BORE_TOP - 1, 24),
			CFrame.new(hillX, (hillTop + BORE_TOP + 1) / 2, 0),
			rock,
			M.Rock,
			true
		)
	)
	local slope = hillTop - GROUND
	for _, side in { -1, 1 } do
		local yaw = if side > 0 then 180 else 0
		earth(
			wedge(
				model,
				Vector3.new(hillLen, slope, 190),
				CFrame.new(hillX, GROUND + slope / 2, side * (12 + 95)) * Kit.angles(0, yaw, 0),
				Kit.shade(rock, 0.95),
				M.Rock,
				true
			)
		)
		local fillTop, fillBottom = BORE_TOP + 1.5, GROUND - 0.2
		part(
			model,
			Vector3.new(p2 - p1, fillTop - fillBottom, 2.5),
			CFrame.new(hillX, (fillTop + fillBottom) / 2, side * (BORE + 2.25)),
			dark,
			M.Slate
		)
	end
	if def.snowcap then
		earth(
			part(
				model,
				Vector3.new(hillLen * 0.9, 1.5, 30),
				CFrame.new(hillX, hillTop + 0.6, 0),
				rgb(230, 234, 240),
				M.Snow
			)
		)
	end
	-- pines and boulders over the hill, apart from one another
	scatter({}, 8, Props.radius("Boulder"), function()
		return rng:range(p1 + 10, p2 - 10), rng:sign() * rng:range(4, 160)
	end, function(x, z)
		-- on the flanks, sunk deep enough that no downhill edge lifts clear of the slope
		local d = math.abs(z)
		local y = if d < 12 then hillTop else hillTop - slope * (d - 12) / 190 - 2
		local ctx = ctxFor(piece.at + x, rng, false)
		local cf = CFrame.new(x, y, z)
		if rng:chance(0.6) then
			if def.snowcap then
				Props.snowPine(model, cf, ctx)
			else
				Props.pine(model, cf, ctx)
			end
		else
			Props.boulder(model, cf, ctx)
		end
	end)

	-- the bore: lined walls (from the ground up, under the ballast shoulders) and a
	-- ceiling, which the camera will not clip through
	local bore = p2 - p1
	for _, side in { -1, 1 } do
		occluder(
			part(
				model,
				Vector3.new(bore, BORE_TOP - GROUND, 1.5),
				CFrame.new(len / 2, (BORE_TOP + GROUND) / 2, side * (BORE + 0.75)),
				Kit.shade(STONE, 0.5),
				M.Brick
			)
		)
		part(
			model,
			Vector3.new(bore, 0.8, 6),
			CFrame.new(len / 2, BORE_TOP - 1.6, side * (BORE - 1.6)) * Kit.angles(side * 45, 0, 0),
			Kit.shade(STONE, 0.45),
			M.Brick
		)
	end
	occluder(
		part(
			model,
			Vector3.new(bore, 2, 2 * BORE + 3),
			CFrame.new(len / 2, BORE_TOP + 1, 0),
			Kit.shade(STONE, 0.42),
			M.Brick
		)
	)
	local lit = 0
	for x = p1 + 20, p2 - 20, 40 do
		lit += 1
		local side = if lit % 2 == 0 then 1 else -1
		local lamp = Kit.neon(
			model,
			Vector3.new(0.8, 0.9, 0.5),
			CFrame.new(x, 8.5, side * (BORE - 0.3)),
			rgb(255, 196, 120)
		)
		Kit.pointLight(lamp, rgb(255, 180, 110), 1.4, 24, false)
		part(model, Vector3.new(1.2, 0.3, 0.8), CFrame.new(x, 9.1, side * (BORE - 0.35)), IRON, M.Metal)
	end

	--[[
		Portals: masonry faces with an arched opening. The jambs stand a fifth of a
		stud proud of the lining and the head a fifth below the ceiling, so the
		opening is framed in dressed stone; the corner voussoirs and the keystone
		stand proud of the face.
	]]
	local jamb = BORE - 0.2
	for _, px in { p1, p2 } do
		local face = Kit.jitter(STONE, 0.05, rng:next())
		for _, side in { -1, 1 } do
			part(
				model,
				Vector3.new(6, 46, 43.5 - jamb),
				CFrame.new(px, GROUND + 23, side * (jamb + 43.5) / 2),
				face,
				M.Cobblestone,
				true
			)
			wedge(
				model,
				Vector3.new(6.2, 4, 4),
				CFrame.new(px, BORE_TOP - 2, side * (BORE - 2))
					* Kit.angles(0, if side > 0 then 180 else 0, 180),
				face,
				M.Cobblestone
			)
		end
		local head = BORE_TOP - 0.2
		part(
			model,
			Vector3.new(6, 32 - head, 2 * jamb),
			CFrame.new(px, (32 + head) / 2, 0),
			face,
			M.Cobblestone,
			true
		)
		part(
			model,
			Vector3.new(6.4, 3, 3),
			CFrame.new(px, BORE_TOP + 1, 0),
			Kit.shade(face, 1.15),
			M.Limestone
		)
		part(
			model,
			Vector3.new(6.6, 1.2, 2 * BORE + 70),
			CFrame.new(px, GROUND + 46.6, 0),
			Kit.shade(face, 0.9),
			M.Limestone,
			true
		)
	end
end

-- Gorge ------------------------------------------------------------------------------------------------

local function gorge(model: Model, piece: Journey.Piece, rng: Rng.Rng)
	local len = piece.length
	local half = Tuning.Journey.GorgeHalfWidth
	local def = World.dominant(piece.at + len / 2)
	local rock = Kit.jitter(def.rock, 0.06, rng:next())
	--[[
		Canyon walls at both ends, out to the mid field, and the far rims. A wall
		meets the near ground and then the mid ground, so its segments keep their
		tops just under whichever surface they meet (inside that slab), alternating
		between two levels so overlapping neighbours never share a plane.
	]]
	local reaches = {
		{ z0 = 9, z1 = Bands.NearZ, segments = 2, top = GROUND - 0.1 },
		{ z0 = Bands.NearZ - 4, z1 = half, segments = 3, top = Bands.MidTop - 0.1 },
	}
	for _, wall in { { x = -15, dir = 1 }, { x = len + 15, dir = -1 } } do
		for _, side in { -1, 1 } do
			local n = 0
			for r, reach in reaches do
				for i = 1, reach.segments do
					n += 1
					local z0 = reach.z0 + (reach.z1 - reach.z0) * (i - 1) / reach.segments - 2
					local z1 = reach.z0 + (reach.z1 - reach.z0) * i / reach.segments + 2
					if r == 1 and i == reach.segments then
						z1 = reach.z1 -- the near ground ends here: no lip above the mid ground
					end
					local top = reach.top - 0.1 * (n % 2)
					local jag = rng:range(-8, 8)
					earth(
						part(
							model,
							Vector3.new(30 + rng:range(0, 16), top - GORGE_FLOOR, z1 - z0),
							CFrame.new(wall.x + jag * wall.dir, (top + GORGE_FLOOR) / 2, side * (z0 + z1) / 2)
								* Kit.angles(0, rng:range(-4, 4), 0),
							Kit.shade(rock, 0.85 + 0.1 * rng:next()),
							M.Slate,
							n == 1
						)
					)
				end
			end
		end
	end
	-- the far rims stand a stud proud of the mid ground's cut edge
	local rimTop = Bands.MidTop - 0.3
	for _, side in { -1, 1 } do
		earth(
			part(
				model,
				Vector3.new(len + 60, rimTop - GORGE_FLOOR, 30),
				CFrame.new(len / 2, (rimTop + GORGE_FLOOR) / 2, side * (half + 14)),
				Kit.shade(rock, 0.8),
				M.Slate
			)
		)
	end
	-- the floor (reaching under every wall's foot), a river and mist
	earth(
		part(
			model,
			Vector3.new(len + 120, 4, 2 * half + 80),
			CFrame.new(len / 2, GORGE_FLOOR - 2, 0),
			Kit.shade(rock, 0.5),
			M.Rock
		)
	)
	local river = part(
		model,
		Vector3.new(len + 40, 1, 70),
		CFrame.new(len / 2, GORGE_FLOOR + 0.3, rng:range(-200, 200)),
		rgb(52, 84, 96),
		M.SmoothPlastic
	)
	river.Reflectance = 0.3
	translucent(
		model,
		Vector3.new(len, 0.4, 2 * half),
		CFrame.new(len / 2, -120, 0),
		rgb(176, 176, 184),
		0.88
	)
	translucent(model, Vector3.new(len, 0.4, 2 * half), CFrame.new(len / 2, -220, 0), rgb(150, 150, 160), 0.8)
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(rgb(200, 200, 208))
	mist.Rate = 6
	mist.Lifetime = NumberRange.new(10, 14)
	mist.Speed = NumberRange.new(1, 3)
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 30), NumberSequenceKeypoint.new(1, 60) })
	mist.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1) })
	mist.Parent = emitter(model, Vector3.new(len, 1, 600), CFrame.new(len / 2, -170, 0))

	if piece.style == 2 then
		-- stone viaduct: piers every 40 studs with arch beams between them
		local stone = Kit.jitter(STONE, 0.05, rng:next())
		for x = 0, len, 40 do
			part(
				model,
				Vector3.new(10, FORMATION - 4 - GORGE_FLOOR, 16),
				CFrame.new(x, (FORMATION - 4 + GORGE_FLOOR) / 2, 0),
				stone,
				M.Brick,
				true
			)
		end
		for x = 20, len - 20, 40 do
			part(
				model,
				Vector3.new(30, 6, 15),
				CFrame.new(x, FORMATION - 7, 0),
				Kit.shade(stone, 0.95),
				M.Brick
			)
			for _, dir in { -1, 1 } do
				wedge(
					model,
					Vector3.new(15, 8, 6),
					CFrame.new(x + dir * 12, FORMATION - 14, 0) * Kit.angles(0, dir * 90, 180),
					Kit.shade(stone, 0.9),
					M.Brick
				)
			end
		end
	else
		-- through-truss girder bridge on a central stone pier
		local steel = rgb(58, 62, 66)
		local low, high = FORMATION + 0.5, BORE_TOP + 1
		for _, side in { -1, 1 } do
			local z = side * 8.6
			part(model, Vector3.new(len, 1, 1), CFrame.new(len / 2, low, z), steel, M.Metal, true)
			part(model, Vector3.new(len - 12, 1.2, 1.2), CFrame.new(len / 2, high, z), steel, M.Metal, true)
			beam(model, Vector3.new(0, low, z), Vector3.new(12, high, z), 0.9, steel)
			beam(model, Vector3.new(len, low, z), Vector3.new(len - 12, high, z), 0.9, steel)
			for x = 12, len - 12, 12 do
				part(
					model,
					Vector3.new(0.7, high - low, 0.7),
					CFrame.new(x, (low + high) / 2, z),
					steel,
					M.Metal,
					true
				)
				-- the two halves' diagonals cross mid-span, so they differ in gauge
				local forward = x < len / 2
				beam(
					model,
					Vector3.new(x, high, z),
					Vector3.new(x + (if forward then 12 else -12), low, z),
					if forward then 0.6 else 0.54,
					steel
				)
			end
		end
		for x = 12, len - 12, 24 do
			part(model, Vector3.new(0.6, 0.6, 17.2), CFrame.new(x, high, 0), steel, M.Metal)
			beam(model, Vector3.new(x, high, -8.6), Vector3.new(x + 12, high, 8.6), 0.4, steel)
		end
		part(
			model,
			Vector3.new(14, FORMATION - 9 - GORGE_FLOOR, 20),
			CFrame.new(len / 2, (FORMATION - 9 + GORGE_FLOOR) / 2, 0),
			Kit.jitter(STONE, 0.05, rng:next()),
			M.Brick,
			true
		)
	end
end

-- Burning town --------------------------------------------------------------------------------------------

local function burningTown(model: Model, piece: Journey.Piece, rng: Rng.Rng)
	local side = piece.side
	local len = piece.length
	-- fires are rationed: each one is three emitters, and only the first few get a light
	local fires = 0
	for _, row in { 44, 110, 196 } do
		local x = rng:range(4, 14)
		while x < len - 10 do
			if rng:chance(0.7) then
				local burning = fires < 10 and rng:chance(0.45)
				local ctx = ctxFor(piece.at + x, rng, row < 120)
				ctx.lights = burning and fires < 7
				if burning then
					fires += 1
				end
				local cf = CFrame.new(x, GROUND, side * (row + rng:range(-4, 4)))
					* Kit.angles(0, (if side > 0 then 0 else 180) + rng:range(-6, 6), 0)
				Props.house(model, cf, ctx, burning)
			end
			x += rng:range(24, 32)
		end
	end
	local church = ctxFor(piece.at + len / 2, rng, true)
	church.lights = fires < 8
	Props.church(
		model,
		CFrame.new(len * rng:range(0.3, 0.7), GROUND, side * 290)
			* Kit.angles(0, if side > 0 then 0 else 180, 0),
		church,
		true
	)
	-- scorched ground and a few ruins smouldering on their own
	patches(model, rng, 6, len, side, 30, 300, 20, 50, 0.7, rgb(30, 26, 24), M.Slate)
	for _ = 1, 3 do
		Props.smoke(
			model,
			CFrame.new(rng:range(0, len), GROUND + 20, side * rng:range(60, 260)),
			rng:range(4, 7),
			rgb(36, 30, 28)
		)
	end
end

-- Abandoned halt ---------------------------------------------------------------------------------------------

local function halt(model: Model, piece: Journey.Piece, rng: Rng.Rng)
	local side = piece.side
	local len = piece.length
	local platformTop = -3
	local stone = Kit.jitter(STONE, 0.05, rng:next())
	part(
		model,
		Vector3.new(len * 0.8, platformTop - GROUND, 12),
		CFrame.new(len / 2, (platformTop + GROUND) / 2, side * 15),
		stone,
		M.Concrete,
		true
	)
	-- the edge coping, standing a touch proud of the platform's face and ends
	part(
		model,
		Vector3.new(len * 0.8 + 0.2, 0.3, 1),
		CFrame.new(len / 2, platformTop + 0.1, side * 9.45),
		rgb(196, 186, 150),
		M.Concrete
	)
	-- shelter: back wall, posts and a canted roof
	local cx = len * 0.4
	part(
		model,
		Vector3.new(16, 8, 0.6),
		CFrame.new(cx, platformTop + 4, side * 20.5),
		rgb(92, 70, 52),
		M.WoodPlanks,
		true
	)
	for _, dx in { -7.5, 7.5 } do
		part(
			model,
			Vector3.new(0.5, 8, 0.5),
			CFrame.new(cx + dx, platformTop + 4, side * 14.5),
			IRON,
			M.Metal,
			true
		)
	end
	part(
		model,
		Vector3.new(17, 0.4, 7.5),
		CFrame.new(cx, platformTop + 8.3, side * 17.3) * Kit.angles(side * 8, 0, 0),
		rgb(60, 56, 54),
		M.CorrodedMetal,
		true
	)
	part(
		model,
		Vector3.new(6, 0.4, 1.4),
		CFrame.new(cx, platformTop + 1.6, side * 19.5),
		rgb(80, 60, 44),
		M.Wood
	)
	-- nameboard, its name long gone
	for _, dx in { -2.6, 2.6 } do
		part(
			model,
			Vector3.new(0.3, 5, 0.3),
			CFrame.new(len * 0.7 + dx, platformTop + 2.5, side * 19),
			IRON,
			M.Metal
		)
	end
	part(
		model,
		Vector3.new(6.4, 1.6, 0.2),
		CFrame.new(len * 0.7, platformTop + 4.6, side * 19),
		rgb(200, 196, 180),
		M.SmoothPlastic
	)
	-- one lamp still burning
	part(
		model,
		Vector3.new(0.4, 9, 0.4),
		CFrame.new(len * 0.2, platformTop + 4.5, side * 18),
		IRON,
		M.Metal,
		true
	)
	local lamp = Kit.neon(
		model,
		Vector3.new(0.9, 1.2, 0.9),
		CFrame.new(len * 0.2, platformTop + 9.3, side * 18),
		rgb(255, 210, 150)
	)
	local light = Kit.pointLight(lamp, rgb(255, 200, 140), 1.2, 22, false)
	light:SetAttribute("Flicker", light.Brightness)
	-- and something waiting on it
	Props.hollow(
		model,
		CFrame.new(len * 0.55, platformTop, side * 14) * Kit.angles(0, if side > 0 then 0 else 180, 0),
		1.1
	)
	Props.deadTree(model, CFrame.new(len * 0.9, GROUND, side * 34), ctxFor(piece.at, rng, true))
end

-- Derailed wreck ------------------------------------------------------------------------------------------------

local function wreck(model: Model, piece: Journey.Piece, rng: Rng.Rng)
	local side = piece.side
	local len = piece.length
	local livery = rng:pick({ rgb(60, 40, 36), rgb(40, 52, 46), rgb(58, 58, 64) })
	local x = 20
	for i = 1, 3 do
		local z = side * rng:range(22, 70)
		local cf = CFrame.new(x + 15, GROUND + 4, z)
			* Kit.angles(0, rng:range(-30, 30), side * rng:range(70, 100))
		part(model, Vector3.new(30, 9, 11), cf, Kit.shade(livery, 0.8 + 0.1 * i), M.SmoothPlastic, true)
		part(
			model,
			Vector3.new(30.4, 1, 12),
			cf * CFrame.new(0, 4.8, 0),
			rgb(40, 38, 38),
			M.CorrodedMetal,
			true
		)
		for wx = -10, 10, 20 do
			Kit.cylinder(
				model,
				0.7,
				3.2,
				cf * CFrame.new(wx, -5, 4) * Kit.angles(0, 90, 0),
				IRON,
				{ material = M.Metal, collide = false, shadow = false }
			)
		end
		x += rng:range(36, 50)
		if x > len - 30 then
			break
		end
	end
	-- the engine, nose-down in the ditch
	local engine = CFrame.new(len - 30, GROUND + 3, side * rng:range(30, 50))
		* Kit.angles(0, rng:range(-40, 40), side * 12)
		* Kit.angles(0, 0, 20)
	Kit.cylinder(
		model,
		24,
		8,
		engine,
		Kit.shade(livery, 0.7),
		{ material = M.Metal, collide = false, shadow = true }
	)
	Kit.cylinder(
		model,
		5,
		8.4,
		engine * CFrame.new(14, 0, 0),
		rgb(26, 26, 28),
		{ material = M.Metal, collide = false, shadow = true }
	)
	Kit.post(
		model,
		4,
		2,
		engine * CFrame.new(14, 5, 0),
		rgb(26, 26, 28),
		{ material = M.Metal, collide = false, shadow = false }
	)
	Props.fire(model, engine * CFrame.new(6, 3, 0), 6, true)
	-- torn rails and scattered debris
	for _ = 1, 3 do
		part(
			model,
			Vector3.new(rng:range(20, 40), 0.5, 0.45),
			CFrame.new(rng:range(0, len), GROUND + 2, side * rng:range(12, 40))
				* Kit.angles(0, rng:range(-30, 30), rng:range(-25, 25)),
			rgb(110, 92, 80),
			M.Metal
		)
	end
	for _ = 1, 8 do
		local s = rng:range(1.5, 4)
		part(
			model,
			Vector3.new(s, s * 0.6, s * 1.4),
			CFrame.new(rng:range(0, len), GROUND + s * 0.2, side * rng:range(14, 90))
				* Kit.angles(rng:range(0, 90), rng:range(0, 90), 0),
			rgb(54, 46, 40),
			M.WoodPlanks
		)
	end
	Props.smoke(model, CFrame.new(len * 0.4, GROUND + 6, side * 50), 4, rgb(50, 46, 44))
end

-- Signal gantry ----------------------------------------------------------------------------------------------------

local function gantry(model: Model, _piece: Journey.Piece, rng: Rng.Rng)
	local x = 8
	local top = 16
	for _, z in { -12, 12 } do
		for _, dx in { -0.9, 0.9 } do
			part(
				model,
				Vector3.new(0.5, top - FORMATION + 2, 0.5),
				CFrame.new(x + dx, (top + FORMATION) / 2 + 1, z),
				IRON,
				M.Metal,
				true
			)
		end
		for y = FORMATION + 3, top - 2, 5 do
			beam(model, Vector3.new(x - 0.9, y, z), Vector3.new(x + 0.9, y + 5, z), 0.25, IRON)
		end
	end
	part(model, Vector3.new(2, 1.6, 26), CFrame.new(x, top + 1, 0), IRON, M.Metal, true)
	part(model, Vector3.new(2.4, 0.2, 26), CFrame.new(x, top + 2, 0), rgb(70, 66, 62), M.DiamondPlate)
	part(model, Vector3.new(0.15, 1.2, 26), CFrame.new(x + 1.1, top + 2.6, 0), IRON, M.Metal)
	for _, z in { -2.6, 2.6, 7 } do
		part(model, Vector3.new(1.2, 3.4, 1.4), CFrame.new(x, top - 1.9, z), rgb(20, 20, 22), M.Metal, true)
		local stop = rng:chance(0.6)
		Kit.neon(
			model,
			Vector3.new(0.2, 0.7, 0.7),
			CFrame.new(x - 0.65, top - 1.1, z),
			if stop then rgb(255, 60, 40) else rgb(40, 40, 40)
		)
		Kit.neon(
			model,
			Vector3.new(0.2, 0.7, 0.7),
			CFrame.new(x - 0.65, top - 2.4, z),
			if stop then rgb(40, 40, 40) else rgb(110, 255, 150)
		)
	end
end

-- Hollow field --------------------------------------------------------------------------------------------------------

local function hollowField(model: Model, piece: Journey.Piece, rng: Rng.Rng)
	local side = piece.side
	local len = piece.length
	patches(model, rng, 5, len, side, 40, 380, 40, 90, 0.8, rgb(84, 76, 58), M.Grass)
	local taken: Taken = {}
	scatter(taken, 4, Props.radius("DeadTree"), function()
		return rng:range(0, len), side * rng:range(40, 300)
	end, function(x, z)
		Props.deadTree(model, CFrame.new(x, GROUND, z), ctxFor(piece.at, rng, false))
	end)
	-- the still crowd, all facing the line
	scatter(taken, rng:int(18, 26), 2, function()
		return rng:range(0, len), side * rng:range(36, 400)
	end, function(x, z)
		local yaw = (if side > 0 then 0 else 180) + rng:range(-15, 15)
		Props.hollow(model, CFrame.new(x, GROUND, z) * Kit.angles(0, yaw, 0), rng:range(0.9, 1.25))
	end)
	Props.fence(model, CFrame.new(len / 2, GROUND, side * 28), ctxFor(piece.at, rng, false))
end

-- Graveyard -----------------------------------------------------------------------------------------------------------

local function graveyard(model: Model, piece: Journey.Piece, rng: Rng.Rng)
	local side = piece.side
	local len = piece.length
	local stone = Kit.jitter(rgb(134, 130, 122), 0.05, rng:next())
	local z0, z1 = 34, 180
	-- low wall around it, a gap for the gate on the track side
	part(model, Vector3.new(len, 3, 1.2), CFrame.new(len / 2, GROUND + 1.5, side * z1), stone, M.Cobblestone)
	for _, x in { 0, len } do
		part(
			model,
			Vector3.new(1.2, 3, z1 - z0),
			CFrame.new(x, GROUND + 1.5, side * (z0 + z1) / 2),
			stone,
			M.Cobblestone
		)
	end
	for _, span in { { 0, len / 2 - 5 }, { len / 2 + 5, len } } do
		part(
			model,
			Vector3.new(span[2] - span[1], 3, 1.2),
			CFrame.new((span[1] + span[2]) / 2, GROUND + 1.5, side * z0),
			stone,
			M.Cobblestone
		)
	end
	-- piers at the corners, where the walls meet, and taller ones either side of the gate
	local pier = Kit.shade(stone, 0.92)
	for _, corner in { { 0, z0 }, { len, z0 }, { 0, z1 }, { len, z1 } } do
		part(
			model,
			Vector3.new(1.8, 3.6, 1.8),
			CFrame.new(corner[1], GROUND + 1.5, side * corner[2]),
			pier,
			M.Cobblestone
		)
	end
	for _, x in { len / 2 - 5, len / 2 + 5 } do
		part(model, Vector3.new(1.8, 4.4, 1.8), CFrame.new(x, GROUND + 1.9, side * z0), pier, M.Cobblestone)
	end
	for x = 12, len - 12, 10 do
		for z = z0 + 14, z1 - 14, 14 do
			if rng:chance(0.7) then
				local cf = CFrame.new(x + rng:range(-2, 2), GROUND, side * (z + rng:range(-2, 2)))
					* Kit.angles(rng:range(-8, 8), rng:range(-10, 10), rng:range(-6, 6))
				local grey = Kit.jitter(stone, 0.12, rng:next())
				if rng:chance(0.3) then
					part(model, Vector3.new(0.5, 4, 0.5), cf * CFrame.new(0, 2, 0), grey, M.Limestone)
					part(model, Vector3.new(2.2, 0.5, 0.4), cf * CFrame.new(0, 2.9, 0), grey, M.Limestone)
				else
					part(
						model,
						Vector3.new(2.2, rng:range(2.2, 3.4), 0.5),
						cf * CFrame.new(0, 1.3, 0),
						grey,
						M.Limestone
					)
				end
			end
		end
	end
	-- a crypt and two dead trees
	local crypt = CFrame.new(len * 0.75, GROUND, side * (z1 - 22))
		* Kit.angles(0, if side > 0 then 0 else 180, 0)
	part(
		model,
		Vector3.new(12, 9, 10),
		crypt * CFrame.new(0, 4.5, 0),
		Kit.shade(stone, 0.85),
		M.Limestone,
		true
	)
	wedge(
		model,
		Vector3.new(12.6, 3, 5.4),
		crypt * CFrame.new(0, 10.5, -2.7),
		Kit.shade(stone, 0.7),
		M.Slate,
		true
	)
	wedge(
		model,
		Vector3.new(12.6, 3, 5.4),
		crypt * CFrame.new(0, 10.5, 2.7) * Kit.angles(0, 180, 0),
		Kit.shade(stone, 0.7),
		M.Slate,
		true
	)
	part(model, Vector3.new(3, 6, 0.3), crypt * CFrame.new(0, 3, -5.05), rgb(20, 18, 18), M.Metal)
	-- by the front wall, between it and the first row of graves, clear of the gate
	scatter({ { len / 2, side * z0, 8 } }, 2, Props.radius("DeadTree"), function()
		return rng:range(6, len - 6), side * (z0 + 6)
	end, function(x, z)
		Props.deadTree(model, CFrame.new(x, GROUND, z), ctxFor(piece.at, rng, true))
	end)
end

-- Lake ----------------------------------------------------------------------------------------------------------------

local function lake(model: Model, piece: Journey.Piece, rng: Rng.Rng)
	local side = piece.side
	local len = piece.length
	local water = rgb(56, 88, 100)
	local shore = Kit.jitter(rgb(96, 90, 70), 0.05, rng:next())
	local center = side * rng:range(170, 230)
	-- three overlapping basins make one ragged lake; each muddy shore and each water
	-- surface has its own level, a tenth of a stud apart, so none of them flicker
	for i = 1, 3 do
		local w = len * rng:range(0.45, 0.75)
		local d = rng:range(120, 220)
		local cf = CFrame.new(len * (0.2 + 0.3 * (i - 1)), 0, center + rng:range(-40, 40))
			* Kit.angles(0, rng:range(-25, 25), 0)
		local shoreTop = GROUND + 0.05 + 0.1 * (i - 1)
		local waterTop = GROUND + 0.45 + 0.1 * (i - 1)
		part(model, Vector3.new(w + 16, 0.2, d + 16), cf * CFrame.new(0, shoreTop - 0.1, 0), shore, M.Mud)
		local surface = part(
			model,
			Vector3.new(w, 0.3, d),
			cf * CFrame.new(0, waterTop - 0.15, 0),
			water,
			M.SmoothPlastic
		)
		surface.Reflectance = 0.28
	end
	local ctx = ctxFor(piece.at, rng, false)
	-- reeds along the near shore, clear of the jetty and its boat
	local taken: Taken = { { len * 0.5 + 2, center - side * 60, 17 } }
	scatter(taken, 8, Props.radius("Reeds"), function()
		return rng:range(0, len), center + side * rng:range(-120, -60)
	end, function(x, z)
		Props.reeds(model, CFrame.new(x, GROUND, z), ctx)
	end)
	-- a jetty and a rowboat
	local jetty = CFrame.new(len * 0.5, GROUND + 1.2, center - side * 70)
	part(model, Vector3.new(4, 0.4, 30), jetty * CFrame.new(0, 0, side * 10), rgb(96, 74, 54), M.WoodPlanks)
	for dz = -2, 22, 8 do
		part(
			model,
			Vector3.new(0.5, 3, 0.5),
			jetty * CFrame.new(-1.6, -1, side * dz),
			rgb(70, 54, 40),
			M.Wood
		)
	end
	local boat = jetty * CFrame.new(4, -0.8, side * 22) * Kit.angles(0, 20, 0)
	part(model, Vector3.new(3.2, 1, 9), boat, rgb(110, 70, 48), M.WoodPlanks)
	wedge(
		model,
		Vector3.new(3.2, 1, 2),
		boat * CFrame.new(0, 0, -5.5) * Kit.angles(0, 180, 0) * Kit.angles(90, 0, 0),
		rgb(110, 70, 48),
		M.WoodPlanks
	)
	-- trees along the far shore
	scatter(taken, 4, Props.radius("Tree"), function()
		return rng:range(0, len), center + side * rng:range(110, 180)
	end, function(x, z)
		Props.tree(model, CFrame.new(x, GROUND, z), ctxFor(piece.at, rng, false))
	end)
end

-- Level crossing --------------------------------------------------------------------------------------------------------

local function crossing(model: Model, piece: Journey.Piece, rng: Rng.Rng)
	local x = piece.length / 2
	local asphalt = rgb(52, 50, 50)
	local slope = FORMATION - GROUND
	for _, side in { -1, 1 } do
		local rect = {
			x0 = piece.at + x - 7,
			x1 = piece.at + x + 7,
			z0 = if side > 0 then 18 else -420,
			z1 = if side > 0 then 420 else -18,
		}
		for _, road in Journey.subtract(rect, World.cuts(rect)) do
			part(
				model,
				Vector3.new(road.x1 - road.x0, 0.3, road.z1 - road.z0),
				CFrame.new((road.x0 + road.x1) / 2 - piece.at, GROUND + 0.16, (road.z0 + road.z1) / 2),
				asphalt,
				M.Asphalt
			)
		end
		-- ramp up the embankment, following the wedge's slope just proud of it
		wedge(
			model,
			Vector3.new(14, slope, 10),
			CFrame.new(x, GROUND + slope / 2 + 0.15, side * 13)
				* Kit.angles(0, if side > 0 then 180 else 0, 0),
			asphalt,
			M.Asphalt
		)
		-- the boom gate and its warning lamps
		local gate = CFrame.new(x - side * 9, embankmentY(15), side * 15)
		part(
			model,
			Vector3.new(0.8, 4, 0.8),
			gate * CFrame.new(0, 2, 0),
			rgb(230, 226, 220),
			M.SmoothPlastic,
			true
		)
		part(
			model,
			Vector3.new(0.4, 0.4, 13),
			gate * CFrame.new(0, 3.4, -side * 6.5),
			rgb(200, 40, 36),
			M.SmoothPlastic
		)
		part(model, Vector3.new(0.5, 7, 0.5), gate * CFrame.new(-side * 2, 3.5, 0), IRON, M.Metal)
		for _, dz in { -0.7, 0.7 } do
			Kit.neon(
				model,
				Vector3.new(0.6, 0.6, 0.3),
				gate * CFrame.new(-side * 2, 6.2, dz),
				if rng:chance(0.5) then rgb(255, 50, 40) else rgb(60, 20, 20)
			)
		end
	end
	part(model, Vector3.new(14, 0.5, 16), CFrame.new(x, -5.6, 0), Kit.shade(asphalt, 1.2), M.WoodPlanks)
	local keeper = rng:sign()
	if not World.sinkholeAt(piece.at + x, keeper * 40) then
		Props.house(
			model,
			CFrame.new(x + 20, GROUND, keeper * 34) * Kit.angles(0, if keeper > 0 then 0 else 180, 0),
			ctxFor(piece.at, rng, true),
			false
		)
	end
end

-- Station sinkholes -------------------------------------------------------------------------------------------------

local function harbour(model: Model, sinkhole: Journey.Sinkhole, rng: Rng.Rng)
	local r = sinkhole.rect
	local len = r.x1 - r.x0
	local stone = Kit.jitter(STONE, 0.05, rng:next())
	-- the basin fills the cut exactly, level with the open sea it opens onto
	local water = part(
		model,
		Vector3.new(len, Bands.SeaThickness, r.z1 - r.z0),
		CFrame.new(len / 2, Bands.SeaNear - Bands.SeaThickness / 2, (r.z0 + r.z1) / 2),
		rgb(44, 78, 92),
		M.SmoothPlastic
	)
	water.Reflectance = 0.25
	-- quays along both ends, from under the platform's edge out past the basin
	for _, x in { -7.5, len + 7.5 } do
		part(
			model,
			Vector3.new(16, 22, r.z1 - r.z0 + 41),
			CFrame.new(x, -23, (r.z0 - 1 + r.z1 + 40) / 2),
			stone,
			M.Cobblestone,
			true
		)
		for z = r.z0 + 20, r.z1, 30 do
			Kit.post(
				model,
				1.4,
				1.2,
				CFrame.new(x + (if x < 0 then 6 else -6), -11.3, z),
				IRON,
				{ material = M.Metal, collide = false, shadow = false }
			)
		end
	end
	-- the lighthouse on a rock rising out of the water off the quay's end
	local coast = Biomes.get("Coast")
	earth(
		part(
			model,
			Vector3.new(20, 4, 20),
			CFrame.new(len + 30, -14.5, r.z1 + 30) * Kit.angles(0, 20, 0),
			Kit.jitter(coast.rock, 0.06, rng:next()),
			M.Rock
		)
	)
	Props.lighthouse(model, CFrame.new(len + 30, -12, r.z1 + 30), { rng = rng, biome = coast, shadow = true })
end

local function abyss(model: Model, sinkhole: Journey.Sinkhole, rng: Rng.Rng)
	local r = sinkhole.rect
	local len = r.x1 - r.x0
	local width = r.z1 - r.z0
	local def = World.dominant(sinkhole.center)
	local rock = Kit.jitter(def.rock, 0.05, rng:next())
	--[[
		Rim cliffs on three sides, jagged, darkening with depth: two courses per
		segment. Tops stay just under the ground (inside the near slab). The end
		walls and the far wall each alternate between their own two top levels and
		their own two course joints, so no two segments share a plane, corners
		included.
	]]
	local function cliff(cx: number, cz: number, sx: number, sz: number, top: number, joint: number)
		for course = 0, 1 do
			local y1 = if course == 0 then top else joint
			local y0 = if course == 0 then joint else ABYSS
			earth(
				part(
					model,
					Vector3.new(sx + rng:range(0, 6), y1 - y0, sz + rng:range(0, 6)),
					CFrame.new(cx + rng:range(-3, 3), (y0 + y1) / 2, cz + rng:range(-3, 3))
						* Kit.angles(0, rng:range(-3, 3), 0),
					Kit.shade(rock, 0.8 - course * 0.3),
					M.Slate,
					course == 0
				)
			)
		end
	end
	local segments = math.max(2, math.floor(width / 60))
	for i = 1, segments do
		local z0 = r.z0 + 2 + (width - 2) * (i - 1) / segments
		local z1 = r.z0 + 2 + (width - 2) * i / segments
		local odd = i % 2
		cliff(-9, (z0 + z1) / 2, 18, z1 - z0, GROUND - 0.08 - 0.08 * odd, -120 - odd)
		cliff(len + 9, (z0 + z1) / 2, 18, z1 - z0, GROUND - 0.08 - 0.08 * odd, -120 - odd)
	end
	local runs = math.max(2, math.floor(len / 80))
	for i = 1, runs do
		local x0 = -18 + (len + 36) * (i - 1) / runs
		local x1 = -18 + (len + 36) * i / runs
		local odd = i % 2
		cliff((x0 + x1) / 2, r.z1 + 9, x1 - x0, 18, GROUND - 0.24 - 0.08 * odd, -122 - odd)
	end
	-- broken lips of ground hanging over the edge
	for _ = 1, 10 do
		local s = rng:range(6, 16)
		local onEnd = rng:chance(0.5)
		local x = if onEnd then (if rng:chance(0.5) then 2 else len - 2) else rng:range(0, len)
		local z = if onEnd then rng:range(r.z0 + 12, r.z1) else r.z1 - 2
		earth(
			part(
				model,
				Vector3.new(s, s * 0.6, s),
				CFrame.new(x, GROUND - s * 0.2, z)
					* Kit.angles(rng:range(-20, 20), rng:range(0, 90), rng:range(-20, 20)),
				Kit.shade(rock, 0.9),
				M.Rock
			)
		)
	end
	-- rock spires rising out of the dark
	for _ = 1, 4 do
		local h = rng:range(70, 160)
		part(
			model,
			Vector3.new(rng:range(8, 18), h, rng:range(8, 18)),
			CFrame.new(rng:range(10, len - 10), ABYSS + h / 2, rng:range(r.z0 + 60, r.z1 - 20))
				* Kit.angles(rng:range(-6, 6), rng:range(0, 90), rng:range(-6, 6)),
			Kit.shade(rock, 0.45),
			M.Slate
		)
	end
	-- the floor (reaching under every cliff's foot), embers and their glow
	earth(
		part(
			model,
			Vector3.new(len + 60, 4, width + 60),
			CFrame.new(len / 2, ABYSS - 2, (r.z0 + r.z1) / 2),
			rgb(22, 18, 18),
			M.Basalt
		)
	)
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
	embers.Color = ColorSequence.new(rgb(255, 150, 70), rgb(190, 50, 20))
	embers.LightEmission = 1
	embers.Rate = 40
	embers.Lifetime = NumberRange.new(6, 9)
	embers.Speed = NumberRange.new(10, 20)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	embers.Parent =
		emitter(model, Vector3.new(len, 1, width), CFrame.new(len / 2, ABYSS + 4, (r.z0 + r.z1) / 2))
	for _, u in { 0.3, 0.7 } do
		local glow = emitter(model, Vector3.one, CFrame.new(len * u, ABYSS + 30, (r.z0 + r.z1) / 2))
		Kit.pointLight(glow, rgb(255, 110, 50), 1.6, 60, false)
	end
	-- mist layers, thickening with depth
	for i, y in { -50, -95, -150 } do
		translucent(
			model,
			Vector3.new(len - 1, 0.4, width),
			CFrame.new(len / 2, y, (r.z0 + r.z1) / 2),
			rgb(126, 116, 114),
			0.9 - i * 0.05
		)
	end
	local smoke = Props.smoke(model, CFrame.new(len / 2, -90, (r.z0 + r.z1) / 2), 6, rgb(70, 62, 60))
	smoke.Rate = 4
	smoke.Speed = NumberRange.new(1, 3)
end

-- Dispatch ----------------------------------------------------------------------------------------------------------

local BUILDERS: { [string]: (Model, Journey.Piece, Rng.Rng) -> () } = {
	Tunnel = tunnel,
	Gorge = gorge,
	BurningTown = burningTown,
	Halt = halt,
	Wreck = wreck,
	Gantry = gantry,
	HollowField = hollowField,
	Graveyard = graveyard,
	Lake = lake,
	Crossing = crossing,
}

-- Kinds big enough to be seen from the mid field get built further ahead.
local FAR_REACH: { [string]: boolean } = { Gorge = true, Lake = true, HollowField = true, BurningTown = true }

function Features.build(piece: Journey.Piece, model: Model)
	local builder = BUILDERS[piece.kind]
	if builder then
		builder(model, piece, Rng.new(piece.seed))
	end
end

function Features.buildSinkhole(sinkhole: Journey.Sinkhole, model: Model)
	local rng = Rng.new(math.floor(sinkhole.center) + World.seed)
	if sinkhole.terminus then
		harbour(model, sinkhole, rng)
	else
		abyss(model, sinkhole, rng)
	end
end

function Features.farReach(kind: string): boolean
	return FAR_REACH[kind] == true
end

return Features
