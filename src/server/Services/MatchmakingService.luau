--!strict
--[[
	The cross-server crew queue (protocol in Logic/CrewQueue, crew rule in Logic/Matchmaking; chosen in
	the server simulation, `lune run servers`). Every occupied boarding car in every public hall is a
	party in one queue, so a lone rider finds a crew in another hall and two part cars couple into one.

	  every QueueRefresh  this hall writes a ticket per occupied car (never over a claim the matcher made),
	                      drops the tickets of cars that emptied or left, and publishes `lobby.queue.waiting`
	  every MatchTick     one matcher pass if this hall holds the lease (CrewQueue.matchStep), reserving a
	                      server per crew (TeleportService:ReserveServerAsync)
	  every second        this hall reads its cars' matches and sends them (CarService.DepartMatched); the
	                      match record is left to expire, so a later pass can never match the car again

	Off in Studio (no teleports, and MemoryStore there is not the live one) and in reserved servers. When
	MemoryStore stops answering for HealthySeconds, Healthy() turns false and cars leave on their own
	countdown as before (CrewQueue.holdLocal).
]]

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local CrewQueue = require(Shared.Logic.CrewQueue)
local Safe = require(Shared.Util.Safe)

local StateService = require(script.Parent.StateService)
local Registry = require(script.Parent.Parent.Registry)

local MatchmakingService = {}

local C = Tuning.Cars
local ENABLED = C.CrossServer and not RunService:IsStudio() and game.PrivateServerId == ""

local healthyAt = -math.huge
local stores: CrewQueue.Stores? = nil
type Mine = { index: number, generation: number }
local mine: { [string]: Mine } = {} -- this hall's live tickets
local leaving: { [string]: boolean } = {} -- tickets to drop (retried until the store takes it)

local function unix(): number
	return DateTime.now().UnixTimestampMillis / 1000
end

local function good()
	healthyAt = os.clock()
end

local function wrap(name: string): CrewQueue.Store
	local map = MemoryStoreService:GetSortedMap(name)
	return {
		get = function(key: string): any
			local value = map:GetAsync(key)
			good()
			return value
		end,
		set = function(key: string, value: any, ttl: number, sortKey: number?)
			map:SetAsync(key, value, ttl, sortKey)
			good()
		end,
		update = function(key: string, transform: (any) -> any, ttl: number): any
			local result = map:UpdateAsync(key, function(old: any, sortKey: any)
				local new = transform(old)
				if new == nil then
					return nil
				end
				-- keep the ticket's place in the queue (its `since`)
				return new, sortKey or (if type(new) == "table" then new.since else nil)
			end, ttl)
			good()
			return result
		end,
		remove = function(key: string)
			map:RemoveAsync(key)
			good()
		end,
		range = function(count: number): { { key: string, value: any } }
			local items = map:GetRangeAsync(Enum.SortDirection.Ascending, count)
			good()
			local rows = {}
			for _, item in items do
				table.insert(rows, { key = item.key, value = item.value })
			end
			return rows
		end,
	}
end

function MatchmakingService.Healthy(): boolean
	return ENABLED and os.clock() - healthyAt < C.HealthySeconds
end

local function refresh(s: CrewQueue.Stores)
	local live: { [string]: boolean } = {}
	for _, car in Registry.CarService.Queueing() do
		local key = CrewQueue.ticket(game.JobId, car.index, car.generation)
		live[key] = true
		local entry = CrewQueue.entry(car.members, car.since, car.deadline)
		local ok = pcall(s.queue.update, key, function(old: any): any
			if type(old) == "table" and old.matched ~= nil then
				return nil -- a crew is forming with this car: leave the claim alone
			end
			return entry
		end, C.QueueTtl)
		if ok then
			mine[key] = { index = car.index, generation = car.generation }
		end
	end
	for key in mine do
		if not live[key] then
			mine[key] = nil
			leaving[key] = true
		end
	end
	for key in leaving do
		if pcall(s.queue.remove, key) then
			leaving[key] = nil
		end
	end
	local ok, rows = pcall(s.queue.range, C.QueueRead)
	if ok then
		local waiting = 0
		for _, row in rows do
			if type(row.value) == "table" and type(row.value.members) == "table" then
				waiting += #row.value.members
			end
		end
		StateService.Set({ "lobby", "queue" }, { waiting = waiting })
	end
end

local function reserve(): string?
	local ok, code = pcall(function()
		return TeleportService:ReserveServerAsync(game.PlaceId)
	end)
	return if ok and type(code) == "string" then code else nil
end

local function collect(s: CrewQueue.Stores)
	for key, car in mine do
		local ok, match = pcall(s.matches.get, key)
		if ok and type(match) == "table" and type(match.code) == "string" and type(match.crew) == "table" then
			mine[key] = nil
			leaving[key] = true
			Registry.CarService.DepartMatched(car.index, car.generation, match)
		end
	end
end

function MatchmakingService.Init()
	if ENABLED then
		stores = {
			queue = wrap("LTO_CrewQueue_v1"),
			matches = wrap("LTO_CrewMatches_v1"),
			lock = wrap("LTO_CrewLock_v1"),
		}
	end
end

function MatchmakingService.Start()
	local s = stores
	if s == nil then
		return
	end
	task.spawn(function()
		while true do
			Safe.call("Matchmaking.refresh", refresh, s)
			task.wait(C.QueueRefresh)
		end
	end)
	task.spawn(function()
		while true do
			Safe.call("Matchmaking.match", function()
				CrewQueue.matchStep(s, game.JobId, unix(), reserve, function()
					return HttpService:GenerateGUID(false)
				end)
			end)
			task.wait(C.MatchTick)
		end
	end)
	task.spawn(function()
		while true do
			Safe.call("Matchmaking.collect", collect, s)
			task.wait(1)
		end
	end)
end

return MatchmakingService
