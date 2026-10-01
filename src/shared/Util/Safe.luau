--!strict
--[[
	Runs a function and reports any error with a traceback instead of letting it
	kill the caller's loop. Every long-lived loop in the game ticks through this.
]]

local Safe = {}

function Safe.call(label: string, fn: (...any) -> ...any, ...: any): boolean
	local ok, err = (xpcall :: any)(fn, debug.traceback, ...)
	if not ok then
		warn(`[{label}] {err}`)
	end
	return ok
end

return table.freeze(Safe)
