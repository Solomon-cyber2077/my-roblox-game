--!strict
--[[
	Stop rewards, banked once (launch hardening step 2). A crew member's Brass and XP are paid as each
	stop departs, so leaving or dropping mid-run keeps what was already earned.

	  earned(tally)                      the base Brass so far: Economy.payout with no Terminus line,
	                                     tier bonus, charter rate or daily bonus
	  grant(bank, stop, tally, solo)     what stop `stop` adds to the bank; 0, 0 if it was banked already
	  remainder(bank, brass, xp)         what RunEnd still owes once its full payout is known

	Grants are cumulative: each one tops the bank up to the run's earnings so far, so the coal and parts
	remainders (per 10, per 5) are never lost between stops and the total never goes past the run's
	payout. The Terminus line, the tier bonus and the first-run-of-the-day bonus are left for RunEnd:
	only a crew member who sees the run out gets them.
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local Economy = require(script.Parent.Economy)
local Types = require(Shared.Types)

export type Bank = {
	run: string,
	stops: { [number]: true },
	brass: number, -- Brass banked this run
	xp: number, -- XP banked this run
	startXp: number, -- the profile's XP before the first grant (the run card's rank before)
}

local StopBank = {}

function StopBank.new(run: string, startXp: number): Bank
	return { run = run, stops = {}, brass = 0, xp = 0, startXp = startXp }
end

function StopBank.earned(tally: Types.CrewTally): number
	return Economy.payout(tally, { outcome = nil, dailyBonus = false, soloCharter = false }).brass
end

function StopBank.grant(
	bank: Bank,
	stop: number,
	tally: Types.CrewTally,
	soloCharter: boolean
): (number, number)
	if bank.stops[stop] then
		return 0, 0
	end
	bank.stops[stop] = true
	local earned = StopBank.earned(tally)
	local target = if soloCharter then math.floor(earned * Tuning.Economy.CharterSoloMultiplier) else earned
	local brass = math.max(0, target - bank.brass)
	local xp = math.max(0, earned - bank.xp)
	bank.brass += brass
	bank.xp += xp
	return brass, xp
end

function StopBank.remainder(bank: Bank?, brass: number, xp: number): (number, number)
	if bank == nil then
		return brass, xp
	end
	return math.max(0, brass - bank.brass), math.max(0, xp - bank.xp)
end

return StopBank
