local TelemetrySink = require(Shared.Logic.TelemetrySink)

local function records(count: number, from: number?): { any }
	local out = {}
	for i = 1, count do
		table.insert(
			out,
			TelemetrySink.record((from or 0) + i, "run_joined", 1, { "phone", "first_run", "2" })
		)
	end
	return out
end

describe("TelemetrySink records", function()
	it("keys by place, server and user", function()
		expect(TelemetrySink.key(123, "job", 7)).toBe("123/job/7")
		expect(TelemetrySink.prefix(123, "job")).toBe("123/job/")
		expect(TelemetrySink.prefix(123)).toBe("123/")
	end)

	it("keeps only string fields and rounds time to a hundredth", function()
		local r = TelemetrySink.record(1.23456, "player_eliminated", 40, { "Taken", false, "Crawler" })
		expect(r.t).toBe(1.23)
		expect(r.f1).toBe("Taken")
		expect(r.f2).toBe(nil)
		expect(r.f3).toBe("Crawler")
	end)
end)

describe("TelemetrySink.merge", function()
	it("appends pending records after what the key holds", function()
		local out, dropped = TelemetrySink.merge(records(2), records(3, 10), 0, 100)
		expect(#out).toBe(5)
		expect(out[3].t).toBe(11)
		expect(dropped).toBe(0)
	end)

	it("starts an empty key", function()
		local out = TelemetrySink.merge(nil, records(2), 0, 100)
		expect(#out).toBe(2)
	end)

	it("caps a key at max records, the last one counting the drops", function()
		local out, dropped = TelemetrySink.merge(records(8), records(5, 100), 0, 10)
		expect(#out).toBe(10)
		expect(dropped).toBe(4)
		expect(out[10].name).toBe(TelemetrySink.Overflow)
		expect(out[10].value).toBe(4)
	end)

	it("replaces the overflow record on the next flush instead of adding one", function()
		local first, dropped = TelemetrySink.merge(records(9), records(3, 100), 0, 10)
		local second, total = TelemetrySink.merge(first, records(2, 200), dropped, 10)
		expect(#second).toBe(10)
		expect(total).toBe(5)
		local overflows = 0
		for _, r in second do
			if r.name == TelemetrySink.Overflow then
				overflows += 1
			end
		end
		expect(overflows).toBe(1)
		expect(second[10].value).toBe(5)
	end)
end)

describe("TelemetrySink buffers", function()
	it("keeps the buffer when a flush fails and records added during a flush", function()
		local buffer = TelemetrySink.newBuffer()
		for _, r in records(3) do
			TelemetrySink.add(buffer, r)
		end
		local count = #buffer.pending
		-- a failed flush: nothing changes
		expect(#buffer.pending).toBe(3)
		-- a record arrives while a later flush is in flight, then that flush succeeds
		TelemetrySink.add(buffer, records(1, 50)[1])
		TelemetrySink.flushed(buffer, count, 0)
		expect(#buffer.pending).toBe(1)
		expect(buffer.pending[1].t).toBe(51)
	end)

	it("writes CSV rows with empty unused fields", function()
		local rows = TelemetrySink.csv(
			"1/j/2",
			{ TelemetrySink.record(3, "session_ended", 12.5, { "Lobby", "desktop", false }) }
		)
		expect(TelemetrySink.csvHeader()).toBe("key,t,name,value,f1,f2,f3")
		expect(rows[1]).toBe("1/j/2,3,session_ended,12.5,Lobby,desktop,")
	end)
end)
