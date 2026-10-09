local Retry = require(Shared.Logic.Retry)

-- A DataStore stand-in: UpdateAsync throws `failures` times, then applies the transform.
local function mockStore(failures: number)
	local store = { calls = 0, data = {} :: { [string]: any } }
	function store.UpdateAsync(self: any, key: string, transform: (any) -> any): any
		self.calls += 1
		if self.calls <= failures then
			error("502: API Services rejected request")
		end
		local nextValue = transform(self.data[key])
		if nextValue ~= nil then
			self.data[key] = nextValue
		end
		return nextValue
	end
	return store
end

-- The same shape as DataService.save.
local function save(store: any, waits: { number }, tries: number, profile: any): (boolean, any, number)
	return Retry.run(
		function()
			return store:UpdateAsync("u_1", function(old: any)
				local data = if type(old) == "table" then old else {}
				data.profile = profile
				return data
			end)
		end,
		tries,
		1,
		function(seconds)
			table.insert(waits, seconds)
		end
	)
end

describe("Retry", function()
	it("saves on the first try without waiting", function()
		local store, waits = mockStore(0), {}
		local ok, _, attempts = save(store, waits, 3, { brass = 5 })
		expect(ok).toBe(true)
		expect(attempts).toBe(1)
		expect(#waits).toBe(0)
		expect(store.data.u_1.profile.brass).toBe(5)
	end)

	it("retries with doubling backoff until the store recovers", function()
		local store, waits = mockStore(2), {}
		local ok, _, attempts = save(store, waits, 3, { npcs = { Mabel = { stage = 2 } } })
		expect(ok).toBe(true)
		expect(attempts).toBe(3)
		expect(waits).toEqual({ 1, 2 })
		expect(store.data.u_1.profile.npcs.Mabel.stage).toBe(2)
	end)

	it("gives up after the last try, reports the error and leaves the stored save alone", function()
		local store, waits = mockStore(10), {}
		store.data.u_1 = { profile = { brass = 99 } }
		local ok, err, attempts = save(store, waits, 3, { brass = 0 })
		expect(ok).toBe(false)
		expect(attempts).toBe(3)
		expect(string.find(tostring(err), "502", 1, true) ~= nil).toBe(true)
		expect(waits).toEqual({ 1, 2 })
		expect(store.data.u_1.profile.brass).toBe(99)
	end)
end)
