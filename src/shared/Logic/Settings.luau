--!strict
local Config = require(script.Parent.Parent.Config.Settings)
local Settings = {}
Settings.Defaults = Config.Defaults :: { [string]: string }

local Ranges = Config.Ranges :: { [string]: { min: number, max: number } }

-- A numeric setting's value, clamped into its range as a whole-number string; nil when the
-- key has no range or the value is not a finite number.
function Settings.clamp(key: string, value: any): string?
	local range = Ranges[key]
	local n = if type(value) == "number"
		then value
		elseif type(value) == "string" then tonumber(value)
		else nil
	if range == nil or n == nil or n ~= n or math.abs(n) == math.huge then
		return nil
	end
	return tostring(math.round(math.clamp(n, range.min, range.max)))
end

function Settings.valid(key: string, value: any): boolean
	if Ranges[key] then
		return Settings.clamp(key, value) ~= nil
	end
	local choices = (Config.Choices :: { [string]: { string } })[key]
	return choices ~= nil and type(value) == "string" and table.find(choices, value) ~= nil
end

function Settings.read(saved: any): { [string]: string }
	local result: { [string]: string } = {}
	for key, default in Settings.Defaults do
		local value = if type(saved) == "table" then saved[key] else nil
		result[key] = if Ranges[key]
			then Settings.clamp(key, value) or default
			elseif Settings.valid(key, value) then value
			else default
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
