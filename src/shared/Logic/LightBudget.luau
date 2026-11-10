--!strict
--[[
	Which of a stop's lamps stay lit on a phone (Controllers/StationVisualsController under the
	Performance setting): the `cap` nearest the camera, and every one within `always` studs however
	many that is, so the pool of light around the crew never goes dark.
]]

local LightBudget = {}

-- `distances[i]` is lamp i's distance from the camera; returns the set of lamps to keep lit.
function LightBudget.keep(distances: { number }, cap: number, always: number): { [number]: boolean }
	local order: { number } = {}
	for i in distances do
		table.insert(order, i)
	end
	table.sort(order, function(a, b)
		return distances[a] < distances[b]
	end)
	local keep: { [number]: boolean } = {}
	for rank, i in order do
		if rank <= cap or distances[i] <= always then
			keep[i] = true
		end
	end
	return keep
end

return table.freeze(LightBudget)
