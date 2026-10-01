--!strict
--[[
	Client mirror of the server's replicated state (see StateService).

	Observe(scope, path, fn) calls fn with the value at `path` now and every time
	a patch touches that path, anything under it, or anything above it. Patches
	carry sequence numbers per scope; a gap asks the server for a fresh snapshot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Net = require(script.Parent.Parent.Net)

type Scope = "public" | "private"
type Path = { string }
type Observer = { scope: Scope, path: Path, fn: (any) -> () }

local StateController = {
	Ready = Signal.new() :: Signal.Signal<>,
}

local trees: { [string]: { [string]: any } } = { public = {}, private = {} }
local seqs: { [string]: number } = { public = 0, private = 0 }
local observers: { Observer } = {}
local isReady = false
local resyncRequested = false

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

local function write(root: { [string]: any }, path: Path, value: any)
	local node = root
	for i = 1, #path - 1 do
		local key = path[i]
		if type(node[key]) ~= "table" then
			node[key] = {}
		end
		node = node[key]
	end
	node[path[#path]] = value
end

local function related(a: Path, b: Path): boolean
	for i = 1, math.min(#a, #b) do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function fire(observer: Observer)
	local ok, err = (pcall :: any)(observer.fn, read(trees[observer.scope], observer.path))
	if not ok then
		warn(`[StateController] observer for {table.concat(observer.path, ".")} failed: {err}`)
	end
end

local function notifyAll()
	for _, observer in table.clone(observers) do
		fire(observer)
	end
end

function StateController.Init()
	Net.On("Snapshot", function(publicTree, publicSeq, privateTree, privateSeq)
		trees.public = publicTree or {}
		trees.private = privateTree or {}
		seqs.public = publicSeq or 0
		seqs.private = privateSeq or 0
		resyncRequested = false
		local first = not isReady
		isReady = true
		notifyAll()
		if first then
			StateController.Ready:Fire()
		end
	end)

	Net.On("Patch", function(scope: Scope, seq: number, changes: { { p: Path, v: any } })
		if not isReady then
			return
		end
		if seq ~= seqs[scope] + 1 then
			if not resyncRequested then
				resyncRequested = true
				Net.Fire("ClientReady")
			end
			return
		end
		seqs[scope] = seq
		local touched: { [Observer]: boolean } = {}
		for _, change in changes do
			write(trees[scope], change.p, change.v)
			for _, observer in observers do
				if observer.scope == scope and related(observer.path, change.p) then
					touched[observer] = true
				end
			end
		end
		for observer in touched do
			fire(observer)
		end
	end)
end

function StateController.Start()
	Net.Fire("ClientReady")
end

function StateController.IsReady(): boolean
	return isReady
end

function StateController.Get(path: Path): any
	return read(trees.public, path)
end

function StateController.GetPrivate(path: Path): any
	return read(trees.private, path)
end

-- Subscribes to a path. Returns a function that unsubscribes.
function StateController.Observe(scope: Scope, path: Path, fn: (any) -> ()): () -> ()
	local observer: Observer = { scope = scope, path = path, fn = fn }
	table.insert(observers, observer)
	if isReady then
		fire(observer)
	end
	return function()
		local index = table.find(observers, observer)
		if index then
			table.remove(observers, index)
		end
	end
end

return StateController
