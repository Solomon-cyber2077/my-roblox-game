--!strict
--[[
	Builds every RemoteEvent declared in Shared.Net.Remotes and enforces the
	contract on the way in: argument kinds, a per-player token bucket, and an
	optional gate supplied by the handling service. Rejected requests are
	dropped silently and counted, so a client gets nothing to probe with.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

type Handler = (player: Player, ...any) -> ()
type Gate = (player: Player) -> boolean

local NetService = {}

local events: { [string]: RemoteEvent } = {}
local buckets: { [Player]: { [string]: { tokens: number, stamp: number } } } = {}
local rejected: { [string]: number } = {}

local function take(player: Player, name: string): boolean
	local def = Remotes.List[name]
	local perPlayer = buckets[player]
	if perPlayer == nil then
		perPlayer = {}
		buckets[player] = perPlayer
	end
	local now = os.clock()
	local bucket = perPlayer[name]
	if bucket == nil then
		bucket = { tokens = def.burst, stamp = now }
		perPlayer[name] = bucket
	end
	bucket.tokens = math.min(def.burst, bucket.tokens + (now - bucket.stamp) * def.rate)
	bucket.stamp = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

local function reject(name: string, why: string)
	local key = `{name}:{why}`
	rejected[key] = (rejected[key] or 0) + 1
end

function NetService.Init()
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName
	for name in Remotes.List do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		events[name] = event
	end
	folder.Parent = ReplicatedStorage
end

function NetService.Start()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

-- Registers the single handler for a client-to-server remote.
function NetService.Handle(name: string, handler: Handler, gate: Gate?)
	local def = Remotes.List[name]
	assert(def and def.direction == "ToServer", `{name} is not a client-to-server remote`)
	events[name].OnServerEvent:Connect(function(player, ...)
		if not take(player, name) then
			reject(name, "rate")
			return
		end
		if not Remotes.validate(def, ...) then
			reject(name, "args")
			return
		end
		if gate and not gate(player) then
			reject(name, "gate")
			return
		end
		handler(player, ...)
	end)
end

function NetService.Fire(name: string, player: Player, ...: any)
	events[name]:FireClient(player, ...)
end

function NetService.FireAll(name: string, ...: any)
	events[name]:FireAllClients(...)
end

function NetService.FireList(name: string, players: { Player }, ...: any)
	for _, player in players do
		events[name]:FireClient(player, ...)
	end
end

function NetService.RejectionCounts(): { [string]: number }
	return table.clone(rejected)
end

return NetService
