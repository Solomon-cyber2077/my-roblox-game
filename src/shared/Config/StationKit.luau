--!strict
--[[
	The stations' Blender kit (tools/stationkit/build_kit.py -> assets/stationkit/StationKit.fbx,
	sizes and centres from StationKit.json). Each piece is one MeshPart with vertex colours
	(give it a white Color), placed by Builders/StationKit over the primitives it dresses.

	Uploaded 2026-10-13 through Studio's 3D Importer (creator Me). A nil meshId, or one that
	fails to load, leaves that piece's props as primitives.

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
		meshId = 93198706345781,
		size = { 1.9, 12.2, 1.9 },
		centre = { 0, 6.1, 0 },
		tris = 260,
		dresses = { "YardLamp" },
	},
	HazardRail = {
		meshId = 132614559525758,
		size = { 12, 3.6, 0.44 },
		centre = { 0, 1.8, 0 },
		tris = 180,
		dresses = { "EdgeMark" },
		stretch = true,
	},
	FencePicket = {
		meshId = 99670469182064,
		size = { 12.2, 4, 0.9 },
		centre = { 0, 2, 0.15 },
		tris = 456,
		-- not dressed: 456 tris over pickets whose primitives cost 168 put Schoolhouse over the
		-- 300k drawn-triangle budget (334k measured, seed 424244); kept for a lighter mesh
		dresses = {},
		stretch = true,
	},
	Crate = {
		meshId = 85895937205144,
		size = { 4.22, 4, 4.22 },
		centre = { 0, 2, 0 },
		tris = 168,
		dresses = {},
	},
	SignBoard = {
		meshId = 122336731586650,
		size = { 8, 5.8, 0.47 },
		centre = { 0, 2.9, 0.115 },
		tris = 48,
		dresses = {},
	},
	WallBrick = {
		meshId = 124480481130526,
		size = { 12.1, 12, 1.33 },
		centre = { 0, 6, -0.135 },
		tris = 120,
		dresses = {},
	},
	RoofSlate = {
		meshId = 83908659612438,
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
