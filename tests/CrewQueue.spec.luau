local CrewQueue = require(Shared.Logic.CrewQueue)
local Tuning = require(Shared.Config.Tuning)

local C = Tuning.Cars

-- A fake MemoryStore sorted map; `fail` (0..1) makes calls error at random, like a throttled store.
local function store(rand: (() -> number)?, fail: number?)
	local data: { [string]: { value: any, sort: number } } = {}
	local function maybe()
		if rand and fail and rand() < fail then
			error("throttled")
		end
	end
	local s = {}
	s.data = data
	function s.get(key)
		maybe()
		local row = data[key]
		return row and row.value
	end
	function s.set(key, value, _ttl, sortKey)
		maybe()
		data[key] = { value = value, sort = sortKey or 0 }
	end
	function s.update(key, transform, _ttl)
		maybe()
		local row = data[key]
		local new = transform(row and row.value)
		if new ~= nil then
			data[key] = { value = new, sort = if row then row.sort else 0 }
		end
		return new
	end
	function s.remove(key)
		maybe()
		data[key] = nil
	end
	function s.range(count)
		maybe()
		local rows = {}
		for key, row in data do
			table.insert(rows, { key = key, value = row.value, sort = row.sort })
		end
		table.sort(rows, function(a, b)
			return if a.sort == b.sort then a.key < b.key else a.sort < b.sort
		end)
		return table.move(rows, 1, math.min(count, #rows), 1, {})
	end
	return s
end

local function stores(rand: (() -> number)?, fail: number?)
	return { queue = store(rand, fail), matches = store(rand, fail), lock = store(rand, fail) }
end

local ids = 0
local function newId()
	ids += 1
	return `m{ids}`
end
local function reserve()
	return "code"
end

describe("CrewQueue", function()
	it("couples lone riders from two halls once the countdown has passed", function()
		local s = stores()
		s.queue.set("hallA/1/1", CrewQueue.entry({ 11 }, 0, 20), C.QueueTtl, 0)
		s.queue.set("hallB/3/1", CrewQueue.entry({ 22 }, 1, 21), C.QueueTtl, 1)
		expect(CrewQueue.matchStep(s, "hallA", 10, reserve, newId)).toBe(0) -- still counting down
		expect(CrewQueue.matchStep(s, "hallA", 21, reserve, newId)).toBe(1)
		local a, b = s.matches.get("hallA/1/1"), s.matches.get("hallB/3/1")
		expect(a.matchId).toBe(b.matchId)
		expect(#a.crew).toBe(2)
		expect(s.queue.get("hallA/1/1")).toBe(nil)
	end)

	it("lets only the lease holder match", function()
		local s = stores()
		s.queue.set("hallA/1/1", CrewQueue.entry({ 1, 2, 3, 4 }, 0, 0), C.QueueTtl, 0)
		s.lock.set("matcher", { owner = "hallB", ["until"] = 100 }, C.LockSeconds, nil)
		expect(CrewQueue.matchStep(s, "hallA", 50, reserve, newId)).toBe(0)
		expect(CrewQueue.matchStep(s, "hallA", 101, reserve, newId)).toBe(1) -- the lease lapsed
	end)

	it("frees a crew's claims when a ticket goes or no server can be reserved", function()
		local s = stores()
		s.queue.set("a", CrewQueue.entry({ 1 }, 0, 0), C.QueueTtl, 0)
		s.queue.set("b", CrewQueue.entry({ 2 }, 1, 0), C.QueueTtl, 1)
		expect(CrewQueue.matchStep(s, "x", 5, function()
			return nil
		end, newId)).toBe(0)
		expect(s.queue.get("a").matched).toBe(nil)
		expect(s.queue.get("b").matched).toBe(nil)
		expect(s.matches.get("a")).toBe(nil)
	end)

	it("never matches a car twice and keeps matching through a throttled store", function()
		local seed = 7
		local function rand()
			seed = (seed * 48271) % 2147483647
			return seed / 2147483647
		end
		local s = stores(rand, 0.15)
		local matchOf: { [string]: string } = {} -- ticket -> the one match it got
		local waiting: { [string]: any } = {} -- cars a hall keeps (re)queueing until matched
		local queued = 0
		local T = 400
		for t = 1, T do
			-- two halls queue a lone rider each second
			if t <= T - 40 then
				for h = 1, 2 do
					queued += 1
					waiting[`hall{h}/{t}/1`] = CrewQueue.entry({ queued }, t, t + 20)
				end
			end
			-- each hall's refresh: a car not in the queue (a write failed) is written again; claims are kept
			for key, entry in waiting do
				pcall(s.queue.update, key, function(old)
					if old ~= nil then
						return nil
					end
					return table.clone(entry)
				end, C.QueueTtl)
			end
			CrewQueue.matchStep(s, if t % 3 == 0 then "hallB" else "hallA", t, reserve, newId)
			-- each hall reads its cars' matches: teleport, stop queueing, drop the ticket (the record expires)
			for key, row in s.matches.data do
				local seen = matchOf[key]
				expect(seen == nil or seen == row.value.matchId).toBe(true)
				matchOf[key] = row.value.matchId
				waiting[key] = nil
				pcall(s.queue.remove, key)
			end
		end
		local sent = 0
		for _ in matchOf do
			sent += 1
		end
		expect(sent >= queued * 0.95).toBe(true)
	end)

	it("holds a part car for the queue until the fallback, never a full one", function()
		expect(CrewQueue.holdLocal(false, true, 100, 105)).toBe(true)
		expect(CrewQueue.holdLocal(false, true, 100, 100 + C.FallbackAfter)).toBe(false)
		expect(CrewQueue.holdLocal(true, true, 100, 101)).toBe(false)
		expect(CrewQueue.holdLocal(false, false, 100, 101)).toBe(false) -- the queue is down: leave as before
	end)
end)
