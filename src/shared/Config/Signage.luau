--!strict
--[[
	The period signage remade as meshes (tools/signage): posters, bills, notices, plaques, chalk,
	framed texts and the stones that carry a lore line. Each sign is one MeshPart laid on the face
	of the part whose SurfaceGui it replaces (Builders/SignArt), wearing the SurfaceAppearance of
	its texture set from Server.SignLooks (src/server/SignLooks.model.json).

	Meshes are sized in studs to that part's face, face toward -Z, back on z = 0. Under Settings'
	Performance the mesh is hidden and the old SurfaceGui shows again (Controllers/DetailController).
]]

export type Sign = { mesh: number, look: string }

local function sign(mesh: number, look: string): Sign
	return table.freeze({ mesh = mesh, look = look })
end

return table.freeze({
	-- off: on the Quality setting the sign meshes draw blank or black (normals or maps), so the printed signs
	-- show everywhere until the meshes are re-exported
	Enabled = false,
	-- out from the old face, so the paper never fights the part under it
	Gap = 0.012,
	Signs = table.freeze({
		poster_coast = sign(79365711666149, "poster_coast"),
		poster_fog = sign(89299046435673, "poster_fog"),
		poster_coal = sign(110059162676417, "poster_coal"),
		poster_moon = sign(122390449518843, "poster_moon"),
		-- the notice board's bills, in StationDressing's NOTICES order, and Ellie's appeal for Tom
		bill_1 = sign(75674038631820, "bills"),
		bill_2 = sign(97666805923622, "bills"),
		bill_3 = sign(105303832590776, "bills"),
		bill_4 = sign(99207294807299, "bills"),
		bill_5 = sign(104505542310357, "bills"),
		bill_tom = sign(89912540456154, "bills"),
		notice_iron = sign(114389624007142, "metal"),
		plaque_kept_lit = sign(73005293215070, "metal"),
		plaque_temperance = sign(77888978574513, "metal"),
		plaque_subscription = sign(77892918733347, "metal"),
		enamel_no_passengers = sign(114862935468367, "metal"),
		datestone_ashgrove = sign(97428956231041, "stone"),
		jubilee_die = sign(130025275383849, "stone"),
		-- the schoolroom boards, in FurnitureKit's CHALK order, and the tea room's menu
		chalk_1 = sign(72808231243982, "chalk_1"),
		chalk_2 = sign(75145140650205, "chalk_2"),
		chalk_3 = sign(81014454656337, "chalk_3"),
		chalk_4 = sign(99754768432083, "chalk_4"),
		chalk_5 = sign(133957315568471, "chalk_5"),
		chalk_tearoom = sign(81092402949269, "chalk_tearoom"),
		-- RoomDecor's framed texts, in its TEXTS order
		framed_1 = sign(120993219931329, "framed"),
		framed_2 = sign(109335027752195, "framed"),
		framed_3 = sign(82452269938214, "framed"),
		framed_4 = sign(71029839754525, "framed"),
		framed_5 = sign(116831568621115, "framed"),
	}) :: { [string]: Sign },
})
