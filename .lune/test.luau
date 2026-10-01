--[[
	Unit test runner for the pure shared layer (src/shared/Logic, Config, Util).

	Run with:  lune run test            (all specs)
	           lune run test Inventory  (specs whose file name contains "Inventory")

	Roblox resolves `require(script.Parent.X)` against the DataModel. Lune has no
	DataModel, so this runner builds a small proxy tree that mirrors the Rojo
	mapping in default.project.json and loads each module with its own `script`.
	Pure modules must therefore only require through `script` and must not touch
	engine globals (Instance, Vector3, task, game).
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local Loader = require("./lib/Loader")
local roots = Loader.roots
local loadFile = Loader.loadFile
local makeNode = Loader.makeNode

-- Test DSL --------------------------------------------------------------------------

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function expect(actual: any)
	local function fail(message: string)
		error(message, 3)
	end
	return {
		toBe = function(expected)
			if actual ~= expected then
				fail(`expected {show(expected)}, got {show(actual)}`)
			end
		end,
		toEqual = function(expected)
			if not deepEqual(actual, expected) then
				fail("tables differ")
			end
		end,
		toBeCloseTo = function(expected: number, epsilon: number?)
			if math.abs(actual - expected) > (epsilon or 1e-6) then
				fail(`expected ~{expected}, got {actual}`)
			end
		end,
		toBeTruthy = function()
			if not actual then
				fail(`expected a truthy value, got {show(actual)}`)
			end
		end,
		toBeFalsy = function()
			if actual then
				fail(`expected a falsy value, got {show(actual)}`)
			end
		end,
		toBeGreaterThan = function(limit: number)
			if not (actual > limit) then
				fail(`expected {actual} > {limit}`)
			end
		end,
		toBeLessThan = function(limit: number)
			if not (actual < limit) then
				fail(`expected {actual} < {limit}`)
			end
		end,
		toBeAtLeast = function(limit: number)
			if not (actual >= limit) then
				fail(`expected {actual} >= {limit}`)
			end
		end,
		toBeAtMost = function(limit: number)
			if not (actual <= limit) then
				fail(`expected {actual} <= {limit}`)
			end
		end,
		toBeBetween = function(lo: number, hi: number)
			if not (actual >= lo and actual <= hi) then
				fail(`expected {actual} within [{lo}, {hi}]`)
			end
		end,
	}
end

type Case = { name: string, fn: () -> () }
local suites: { { name: string, cases: { Case } } } = {}
local currentSuite: { name: string, cases: { Case } }? = nil

local function describe(name: string, body: () -> ())
	local suite = { name = name, cases = {} }
	table.insert(suites, suite)
	local previous = currentSuite
	currentSuite = suite
	body()
	currentSuite = previous
end

local function it(name: string, fn: () -> ())
	assert(currentSuite, "it() must be called inside describe()")
	table.insert(currentSuite.cases, { name = name, fn = fn })
end

-- Discover and run -----------------------------------------------------------------

local filter = process.args[1]
local specFiles = {}
for _, entry in fs.readDir("tests") do
	if string.match(entry, "%.spec%.luau$") and (filter == nil or string.find(entry, filter, 1, true)) then
		table.insert(specFiles, "tests/" .. entry)
	end
end
table.sort(specFiles)

for _, file in specFiles do
	loadFile(file, makeNode(string.gsub(file, "%.luau$", ""), file, nil), {
		Shared = roots.Shared,
		describe = describe,
		it = it,
		expect = expect,
	})
end

local passed, failed = 0, 0
for _, suite in suites do
	print(stdio.style("bold") .. suite.name .. stdio.style("reset"))
	for _, case in suite.cases do
		local ok, err = pcall(case.fn)
		if ok then
			passed += 1
			print(stdio.color("green") .. "  ok   " .. stdio.color("reset") .. case.name)
		else
			failed += 1
			print(stdio.color("red") .. "  FAIL " .. stdio.color("reset") .. case.name)
			print("       " .. tostring(err))
		end
	end
end

print(`\n{passed} passed, {failed} failed, {#specFiles} spec files`)
process.exit(if failed > 0 then 1 else 0)
