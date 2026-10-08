--!strict
--[[
	What a paper ticket says, as data. Pure: UI/Ticket draws it, the junction ballot
	(UI/RouteVote) and later the station board feed it.

	  seal      danger tier -> the number in the wax seal and 1-3 chalk tally strokes
	  coal      a leg's coal cost -> lumps grouped in fives (capped) and the "x12" label
	  track     a distance -> how far along the inked line it runs, shortest to longest offered
	  view      a route option (any field may be missing) -> everything one ticket prints; a sealed
	            mystery (option.mystery) prints "????", no type, no seal: only its distance and coal
	  pile      the votes -> whose stamps sit on one ticket, oldest first, at most MaxStamps
	  dial      the vote timer -> the hand's sweep and, in the last ten seconds, the numeral
	  tieNote   the votes -> what Logic/Vote will do with a tie, said plainly (never invented)
]]

local Shared = script.Parent.Parent
local MysteryConfig = require(Shared.Config.Mystery)
local Stations = require(Shared.Config.Stations)
local Types = require(Shared.Types)
local Vote = require(script.Parent.Vote)

local TicketModel = {}

TicketModel.MaxStamps = 4
TicketModel.LumpGroup = 5
TicketModel.MaxLumps = 20 -- four groups; the label still carries the true cost
TicketModel.NumeralSeconds = 10
TicketModel.MaxTilt = 1.5 -- degrees either way
TicketModel.MinTrack = 0.35 -- the shortest line offered still draws this much track

export type Seal = { number: number, strokes: number }
export type Coal = { lumps: number, groups: { number }, more: boolean, label: string }

export type View = {
	serial: string,
	name: string,
	kind: string,
	description: string,
	hint: string,
	tier: number,
	terminus: boolean,
	seal: Seal?,
	distanceKm: number,
	coal: Coal?,
	after: number?,
	short: boolean,
	mystery: boolean,
}

local function trim(n: number): string
	if n % 1 == 0 then
		return tostring(n)
	end
	return string.format("%.1f", n)
end

-- "ToolChest" -> "TOOL CHEST"
function TicketModel.words(id: string): string
	return string.upper((string.gsub(id, "(%l)(%u)", "%1 %2")))
end

-- A stable number in [0, 1) from a string (FNV-1a).
function TicketModel.hash(text: string): number
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (h * 16777619) % 4294967296
	end
	return h / 4294967296
end

-- The ticket's slight lean, seeded by its route id so it never jitters between redraws.
function TicketModel.tilt(routeId: string): number
	return (TicketModel.hash(routeId) * 2 - 1) * TicketModel.MaxTilt
end

function TicketModel.seal(tier: number?, terminus: boolean?): Seal?
	if terminus or tier == nil then
		return nil
	end
	local n = math.max(math.floor(tier), 1)
	return { number = n, strokes = math.clamp(n, 1, 3) }
end

function TicketModel.coal(cost: number?): Coal?
	if cost == nil or cost < 0 then
		return nil
	end
	local lumps = math.ceil(cost - 1e-9)
	local drawn = math.min(lumps, TicketModel.MaxLumps)
	local groups: { number } = {}
	local left = drawn
	while left > 0 do
		local take = math.min(left, TicketModel.LumpGroup)
		table.insert(groups, take)
		left -= take
	end
	return { lumps = lumps, groups = groups, more = lumps > drawn, label = `x{trim(cost)}` }
end

-- How much of the inked line a leg of `km` fills, between the shortest and longest offered.
function TicketModel.track(km: number?, shortest: number?, longest: number?): number
	if km == nil or shortest == nil or longest == nil or longest - shortest < 1e-6 then
		return 1
	end
	local t = math.clamp((km - shortest) / (longest - shortest), 0, 1)
	return TicketModel.MinTrack + (1 - TicketModel.MinTrack) * t
end

-- Short of the station's own loot and hazard weights: the one that stands out, or a fallback.
function TicketModel.hint(arch: Stations.Archetype?): string
	if arch == nil then
		return ""
	end
	if arch.terminus then
		return "The last stop"
	end
	local lootBest, lootValue = "", 1
	for _, kind in { "coal", "parts", "relic", "tools" } do
		local value = (arch.loot :: any)[kind] or 0
		if value > lootValue then
			lootValue, lootBest = value, if kind == "relic" then "relics" else kind
		end
	end
	local hazardNames = { fog = "heavy fog", collapse = "unstable ground", hollows = "Hollows nearby" }
	local hazardBest, hazardValue = "", 1
	for _, kind in { "fog", "collapse", "hollows" } do
		local value = (arch.hazard :: any)[kind] or 0
		if value > hazardValue then
			hazardValue, hazardBest = value, hazardNames[kind]
		end
	end
	local loot = if lootBest ~= "" then `Lots of {lootBest}` else "Balanced haul"
	local hazard = if hazardBest ~= "" then hazardBest else "standard hazards"
	return `{loot}, {hazard}`
