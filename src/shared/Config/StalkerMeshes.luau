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
	head = { id = 113544450008210, size = { 0.82, 1.403, 1.022 }, center = { 0.001, 0, -0.019 } },
	hand = { id = 103415365644746, size = { 0.542, 1.689, 0.336 }, center = { 0.069, -0.624, -0.064 } },
	forearm = { id = 71731572612543, size = { 2.75, 0.342, 0.304 }, center = { 0, 0, -0.004 } },
	sleeve = { id = 97551971745771, size = { 3.128, 0.452, 0.408 }, center = { -0.114, 0, 0 } },
	coat = { id = 84076796145609, size = { 1.84, 3.893, 1.455 }, center = { -0.01, -2.346, 0.135 } },
}

return StalkerMeshes
