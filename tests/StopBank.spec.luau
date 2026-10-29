local StopBank = require(Shared.Logic.StopBank)
local Economy = require(Shared.Logic.Economy)
local Tuning = require(Shared.Config.Tuning)

local e = Tuning.Economy

local function tally(stations: number, coal: number)
	local t = Economy.emptyTally()
	t.stationsDeparted = stations
	t.coalDelivered = coal
	return t
end

describe("StopBank", function()
	it("banks each stop's earnings once", function()
		local bank = StopBank.new("run", 0)
		local brass, xp = StopBank.grant(bank, 1, tally(1, 0), false)
		expect(brass).toBe(e.BrassPerStation)
		expect(xp).toBe(e.BrassPerStation)
		-- the same stop again (a repeated callback) pays nothing
		brass, xp = StopBank.grant(bank, 1, tally(1, 0), false)
		expect(brass).toBe(0)
		expect(xp).toBe(0)
		expect(bank.brass).toBe(e.BrassPerStation)
	end)

	it("keeps coal remainders across stops", function()
		local bank = StopBank.new("run", 0)
		expect((StopBank.grant(bank, 1, tally(1, 6), false))).toBe(e.BrassPerStation)
		-- 6 + 6 coal is one full ten: its Brass arrives with stop 2
		expect((StopBank.grant(bank, 2, tally(2, 12), false))).toBe(e.BrassPerStation + e.BrassPerTenCoal)
	end)

	it("pays a finisher exactly the run payout in total", function()
		local bank = StopBank.new("run", 0)
		for stop = 1, 5 do
			StopBank.grant(bank, stop, tally(stop, stop * 10), false)
		end
		local final = tally(5, 50)
		final.reachedTerminus = true
		local payout =
			Economy.payout(final, { outcome = "Victory", dailyBonus = true, soloCharter = false, tier = 3 })
		local brass, xp = StopBank.remainder(bank, payout.brass, payout.xp)
		expect(bank.brass + brass).toBe(payout.brass)
		expect(bank.xp + xp).toBe(payout.xp)
		expect(brass).toBeGreaterThan(0) -- the Terminus, tier and daily lines wait for RunEnd
	end)

	it("applies the solo charter rate to each grant", function()
		local bank = StopBank.new("run", 0)
		for stop = 1, 3 do
			StopBank.grant(bank, stop, tally(stop, 0), true)
		end
		expect(bank.brass).toBe(math.floor(3 * e.BrassPerStation * e.CharterSoloMultiplier))
		local payout =
			Economy.payout(tally(3, 0), { outcome = "Wiped", dailyBonus = false, soloCharter = true })
		local brass = StopBank.remainder(bank, payout.brass, payout.xp)
		expect(bank.brass + brass).toBe(payout.brass)
	end)

	it("never takes Brass back", function()
		local bank = StopBank.new("run", 0)
		StopBank.grant(bank, 1, tally(1, 0), false)
		local brass, xp = StopBank.remainder(bank, 0, 0)
		expect(brass).toBe(0)
		expect(xp).toBe(0)
		expect(StopBank.remainder(nil, 7, 9)).toBe(7)
	end)
end)
