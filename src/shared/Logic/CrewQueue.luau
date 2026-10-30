--!strict
--[[
	The cross-server crew queue's protocol (Services/MatchmakingService; crew rule in Logic/Matchmaking).
	Pure: the stores are passed in, so the same code runs on MemoryStore in game and on fakes in tests.

	Three keyed stores (MemoryStore sorted maps in game):
	  queue    one ticket per occupied car in a hall: { members, since, deadline }, sorted by `since`;
	           a hall refreshes its tickets every QueueRefresh and a dead hall's tickets expire (QueueTtl)
	  matches  a ticket's match once a crew forms: { matchId, code, crew }; the car's hall reads it and
	           teleports its riders into that reserved server (MatchTtl)
	  lock     one hall matches at a time, on a lease (LockSeconds)

	  ticket(jobId, car, generation)        a car's ticket key; a fresh generation each time the car empties
	  entry(members, since, deadline)       a ticket's value
	  matchStep(stores, me, now, reserve, newId)
	                                        one matcher pass: take the lease, read the queue, form crews, claim each
	                                        crew's tickets atomically (a ticket already claimed aborts the crew and
	                                        frees the rest), reserve a server, record the match, drop the tickets.
	                                        Returns how many crews it sent. Any store error ends the pass
	                                        harmlessly: a car is never matched twice, and a claim a failed pass
	                                        left behind is released after StaleClaim (or, if its match record
	                                        was written, the ticket is cleared: that car is on its way).
	  holdLocal(full, healthy, deadline, now)
	                                        whether a car must wait for the queue instead of leaving on its own
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local Matchmaking = require(script.Parent.Matchmaking)

local C = Tuning.Cars

export type Entry = {
	members: { number },
	since: number,
	deadline: number,
	matched: string?,
	claimedAt: number?,
}
export type Match = { matchId: string, code: string, crew: { number } }
export type Store = {
	get: (key: string) -> any,
	set: (key: string, value: any, ttl: number, sortKey: number?) -> (),
	update: (key: string, transform: (old: any) -> any, ttl: number) -> any,
	remove: (key: string) -> (),
	range: (count: number) -> { { key: string, value: any } },
}
export type Stores = { queue: Store, matches: Store, lock: Store }

local CrewQueue = {}

function CrewQueue.ticket(jobId: string, car: number, generation: number): string
	return `{jobId}/{car}/{generation}`
end

function CrewQueue.entry(members: { number }, since: number, deadline: number): Entry
	return { members = members, since = since, deadline = deadline }
end

local function valid(v: any): boolean
	if type(v) ~= "table" or type(v.members) ~= "table" or type(v.deadline) ~= "number" then
		return false
	end
	local n = #v.members
	return n >= 1 and n <= C.MaxPlayers
end

-- The lease: take it if nobody holds it, it lapsed, or we already hold it.
function CrewQueue.takeLock(old: any, me: string, now: number): any
	if type(old) == "table" and old.owner ~= me and type(old["until"]) == "number" and old["until"] > now then
		return nil
	end
	return { owner = me, ["until"] = now + C.LockSeconds }
end

-- Claim a ticket for a match: only a live, unclaimed ticket can be claimed.
function CrewQueue.claim(old: any, matchId: string, now: number?): any
	if not valid(old) or old.matched ~= nil then
		return nil
	end
	old.matched = matchId
	old.claimedAt = now or 0
	return old
end

local function unclaim(old: any, matchId: string): any
	if type(old) == "table" and old.matched == matchId then
		old.matched = nil
		old.claimedAt = nil
		return old
	end
	return nil
end

function CrewQueue.matchStep(
	stores: Stores,
	me: string,
	now: number,
	reserve: () -> string?,
	newId: () -> string
): number
	local ok, sent = pcall(function(): number
		local lease = stores.lock.update("matcher", function(old)
			return CrewQueue.takeLock(old, me, now)
		end, C.LockSeconds)
		if lease == nil or lease.owner ~= me then
			return 0
		end
		-- live, unclaimed tickets, oldest first
		local rows = stores.queue.range(C.QueueRead)
		local keys: { string } = {}
		local entries: { Matchmaking.Entry } = {}
		local values: { Entry } = {}
		for _, row in rows do
			local v = row.value
			if valid(v) and v.matched ~= nil and now - (v.claimedAt or 0) > C.StaleClaim then
				-- a pass failed after claiming this: if its match was recorded the car is on its way (drop the
				-- ticket), otherwise release the claim so the car can be matched again
				local stale = v.matched
				pcall(function() -- on its own: a store error here must not end the pass
					if stores.matches.get(row.key) ~= nil then
						stores.queue.remove(row.key)
					else
						stores.queue.update(row.key, function(old)
							return unclaim(old, stale)
						end, C.QueueTtl)
					end
				end)
			elseif valid(v) and v.matched == nil then
				table.insert(keys, row.key)
				table.insert(values, v)
				table.insert(entries, { size = #v.members, deadline = v.deadline })
			end
		end
		local count = 0
		for _, crewIdx in Matchmaking.form(entries, now, C.MaxPlayers) do
			-- each crew on its own: a store error loses this crew's turn, not the rest of the pass
			local crewOk, crewSent = pcall(function(): boolean
				local matchId = newId()
				local claimed: { string } = {}
				local whole = true
				for _, i in crewIdx do
					local got = stores.queue.update(keys[i], function(old)
						return CrewQueue.claim(old, matchId, now)
					end, C.QueueTtl)
					if got == nil then
						whole = false
						break
					end
					table.insert(claimed, keys[i])
				end
				local code = if whole then reserve() else nil
				if not whole or code == nil then
					-- a ticket went (its hall emptied the car or another pass took it), or no server: free the rest
					for _, key in claimed do
						stores.queue.update(key, function(old)
							return unclaim(old, matchId)
						end, C.QueueTtl)
					end
					return false
				end
				local crew: { number } = {}
				for _, i in crewIdx do
					for _, id in values[i].members do
						table.insert(crew, id)
					end
				end
				local match: Match = { matchId = matchId, code = code :: string, crew = crew }
				for _, key in claimed do
					stores.matches.set(key, match, C.MatchTtl, nil)
				end
				for _, key in claimed do
					stores.queue.remove(key)
				end
				return true
			end)
			if crewOk and crewSent then
				count += 1
			end
		end
		return count
	end)
	return if ok then sent else 0
end

function CrewQueue.holdLocal(full: boolean, healthy: boolean, deadline: number, now: number): boolean
	return not full and healthy and now < deadline + C.FallbackAfter
end

return table.freeze(CrewQueue)