end

-- Everything one ticket prints. Any input may be nil (a half-replicated route, a removed
-- archetype); the ticket then prints what it has and leaves the rest blank.
function TicketModel.view(option: Types.RouteOption?, serial: number?, cost: number?, coalHeld: number?): View
	local mystery = option ~= nil and option.mystery == true
	local arch = if option and not mystery then Stations.List[option.archetype] else nil
	local terminus = arch ~= nil and arch.terminus == true
	local tier = if option and not mystery then option.tier else 0
	return {
		serial = string.format("No. %02d", serial or 0),
		name = if mystery then MysteryConfig.Name elseif arch then string.upper(arch.name) else "UNKNOWN LINE",
		kind = if mystery then "SEALED LINE" elseif option then TicketModel.words(option.archetype) else "",
		description = if mystery
			then "The clerk will not say. Destination unknown until the doors open."
			elseif arch then arch.hint
			elseif option then option.hint or ""
			else "",
		hint = if mystery then "No questions answered" else TicketModel.hint(arch),
		tier = tier,
		terminus = terminus,
		seal = if option and not mystery then TicketModel.seal(tier, terminus) else nil,
		distanceKm = if option then option.distanceKm else 0,
		coal = TicketModel.coal(cost),
		after = if cost ~= nil and coalHeld ~= nil
			then math.floor((coalHeld - cost) * 10 + 0.5) / 10
			else nil,
		short = cost ~= nil and coalHeld ~= nil and cost > coalHeld,
		mystery = mystery,
	}
end

-- The stamps on ticket `index`: every voter for it, sorted by user id with the local player
-- last (on top). Past MaxStamps the oldest others drop off; `extra` counts them.
function TicketModel.pile(
	votes: { [string]: number }?,
	index: number,
	localKey: string?
): ({ string }, number)
	local others: { string } = {}
	local mineHere = false
	local all: { [string]: number } = votes or {}
	for key, choice in all do
		if choice == index then
			if key == localKey then
				mineHere = true
			else
				table.insert(others, key)
			end
		end
	end
	table.sort(others, function(a, b)
		local na, nb = tonumber(a), tonumber(b)
		if na and nb and na ~= nb then
			return na < nb
		end
		return a < b
	end)
	local room = TicketModel.MaxStamps - (if mineHere then 1 else 0)
	local extra = math.max(#others - room, 0)
	local pile: { string } = {}
	for i = extra + 1, #others do
		table.insert(pile, others[i])
	end
	if mineHere then
		table.insert(pile, localKey :: string)
	end
	return pile, extra
end

-- The dial's sweep in [0, 1] from the vote's start to its end, and the whole seconds left
-- once inside the last NumeralSeconds (else nil).
function TicketModel.dial(now: number, startedAt: number?, endsAt: number?): (number, number?)
	if startedAt == nil or endsAt == nil or endsAt <= startedAt then
		return 0, nil
	end
	local sweep = math.clamp((now - startedAt) / (endsAt - startedAt), 0, 1)
	local left = math.max(endsAt - now, 0)
	local numeral = if left <= TicketModel.NumeralSeconds then math.ceil(left) else nil
	return sweep, numeral
end

-- What Logic/Vote.tally will do if the vote closed now, when that is not a plain majority.
function TicketModel.tieNote(votes: { [string]: number }?, options: { Types.RouteOption }): string?
	if #options < 2 then
		return nil
	end
	local counts = Vote.counts(votes or {}, #options)
	local best = 0
	for _, c in counts do
		best = math.max(best, c)
	end
	local tied: { number } = {}
	for i, c in counts do
		if c == best then
			table.insert(tied, i)
		end
	end
	if #tied < 2 then
		return nil
	end
	local shortest = math.huge
	for _, i in tied do
		shortest = math.min(shortest, options[i].distanceKm)
	end
	local level = 0
	for _, i in tied do
		if options[i].distanceKm == shortest then
			level += 1
		end
	end
	local lead = if best == 0 then "NO VOTES" else "A TIE"
	if level > 1 then
		return `{lead}: SHORTEST LINES LEVEL, THE DRIVER TOSSES A COIN`
	end
	return `{lead}: THE DRIVER TAKES THE SHORT LINE`
end

return table.freeze(TicketModel)
