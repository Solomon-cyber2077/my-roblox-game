--!strict
--[[
	The cross-server crew queue's rule (chosen by `lune run servers`, which runs this same
	rule). Pure: given the parties waiting, in arrival order, which crews leave now.

	Each entry is a party (1-4 players who stay together) and the time it stops waiting for more:
	a crew-seeker waits the car countdown (Tuning.Cars.CountdownSeconds); a player happy alone waits a short
	window and then starts solo (the caller handles that). From the oldest entry, a crew fills greedily up to
	`max`; it leaves when full, or when it has 2+ players and its earliest deadline has passed.

	  form(entries, now, max)   a list of crews, each a list of entry indices (into `entries`)
]]

export type Entry = { size: number, deadline: number }

local Matchmaking = {}

function Matchmaking.form(entries: { Entry }, now: number, max: number): { { number } }
	local left: { number } = {}
	for i = 1, #entries do
		table.insert(left, i)
	end
	local crews: { { number } } = {}
	local i = 1
	while i <= #left do
		local used: { number } = {} -- positions in `left`
		local players = 0
		for j = i, #left do
			local e = entries[left[j]]
			if players + e.size <= max then
				players += e.size
				table.insert(used, j)
			end
			if players == max then
				break
			end
		end
		local due = math.huge
		for _, j in used do
			due = math.min(due, entries[left[j]].deadline)
		end
		if players == max or (players >= 2 and now >= due) then
			local crew: { number } = {}
			for k = #used, 1, -1 do
				table.insert(crew, 1, table.remove(left, used[k]) :: number)
			end
			table.insert(crews, crew)
		else
			i += 1
		end
	end
	return crews
end

return table.freeze(Matchmaking)
