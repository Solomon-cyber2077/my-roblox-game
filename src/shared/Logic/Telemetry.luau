--!strict
--[[
	Telemetry rules (Config/Telemetry). Pure: Services/TelemetryService builds the calls, this module
	buckets the numbers, names the device and checks that every custom field is in its event's frozen
	vocabulary, so a typo or an unbounded value never reaches AnalyticsService.
]]

local Shared = script.Parent.Parent
local Config = require(Shared.Config.Telemetry)
local Tuning = require(Shared.Config.Tuning)

local Telemetry = {}

export type Fields = { string | false }

local function member(values: { string }, value: any): boolean
	return type(value) == "string" and table.find(values, value) ~= nil
end

-- The label of `value` against ascending upper edges: labels[i] for value < edges[i], else the last.
local function bucket(value: number, edges: { number }, labels: { string }): string
	for i, edge in edges do
		if value < edge then
			return labels[i]
		end
	end
	return labels[#labels]
end

function Telemetry.runDuration(minutes: number): string
	return bucket(minutes, Config.Buckets.RunMinutes, Config.Vocab.RunDuration)
end

function Telemetry.doorsOpen(seconds: number): string
	return bucket(seconds, Config.Buckets.DoorsOpenSeconds, Config.Vocab.DoorsOpen)
end

-- 0, (0, 1.5), [1.5, 3), 3+
function Telemetry.tell(seconds: number): string
	if seconds <= 0 then
		return "0"
	end
	local labels = Config.Vocab.TellBucket
	return bucket(seconds, Config.Buckets.TellSeconds, { labels[2], labels[3], labels[4] })
end

function Telemetry.secondsLeft(seconds: number): string
	return bucket(seconds, Config.Buckets.SecondsLeft, Config.Vocab.SecondsLeft)
end

function Telemetry.crewNear(count: number): string
	return if count <= 0 then "0" elseif count == 1 then "1" else "2+"
end

function Telemetry.crewSize(count: number): string
	return tostring(math.clamp(math.floor(count), 1, #Config.Vocab.CrewSize))
end

-- A stop number as a field: "pre" before stop 1 opens, "terminus" past the last regular stop.
function Telemetry.stop(stop: number?, stopCount: number?): string
	local count = stopCount or Tuning.Run.StationCount
	if stop == nil or stop < 1 then
		return "pre"
	elseif stop > count then
		return "terminus"
	end
	return tostring(math.floor(stop))
end

function Telemetry.routeLength(stopCount: number): string
	return if stopCount < Tuning.Run.StationCount then "short" else "long"
end

-- A client's one-time device report; anything outside the list reads as unknown.
function Telemetry.device(report: any): string
	return if member(Config.Vocab.Device, report) then report else "unknown"
end

export type Input = {
	touch: boolean,
	keyboard: boolean,
	mouse: boolean,
	gamepad: boolean,
	tenFoot: boolean, -- GuiService:IsTenFootInterface()
	shortSide: number?, -- the viewport's shorter side in pixels
}

-- What a client reports, from what UserInputService and GuiService say once at start.
function Telemetry.classify(input: Input): string
	if input.tenFoot then
		return "console"
	elseif input.touch and not input.keyboard and not input.mouse then
		local side = input.shortSide
		if side == nil then
			return "unknown"
		end
		return if side >= Tuning.Telemetry.TabletShortSide then "tablet" else "phone"
	elseif input.keyboard or input.mouse then
		return "desktop"
	elseif input.gamepad then
		return "console"
	end
	return "unknown"
end

-- True when `name` is a declared event and each field is in its slot's vocabulary (or the slot
-- is unused and left empty). The second result says what is wrong.
function Telemetry.check(name: string, fields: Fields): (boolean, string?)
	local def = Config.Events[name]
	if def == nil then
		return false, `unknown event {name}`
	end
	for slot = 1, 3 do
		local vocab = def.fields[slot]
		local value = fields[slot]
		if vocab == false then
			if value ~= nil and value ~= false then
				return false, `{name} field {slot} is unused`
			end
		elseif not member((Config.Vocab :: any)[vocab], value) then
			return false, `{name} field {slot} ({vocab}) has {tostring(value)}`
		end
	end
	return true, nil
end

function Telemetry.checkFunnel(funnel: string, step: number, name: string): (boolean, string?)
	local steps = Config.Funnels[funnel]
	if steps == nil then
		return false, `unknown funnel {funnel}`
	elseif steps[step] ~= name then
		return false, `{funnel} step {step} is {tostring(steps[step])}, not {name}`
	end
	return true, nil
end

-- Distinct field combinations an event can produce.
function Telemetry.combinations(name: string): number
	local total = 1
	for _, vocab in Config.Events[name].fields do
		if vocab then
			total *= #(Config.Vocab :: any)[vocab]
		end
	end
	return total
end

return table.freeze(Telemetry)
