--!strict
--[[
	End-of-run payouts, lifetime stats, Crew Rank and Line Mastery milestones.
	Each stop's Brass and XP are banked as it departs (BankStop, Logic/StopBank); RunEnd pays the rest:
	the Terminus line, the tier bonus and the first run of the day, to whoever is still in the run.
	Charter (private server) rules: a solo run pays 60%, Brass from charter runs is
	capped per day, and the owner earns a Charter Stamp for each run with 3+ crew
	that clears 5+ stations. A victory at run tier N unlocks tier N + 1 (Logic/RunTier).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Progression = require(Shared.Config.Progression)
local Tuning = require(Shared.Config.Tuning)
local Catalog = require(Shared.Logic.Catalog)
local Economy = require(Shared.Logic.Economy)
local Milestones = require(Shared.Logic.Milestones)
local Rank = require(Shared.Logic.Rank)
local RunTier = require(Shared.Logic.RunTier)
local StopBank = require(Shared.Logic.StopBank)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)

local ProgressionService = {}

-- this run's banked stop rewards per player; a player who leaves and comes back starts a new bank
local banks: { [Player]: StopBank.Bank } = {}

local function isCharter(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

local function crewCountOf(tallies: { [Player]: Types.CrewTally }): number
	local count = 0
	for _ in tallies do
		count += 1
	end
	return count
end

-- Brass after the charter's daily cap, and the profile edit that spends the cap.
local function charterCapped(profile: Types.Profile, brass: number, day: number): number
	local used = if profile.daily.charterBrassDay == day then profile.daily.charterBrass else 0
	return math.max(0, math.min(brass, Tuning.Economy.CharterDailyBrassCap - used))
end

local function spendCharter(p: Types.Profile, brass: number, day: number)
	if p.daily.charterBrassDay ~= day then
		p.daily.charterBrassDay = day
		p.daily.charterBrass = 0
	end
	p.daily.charterBrass += brass
end

function ProgressionService.Init() end

function ProgressionService.Start()
	Players.PlayerRemoving:Connect(function(player)
		banks[player] = nil
	end)
end

-- A stop has departed: bank what each crew member has earned so far, once per run and stop.
function ProgressionService.BankStop(runId: string, stop: number, tallies: { [Player]: Types.CrewTally })
	local day = Catalog.dayNumber(os.time())
	local charter = isCharter()
	local solo = charter and crewCountOf(tallies) == 1
	for player, tally in tallies do
		local profile = DataService.GetProfile(player)
		if profile == nil then
			continue
		end
		local bank = banks[player]
		if bank == nil or bank.run ~= runId then
			bank = StopBank.new(runId, profile.xp)
			banks[player] = bank
		end
		local brass, xp = StopBank.grant(bank, stop, tally, solo)
		if charter then
			local capped = charterCapped(profile, brass, day)
			bank.brass -= brass - capped
			brass = capped
		end
		if brass <= 0 and xp <= 0 then
			continue
		end
		DataService.Update(player, function(p)
			p.brass += brass
			p.xp += xp
			if charter then
				spendCharter(p, brass, day)
			end
		end)
		Registry.TelemetryService.Brass(player, "Source", brass, profile.brass, "stop_payout")
		if brass > 0 then
			NetService.Fire("Notify", player, "Banked", `Banked {brass} Brass from this stop.`)
		end
	end
end

-- One crew member's end of a run, as PayRun or CashOut settles it.
type Settlement = {
	outcome: Types.Outcome,
	haul: Types.HaulReceipt,
	stationsCleared: number,
	tier: number,
	route: string?,
	runId: string?,
	crewCount: number,
	day: number,
	charter: boolean,
}

-- Pays one crew member their run: what the stops have not banked yet, the Terminus line on a victory,
-- the tier and first-run-of-the-day bonuses; then stats and milestones.
local function settle(player: Player, tally: Types.CrewTally, run: Settlement)
	local outcome, haul, tier, route, day, charter =
		run.outcome, run.haul, run.tier, run.route, run.day, run.charter
	local stationsCleared, runId, crewCount = run.stationsCleared, run.runId, run.crewCount
	local e = Tuning.Economy
	do
		local profile = DataService.GetProfile(player)
		if profile then
			local held = banks[player]
			local bank: StopBank.Bank? = if held and held.run == runId then held else nil
			banks[player] = nil
			local rankBefore = Rank.fromXp(if bank then bank.startXp else profile.xp)
			local tierBefore = profile.unlockedTier
			local dailyBonus = profile.daily.lastBonusDay ~= day -- the first run of each UTC day
			local options: Economy.Options = {
				outcome = run.outcome,
				dailyBonus = dailyBonus,
				soloCharter = charter and crewCount == 1,
				tier = tier,
			}
			local payout = Economy.payout(tally, options)
			payout.xp += haul.xp
			-- what the stops already banked is not paid twice
			local brass, xp = StopBank.remainder(bank, payout.brass, payout.xp)
			if charter then
				local capped = charterCapped(profile, brass, day)
				if capped < brass then
					table.insert(payout.lines, { label = "Charter daily cap", amount = capped - brass })
				end
				brass = capped
			end
			local banked = if bank then bank.brass else 0

			local granted: { string } = {}
			local milestoneBrass = 0
			DataService.Update(player, function(p)
				p.brass += brass
				p.xp += xp
				p.unlockedTier = RunTier.afterRun(p.unlockedTier, tier, outcome == "Victory")
				if dailyBonus and payout.brass > 0 then
					p.daily.lastBonusDay = day
				end
				if charter then
					spendCharter(p, brass, day)
				end
				local s = p.stats
				-- Persistent keepsake and unlock-track placeholders; these are not currencies.
				if outcome == "Victory" then
					s.payrollTickets = (s.payrollTickets or 0) + #haul.trophies
					s.recoveredValuables = (s.recoveredValuables or 0) + #haul.valuables
					s.payrollOutfitProgress = (s.payrollOutfitProgress or 0) + #haul.valuables
					s.payrollCrewPassProgress = (s.payrollCrewPassProgress or 0) + #haul.trophies
				end
				s.runs = (s.runs or 0) + 1
				local arrived = outcome == "Victory" and tally.reachedTerminus
				s.victories = (s.victories or 0) + (if arrived then 1 else 0)
				-- a Short Line victory counts above; this one is the Long Line's alone
				s.longVictories = (s.longVictories or 0) + (if arrived and route ~= "Short" then 1 else 0)
				s.stationsDeparted = (s.stationsDeparted or 0) + tally.stationsDeparted
				s.bestStation = math.max(s.bestStation or 0, tally.stationsDeparted)
				s.coalDelivered = (s.coalDelivered or 0) + tally.coalDelivered
				s.partsDelivered = (s.partsDelivered or 0) + tally.partsDelivered
				s.relicsBanked = (s.relicsBanked or 0) + tally.relicsBanked
				s.rescues = (s.rescues or 0) + tally.rescues
				s.clutchBoards = (s.clutchBoards or 0) + tally.clutchBoards
				if
					charter
					and player.UserId == game.PrivateServerOwnerId
					and crewCount >= e.CharterStampMinCrew
					and stationsCleared >= e.CharterStampMinStations
				then
					s.charterStamps = (s.charterStamps or 0) + 1
				end

				for _, id in Milestones.newlyCompleted(s, Rank.fromXp(p.xp), p.milestones) do
					local milestone = Progression.ById[id]
					p.milestones[id] = true
					if milestone.reward.brass then
						p.brass += milestone.reward.brass
						milestoneBrass += milestone.reward.brass
					end
					if milestone.reward.cosmetic then
						p.owned[milestone.reward.cosmetic] = true
					end
					table.insert(granted, milestone.name)
				end
				for _, def in Cosmetics.List do
					if def.charterStamps and (s.charterStamps or 0) >= def.charterStamps then
						p.owned[def.id] = true
					end
				end
			end)

			Registry.TelemetryService.Brass(
				player,
				"Source",
				brass,
				profile.brass - milestoneBrass,
				"run_payout"
			)
			Registry.TelemetryService.Brass(player, "Source", milestoneBrass, profile.brass, "milestone")
			NetService.Fire("Fx", player, "RunSummary", {
				outcome = outcome,
				haul = haul,
				brass = banked + brass, -- the run's whole take, stops included
				xp = payout.xp,
				lines = payout.lines,
				rankBefore = rankBefore,
				rankAfter = Rank.fromXp(profile.xp),
				milestones = granted,
				stations = stationsCleared,
				tier = tier,
				unlockedTier = if profile.unlockedTier > tierBefore then profile.unlockedTier else nil,
				tally = tally,
				saved = DataService.IsOnline(player),
			})
		end
	end
end

function ProgressionService.PayRun(
	outcome: Types.Outcome,
	tallies: { [Player]: Types.CrewTally },
	stationsCleared: number,
	tier: number,
	route: string?,
	runId: string?
)
	local run: Settlement = {
		outcome = outcome,
		haul = Registry.HaulService.Settle(outcome == "Victory"),
		stationsCleared = stationsCleared,
		tier = tier,
		route = route,
		runId = runId,
		crewCount = crewCountOf(tallies),
		day = Catalog.dayNumber(os.time()),
		charter = isCharter(),
	}
	for player, tally in tallies do
		settle(player, tally, run)
	end
end

-- The stop-five cash-out (Logic/CashOut): this player's run ends here, paid as earned. No Terminus
-- line and no share of the haul: those settle at the run's end, for whoever is still aboard.
function ProgressionService.CashOut(
	player: Player,
	tally: Types.CrewTally,
	crewCount: number,
	stationsCleared: number,
	tier: number,
	route: string?,
	runId: string?
)
	settle(player, tally, {
		outcome = "CashedOut",
		haul = { valuables = {}, trophies = {}, xp = 0 },
		stationsCleared = stationsCleared,
		tier = tier,
		route = route,
		runId = runId,
		crewCount = crewCount,
		day = Catalog.dayNumber(os.time()),
		charter = isCharter(),
	})
end

return ProgressionService
