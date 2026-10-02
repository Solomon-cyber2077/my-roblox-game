--!strict
--[[
	The landscape's chunk layers. Each layer tiles land x in fixed-length chunks
	and keeps the chunks inside its window (world x, relative to the train) built.

	  Bed        48   the formation, ballast and rails; embankments down to the
	                  ground, a causeway wall over a sinkhole, a deck over a gorge
	  Sleepers   48   timber sleepers
	  Trackside  60   telegraph poles with sagging wires, signals, fences, verges
	  Near      120   the ground (top y -14) with a patchwork or field strips,
	                  hedgerows, mounds, trees, buildings and the odd eerie sight
	  Mid       400   lower ground, hills, forest belts, power lines, clumps
	  Horizon  1200   a band of hills and, far beyond, a mountain range

	Builders work in chunk-local space: land x maps to local x = x - x0.

	No two visible faces may share a plane (lune run audit): each ground layer
	has its own height band (Bands), flat overlays on the same layer never
	overlap, and props are spaced so they never intersect one another.
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

export type Layer = {
	name: string,
	length: number,
	from: number, -- window in world x
	to: number,
	hideable: boolean,
}

local Land = {}

Land.Layers = {
	{ name = "Bed", length = 48, from = -480, to = 1800, hideable = true },
	{ name = "Sleepers", length = 48, from = -240, to = 480, hideable = true },
	{ name = "Trackside", length = 60, from = -400, to = 1500, hideable = false },
	{ name = "Near", length = 120, from = -500, to = Tuning.Journey.BuiltAhead, hideable = false },
	{ name = "Mid", length = 400, from = -1600, to = 4400, hideable = false },
	{ name = "Horizon", length = 1200, from = -4800, to = 7200, hideable = false },
} :: { Layer }

-- Height bands and reaches (see Bands for the full table).
local GROUND = Bands.Ground
local NEAR_T = Bands.NearThickness
local OVERLAY_T = Bands.Overlay
local MID_OVERLAY_T = Bands.MidOverlay
local MID_TOP = Bands.MidTop
local MID_T = Bands.MidThickness
local HORIZON_TOP = Bands.HorizonTop
local HORIZON_T = Bands.HorizonThickness
local INNER_TOP = Bands.HorizonInnerTop
local INNER_T = Bands.HorizonInnerThickness
local RIDGE_BASE = Bands.RidgeBase
local SEA_NEAR = Bands.SeaNear
local SEA_MID = Bands.SeaMid
local SEA_HORIZON = Bands.SeaHorizon
local SEA_T = Bands.SeaThickness
local FORMATION = Bands.Formation
local NEAR_Z = Bands.NearZ
local MID_Z = Bands.MidZ
local FAR_Z = Bands.FarZ

local HEDGE_D = 3.2
local SHORE = 70 -- coast: sand from the track out to here, then sea
local PYLON_Z = -720
local LINE_CLEARANCE = 24 -- either side of the power line, past its widest arms

local M = Enum.Material
local rgb = Color3.fromRGB
local BALLAST = rgb(84, 80, 76)
local STONE = rgb(110, 102, 92)
local IRON = rgb(44, 44, 48)
local SEA = rgb(40, 70, 84)
local HEDGE = rgb(52, 70, 40)

local function slab(
	parent: Instance,
	x0: number,
	rect: Journey.Rect,
	top: number,
	thickness: number,
	color: Color3,
	material: Enum.Material
): BasePart
	return Kit.block(
		parent,
		Vector3.new(rect.x1 - rect.x0, thickness, rect.z1 - rect.z0),
		CFrame.new((rect.x0 + rect.x1) / 2 - x0, top - thickness / 2, (rect.z0 + rect.z1) / 2),
		color,
		{ material = material, collide = false, shadow = false }
	)
end

-- Open water over `rect`, minus every cut (a gorge or sinkhole is a void, not a pond).
local function sea(parent: Instance, x0: number, rect: Journey.Rect, top: number)
	for _, piece in Journey.subtract(rect, World.cuts(rect)) do
		local part = slab(parent, x0, piece, top, SEA_T, SEA, M.SmoothPlastic)
		part.Reflectance = 0.22
	end
end

local function sideRect(x0: number, x1: number, side: number, near: number, far: number): Journey.Rect
	if side > 0 then
		return { x0 = x0, x1 = x1, z0 = near, z1 = far }
	end
	return { x0 = x0, x1 = x1, z0 = -far, z1 = -near }
end

-- Every reservation and cut overlapping `rect`, for clipping overlays.
local function reserved(rect: Journey.Rect): { Journey.Rect }
	local list = World.cuts(rect)
	for _, piece in World.pieces do
		local footprint = Journey.footprint(piece)
		if Journey.overlaps(footprint, rect) then
			table.insert(list, footprint)
		end
	end
	return list
end

-- Ground slabs over `rect`, minus every cut, coloured by the biome mix along the chunk.
local function ground(
	parent: Instance,
	x0: number,
	rect: Journey.Rect,
	top: number,
	thickness: number,
	darken: number
)
	local cx = (rect.x0 + rect.x1) / 2
	local color = Kit.shade(
		World.color(cx, function(def)
			return def.ground
		end),
		darken
	)
	local material = World.dominant(cx).groundMaterial
	for _, piece in Journey.subtract(rect, World.cuts(rect)) do
		slab(parent, x0, piece, top, thickness, color, material)
	end
end

-- Ground taken on one side of a chunk: circles (props, mounds) and bands of z kept clear (a power line).
type Packer = { circles: { { x: number, z: number, r: number } }, bands: { { number } } }

local function newPacker(): Packer
	return { circles = {}, bands = {} }
end

local function fits(packer: Packer, x: number, z: number, r: number): boolean
	for _, band in packer.bands do
		if z + r > band[1] and z - r < band[2] then
			return false
		end
	end
	for _, c in packer.circles do
		local dx, dz = c.x - x, c.z - z
		if dx * dx + dz * dz < (c.r + r) * (c.r + r) then
			return false
		end
	end
	return true
end

local function take(packer: Packer, x: number, z: number, r: number)
	table.insert(packer.circles, { x = x, z = z, r = r })
end

local function weightedKind(rng: Rng.Rng, list: { Biomes.Weighted }): string
	local entries: { Rng.Weighted<string> } = {}
	for _, entry in list do
		table.insert(entries, { weight = entry.weight, value = entry.kind })
	end
	return rng:weighted(entries)
end

-- Places `count` props from `listOf(biome)` on one side, spaced and clear of reservations.
local function placeProps(
	model: Model,
	x0: number,
	length: number,
	rng: Rng.Rng,
	side: number,
	zNear: number,
	zFar: number,
	count: number,
	listOf: (Biomes.Def) -> { Biomes.Weighted },
	packer: Packer,
	far: boolean,
	groundTop: number
)
	-- lit things (fires, lamps) are rationed: one light per side of a chunk, and only near the line
	local lit = 0
	local placed = 0
	for _ = 1, count * 3 do
		if placed >= count then
			break
		end
		-- what, then where its whole footprint fits: inside the band (nothing leans over the
		-- fences or the line) and inside the chunk, whose neighbours' props this packer never sees
		local def = World.pick(x0 + rng:range(0, length), rng)
		local kind = weightedKind(rng, listOf(def))
		local radius = Props.radius(kind)
		local zLow, zHigh = zNear + radius, zFar - radius
		if zHigh <= zLow or length <= 2 * radius then
			continue
		end
		local x = x0 + radius + rng:next() * (length - 2 * radius)
		-- half the props crowd the near band, where they read at speed
		local z = side
			* (
				if rng:chance(0.5)
					then rng:range(zLow, math.min(zLow + 120, zHigh))
					else rng:range(zLow, zHigh)
			)
		if def.sea and side > 0 and math.abs(z) > SHORE - 6 - radius then
			continue
		end
		if World.blocked(x, z, radius) or not fits(packer, x, z, radius) then
			continue
		end
		take(packer, x, z, radius)
		placed += 1
		local yaw = if Props.faces(kind)
			then (if side > 0 then 0 else 180) + rng:range(-8, 8)
			else rng:range(0, 360)
		local lights = not far and lit < 1 and math.abs(z) < 150
		if lights and Props.lit(kind) then
			lit += 1
		end
		local ctx: Props.Ctx = {
			rng = rng,
			biome = def,
			shadow = not far and Props.tall(kind) and math.abs(z) < 160,
			lights = lights,
			far = far,
		}
		Props.build(kind, model, CFrame.new(x - x0, groundTop, z) * Kit.angles(0, yaw, 0), ctx)
	end
end

--[[
	A patchwork on one side: one patch per grid cell, each rotated a little and
	kept inside its cell, so no two overlays ever overlap.
]]
local function patchwork(
	model: Model,
	x0: number,
	length: number,
	rng: Rng.Rng,
	side: number,
	bands: { { number } },
	columns: number,
	top: number,
	thickness: number
)
	local cellW = length / columns
	for column = 0, columns - 1 do
		for _, band in bands do
			if not rng:chance(0.78) then
				continue
			end
			local cellD = band[2] - band[1]
			local w, d = cellW * rng:range(0.45, 0.8), cellD * rng:range(0.45, 0.8)
			local theta = math.rad(rng:range(-12, 12))
			local ex = (w * math.abs(math.cos(theta)) + d * math.abs(math.sin(theta))) / 2
			local ez = (w * math.abs(math.sin(theta)) + d * math.abs(math.cos(theta))) / 2
			-- a long patch turned even a little can outgrow its cell: shrink it until it fits
			local fit = math.min(1, 0.96 * cellW / (2 * ex), 0.96 * cellD / (2 * ez))
			w, d, ex, ez = w * fit, d * fit, ex * fit, ez * fit
			local cx = x0 + column * cellW + ex + rng:next() * math.max(cellW - 2 * ex, 0)
			local cz = side * (band[1] + ez + rng:next() * math.max(cellD - 2 * ez, 0))
			local bounds = { x0 = cx - ex, x1 = cx + ex, z0 = cz - ez, z1 = cz + ez }
			if #reserved(bounds) > 0 then
				continue
			end
			local def = World.pick(cx, rng)
			local i = rng:int(1, #def.patches)
			Kit.block(
				model,
				Vector3.new(w, thickness, d),
				CFrame.new(cx - x0, top + thickness / 2, cz) * CFrame.Angles(0, theta, 0),
				Kit.jitter(def.patches[i], 0.05, rng:next()),
				{
					material = def.patchMaterials[math.min(i, #def.patchMaterials)],
					collide = false,
					shadow = false,
				}
			)
		end
	end
end

-- Track bed ---------------------------------------------------------------------------------------

local function buildBed(model: Model, x0: number, length: number, rng: Rng.Rng)
	local cx = length / 2
	Kit.block(
		model,
		Vector3.new(length, 0.6, 14),
		CFrame.new(cx, -6.55, 0),
		Kit.jitter(BALLAST, 0.04, rng:next()),
		{
			material = M.Pebble,
			collide = false,
			shadow = false,
		}
	)
	for _, z in { -2.6, 2.6 } do
		Kit.block(model, Vector3.new(length, 0.55, 0.5), CFrame.new(cx, -5.475, z), rgb(122, 118, 114), {
			material = M.Metal,
			collide = false,
			shadow = false,
		})
	end
	local height = FORMATION - GROUND
	for _, span in World.trackSpans(x0, x0 + length) do
		local len = span.b - span.a
		local mid = (span.a + span.b) / 2 - x0
		if len > 0.05 then
			if span.kind == "Gorge" then
				local piece = World.inKind("Gorge", (span.a + span.b) / 2)
				if piece and piece.style == 2 then
					Kit.block(model, Vector3.new(len, 4, 15), CFrame.new(mid, FORMATION - 2, 0), STONE, {
						material = M.Brick,
						collide = false,
						shadow = false,
					})
					for _, z in { -7.15, 7.15 } do
						-- parapets stand a touch proud of the deck's sides
						Kit.block(
							model,
							Vector3.new(len, 1.4, 0.8),
							CFrame.new(mid, -6.2, z),
							Kit.shade(STONE, 0.9),
							{
								material = M.Brick,
								collide = false,
								shadow = false,
							}
						)
					end
				else
					Kit.block(model, Vector3.new(len, 2.4, 12), CFrame.new(mid, FORMATION - 1.2, 0), IRON, {
						material = M.Metal,
						collide = false,
						shadow = false,
					})
				end
			else
				Kit.block(
					model,
					Vector3.new(len, height, 16),
					CFrame.new(mid, GROUND + height / 2, 0),
					Kit.shade(BALLAST, 0.8),
					{
						material = M.Ground,
						collide = false,
						shadow = false,
					}
				)
				-- far side (-Z) embankment: full height at the wedge's +Z face, toward the track
				Kit.wedge(
					model,
					Vector3.new(len, height, 10),
					CFrame.new(mid, GROUND + height / 2, -13),
					Kit.shade(BALLAST, 0.7),
					{
						material = M.Ground,
						collide = false,
						shadow = false,
					}
				)
				if span.kind == "Sink" then
					-- causeway wall dropping into the sinkhole
					-- (the wall stops under the coping, so their ends never share a plane)
					Kit.block(
						model,
						Vector3.new(len, 119.8, 2),
						CFrame.new(mid, FORMATION - 60.1, 9),
						STONE,
						{
							material = M.Brick,
							collide = false,
							shadow = false,
						}
					)
					Kit.block(
						model,
						Vector3.new(len, 0.6, 2.6),
						CFrame.new(mid, FORMATION + 0.1, 9),
						Kit.shade(STONE, 1.15),
						{
							material = M.Concrete,
							collide = false,
							shadow = false,
						}
					)
				else
					Kit.wedge(
						model,
						Vector3.new(len, height, 10),
						CFrame.new(mid, GROUND + height / 2, 13) * Kit.angles(0, 180, 0),
						Kit.shade(BALLAST, 0.7),
						{ material = M.Ground, collide = false, shadow = false }
					)
				end
			end
		end
	end
end

local function buildSleepers(model: Model, _x0: number, length: number, rng: Rng.Rng)
	local wood = rgb(74, 56, 40)
	for i = 0, math.floor(length / 4) - 1 do
		Kit.block(
			model,
			Vector3.new(1.3, 0.5, 9),
			CFrame.new(2 + i * 4, -6.0, 0),
			Kit.jitter(wood, 0.1, rng:next()),
			{
				material = M.Wood,
				collide = false,
				shadow = false,
			}
		)
	end
end

-- Trackside ---------------------------------------------------------------------------------------

local function embankmentY(z: number): number
	return FORMATION - (math.abs(z) - 8) * (FORMATION - GROUND) / 10
end

local function clearTrack(x: number): boolean
	return World.inKind("Tunnel", x, 10) == nil and World.inKind("Gorge", x, 10) == nil
end

-- Nothing reserved (a set piece, a sinkhole) at (x, z), and no tunnel or gorge on the line.
local function free(x: number, z: number, radius: number): boolean
	return clearTrack(x) and not World.blocked(x, z, radius)
end

-- Runs of fence along the line come in stretches several chunks long.
local function fenceRun(key: number, side: number): boolean
	local region = Rng.new(Rng.derive(World.seed, "fence", math.floor(key / 4), side))
	return region:chance(0.45)
end

local function buildTrackside(model: Model, x0: number, length: number, rng: Rng.Rng, key: number)
	local def = World.pick(x0 + length / 2, rng)
	local ctx: Props.Ctx = { rng = rng, biome = def, shadow = true }
	local poleX = x0 + length / 2
	if free(poleX, -13, 2) then
		-- telegraph pole on the far side, wires sagging to the next pole
		local z = -13
		local base = embankmentY(z)
		local top = base + 22
		Kit.post(model, 22, 0.7, CFrame.new(poleX - x0, base + 11, z), rgb(70, 56, 44), {
			material = M.Wood,
			collide = false,
			shadow = true,
		})
		Kit.block(model, Vector3.new(0.4, 0.4, 4), CFrame.new(poleX - x0, top - 1.5, z), rgb(64, 52, 42), {
			material = M.Wood,
			collide = false,
			shadow = false,
		})
		if free(poleX + length, -13, 2) then
			for _, dz in { -1.6, 1.6 } do
				local y = top - 1.3
				local from = Vector3.new(poleX - x0, y, z + dz)
				local sagMid = Vector3.new(poleX - x0 + length / 2, y - 1.6, z + dz)
				local to = Vector3.new(poleX - x0 + length, y, z + dz)
				for _, pair in { { from, sagMid }, { sagMid, to } } do
					local a, b = pair[1], pair[2]
					Kit.block(
						model,
						Vector3.new(0.08, 0.08, (b - a).Magnitude),
						Kit.between(a, b),
						rgb(30, 30, 32),
						{
							collide = false,
							shadow = false,
						}
					)
				end
			end
		end
	end
	if not clearTrack(x0) and not clearTrack(x0 + length) then
		return
	end
	-- verge grass on both shoulders
	for _ = 1, 2 do
		local x = x0 + rng:range(2, length - 2)
		local z = rng:sign() * rng:range(9.5, 16.5)
		if free(x, z, 2) then
			Props.grass(
				model,
				CFrame.new(x - x0, embankmentY(z) - 0.2, z) * Kit.angles(0, rng:range(0, 360), 0),
				{ rng = rng, biome = def, shadow = false }
			)
		end
	end
	-- mileposts every ten chunks, a signal now and then
	local sx = x0 + length * 0.3
	if key % 10 == 0 and free(sx, 10, 2) then
		Kit.block(
			model,
			Vector3.new(0.6, 3, 0.6),
			CFrame.new(sx - x0, embankmentY(10) + 1.5, 10),
			rgb(226, 222, 210),
			{
				material = M.Concrete,
				collide = false,
				shadow = false,
			}
		)
	end
	local signalX = x0 + length * 0.7
	if rng:chance(0.12) and free(signalX, 11, 3) then
		Props.semaphore(model, CFrame.new(signalX - x0, embankmentY(11), 11) * Kit.angles(0, 180, 0), ctx)
	end
	-- lineside fences, in runs, just past the foot of the embankment
	if not def.sea then
		for _, side in { -1, 1 } do
			local z = side * 20.5
			if fenceRun(key, side) and free(x0 + length / 2, z, length / 2) then
				Props.fence(
					model,
					CFrame.new(length / 2, GROUND, z),
					{ rng = rng, biome = def, shadow = false },
					length - 0.6
				)
			end
		end
	end
end

-- Near field ------------------------------------------------------------------------------------------

local NEAR_BANDS = { { 26, 120 }, { 120, 220 }, { 220, 320 }, { 320, 412 } }

-- Farmland: strips of crop across the track with hedgerows and the odd lane between them.
local function fields(model: Model, x0: number, x1: number, rng: Rng.Rng, side: number, farm: Biomes.Def)
	local cursor = x0
	local strips = farm.fields or farm.patches
	while cursor < x1 - 8 do
		local w = math.min(rng:range(26, 52), x1 - cursor)
		local strip = sideRect(cursor + 1.2, cursor + w - 1.2, side, 30, NEAR_Z - 10)
		local lane = rng:chance(0.12)
		local color = if lane then rgb(96, 80, 60) else Kit.jitter(rng:pick(strips), 0.05, rng:next())
		if lane then
			strip = sideRect(cursor + w / 2 - 3, cursor + w / 2 + 3, side, 22, NEAR_Z - 10)
		end
		for _, piece in Journey.subtract(strip, reserved(strip)) do
			slab(model, x0, piece, GROUND + OVERLAY_T, OVERLAY_T, color, if lane then M.Mud else M.Grass)
		end
		-- a hedgerow on the boundary, short of the strip ends so their faces never meet
		local hx = cursor + w
		if farm.hedges and hx < x1 - 4 and rng:chance(0.55) then
			local hedge = sideRect(hx - HEDGE_D / 2, hx + HEDGE_D / 2, side, 31, NEAR_Z - 11)
			if #reserved(hedge) == 0 then
				Kit.cylinder(
					model,
					hedge.z1 - hedge.z0,
					HEDGE_D,
					CFrame.new(hx - x0, GROUND + 0.6, (hedge.z0 + hedge.z1) / 2) * Kit.angles(0, 90, 0),
					Kit.jitter(HEDGE, 0.08, rng:next()),
					{ material = M.LeafyGrass, collide = false, shadow = false }
				)
			end
		end
		cursor += w
	end
end

local function buildNear(model: Model, x0: number, length: number, rng: Rng.Rng)
	local x1 = x0 + length
	local density = World.density
	for _, side in { -1, 1 } do
		local def = World.dominant(x0 + length / 2)
		local packer = newPacker()
		if def.sea and side > 0 then
			ground(model, x0, sideRect(x0, x1, side, 0, SHORE), GROUND, NEAR_T, 1)
			sea(model, x0, sideRect(x0, x1, side, SHORE, NEAR_Z), SEA_NEAR)
		else
			ground(model, x0, sideRect(x0, x1, side, 0, NEAR_Z), GROUND, NEAR_T, 1)
		end
		local zFar = if def.sea and side > 0 then SHORE - 6 else NEAR_Z - 20

		local farm = World.pick(x0 + length / 2, rng)
		if farm.fields and not (farm.sea and side > 0) then
			fields(model, x0, x1, rng, side, farm)
		elseif not (def.sea and side > 0) then
			patchwork(model, x0, length, rng, side, NEAR_BANDS, 2, GROUND, OVERLAY_T)
		end

		-- rolling ground: big balls buried so only a dome shows (0.35 of the size across at its foot)
		for _ = 1, math.floor(def.mounds * density + 0.5) do
			local size = rng:range(36, 110)
			-- the dome's foot inside the chunk, clear of props this chunk cannot see
			local x = x0 + size * 0.35 + rng:next() * (length - size * 0.7)
			local z = side * rng:range(70 + size / 2, NEAR_Z)
			if
				not (def.sea and side > 0)
				and not World.blocked(x, z, size / 2)
				and fits(packer, x, z, size * 0.35)
			then
				take(packer, x, z, size * 0.35)
				Kit.ball(
					model,
					size,
					CFrame.new(x - x0, GROUND - size * 0.36, z),
					Kit.jitter(def.hill, 0.06, rng:next()),
					{
						material = def.groundMaterial,
						collide = false,
						shadow = false,
					}
				)
			end
		end

		placeProps(
			model,
			x0,
			length,
			rng,
			side,
			24,
			zFar,
			math.floor(def.nearCount * density + 0.5),
			function(pick)
				return pick.near
			end,
			packer,
			false,
			GROUND
		)

		-- once in a while, something by the line that makes you look twice
		if rng:chance(0.14 * density) then
			placeProps(model, x0, length, rng, side, 30, 150, 1, function(pick)
				return pick.eerie
			end, packer, false, GROUND)
		end
	end
end

-- Mid field ----------------------------------------------------------------------------------------------

local MID_BANDS = { { NEAR_Z + 10, 760 }, { 760, 1180 }, { 1180, MID_Z - 20 } }

-- Whether the power line has a pylon in mid chunk k (same answer from both of its neighbours).
local function pylonAt(k: number): (boolean, number)
	local x = k * 400 + 200
	local def = World.dominant(x)
	return def.pylons and not World.blocked(x, PYLON_Z, 14), x
end

local function powerLine(model: Model, x0: number, k: number, rng: Rng.Rng)
	local here, x = pylonAt(k)
	if not here then
		return
	end
	local ctx: Props.Ctx = { rng = rng, biome = World.dominant(x), shadow = false, far = true }
	local frame = CFrame.new(x - x0, MID_TOP, PYLON_Z)
	local arms = Props.pylon(model, frame, ctx)
	local nextHere, nextX = pylonAt(k + 1)
	if not nextHere then
		return
	end
	local span = nextX - x
	for _, arm in arms do
		local a = frame * arm
		local b = a + Vector3.new(span, 0, 0)
		local sag = (a + b) / 2 - Vector3.new(0, 9, 0)
		for _, pair in { { a, sag }, { sag, b } } do
			local p, q = pair[1], pair[2]
			Kit.block(model, Vector3.new(0.18, 0.18, (q - p).Magnitude), Kit.between(p, q), rgb(26, 26, 28), {
				collide = false,
				shadow = false,
			})
		end
	end
end

--[[
	Hedgerows across the mid field (farm country): long hedges along the bands'
	edges, broken by gaps, cross hedges between them, and now and then a tree
	growing out of one. A run is only laid where every stretch of it is clear of
	reserved ground, hills and the power line, and then claims its line in the
	packer so props keep off it.
]]
local function midHedges(model: Model, x0: number, length: number, rng: Rng.Rng, side: number, packer: Packer)
	local y = MID_TOP + 0.7 -- the round's foot inside the mid slab
	local function run(ax: number, az: number, bx: number, bz: number)
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local steps = math.max(1, math.ceil(len / 10))
		for i = 0, steps do
			local t = i / steps
			local px, pz = ax + (bx - ax) * t, az + (bz - az) * t
			if World.blocked(px, pz, 3) or not fits(packer, px, pz, 2) then
				return
			end
		end
		for i = 0, steps do
			local t = i / steps
			take(packer, ax + (bx - ax) * t, az + (bz - az) * t, 2)
		end
		Kit.cylinder(
			model,
			len,
			HEDGE_D,
			-- the round's axis (its X) along the run
			Kit.between(Vector3.new(ax - x0, y, az), Vector3.new(bx - x0, y, bz)) * Kit.angles(0, 90, 0),
			Kit.jitter(HEDGE, 0.08, rng:next()),
			{ material = M.LeafyGrass, collide = false, shadow = false }
		)
		-- a hedgerow tree: a trunk and a crown, all that reads from here
		if len > 60 and rng:chance(0.6 * World.density) then
			local t = rng:range(0.2, 0.8)
			local tx, tz = ax + (bx - ax) * t - x0, az + (bz - az) * t
			local h = rng:range(18, 28)
			local def = World.pick(x0 + tx, rng)
			Kit.post(model, h * 0.5, h * 0.08, CFrame.new(tx, MID_TOP + h * 0.25 - 0.3, tz), def.trunk, {
				material = M.Wood,
				collide = false,
				shadow = false,
			})
			Kit.ball(
				model,
				h * 0.6,
				CFrame.new(tx, MID_TOP + h * 0.62, tz),
				Kit.jitter(def.foliage[rng:int(1, #def.foliage)], 0.06, rng:next()),
				{ material = M.LeafyGrass, collide = false, shadow = false }
			)
		end
	end
	-- long hedges on the bands' edges, in runs with gaps between
	for _, edge in { 760, 1180 } do
		local x = x0 + rng:range(4, 30)
		while x < x0 + length - 40 do
			local stop = math.min(x + rng:range(80, 200), x0 + length - 4)
			run(x, side * edge, stop, side * edge)
			x = stop + rng:range(20, 50)
		end
	end
	-- cross hedges between the long ones
	for _, band in { { NEAR_Z + 20, 754 }, { 766, 1174 }, { 1186, MID_Z - 30 } } do
		for _ = 1, rng:int(1, 3) do
			local x = x0 + rng:range(20, length - 20)
			run(x, side * band[1], x, side * band[2])
		end
	end
end

local function buildMid(model: Model, x0: number, length: number, rng: Rng.Rng, key: number)
	local x1 = x0 + length
	for _, side in { -1, 1 } do
		local def = World.dominant(x0 + length / 2)
		local packer = newPacker()
		if def.sea and side > 0 then
			sea(model, x0, sideRect(x0, x1, side, 18, MID_Z), SEA_MID)
			continue
		end
		if def.pylons and side < 0 then
			-- the power line's corridor: nothing grows into its pylons or under its cables
			table.insert(packer.bands, { PYLON_Z - LINE_CLEARANCE, PYLON_Z + LINE_CLEARANCE })
		end
		ground(model, x0, sideRect(x0, x1, side, 18, MID_Z), MID_TOP, MID_T, 0.94)
		patchwork(model, x0, length, rng, side, MID_BANDS, 3, MID_TOP, MID_OVERLAY_T)
		-- hills
		for _ = 1, rng:int(2, 4) do
			local size = rng:range(140, 440)
			-- the hill's foot inside the chunk, clear of props this chunk cannot see
			local x = x0 + size * 0.4 + rng:next() * (length - size * 0.8)
			local z = side * rng:range(NEAR_Z + size * 0.3, MID_Z - size * 0.3)
			-- buried 0.3 of its size, a hill's foot is 0.4 of its size across; underground
			-- it swells to half its size, which must stay out of any gorge or sinkhole
			if not World.blocked(x, z, size * 0.5) and fits(packer, x, z, size * 0.4) then
				take(packer, x, z, size * 0.4)
				local pick = World.pick(x, rng)
				Kit.ball(
					model,
					size,
					CFrame.new(x - x0, MID_TOP - size * 0.3, z),
					Kit.jitter(pick.hill, 0.06, rng:next()),
					{
						material = pick.groundMaterial,
						collide = false,
						shadow = false,
					}
				)
				if pick.snowcap and size > 260 then
					Kit.ball(
						model,
						size * 0.42,
						CFrame.new(x - x0, MID_TOP + size * 0.04, z),
						rgb(226, 230, 236),
						{
							material = M.Snow,
							collide = false,
							shadow = false,
						}
					)
				end
			end
		end
		if def.hedges and rng:chance(World.density) then
			midHedges(model, x0, length, rng, side, packer)
		end
		-- the edge of a wood, running along the line
		if def.belt and rng:chance(0.7) then
			local belt = def.belt :: string
			placeProps(model, x0, length, rng, side, 520, MID_Z - 200, 1, function()
				return { { kind = belt, weight = 1 } }
			end, packer, true, MID_TOP)
		end
		placeProps(
			model,
			x0,
			length,
			rng,
			side,
			NEAR_Z + 20,
			MID_Z - 120,
			math.floor(def.midCount * World.density + 0.5),
			function(pick)
				return pick.mid
			end,
			packer,
			true,
			MID_TOP
		)
		-- a column of smoke from somewhere out there
		if (def.id == "Coalfield" or def.id == "BurningTown") and rng:chance(0.5) then
			Props.smoke(
				model,
				CFrame.new(rng:range(40, length - 40), MID_TOP + 20, side * rng:range(600, 1400)),
				rng:range(8, 14),
				rgb(34, 30, 28)
			)
		end
	end
	powerLine(model, x0, key, rng)
end

-- Horizon ---------------------------------------------------------------------------------------------------

--[[
	A massif: a main peak and one to three lower shoulders strung along a random
	line, each peak a spire (two thin gables crossed, Props.spire), so the skyline
	is jagged and peaked from every side. Tall peaks carry snow: a copy of their
	top a touch wider, thicker and slacker, so it sits just proud of the rock.
	Everything stands on `base`, inside the slab beneath.
]]
local function massif(
	model: Model,
	x0: number,
	x: number,
	z: number,
	rng: Rng.Rng,
	color: Color3,
	snowcap: boolean,
	scale: number,
	base: number
)
	local main = rng:range(220, 700) * scale
	local axis = rng:range(0, math.pi)
	local function peak(px: number, pz: number, h: number)
		local width = h * rng:range(1.5, 2.1)
		local thin = width * 0.18
		-- each peak's feet at their own depth in the slab, so overlapping peaks never share a plane
		local at = CFrame.new(px - x0, base - rng:range(0, 0.2), pz) * Kit.angles(0, rng:range(0, 90), 0)
		Props.spire(model, at, h, width, Kit.jitter(color, 0.08, rng:next()), M.Rock, false, thin)
		if snowcap and h > 340 * scale then
			local cap = h * 0.3
			Props.spire(
				model,
				at * CFrame.new(0, h - cap, 0),
				cap,
				width * 0.3 * 1.04,
				rgb(232, 236, 244),
				M.Snow,
				false,
				thin * 1.04
			)
		end
	end
	peak(x, z, main)
	for i = 1, rng:int(1, 2) do
		local along = (if i % 2 == 0 then 1 else -1) * main * rng:range(0.45, 0.8) * (1 + (i - 1) * 0.4)
		peak(x + math.cos(axis) * along, z + math.sin(axis) * along, main * rng:range(0.45, 0.8))
	end
end

--[[
	The horizon's ground runs all the way in to the mid field's inner edge, right
	under the mid layer: the mid and near layers only reach so far ahead of the
	train, and past them this is the ground. Every ridge stands in it.
]]
local function buildHorizon(model: Model, x0: number, length: number, rng: Rng.Rng)
	local x1 = x0 + length
	for _, side in { -1, 1 } do
		local def = World.dominant(x0 + length / 2)
		local rect = sideRect(x0, x1, side, 18, FAR_Z)
		if def.sea and side > 0 then
			sea(model, x0, rect, SEA_HORIZON)
			if rng:chance(0.3) then
				-- an island, its foot inside the sea slab
				massif(
					model,
					x0,
					x0 + rng:range(0, length),
					side * rng:range(2800, 3600),
					rng,
					def.ridge,
					false,
					0.6,
					RIDGE_BASE
				)
			end
			continue
		end
		local color = Kit.shade(def.hill, 0.8)
		for _, band in { { 18, MID_Z, INNER_TOP, INNER_T }, { MID_Z, FAR_Z, HORIZON_TOP, HORIZON_T } } do
			local part = sideRect(x0, x1, side, band[1], band[2])
			for _, piece in Journey.subtract(part, World.cuts(part)) do
				slab(model, x0, piece, band[3], band[4], color, def.groundMaterial)
			end
		end
		-- a band of hills, then the far range behind it
		for _ = 1, 2 do
			local pick = World.pick(x0 + length / 2, rng)
			massif(
				model,
				x0,
				x0 + rng:range(0, length),
				side * rng:range(2000, 3500),
				rng,
				pick.ridge,
				pick.snowcap,
				1,
				RIDGE_BASE
			)
		end
		do
			local pick = World.pick(x0 + length / 2, rng)
			massif(
				model,
				x0,
				x0 + rng:range(0, length),
				side * rng:range(5200, 7800),
				rng,
				pick.mountain,
				pick.snowcap,
				2.4,
				RIDGE_BASE
			)
		end
	end
end

-- Dispatch ---------------------------------------------------------------------------------------------------

function Land.build(layer: Layer, key: number, model: Model, x0: number)
	local rng = World.rng(layer.name, key)
	if layer.name == "Bed" then
		buildBed(model, x0, layer.length, rng)
	elseif layer.name == "Sleepers" then
		buildSleepers(model, x0, layer.length, rng)
	elseif layer.name == "Trackside" then
		buildTrackside(model, x0, layer.length, rng, key)
	elseif layer.name == "Near" then
		buildNear(model, x0, layer.length, rng)
	elseif layer.name == "Mid" then
		buildMid(model, x0, layer.length, rng, key)
	elseif layer.name == "Horizon" then
		buildHorizon(model, x0, layer.length, rng)
	end
end

return Land
