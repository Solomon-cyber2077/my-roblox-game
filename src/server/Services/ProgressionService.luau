--!strict
--[[
	End-of-run payouts, lifetime stats, Crew Rank and Line Mastery milestones.
	Charter (private server) rules: a solo run pays 60%, Brass from charter runs is
	capped per day, and the owner earns a Charter Stamp for each run with 3+ crew
	that clears 5+ stations.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Cosmetics = require(Shared.Config.Cosmetics)
local Progression = require(Shared.Config.Progression)
local Tuning = require(Shared.Config.Tuning)
local Catalog = require(Shared.Logic.Catalog)
local Economy = require(Shared.Logic.Economy)
local Milestones = require(Shared.Logic.Milestones)
local Rank = require(Shared.Logic.Rank)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)

local ProgressionService = {}

local function isCharter(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
end

function ProgressionService.Init() end

function ProgressionService.Start() end

function ProgressionService.PayRun(
	outcome: Types.Outcome,
	tallies: { [Player]: Types.CrewTally },
	stationsCleared: number
)
	local day = Catalog.dayNumber(os.time())
	local charter = isCharter()
	local crewCount = 0
	for _ in tallies do
		crewCount += 1
	end
	local e = Tuning.Economy

	for player, tally in tallies do
		local profile = DataService.GetProfile(player)
		if profile then
			local rankBefore = Rank.fromXp(profile.xp)
			local dailyBonus = profile.daily.lastBonusDay ~= day
			local payout = Economy.payout(tally, {
				outcome = outcome,
				dailyBonus = dailyBonus,
				soloCharter = charter and crewCount == 1,
			})
			local brass = payout.brass
			if charter then
				local used = if profile.daily.charterBrassDay == day then profile.daily.charterBrass else 0
				local capped = math.max(0, math.min(brass, e.CharterDailyBrassCap - used))
				if capped < brass then
					table.insert(payout.lines, { label = "Charter daily cap", amount = capped - brass })
				end
				brass = capped
			end

			local granted: { string } = {}
			DataService.Update(player, function(p)
				p.brass += brass
				p.xp += payout.xp
				if dailyBonus and payout.brass > 0 then
					p.daily.lastBonusDay = day
				end
				if charter then
					if p.daily.charterBrassDay ~= day then
						p.daily.charterBrassDay = day
						p.daily.charterBrass = 0
					end
					p.daily.charterBrass += brass
				end
				local s = p.stats
				s.runs = (s.runs or 0) + 1
				s.victories = (s.victories or 0)
					+ (if outcome == "Victory" and tally.reachedTerminus then 1 else 0)
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

			NetService.Fire("Fx", player, "RunSummary", {
				outcome = outcome,
				brass = brass,
				xp = payout.xp,
				lines = payout.lines,
				rankBefore = rankBefore,
				rankAfter = Rank.fromXp(profile.xp),
				milestones = granted,
				stations = stationsCleared,
				tally = tally,
				saved = DataService.IsOnline(player),
			})
		end
	end
end

return ProgressionService
