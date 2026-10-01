local Ledger = require(Shared.Logic.Ledger)
local Tuning = require(Shared.Config.Tuning)

describe("Ledger", function()
	it("starts a run with the configured stores", function()
		local train = Ledger.newTrain()
		expect(train.coal).toBe(Tuning.Train.StartCoal)
		expect(train.parts).toBe(Tuning.Train.StartParts)
		expect(train.integrity).toBe(Tuning.Train.IntegrityMax)
	end)

	it("deposits coal, parts and relic Brass with a receipt", function()
		local train, receipt =
			Ledger.deposit(Ledger.newTrain(), { "CoalSack", "Scrap", "GearCrate", "SignalLamp" })
		expect(train.coal).toBe(Tuning.Train.StartCoal + 8)
		expect(train.parts).toBe(Tuning.Train.StartParts + 6)
		expect(receipt.relicBrass).toBe(20)
		expect(receipt.relics).toBe(1)
		expect(receipt.coalWasted).toBe(0)
	end)

	it("caps coal at the bunker size and reports waste", function()
		local train = Ledger.newTrain()
		train.coal = 96
		local after, receipt = Ledger.deposit(train, { "CoalSack" })
		expect(after.coal).toBe(100)
		expect(receipt.coal).toBe(4)
		expect(receipt.coalWasted).toBe(4)
	end)

	it("burns coal and flags starving at zero", function()
		local train = Ledger.newTrain()
		train = Ledger.burn(train, 12.5)
		expect(train.coal).toBeCloseTo(Tuning.Train.StartCoal - 12.5)
		expect(train.starving).toBe(false)
		train = Ledger.burn(train, 100)
		expect(train.coal).toBe(0)
		expect(train.starving).toBe(true)
		local refuelled = Ledger.deposit(train, { "CoalLump" })
		expect(refuelled.starving).toBe(false)
	end)

	it("drains integrity from breaches and starvation", function()
		local train = Ledger.openBreach(Ledger.newTrain(), "b1", "Car2", 0)
		train = Ledger.drain(train, 10)
		expect(train.integrity).toBeCloseTo(100 - 10 * Tuning.Train.BreachDrainPerSecond)
		train.starving = true
		local starving = Ledger.drain(train, 1)
		expect(starving.integrity).toBeCloseTo(
			train.integrity - Tuning.Train.BreachDrainPerSecond - Tuning.Train.StarvingDrainPerSecond
		)
	end)

	it("patches breaches for one part", function()
		local train = Ledger.openBreach(Ledger.newTrain(), "b1", "Car2", 0)
		local patched, ok = Ledger.patchBreach(train, "b1")
		expect(ok).toBe(true)
		expect(patched.parts).toBe(train.parts - 1)
		expect(Ledger.breachCount(patched)).toBe(0)
	end)

	it("buys upgrades level by level and refuses when short or maxed", function()
		local train = Ledger.newTrain()
		train.parts = 40
		local ok, reason
		train, ok = Ledger.buyUpgrade(train, "CoalBunker")
		expect(ok).toBe(true)
		expect(train.coalMax).toBe(125)
		expect(train.parts).toBe(35)
		train, ok = Ledger.buyUpgrade(train, "CoalBunker")
		expect(train.coalMax).toBe(150)
		train, ok, reason = Ledger.buyUpgrade(train, "CoalBunker")
		expect(ok).toBe(false)
		expect(reason).toBe("Maxed")
		train.parts = 2
		train, ok, reason = Ledger.buyUpgrade(train, "FireboxBaffles")
		expect(ok).toBe(false)
		expect(reason).toBe("Parts")
	end)

	it("prices legs with the firebox upgrade", function()
		local train = Ledger.newTrain()
		expect(Ledger.legCoalCost(train, 5)).toBe(10)
		train.upgrades.FireboxBaffles = 2
		expect(Ledger.legCoalCost(train, 5)).toBeCloseTo(7.2)
	end)

	it("patches the hull for five parts", function()
		local train = Ledger.newTrain()
		train.integrity = 50
		train.parts = 6
		local patched, ok = Ledger.hullPatch(train)
		expect(ok).toBe(true)
		expect(patched.integrity).toBe(70)
		expect(patched.parts).toBe(1)
	end)
end)
