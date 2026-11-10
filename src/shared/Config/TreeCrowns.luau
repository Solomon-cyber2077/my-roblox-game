--!strict
--[[
	Blender crowns for the station trees (tools/trees/build.py: one mesh each, no texture), uploaded
	through Studio's 3D Importer under the owner's account. A crown with no id yet keeps its Part balls
	(Builders/TreeCrowns).
]]

local TreeCrowns: { [string]: number } = {
	-- crown_oak_a = <mesh id>,
	-- crown_oak_b = <mesh id>,
	-- crown_elm = <mesh id>,
	-- crown_poplar = <mesh id>,
	-- crown_birch = <mesh id>,
}

return table.freeze(TreeCrowns)
