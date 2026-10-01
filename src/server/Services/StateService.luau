--!strict
--[[
	The single authoritative copy of replicated game state.

	Public tree:  run, train, crew, lobby, stats  (sent to everyone)
	Private tree: inventory, profile              (sent only to its owner)

	Services write with Set/Update; nothing else mutates these tables. Writes
	are recorded as (path, value) changes and flushed once per Heartbeat, so a
	burst of writes in one frame costs one message per audience. Each stream
	carries its own sequence number; a client that sees a gap asks for a
	snapshot through ClientReady.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NetService = require(script.Parent.NetService)

type Path = { string }
type Change = { p: Path, v: any }

local StateService = {}

local publicTree: { [string]: any } = {}
local privateTrees: { [Player]: { [string]: any } } = {}
local publicQueue: { Change } = {}
local privateQueues: { [Player]: { Change } } = {}
local publicSeq = 0
local privateSeq: { [Player]: number } = {}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function walk(root: { [string]: any }, path: Path, create: boolean): ({ [string]: any }?, string)
	local node = root
	for i = 1, #path - 1 do
		local key = path[i]
		local nextNode = node[key]
		if type(nextNode) ~= "table" then
			if not create then
				return nil, path[#path]
			end
			nextNode = {}
			node[key] = nextNode
		end
		node = nextNode
	end
	return node, path[#path]
end

local function read(root: { [string]: any }, path: Path): any
	local node: any = root
	for _, key in path do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

local function record(queue: { Change }, path: Path, value: any)
	-- Drop queued writes this one overrides (same path or a path underneath it).
	for i = #queue, 1, -1 do
		local existing = queue[i].p
		if #existing >= #path then
			local covered = true
			for j = 1, #path do
				if existing[j] ~= path[j] then
					covered = false
					break
				end
			end
			if covered then
				table.remove(queue, i)
			end
		end
	end
	table.insert(queue, { p = table.clone(path), v = deepCopy(value) })
end

-- Public tree ---------------------------------------------------------------------

function StateService.Get(path: Path): any
	return deepCopy(read(publicTree, path))
end

function StateService.Set(path: Path, value: any)
	local parent, key = walk(publicTree, path, true)
	assert(parent, "invalid path")
	parent[key] = deepCopy(value)
	record(publicQueue, path, value)
end

function StateService.Update(path: Path, mutator: (any) -> any)
	StateService.Set(path, mutator(StateService.Get(path)))
end

-- Private tree --------------------------------------------------------------------

function StateService.GetPrivate(player: Player, path: Path): any
	local tree = privateTrees[player]
	return if tree then deepCopy(read(tree, path)) else nil
end

function StateService.SetPrivate(player: Player, path: Path, value: any)
	local tree = privateTrees[player]
	if tree == nil then
		tree = {}
		privateTrees[player] = tree
		privateQueues[player] = {}
		privateSeq[player] = 0
	end
	local parent, key = walk(tree, path, true)
	assert(parent, "invalid path")
	parent[key] = deepCopy(value)
	record(privateQueues[player], path, value)
end

-- Replication ---------------------------------------------------------------------

local function flush()
	if #publicQueue > 0 then
		publicSeq += 1
		NetService.FireAll("Patch", "public", publicSeq, publicQueue)
		publicQueue = {}
	end
	for player, queue in privateQueues do
		if #queue > 0 then
			privateSeq[player] += 1
			NetService.Fire("Patch", player, "private", privateSeq[player], queue)
			privateQueues[player] = {}
		end
	end
end

function StateService.SendSnapshot(player: Player)
	-- Flush first so the snapshot and the patch stream agree on sequence numbers.
	flush()
	NetService.Fire(
		"Snapshot",
		player,
		publicTree,
		publicSeq,
		privateTrees[player] or {},
		privateSeq[player] or 0
	)
end

function StateService.Init() end

function StateService.Start()
	NetService.Handle("ClientReady", function(player)
		StateService.SendSnapshot(player)
	end)
	RunService.Heartbeat:Connect(flush)
	Players.PlayerRemoving:Connect(function(player)
		privateTrees[player] = nil
		privateQueues[player] = nil
		privateSeq[player] = nil
	end)
end

return StateService
