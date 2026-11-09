--!strict
--[[
	The Depot hall's lived-in props as Blender meshes (tools/hallwear/build.py: one mesh and one
	baked texture each), uploaded through Studio's 3D Importer.
	Each mesh stands on its own base, centred: Builders/HallWear lifts it by half its height.
]]

export type Asset = { mesh: number, texture: number }

local HallProps: { [string]: Asset } = {
	churn = { mesh = 98143953191165, texture = 101886164443067 },
	coat = { mesh = 131538888034576, texture = 88789015590756 },
	puddle = { mesh = 112159736508125, texture = 102137652430338 },
	trunk = { mesh = 88542748982516, texture = 130924212827569 },
	hatbox = { mesh = 125277676193961, texture = 107630013267107 },
	barrow = { mesh = 124266200783682, texture = 78966560037717 },
	sack = { mesh = 121432835497606, texture = 105301534801215 },
}

return table.freeze(HallProps)
