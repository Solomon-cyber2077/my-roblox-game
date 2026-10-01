--!strict
--[[
	The landscape's chunk layers. Each layer tiles land x in fixed-length chunks
	and keeps the chunks inside its window (world x, relative to the train) built.

	  Bed        48   the formation, ballast and rails; embankments down to the
	                  ground, a causeway wall over a sinkhole, a deck over a gorge
	  Sleepers   48   timber sleepers
	  Trackside  60   telegraph poles with sagging wires, signals, fences, tufts
	  Near      120   the ground slab (top y -14), patches, field strips, mounds,
	                  trees and buildings out to |z| 420
	  Mid       400   lower ground out to |z| 1600, hills, groves and clumps
	  Horizon  1200   ridges with snowcaps out to |z| 4000

	Builders work in chunk-local space: land x maps to local x = x - x0.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Journey = require(Shared.Logic.Journey)
local Kit = require(Shared.Visual.Kit)
local Rng = require(Shared.Util.Rng)

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
	{ name = "Sleepers", length = 48, from = -300, to = 600, hideable = true },
	{ name = "Trackside", length = 60, from = -400, to = 1500, hideable = false },
	{ name = "Near", length = 120, from = -500, to = 2200, hideable = false },
	{ name = "Mid", length = 400, from = -1600, to = 4400, hideable = false },
	{ name = "Horizon", length = 1200, from = -6000, to = 8400, hideable = false },
} :: { Layer }

local GROUND = -14 -- near-field ground top
local MID_DROP = 0.3 -- the mid field sits this much lower so it never fights the near field
local SEA_NEAR = -15.2
local SEA_MID = -15.5
local SEA_HORIZON = -15.8
local FORMATION = -6.85 -- top of the formation under the ballast
local SHORE = 70 -- coast: sand from the track out to here, then sea
local NEAR_Z = 420
local MID_Z = 1600
local HORIZON_Z = 4000

local M = Enum.Material
local rgb = Color3.fromRGB
local BALLAST = rgb(84, 80, 76)
local STONE = rgb(110, 102, 92)
local IRON = rgb(44, 44, 48)
local SEA = rgb(44, 78, 92)

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

local function sea(parent: Instance, x0: number, rect: Journey.Rect, top: number)
	local part = slab(parent, x0, rect, top, 1, SEA, M.SmoothPlastic)
	part.Reflectance = 0.22
end

-- Ground slabs over `rect`, minus every cut, coloured by the biome mix along the chunk.
local function ground(parent: Instance, x0: number, rect: Journey.Rect, top: number, darken: number)
	local cx = (rect.x0 + rect.x1) / 2
	local color = Kit.shade(
		World.color(cx, function(def)
			return def.ground
		end),
		darken
	)
	local material = World.dominant(cx).groundMaterial
	for _, piece in Journey.subtract(rect, World.cuts(rect)) do
		slab(parent, x0, piece, top, 2, color, material)
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
					for _, z in { -7.1, 7.1 } do
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
					Kit.block(model, Vector3.new(len, 120, 2), CFrame.new(mid, FORMATION - 60, 9), STONE, {
						material = M.Brick,
						collide = false,
						shadow = false,
					})
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
						CFrame.lookAt((a + b) / 2, b),
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
	-- grass tufts on both shoulders
	for _ = 1, 2 do
		local x = x0 + rng:range(0, length)
		local z = rng:sign() * rng:range(9, 17)
		if free(x, z, 2) then
			local size = rng:range(1.2, 2.6)
			Kit.block(
				model,
				Vector3.new(size * 1.6, size, size),
				CFrame.new(x - x0, embankmentY(z) + size * 0.25, z) * Kit.angles(0, rng:range(0, 90), 0),
				Kit.jitter(def.tufts, 0.12, rng:next()),
				{ material = M.Grass, collide = false, shadow = false }
			)
		end
	end
	-- mileposts every ten chunks, a signal now and then, fences in farm country
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
	if def.fields and rng:chance(0.3) then
		for _, side in { -1, 1 } do
			local z = side * 19.5
			if free(x0 + length / 2, z, length / 2) then
				Props.fence(
					model,
					CFrame.new(length / 2, GROUND, z),
					{ rng = rng, biome = def, shadow = false }
				)
			end
		end
	end
end

-- Near field ------------------------------------------------------------------------------------------

-- Every reservation and cut overlapping `rect`, for clipping strips and patches.
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

local function sideRect(x0: number, x1: number, side: number, near: number, far: number): Journey.Rect
	if side > 0 then
		return { x0 = x0, x1 = x1, z0 = near, z1 = far }
	end
	return { x0 = x0, x1 = x1, z0 = -far, z1 = -near }
end

local function placeProps(
	model: Model,
	x0: number,
	length: number,
	rng: Rng.Rng,
	side: number,
	zNear: number,
	zFar: number,
	count: number,
	listOf: (Biomes.Def) -> { Biomes.Weighted }
)
	for _ = 1, count do
		local x = x0 + rng:range(0, length)
		local z = side * rng:range(zNear, zFar)
		local def = World.pick(x, rng)
		local entries: { Rng.Weighted<string> } = {}
		for _, entry in listOf(def) do
			table.insert(entries, { weight = entry.weight, value = entry.kind })
		end
		local kind = rng:weighted(entries)
		if def.sea and side > 0 and z > SHORE - 6 then
			continue
		end
		if World.blocked(x, z, Props.radius(kind)) then
			continue
		end
		local yaw = if Props.faces(kind)
			then (if side > 0 then 0 else 180) + rng:range(-8, 8)
			else rng:range(0, 360)
		local ctx: Props.Ctx = {
			rng = rng,
			biome = def,
			shadow = Props.tall(kind) and math.abs(z) < 160,
			far = zNear >= NEAR_Z,
		}
		Props.build(kind, model, CFrame.new(x - x0, GROUND, z) * Kit.angles(0, yaw, 0), ctx)
	end
end

local function buildNear(model: Model, x0: number, length: number, rng: Rng.Rng)
	local x1 = x0 + length
	local density = World.density
	for _, side in { -1, 1 } do
		local def = World.dominant(x0 + length / 2)
		if def.sea and side > 0 then
			ground(model, x0, sideRect(x0, x1, side, 18, SHORE), GROUND, 1)
			local water = sideRect(x0, x1, side, SHORE, NEAR_Z)
			for _, piece in Journey.subtract(water, World.cuts(water)) do
				sea(model, x0, piece, SEA_NEAR)
			end
		else
			ground(model, x0, sideRect(x0, x1, side, 18, NEAR_Z), GROUND, 1)
		end
		local zFar = if def.sea and side > 0 then SHORE - 6 else NEAR_Z - 20

		-- patches of a different shade
		for _ = 1, math.floor(3 * density + 0.5) do
			local x = x0 + rng:range(0, length)
			local z = side * rng:range(24, zFar)
			local pick = World.pick(x, rng)
			local w, d = rng:range(16, 60), rng:range(16, 60)
			if not World.blocked(x, z, math.max(w, d) / 2) then
				Kit.block(
					model,
					Vector3.new(w, 0.2, d),
					CFrame.new(x - x0, GROUND + 0.1, z) * Kit.angles(0, rng:range(0, 90), 0),
					Kit.jitter(rng:pick(pick.patches), 0.06, rng:next()),
					{ material = pick.groundMaterial, collide = false, shadow = false }
				)
			end
		end

		-- field strips across the track
		local farm = World.pick(x0 + length / 2, rng)
		if farm.fields and not (farm.sea and side > 0) then
			local fields = farm.fields
			local cursor = x0
			while cursor < x1 - 8 do
				local w = math.min(rng:range(26, 52), x1 - cursor)
				local strip = sideRect(cursor + 0.8, cursor + w - 0.8, side, 30, NEAR_Z - 10)
				local color = Kit.jitter(rng:pick(fields), 0.05, rng:next())
				for _, piece in Journey.subtract(strip, reserved(strip)) do
					slab(model, x0, piece, GROUND + 0.18, 0.2, color, M.Grass)
				end
				cursor += w
			end
		end

		-- mounds: big balls buried so only a dome shows
		for _ = 1, math.floor(def.mounds * density + 0.5) do
			local size = rng:range(30, 90)
			local x = x0 + rng:range(0, length)
			local z = side * rng:range(60 + size / 2, NEAR_Z)
			if not World.blocked(x, z, size / 2) and not (def.sea and side > 0) then
				Kit.ball(
					model,
					size,
					CFrame.new(x - x0, GROUND - size * 0.34, z),
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
			end
		)
	end
end

-- Mid field ----------------------------------------------------------------------------------------------

local function buildMid(model: Model, x0: number, length: number, rng: Rng.Rng)
	local x1 = x0 + length
	local top = GROUND - MID_DROP
	for _, side in { -1, 1 } do
		local def = World.dominant(x0 + length / 2)
		if def.sea and side > 0 then
			sea(model, x0, sideRect(x0, x1, side, 18, MID_Z), SEA_MID)
			continue
		end
		ground(model, x0, sideRect(x0, x1, side, 18, MID_Z), top, 0.96)
		for _ = 1, rng:int(2, 3) do
			local size = rng:range(120, 360)
			local x = x0 + rng:range(0, length)
			local z = side * rng:range(NEAR_Z + size * 0.3, MID_Z - size * 0.3)
			if not World.blocked(x, z, size * 0.4) then
				local pick = World.pick(x, rng)
				local color = Kit.jitter(pick.hill, 0.06, rng:next())
				Kit.ball(model, size, CFrame.new(x - x0, top - size * 0.3, z), color, {
					material = pick.groundMaterial,
					collide = false,
					shadow = false,
				})
				if pick.snowcap and size > 240 then
					Kit.ball(
						model,
						size * 0.42,
						CFrame.new(x - x0, top + size * 0.04, z),
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
		for _ = 1, 2 do
			local x = x0 + rng:range(0, length)
			local z = side * rng:range(NEAR_Z, MID_Z - 100)
			local pick = World.pick(x, rng)
			local size = rng:range(80, 200)
			if not World.blocked(x, z, size / 2) then
				Kit.block(
					model,
					Vector3.new(size, 0.3, size * rng:range(0.5, 1)),
					CFrame.new(x - x0, top + 0.15, z) * Kit.angles(0, rng:range(0, 90), 0),
					Kit.jitter(rng:pick(pick.fields or pick.patches), 0.05, rng:next()),
					{ material = pick.groundMaterial, collide = false, shadow = false }
				)
			end
		end
		placeProps(
			model,
			x0,
			length,
			rng,
			side,
			NEAR_Z + 20,
			MID_Z - 120,
			math.floor(4 * World.density + 0.5),
			function(pick)
				return pick.mid
			end
		)
	end
end

-- Horizon ---------------------------------------------------------------------------------------------------

local function ridge(model: Model, x0: number, x: number, z: number, rng: Rng.Rng, def: Biomes.Def)
	local length = rng:range(300, 900)
	local height = rng:range(220, 760)
	local depth = height * rng:range(1.4, 2)
	local frame = CFrame.new(x - x0, GROUND - 1, z) * Kit.angles(0, rng:range(-25, 25), 0)
	local color = Kit.jitter(def.ridge, 0.08, rng:next())
	local function prism(h: number, d: number, base: CFrame, c: Color3, material: Enum.Material)
		Kit.wedge(
			model,
			Vector3.new(length * (h / height), h, d / 2),
			base * CFrame.new(0, h / 2, -d / 4),
			c,
			{
				material = material,
				collide = false,
				shadow = false,
			}
		)
		Kit.wedge(
			model,
			Vector3.new(length * (h / height), h, d / 2),
			base * CFrame.new(0, h / 2, d / 4) * Kit.angles(0, 180, 0),
			Kit.shade(c, 0.86),
			{ material = material, collide = false, shadow = false }
		)
	end
	prism(height, depth, frame, color, M.Rock)
	if def.snowcap and height > 360 then
		local h = height * 0.3
		-- a scaled copy of the ridge, a touch deeper so its faces sit just proud of the rock
		prism(h, depth * 0.3 * 1.04, frame * CFrame.new(0, height - h, 0), rgb(232, 236, 244), M.Snow)
	end
end

local function buildHorizon(model: Model, x0: number, length: number, rng: Rng.Rng)
	local x1 = x0 + length
	for _, side in { -1, 1 } do
		local def = World.dominant(x0 + length / 2)
		local rect = sideRect(x0, x1, side, MID_Z, HORIZON_Z)
		if def.sea and side > 0 then
			sea(model, x0, rect, SEA_HORIZON)
			if rng:chance(0.3) then
				ridge(model, x0, x0 + rng:range(0, length), side * rng:range(2800, 3600), rng, def)
			end
			continue
		end
		slab(model, x0, rect, GROUND - 1, 2, Kit.shade(def.hill, 0.85), def.groundMaterial)
		for _ = 1, rng:int(3, 5) do
			ridge(
				model,
				x0,
				x0 + rng:range(0, length),
				side * rng:range(2000, 3500),
				rng,
				World.pick(x0 + length / 2, rng)
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
		buildMid(model, x0, layer.length, rng)
	elseif layer.name == "Horizon" then
		buildHorizon(model, x0, layer.length, rng)
	end
end

return Land
