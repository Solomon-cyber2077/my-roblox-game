--!strict
--[[
	The planned world the chunk builders read: the scene seed, the biome
	timeline, the set pieces and the station sinkholes, all in land coordinates
	(see Logic/Journey). SceneryController owns and edits it; builders only
	query it, so a chunk built twice from the same plan comes out the same.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Journey = require(Shared.Logic.Journey)
local Rng = require(Shared.Util.Rng)

local Biomes = require(script.Parent.Biomes)

local World = {
	seed = 1931,
	density = 1,
	base = Journey.FirstBiome :: Journey.Biome,
	transitions = {} :: { Journey.Transition },
	pieces = {} :: { Journey.Piece },
	sinkholes = {} :: { Journey.Sinkhole },
}

function World.reset(seed: number, base: Journey.Biome)
	World.seed = seed
	World.base = base
	table.clear(World.transitions)
	table.clear(World.pieces)
	table.clear(World.sinkholes)
end

function World.rng(layer: string, key: number): Rng.Rng
	return Rng.new(Rng.derive(World.seed, layer, key))
end

-- Biomes ------------------------------------------------------------------------------------

function World.biomes(x: number): (Biomes.Def, Biomes.Def, number)
	local a, b, w = Journey.sample(World.base, World.transitions, x)
	return Biomes.get(a), Biomes.get(b), w
end

-- One biome for a single prop at land x.
function World.pick(x: number, rng: Rng.Rng): Biomes.Def
	local a, b, w = World.biomes(x)
	return if rng:next() < w then b else a
end

-- The dominant biome at land x (for things that cannot mix, like the sea).
function World.dominant(x: number): Biomes.Def
	local a, b, w = World.biomes(x)
	return if w >= 0.5 then b else a
end

function World.color(x: number, read: (Biomes.Def) -> Color3): Color3
	local a, b, w = World.biomes(x)
	return read(a):Lerp(read(b), w)
end

function World.addTransition(transition: Journey.Transition)
	table.insert(World.transitions, transition)
	table.sort(World.transitions, function(p, q)
		return p.at < q.at
	end)
end

-- Ground and reservations --------------------------------------------------------------------

-- Every cut (gorge voids, sinkholes) that overlaps `rect`.
function World.cuts(rect: Journey.Rect): { Journey.Rect }
	local cuts: { Journey.Rect } = {}
	for _, piece in World.pieces do
		local cut = Journey.groundCut(piece)
		if cut and Journey.overlaps(cut, rect) then
			table.insert(cuts, cut)
		end
	end
	for _, sinkhole in World.sinkholes do
		if Journey.overlaps(sinkhole.rect, rect) then
			table.insert(cuts, sinkhole.rect)
		end
	end
	return cuts
end

-- True when a prop of `radius` at (x, z) would sit on a set piece, a cut or a sinkhole.
function World.blocked(x: number, z: number, radius: number): boolean
	for _, piece in World.pieces do
		if Journey.contains(Journey.footprint(piece), x, z, radius) then
			return true
		end
	end
	for _, sinkhole in World.sinkholes do
		if Journey.contains(sinkhole.rect, x, z, radius + 6) then
			return true
		end
	end
	return false
end

--[[
	The track bed between land x0 and x1 as ordered spans: "Land" (embankment),
	"Gorge" (a bridge deck over the void) and "Sink" (a causeway wall on the
	platform side). Sinkholes never overlap gorges: pieces are trimmed clear of docks.
]]
function World.trackSpans(x0: number, x1: number): { Journey.Span }
	local spans: { Journey.Span } = { { a = x0, b = x1, kind = "Land" } }
	for _, piece in World.pieces do
		if piece.kind == "Gorge" and piece.at < x1 and piece.at + piece.length > x0 then
			spans = Journey.split(spans, piece.at, piece.at + piece.length, "Gorge")
		end
	end
	for _, sinkhole in World.sinkholes do
		if sinkhole.rect.x0 < x1 and sinkhole.rect.x1 > x0 then
			spans = Journey.split(spans, sinkhole.rect.x0, sinkhole.rect.x1, "Sink")
		end
	end
	return spans
end

function World.inKind(kind: Journey.PieceKind, x: number, pad: number?): Journey.Piece?
	local p = pad or 0
	for _, piece in World.pieces do
		if piece.kind == kind and x > piece.at - p and x < piece.at + piece.length + p then
			return piece
		end
	end
	return nil
end

function World.sinkholeAt(x: number, z: number): Journey.Sinkhole?
	for _, sinkhole in World.sinkholes do
		if Journey.contains(sinkhole.rect, x, z) then
			return sinkhole
		end
	end
	return nil
end

return World
