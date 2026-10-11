--!strict
local Config = require(script.Parent.Parent.Config.Settings)
local Settings = {}
Settings.Defaults = Config.Defaults :: { [string]: string }

function Settings.valid(key: string, value: any): boolean
	local choices = (Config.Choices :: { [string]: { string } })[key]
	return choices ~= nil and type(value) == "string" and table.find(choices, value) ~= nil
end

function Settings.read(saved: any): { [string]: string }
	local result: { [string]: string } = {}
	for key, default in Settings.Defaults do
		local value = if type(saved) == "table" then saved[key] else nil
		result[key] = if Settings.valid(key, value) then value else default
	end
	return result
end

-- Completed runs give existing profiles a conservative migration baseline.
function Settings.runsStarted(saved: any, completed: any): number
	local value = if type(saved) == "table" then saved.RunsStarted else nil
	if value == nil then
		value = completed
	end
	return if type(value) == "number"
			and value == value
			and value < math.huge
		then math.max(0, math.floor(value))
		else 0
end

-- Count once at departure, never again for a respawn, stop or reconnect.
function Settings.startRun(saved: { [string]: any }, runId: string, completed: any): boolean
	if runId == "" or saved.LastCountedRun == runId then
		return false
	end
	saved.RunsStarted = Settings.runsStarted(saved, completed) + 1
	saved.LastCountedRun = runId
	return true
end

function Settings.markersVisible(mode: any, runs: any): boolean
	if mode == "Always" then
		return true
	elseif mode == "Off" then
		return false
	end
	return Settings.runsStarted({ RunsStarted = runs }, nil) <= Config.FirstFewRuns
end

return Settings
