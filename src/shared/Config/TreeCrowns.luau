--!strict
--[[
	Blender crowns for the station trees (tools/trees/build.py: one mesh each, no texture), uploaded
	under the owner's account. A crown with no id yet keeps its Part balls
	(Builders/TreeCrowns).
]]

local TreeCrowns: { [string]: number } = {
	crown_oak_a = 82061257568745,
	crown_oak_b = 117809123805414,
	crown_elm = 99574489469487,
	crown_poplar = 139177178887647,
	crown_birch = 130859333337669,
}

return table.freeze(TreeCrowns)
