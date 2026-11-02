--!strict
--[[
	Whether a session may write a stored profile. `data` is the value in the store:
	`lock` { job, time } while a server holds the profile, and `session`, the id of
	the latest load, which stays after the lock is released. A session may write
	only while no other server holds the lock and it is still the latest load, so
	an old server's late save can't replace newer progress.
]]

local SaveLock = {}

function SaveLock.owns(data: any, job: string, session: string): boolean
	if data.lock and data.lock.job ~= job then
		return false
	end
	return data.session == nil or data.session == session
end

return table.freeze(SaveLock)
