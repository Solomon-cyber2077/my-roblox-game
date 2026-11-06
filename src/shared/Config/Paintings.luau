--!strict
--[[
	The rendered oil paintings (Blender, `tools/paintings/`): image asset ids, 0 until uploaded.

	  Train    the saloon's four, by style (Builders/TrainInterior PAINTINGS, same order and titles):
	           Dusk at the Viaduct, The High Line at Noon, Under the Amber Moon, Last Light over the Pass
	  Station  the dark landscapes in station rooms (Builders/RoomDecor Picture)

	While an id is 0 the old drawn painting stands in, clipped to its canvas.
]]

return table.freeze({
	Train = table.freeze({ 104089333086837, 135245425998975, 96427591092286, 119057284592989 }),
	Station = table.freeze({ 126325713436042, 120874758607785 }),
})
