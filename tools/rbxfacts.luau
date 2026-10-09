--!nonstrict
--[[
	rbxfacts: rbxmap's sibling for "what exists / what's it called / who calls it".
	Answers in one cheap call the questions that cost retries last time:
	  - which remotes exist, who fires them, who handles them (ready-up, skip, ...)
	  - does this module actually exist? (catches requires of nonexistent modules,
	    and client scripts requiring server-only modules)
	  - which dev/chat commands exist

	Run from the repo root (next to default.project.json):
	  lune run tools/rbxfacts                    write .rbxfacts.md + print summary
	  lune run tools/rbxfacts find <text>        modules whose path/file contains <text>
	  lune run tools/rbxfacts remote <text>      remotes matching <text>
	  lune run tools/rbxfacts grep <lua-pattern> compact grep, max 25 hits, 100 chars each
	  lune run tools/rbxfacts check              exit 1 if any require can't resolve (for `lune run check`)

	Heuristic (regex over source, not a real parser): treat output as a fast
	pointer, then open the file for anything that matters.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local PROJECT = "default.project.json"
local OUT = ".rbxfacts.md"

-- ---------------------------------------------------------------- module map
local entries = {} -- { fsPath, inst, kind }
local byName = {} -- last instance name -> { entry }
local lineCache = {} -- fsPath -> { string }

local function join(a, b)
	if a == "" then
		return b
	end
	return a .. "." .. b
end

local function addEntry(fsPath, inst, kind)
	local e = { fsPath = fsPath, inst = inst, kind = kind }
	table.insert(entries, e)
	local last = inst:match("([^%.]+)$")
	byName[last] = byName[last] or {}
	table.insert(byName[last], e)
end

local function splitName(file)
	local rules = {
		{ ".server.luau", "Script" },
		{ ".server.lua", "Script" },
		{ ".client.luau", "LocalScript" },
		{ ".client.lua", "LocalScript" },
		{ ".luau", "ModuleScript" },
		{ ".lua", "ModuleScript" },
	}
	for _, rule in rules do
		local ext = rule[1]
		if file:sub(-#ext) == ext then
			return file:sub(1, -#ext - 1), rule[2]
		end
	end
	return nil, nil
end

local function walkDir(dir, inst)
	for _, item in fs.readDir(dir) do
		local full = dir .. "/" .. item
		if fs.isDir(full) then
			walkDir(full, join(inst, item))
		else
			local name, kind = splitName(item)
			if name then
				if name == "init" then
					addEntry(full, inst, kind)
				else
					addEntry(full, join(inst, name), kind)
				end
			end
		end
	end
end

local function walkTree(node, inst)
	local p = node["$path"]
	if type(p) == "string" then
		if fs.isDir(p) then
			walkDir(p, inst)
		elseif fs.isFile(p) then
			local base = p:match("([^/\\]+)$")
			local name, kind = splitName(base)
			if name then
				addEntry(p, inst, kind)
			end
		end
	end
	for key, child in node do
		if key:sub(1, 1) ~= "$" and type(child) == "table" then
			walkTree(child, join(inst, key))
		end
	end
end

if not fs.isFile(PROJECT) then
	print(`rbxfacts: {PROJECT} not found - run from the repo root`)
	process.exit(2)
end
local project = serde.decode("json", fs.readFile(PROJECT))
walkTree(project.tree, "")

local function linesOf(path)
	if lineCache[path] then
		return lineCache[path]
	end
	local out = {}
	for line in (fs.readFile(path) .. "\n"):gmatch("(.-)\r?\n") do
		table.insert(out, line)
	end
	lineCache[path] = out
	return out
end

-- ------------------------------------------------------------------- scanning
local ROLES = {
	{ "([%w_]+)%s*:%s*FireServer", "fires C>S" },
	{ "[\"']([%w_]+)[\"']%)%s*:%s*FireServer", "fires C>S" },
	{ "([%w_]+)%s*:%s*InvokeServer", "invokes C>S" },
	{ "([%w_]+)%s*:%s*FireClient", "fires S>C" },
	{ "([%w_]+)%s*:%s*FireAllClients", "fires S>C" },
	{ "[\"']([%w_]+)[\"']%)%s*:%s*FireClient", "fires S>C" },
	{ "[\"']([%w_]+)[\"']%)%s*:%s*FireAllClients", "fires S>C" },
	{ "([%w_]+)%.OnServerEvent", "handled on server" },
	{ "([%w_]+)%.OnServerInvoke", "handled on server" },
	{ "([%w_]+)%.OnClientEvent", "handled on client" },
	{ "[\"']([%w_]+)[\"']%)%.OnServerEvent", "handled on server" },
	{ "[\"']([%w_]+)[\"']%)%.OnClientEvent", "handled on client" },
}

local remotes = {} -- name -> { declared = {loc}, [role] = {loc} }
local function remoteRec(name)
	remotes[name] = remotes[name] or { declared = {} }
	return remotes[name]
end

local tableRemotes = {} -- remotes declared as `Name = { direction = "ToServer", ... }`
local commands = {} -- name -> loc
local unresolved = {} -- strings
local CLIENT_ROOTS = { "StarterPlayer", "StarterGui", "StarterPack", "ReplicatedFirst" }
local SERVER_ROOTS = { "ServerScriptService", "ServerStorage" }

local function startsWithAny(s, list)
	for _, p in list do
		if s:sub(1, #p) == p then
			return true
		end
	end
	return false
end

local function requireTarget(expr)
	expr = expr:gsub("^%s+", ""):gsub("%s+$", "")
	local quoted = expr:match("[\"']([%w_]+)[\"']%)%s*$") -- ...:WaitForChild("Foo")
	if quoted then
		return quoted
	end
	if not expr:find("[%.:]") then
		return nil -- plain variable, can't tell
	end
	local last = expr:match("([%w_]+)%s*$")
	if last == "Parent" or last == "script" then
		return nil
	end
	return last
end

for _, e in entries do
	local lines = linesOf(e.fsPath)
	for i, line in lines do
		local loc = `{e.fsPath}:{i}`

		-- declared remotes
		local rtype = line:match("Instance%.new%([\"'](Remote%a+)[\"']%)")
		if rtype then
			for j = i, math.min(i + 4, #lines) do
				local nm = lines[j]:match("Name%s*=%s*[\"']([%w_]+)[\"']")
				if nm then
					table.insert(remoteRec(nm).declared, `{rtype} @ {e.fsPath}:{j}`)
					break
				end
			end
		end

		-- remotes declared in a central table: Name = { direction = "ToServer", ... }
		local dname, ddir = line:match("^%s*([%w_]+)%s*=%s*{%s*direction%s*=%s*[\"'](%w+)[\"']")
		if dname then
			table.insert(remoteRec(dname).declared, `{ddir} @ {loc}`)
			tableRemotes[dname] = true
		end

		-- fire / handle
		for _, role in ROLES do
			local nm = line:match(role[1])
			if nm then
				local rec = remoteRec(nm)
				rec[role[2]] = rec[role[2]] or {}
				table.insert(rec[role[2]], loc)
			end
		end

		-- requires
		local expr = line:match("require%((.*)%)")
		if expr then
			local target = requireTarget(expr)
			if target then
				local found = byName[target]
				if not found then
					table.insert(unresolved, `{loc}: require(...{target}) - no module named '{target}' in {PROJECT} tree`)
				elseif startsWithAny(e.inst, CLIENT_ROOTS) then
					local allServer = true
					for _, f in found do
						if not startsWithAny(f.inst, SERVER_ROOTS) then
							allServer = false
						end
					end
					if allServer then
						table.insert(unresolved, `{loc}: client code requires server-only module {found[1].inst}`)
					end
				end
			end
		end

		-- dev / chat commands (heuristic)
		local slash = line:match("[\"']/([%a][%w_]*)[\"']")
		if slash and not commands[slash] then
			commands[slash] = loc
		end
		local ck = line:match("[Cc]ommands%.([%w_]+)%s*=") or line:match("[Cc]ommands%[[\"']([%w_]+)[\"']%]%s*=")
		if ck and not commands[ck] then
			commands[ck] = loc
		end
	end
end

-- second pass: where is each table-declared remote referenced by name?
for name in tableRemotes do
	local dq, sq = `"{name}"`, `'{name}'`
	for _, e in entries do
		for i, line in linesOf(e.fsPath) do
			if line:find(dq, 1, true) or line:find(sq, 1, true) then
				local rec = remoteRec(name)
				rec["used by"] = rec["used by"] or {}
				table.insert(rec["used by"], `{e.fsPath}:{i}`)
			end
		end
	end
end

local function sortedKeys(t)
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

local function firstN(list, n)
	local out = {}
	for i = 1, math.min(n, #list) do
		table.insert(out, list[i])
	end
	if #list > n then
		table.insert(out, `+{#list - n} more`)
	end
	return table.concat(out, ", ")
end

local function remoteLines(filter)
	local out = {}
	for _, name in sortedKeys(remotes) do
		if not filter or name:lower():find(filter:lower(), 1, true) then
			local rec = remotes[name]
			local parts = {}
			if #rec.declared > 0 then
				table.insert(parts, `declared {firstN(rec.declared, 1)}`)
			end
			for _, role in { "fires C>S", "invokes C>S", "handled on server", "fires S>C", "handled on client", "used by" } do
				if rec[role] then
					table.insert(parts, `{role}: {firstN(rec[role], 3)}`)
				end
			end
			table.insert(out, `- {name} - {table.concat(parts, " | ")}`)
		end
	end
	return out
end

-- ------------------------------------------------------------------------ CLI
local args = process.args
local cmd = args[1] or "build"

if cmd == "find" then
	local q = (args[2] or ""):lower()
	local n = 0
	for _, e in entries do
		if e.inst:lower():find(q, 1, true) or e.fsPath:lower():find(q, 1, true) then
			n += 1
			if n <= 15 then
				print(`{e.inst} [{e.kind}] {e.fsPath}`)
			end
		end
	end
	if n == 0 then
		print(`no module matching '{q}' (checked {#entries} scripts) - it does not exist`)
	elseif n > 15 then
		print(`+{n - 15} more`)
	end
elseif cmd == "remote" then
	local lines = remoteLines(args[2])
	print(if #lines > 0 then table.concat(lines, "\n") else `no remote matching '{args[2] or ""}'`)
elseif cmd == "grep" then
	local pat = args[2]
	if not pat then
		print("usage: grep <lua-pattern>")
		process.exit(2)
	end
	local n = 0
	for _, e in entries do
		for i, line in linesOf(e.fsPath) do
			if line:find(pat) then
				n += 1
				if n <= 25 then
					local text = line:gsub("^%s+", "")
					print(`{e.fsPath}:{i}: {text:sub(1, 100)}`)
				end
			end
		end
	end
	if n > 25 then
		print(`+{n - 25} more hits`)
	elseif n == 0 then
		print("no hits")
	end
elseif cmd == "check" then
	for _, u in unresolved do
		print(u)
	end
	print(`rbxfacts check: {#unresolved} problem(s)`)
	process.exit(if #unresolved > 0 then 1 else 0)
else
	local out = {}
	table.insert(out, `# rbxfacts ({os.date("%Y-%m-%d %H:%M")}) - regenerate: lune run tools/rbxfacts`)
	table.insert(out, `{#entries} scripts mapped from {PROJECT}`)
	table.insert(out, "")
	table.insert(out, "## Remotes (name - declared | who fires | who handles)")
	for _, l in remoteLines(nil) do
		table.insert(out, l)
	end
	table.insert(out, "")
	table.insert(out, "## Dev / chat commands (heuristic)")
	for _, k in sortedKeys(commands) do
		table.insert(out, `- {k} @ {commands[k]}`)
	end
	table.insert(out, "")
	table.insert(out, "## Unresolved requires")
	if #unresolved == 0 then
		table.insert(out, "none")
	end
	for _, u in unresolved do
		table.insert(out, `- {u}`)
	end
	fs.writeFile(OUT, table.concat(out, "\n") .. "\n")
	print(`wrote {OUT}: {#entries} scripts, {#sortedKeys(remotes)} remotes, {#sortedKeys(commands)} commands, {#unresolved} unresolved requires`)
end
