--!strict
--[[
	Runs a call that may throw (a DataStore request) up to `tries` times, waiting
	baseDelay, 2 * baseDelay, 4 * baseDelay ... between attempts. The wait is passed in
	(task.wait in game, a recorder in tests), so this stays pure.
	Returns whether it succeeded, its result or the last error, and the attempts used.
]]

local Retry = {}

function Retry.run(
	call: () -> any,
	tries: number,
	baseDelay: number,
	wait: (number) -> ()
): (boolean, any, number)
	local lastError: any = nil
	for attempt = 1, math.max(tries, 1) do
		local ok, result = pcall(call)
		if ok then
			return true, result, attempt
		end
		lastError = result
		if attempt < tries then
			wait(baseDelay * 2 ^ (attempt - 1))
		end
	end
	return false, lastError, math.max(tries, 1)
end

return Retry
