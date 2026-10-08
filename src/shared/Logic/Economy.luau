--!strict
--[[
	End-of-run payout. Brass is the only soft currency and it only buys cosmetics.

	Brass = 6 per station departed alive
	      + 2 per 10 coal and 2 per 5 parts delivered by this player
	      + relic Brass banked by this player
	      + 10 per flare rescue
	      + 80 for being aboard at the Terminus (40 if the crew won without you)
	XP    = that Brass + 25 for finishing the run
	A run at tier t > 1 adds BrassBonusPerTier per tier (Config/Difficulty.RunTier).
	The first run of each UTC day doubles the Brass (bonus capped at 400).
	A private-server run with one player pays 60%.
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local RunTier = require(script.Parent.RunTier)
local Types = require(Shared.Types)

export type Line = { label: string, amount: number }
export type Payout = { brass: number, xp: number, lines: { Line } }
export type Options = {
	outcome: Types.Outcome?,
	dailyBonus: boolean,
	soloCharter: boolean,
	tier: number?,
}

local Economy = {}

function Economy.payout(tally: Types.CrewTally, options: Options): Payout
	local e = Tuning.Economy
	local lines: { Line } = {}
	local function add(label: string, amount: number)
		if amount > 0 then
			table.insert(lines, { label = label, amount = amount })
		end
	end

	add("Stations departed", tally.stationsDeparted * e.BrassPerStation)
	add("Coal delivered", (tally.coalDelivered // 10) * e.BrassPerTenCoal)
	add("Parts delivered", (tally.partsDelivered // 5) * e.BrassPerFiveParts)
	add("Relics banked", tally.relicBrass)
	add("Rescues", tally.rescues * e.BrassPerRescue)
	if options.outcome == "Victory" then
		add("Reached the Terminus", if tally.reachedTerminus then e.BrassVictoryAlive else e.BrassVictoryCrew)
	end

	local base = 0
	for _, line in lines do
		base += line.amount
	end

	local brass = base
	local tier = RunTier.clamp(options.tier)
	if tier > 1 and brass > 0 then
		local boosted = math.floor(brass * RunTier.brassMultiplier(tier))
		add(`Tier {tier} bonus`, boosted - brass)
		brass = boosted
	end
	if options.soloCharter then
		local reduced = math.floor(brass * e.CharterSoloMultiplier)
		add("Solo charter run", reduced - brass)
		brass = reduced
	end
	if options.dailyBonus and brass > 0 then
		local bonus = math.min(brass * (e.DailyFirstRunMultiplier - 1), e.DailyBonusCap)
		table.insert(lines, { label = "First run of the day", amount = bonus })
		brass += bonus
	end

	return { brass = brass, xp = base + e.XpPerRun, lines = lines }
end

function Economy.emptyTally(): Types.CrewTally
	return {
		stationsDeparted = 0,
		coalDelivered = 0,
		partsDelivered = 0,
		relicBrass = 0,
		relicsBanked = 0,
		rescues = 0,
		clutchBoards = 0,
		closeCalls = 0,
		reachedTerminus = false,
	}
end

return table.freeze(Economy)
