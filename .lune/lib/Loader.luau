--[[
	Loads game modules outside Roblox. Builds a proxy tree that mirrors the Rojo
	mapping so `require(script.Parent.X)` works under Lune, and reads all sources
	up front because Lune's filesystem calls cannot run inside metamethods.

	The unit tests load only the pure shared layer. The audit also loads client
	and server builders; it puts Lune's Roblox datatypes and a small `game` shim
	into `env`, which every module loaded afterwards sees as globals.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local ROOTS: { [string]: string } = {
	Shared = "src/shared",
	Client = "src/client",
	Server = "src/server",
}

-- Extra globals for every module loaded from now on (empty for the pure unit tests).
local GLOBAL_ENV: { [string]: any } = {}

-- Module proxy tree --------------------------------------------------------------

--[[
	Lune's filesystem calls yield, and metamethods cannot yield, so the whole
	source tree is indexed and read up front. Lookups below are in-memory only.
]]
local isFile: { [string]: boolean } = {}
local isDir: { [string]: boolean } = {}
local sources: { [string]: string } = {}
local dirEntries: { [string]: { string } } = {}

local function indexTree(path: string)
	isDir[path] = true
	local entries = fs.readDir(path)
	table.sort(entries)
	dirEntries[path] = entries
	for _, entry in entries do
		local full = path .. "/" .. entry
		if fs.isDir(full) then
			indexTree(full)
		elseif string.match(entry, "%.luau$") then
			isFile[full] = true
			sources[full] = fs.readFile(full)
		end
	end
end

for _, path in ROOTS do
	indexTree(path)
end

local nodeCache: { [string]: any } = {}
local moduleCache: { [string]: any } = {}
local makeNode: (path: string, name: string, parent: any) -> any

local function moduleFile(path: string): string?
	if isFile[path .. ".luau"] then
		return path .. ".luau"
	elseif isDir[path] and isFile[path .. "/init.luau"] then
		return path .. "/init.luau"
	end
	return nil
end

local function childNode(node: any, name: string): any?
	local base = rawget(node, "__path") :: string
	local childPath = base .. "/" .. name
	if isFile[childPath .. ".luau"] or isDir[childPath] then
		return makeNode(childPath, name, node)
	end
	return nil
end

local NodeMeta = {}
NodeMeta.__index = function(node, key)
	if key == "Name" then
		return rawget(node, "__name")
	elseif key == "Parent" then
		return rawget(node, "__parent")
	elseif key == "FindFirstChild" or key == "WaitForChild" then
		return function(self, name)
			return childNode(self, name)
		end
	elseif key == "GetChildren" then
		return function(self)
			local out = {}
			local base = rawget(self, "__path")
			for _, entry in dirEntries[base] or {} do
				local name = string.gsub(entry, "%.luau$", "")
				if name ~= "init" then
					table.insert(out, makeNode(base .. "/" .. name, name, self))
				end
			end
			return out
		end
	end
	local child = childNode(node, key)
	if child == nil then
		error(`{key} is not a valid member of {rawget(node, "__name")} ({rawget(node, "__path")})`, 2)
	end
	return child
end
NodeMeta.__tostring = function(node)
	return rawget(node, "__name")
end

makeNode = function(path, name, parent)
	local cached = nodeCache[path]
	if cached then
		return cached
	end
	local node = setmetatable({ __path = path, __name = name, __parent = parent }, NodeMeta)
	nodeCache[path] = node
	return node
end

local requireNode: (node: any) -> any

local function loadFile(file: string, scriptNode: any, extraEnv: { [string]: any }?): any
	local source = sources[file] or fs.readFile(file)
	local env: { [string]: any } = {
		script = scriptNode,
		require = function(target)
			if type(target) == "table" and rawget(target, "__path") then
				return requireNode(target)
			end
			return require(target)
		end,
	}
	for key, value in GLOBAL_ENV do
		env[key] = value
	end
	if extraEnv then
		for key, value in extraEnv do
			env[key] = value
		end
	end
	local chunk = luau.load(source, { debugName = file, environment = env })
	return chunk()
end

requireNode = function(node)
	local path = rawget(node, "__path")
	local file = moduleFile(path)
	if file == nil then
		error(`no module at {path}`)
	end
	if moduleCache[file] == nil then
		moduleCache[file] = loadFile(file, node)
	end
	return moduleCache[file]
end

local roots: { [string]: any } = {}
for name, path in ROOTS do
	roots[name] = makeNode(path, name, nil)
end

return {
	env = GLOBAL_ENV,
	roots = roots,
	requireNode = requireNode,
	loadFile = loadFile,
	makeNode = makeNode,
}
