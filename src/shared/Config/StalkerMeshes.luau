--!strict
--[[
	Close-up meshes for the Stalker (tools/stalker/build.py, assets/stalker/*.fbx), uploaded under the
	owner's account. `size` is the mesh's box in studs and `center` where that box's middle sits in the
	frame of the part it is welded to (the head, a hand, a forearm bone, an upper-arm bone, the pelvis).
	A mesh with no id yet leaves the block build in place (Builders/HollowBuilder); the blocks also stay
	as the Performance setting's lighter version.
]]

export type Piece = { id: number?, size: { number }, center: { number } }

local StalkerMeshes: { [string]: Piece } = {
	head = { id = 123906462924166, size = { 0.765, 1.469, 1.061 }, center = { -0.003, 0.005, -0.035 } },
	hand = { id = 103415365644746, size = { 0.542, 1.689, 0.336 }, center = { 0.069, -0.624, -0.064 } },
	handL = { id = 81276671935458, size = { 0.542, 1.689, 0.336 }, center = { -0.069, -0.624, -0.064 } }, -- the right hand, thumb inward
	forearm = { id = 71731572612543, size = { 2.75, 0.342, 0.304 }, center = { 0, 0, -0.004 } },
	sleeve = { id = 123969143830111, size = { 3.523, 0.452, 0.408 }, center = { -0.311, 0, 0 } },
	coat = { id = 87378685938379, size = { 1.86, 4.118, 1.429 }, center = { 0, -2.459, 0.105 } },
}

return StalkerMeshes
