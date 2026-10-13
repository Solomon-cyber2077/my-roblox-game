--!strict
--[[
	Why a crew member went down. The server tags the character where the harm happens
	(`LastDamageSource` + `LastDamageAt`, cleared on every spawn); on death the tag is
	read here. A tag older than StaleSeconds no longer explains the death (you healed
	and then reset, say), so it reads as Other. Lines are the death screen's and the
	run ticket's words for each cause.
]]

local Shared = script.Parent.Parent
local Types = require(Shared.Types)

type Cause = Types.Cause

local DeathCause = {}

DeathCause.StaleSeconds = 8

-- Damage source tag -> cause.
local BY_SOURCE: { [string]: Cause } = {
	Hollow = "Taken",
	Fog = "Smothered",
	Fall = "Fell",
	Train = "Wrecked",
}

DeathCause.Lines = table.freeze({
	LeftBehind = table.freeze({ title = "LEFT BEHIND", line = "The train pulled out without you." }),
	Taken = table.freeze({ title = "TAKEN", line = "A Hollow caught you and would not let go." }),
	Smothered = table.freeze({ title = "LOST IN THE FOG", line = "You stayed too long past the fog line." }),
	Fell = table.freeze({ title = "FELL", line = "The ground gave way beneath you." }),
	Wrecked = table.freeze({ title = "WRECKED", line = "The train broke down on the line." }),
	Disconnected = table.freeze({ title = "DISCONNECTED", line = "You lost the line." }),
	Other = table.freeze({ title = "LOST", line = "Something on the line took you." }),
})

--[[
	The cause of a death. `source`/`at` are the character's last damage tag, `now` the
	server clock, `fell` whether the body was below the fall line when it died.
]]
function DeathCause.fromDeath(source: string?, at: number?, now: number, fell: boolean): Cause
	if fell then
		return "Fell"
	end
	local cause: Cause? = if source then BY_SOURCE[source] else nil
	if cause and at and now - at <= DeathCause.StaleSeconds then
		return cause
	end
	return "Other"
end

-- The words for a cause; unknown causes read as Other.
function DeathCause.line(cause: string?): { title: string, line: string }
	return (DeathCause.Lines :: any)[cause or "Other"] or DeathCause.Lines.Other
end

return table.freeze(DeathCause)
