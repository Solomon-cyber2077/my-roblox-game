--!strict
--[[
	The stations' Blender kit (tools/stationkit/build_kit.py -> assets/stationkit/StationKit.fbx,
	sizes and centres from StationKit.json). Each piece is one MeshPart with vertex colours
	(give it a white Color), placed by Builders/StationKit over the primitives it dresses.

	meshId is nil until the FBX is uploaded (Studio's 3D Importer, creator Me): until then
	every station keeps its primitives, unchanged. After uploading, paste each piece's mesh
	id here; nothing else changes.

	size and centre are in the piece's frame (X along, Y up, Z away from the train), studs,
	the centre measured from the piece's foot. `for`: the station prop kinds it dresses;
	`stretch` pieces scale along X to the prop's length.
]]

export type Piece = {
	meshId: number?,
	size: { number },
	centre: { number },
	tris: number,
	dresses: { string },
	stretch: boolean?,
}

local Pieces: { [string]: Piece } = {
	GasLamp = {
		meshId = nil,
		size = { 1.9, 12.2, 1.9 },
		centre = { 0, 6.1, 0 },
		tris = 260,
		dresses = { "YardLamp" },
	},
	HazardRail = {
		meshId = nil,
		size = { 12, 3.6, 0.44 },
		centre = { 0, 1.8, 0 },
		tris = 180,
		dresses = { "EdgeMark" },
		stretch = true,
	},
	FencePicket = {
		meshId = nil,
		size = { 12.2, 4, 0.9 },
		centre = { 0, 2, 0.15 },
		tris = 456,
		dresses = { "FencePicket" },
		stretch = true,
	},
	Crate = { meshId = nil, size = { 4.22, 4, 4.22 }, centre = { 0, 2, 0 }, tris = 168, dresses = {} },
	SignBoard = { meshId = nil, size = { 8, 5.8, 0.47 }, centre = { 0, 2.9, 0.115 }, tris = 48, dresses = {} },
	WallBrick = {
		meshId = nil,
		size = { 12.1, 12, 1.33 },
		centre = { 0, 6, -0.135 },
		tris = 120,
		dresses = {},
	},
	RoofSlate = {
		meshId = nil,
		size = { 12.1, 4.451, 12.33 },
		centre = { 0, 2.175, 0 },
		tris = 132,
		dresses = {},
	},
}

-- prop kind -> piece name
local ByProp: { [string]: string } = {}
for name, piece in Pieces do
	for _, kind in piece.dresses do
		ByProp[kind] = name
	end
	table.freeze(piece)
end

return table.freeze({
	Pieces = table.freeze(Pieces),
	ByProp = table.freeze(ByProp),
})
