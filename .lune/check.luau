--[[
	The full quality gate. Run it before every commit:

	  lune run check

	Steps, in order: formatting (StyLua), lint (selene), a fresh Rojo sourcemap,
	strict type checking (luau-lsp) and the unit tests. The first failure stops the
	run with that tool's exit code. The Roblox type definitions luau-lsp needs are
	downloaded into .tooling/ the first time.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local DEFINITIONS = ".tooling/globalTypes.d.luau"
local DEFINITIONS_URL =
	"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.PluginSecurity.d.luau"

type Step = { name: string, program: string, args: { string } }

local STEPS: { Step } = {
	{ name = "format", program = "stylua", args = { "--check", "src", "tests", ".lune" } },
	{ name = "lint", program = "selene", args = { "src", ".lune" } },
	{ name = "lint tests", program = "selene", args = { "--config", "tests/selene.toml", "tests" } },
	{
		name = "sourcemap",
		program = "rojo",
		args = { "sourcemap", "default.project.json", "--output", "sourcemap.json" },
	},
	{
		name = "types",
		program = "luau-lsp",
		args = { "analyze", "--sourcemap=sourcemap.json", `--definitions=@roblox={DEFINITIONS}`, "src" },
	},
	{ name = "tests", program = "lune", args = { "run", "test" } },
}

local function ensureDefinitions()
	if fs.isFile(DEFINITIONS) then
		return
	end
	print(`Downloading Roblox type definitions to {DEFINITIONS}`)
	local response = net.request(DEFINITIONS_URL)
	if not response.ok then
		error(`download failed: HTTP {response.statusCode}`)
	end
	if not fs.isDir(".tooling") then
		fs.writeDir(".tooling")
	end
	fs.writeFile(DEFINITIONS, response.body)
end

ensureDefinitions()

for _, step in STEPS do
	print(stdio.style("bold") .. `== {step.name}` .. stdio.style("reset"))
	local result = process.exec(step.program, step.args, { stdio = "inherit" })
	if not result.ok then
		print(
			stdio.color("red")
				.. `{step.name} failed: {step.program} exited with {result.code}`
				.. stdio.color("reset")
		)
		process.exit(result.code)
	end
end

print(stdio.color("green") .. "All checks passed." .. stdio.color("reset"))
