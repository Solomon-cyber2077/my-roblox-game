--!strict
--[[
	Sculpted heads and hands for the kit figures (tools/faces/build.py; Builders/FaceKit wears them):
	four base heads (male/female, young/old), two cuts of hair (hair_short, hair_bun), six styles of
	facial hair (whiskers_<style>, none with sideburns) and a left and right hand. Each mesh's
	texture is clear where the skin is plain, so the MeshPart's Color, the person's own skin (the hair
	colour for hair and whiskers), shows through.

	`centre` is each mesh's box centre from its anchor and `size` its box as built, in studs (right, up,
	back; the upload is set to it, whatever units the importer read): a head from the kit
	head ball's centre, a hand from the wrist (0.19 above the kit hand ball's centre). Ids are the owner's uploads (2026-11-07, Open Cloud, one model per piece; the ids
	are the mesh and texture inside each). Until every mesh a figure needs has one, it keeps its part-built
	face and hands.
]]

export type Piece = { centre: { number }, faces: number, size: { number } }
export type Asset = { mesh: number, texture: number }

local FaceKit = {}

-- where the sculpted head (and its whiskers) sits from the kit head ball's centre: up and forward,
-- so the face clears the kit's hair cap and hats (right, up, back)
FaceKit.Seat = table.freeze({ 0, 0.1, -0.1 })

FaceKit.Pieces = table.freeze({
	head_m_young = { centre = { 0.0, -0.144, -0.051 }, faces = 2084, size = { 0.988, 1.452, 1.142 } },
	head_m_old = { centre = { 0.0, -0.144, -0.056 }, faces = 2084, size = { 0.99, 1.452, 1.152 } },
	head_f_young = { centre = { 0.0, -0.159, -0.038 }, faces = 2084, size = { 0.897, 1.423, 1.075 } },
	head_f_old = { centre = { 0.0, -0.159, -0.041 }, faces = 2084, size = { 0.899, 1.423, 1.083 } },
	hair_short = { centre = { 0.001, 0.205, 0.043 }, faces = 368, size = { 0.883, 0.864, 0.975 } },
	hair_bun = { centre = { -0.001, 0.17, 0.092 }, faces = 1264, size = { 1.094, 0.9, 1.193 } },
	whiskers_walrus = { centre = { -0.002, -0.36, -0.391 }, faces = 1080, size = { 0.451, 0.287, 0.341 } },
	whiskers_handlebar = { centre = { 0.002, -0.257, -0.413 }, faces = 1920, size = { 0.711, 0.139, 0.294 } },
	whiskers_chevron = { centre = { -0.0, -0.278, -0.534 }, faces = 160, size = { 0.315, 0.119, 0.072 } },
	whiskers_vandyke = { centre = { 0.001, -0.448, -0.311 }, faces = 198, size = { 0.364, 0.459, 0.517 } },
	whiskers_curtain = { centre = { 0.002, -0.534, -0.179 }, faces = 180, size = { 0.75, 0.354, 0.64 } },
	whiskers_full = { centre = { 0.002, -0.668, -0.21 }, faces = 1292, size = { 0.884, 0.904, 0.702 } },
	hand_r = { centre = { -0.043, -0.175, -0.016 }, faces = 684, size = { 0.199, 0.35, 0.221 } },
	hand_l = { centre = { 0.043, -0.175, -0.016 }, faces = 684, size = { 0.199, 0.35, 0.221 } },
}) :: { [string]: Piece }

FaceKit.Ids = table.freeze({
	head_m_young = { mesh = 102365691059734, texture = 112223543580022 },
	head_m_old = { mesh = 138232892001043, texture = 134695108290828 },
	head_f_young = { mesh = 129199845761429, texture = 98026444074305 },
	head_f_old = { mesh = 98788765258453, texture = 110280059433780 },
	hair_short = { mesh = 135841155645944, texture = 90729120332816 },
	hair_bun = { mesh = 125726686328895, texture = 75029872110469 },
	whiskers_walrus = { mesh = 97963562251722, texture = 79629523580995 },
	whiskers_handlebar = { mesh = 97878157337654, texture = 108026881818396 },
	whiskers_chevron = { mesh = 134973910550800, texture = 97405858430759 },
	whiskers_vandyke = { mesh = 84611975108603, texture = 91690470906548 },
	whiskers_curtain = { mesh = 135268200951356, texture = 129493859789662 },
	whiskers_full = { mesh = 127785541694915, texture = 112944778175656 },
	hand_r = { mesh = 106704169619675, texture = 90613753703154 },
	hand_l = { mesh = 124806427096467, texture = 74400584098128 },
}) :: { [string]: Asset }

return table.freeze(FaceKit)
