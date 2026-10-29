--!strict
--[[
	The stop-five cash-out (launch hardening step 4). Pure: RunDirector opens and closes the offer,
	CrewService asks it before letting a player off.

	  offered(stopCount, departed)       true when the stop that just departed is Tuning.Run.CashOutStop
	                                     and the line runs on past it (a Short Line ends there anyway)
	  open(stop, userIds, endsAt)        the offer, made to each living crew member aboard as it departs
	  check(offer, userId, aboard, now)  nil when this player may cash out now, else why not
	  take(offer, userId)                records the choice

	Rules, the same every time:
	  - only those alive and aboard when the stop departs are offered; a joiner or a downed player is not
	  - the offer lasts the junction; no answer by then means ride on
	  - the choice is final: a second press changes nothing, and nobody cashes out after the window
	  - going down or leaving the game before choosing is the same as at any other stop
	  - cashing out pays what is earned (no Terminus line, no share of the haul) and puts the player
	    in the Depot Hall; another run in this server waits until this crew's run ends
	  - when the last living crew member cashes out the run ends with outcome CashedOut
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local Types = require(Shared.Types)

type Offer = Types.CashOutOffer

local CashOut = {}

function CashOut.offered(stopCount: number, departed: number): boolean
	local stop = Tuning.Run.CashOutStop
	return departed == stop and stopCount > stop
end

function CashOut.open(stop: number, userIds: { number }, endsAt: number): Offer
	local eligible: { [string]: boolean } = {}
	for _, id in userIds do
		eligible[tostring(id)] = true
	end
	return { stop = stop, endsAt = endsAt, eligible = eligible, taken = {} }
end

function CashOut.check(offer: Offer?, userId: number, aboard: boolean, now: number): string?
	if offer == nil or now > offer.endsAt then
		return "closed"
	end
	local key = tostring(userId)
	if not offer.eligible[key] then
		return "not_offered"
	end
	if offer.taken[key] then
		return "taken"
	end
	if not aboard then
		return "not_aboard"
	end
	return nil
end

function CashOut.take(offer: Offer, userId: number)
	offer.taken[tostring(userId)] = true
end

return table.freeze(CashOut)
