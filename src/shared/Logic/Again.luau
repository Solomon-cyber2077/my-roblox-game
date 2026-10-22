--!strict
--[[
	AGAIN and DEPOT on the run card (docs/FINAL-DESIGN.md Prompt 5). Pure: LobbyService keeps one
	card per ended run and asks this module.

	  eligible   the present participants of the ended run, alive or eliminated
	  press      AGAIN during RunEnd is queued and applied on Enter.Lobby after ResetReady; in the
	             Lobby it applies at once. DEPOT clears that player's queue and ready and drops
	             them from the wait (they stay unready in the hall)
	  hold       while an AGAIN group is waiting, the hall does not count down: it goes once every
	             present eligible member who has not chosen DEPOT is ready, or once FallbackSeconds
	             have passed since the first applied press with at least one of them ready
]]

local Again = {}

Again.FallbackSeconds = 20 -- FIXED

export type Card = {
	eligible: { [number]: boolean }, -- userIds
	queued: { [number]: boolean }, -- AGAIN pressed during RunEnd, not yet applied
	declined: { [number]: boolean }, -- DEPOT
	pressed: { [number]: boolean }, -- every accepted AGAIN (telemetry once per player per card)
	firstAppliedAt: number?, -- the first AGAIN applied in the Lobby
	closed: boolean,
}

function Again.card(eligible: { number }): Card
	local set: { [number]: boolean } = {}
	for _, id in eligible do
		set[id] = true
	end
	return { eligible = set, queued = {}, declined = {}, pressed = {}, firstAppliedAt = nil, closed = false }
end

--[[
	An AGAIN press from `id`. `inLobby` is true once the hall is open again (apply now), false during
	RunEnd (queue). Returns whether it was accepted, and whether it should set ready now.
]]
function Again.press(card: Card, id: number, inLobby: boolean, now: number): (boolean, boolean)
	if card.closed or not card.eligible[id] then
		return false, false
	end
	card.declined[id] = nil
	local first = not card.pressed[id]
	card.pressed[id] = true
	if inLobby then
		if card.firstAppliedAt == nil then
			card.firstAppliedAt = now
		end
		return first, true
	end
	card.queued[id] = true
	return first, false
end

-- DEPOT from `id`: no queue, no ready, out of the wait.
function Again.depot(card: Card, id: number)
	card.queued[id] = nil
	card.declined[id] = true
end

-- Enter.Lobby, after ResetReady: the queued presses become ready now. Returns their ids.
function Again.apply(card: Card, now: number): { number }
	local ids: { number } = {}
	for id in card.queued do
		table.insert(ids, id)
	end
	table.clear(card.queued)
	table.sort(ids)
	if #ids > 0 and card.firstAppliedAt == nil then
		card.firstAppliedAt = now
	end
	return ids
end

-- The members the wait is for: present, eligible, not DEPOT.
local function waitingFor(card: Card, present: { [number]: boolean }): { number }
	local out: { number } = {}
	for id in card.eligible do
		if present[id] and not card.declined[id] then
			table.insert(out, id)
		end
	end
	return out
end

--[[
	Whether the hall must hold its countdown. `present`: userIds still in the server; `ready`: userIds
	ready now.
]]
function Again.hold(
	card: Card?,
	present: { [number]: boolean },
	ready: { [number]: boolean },
	now: number
): boolean
	if card == nil or card.closed or card.firstAppliedAt == nil then
		return false
	end
	local members = waitingFor(card, present)
	local readyCount, allReady = 0, true
	for _, id in members do
		if ready[id] then
			readyCount += 1
		else
			allReady = false
		end
	end
	if readyCount == 0 then
		return false -- nobody of this group is waiting to go: the hall works as usual
	end
	if allReady then
		return false
	end
	return now - card.firstAppliedAt < Again.FallbackSeconds
end

-- How many of the group are ready, and how many it waits for (the card's count).
function Again.count(
	card: Card,
	present: { [number]: boolean },
	ready: { [number]: boolean }
): (number, number)
	local members = waitingFor(card, present)
	local readyCount = 0
	for _, id in members do
		if ready[id] or card.queued[id] then
			readyCount += 1
		end
	end
	return readyCount, #members
end

return table.freeze(Again)
