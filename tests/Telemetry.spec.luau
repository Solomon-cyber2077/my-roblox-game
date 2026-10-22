local Config = require(Shared.Config.Telemetry)
local Telemetry = require(Shared.Logic.Telemetry)

describe("Telemetry vocabulary", function()
	it("keeps every event under Roblox's field-combination limit", function()
		for name in Config.Events do
			expect(Telemetry.combinations(name)).toBeLessThan(Config.MaxCombinations)
		end
	end)

	it("declares every Prompt 0 event and the A.4 additions", function()
		for _, name in
			{
				"run_started",
				"run_joined",
				"stop_resolved",
				"stop_archetype",
				"stop_timing",
				"player_stop_resolved",
				"player_eliminated",
				"tell_exposure",
				"tell_cohort",
				"grasp",
				"grasp_shortfall",
				"run_ended",
				"run_progress",
				"player_run_outcome",
				"player_progress",
				"again_pressed",
				"session_ended",
				"quit_after_outcome",
				"first_session_timing",
				"cohort_assigned",
				"invite_prompted",
			}
		do
			expect(Config.Events[name] ~= nil).toBe(true)
		end
	end)

	it("names a real vocabulary for every used slot, and freezes it", function()
		for _, def in Config.Events do
			expect(#def.fields).toBe(3)
			for _, vocab in def.fields do
				if vocab then
					local values = (Config.Vocab :: any)[vocab]
					expect(values ~= nil).toBe(true)
					expect(table.isfrozen(values)).toBe(true)
				end
			end
		end
	end)

	it("puts runTier on run_started and route length on run_progress", function()
		expect(Config.Events.run_started.fields[2]).toBe("RunTier")
		expect(Config.Events.run_progress.fields[3]).toBe("RouteLength")
	end)
end)

describe("Telemetry.check", function()
	it("accepts fields from the vocabulary", function()
		expect((Telemetry.check("run_started", { "4", "1", "0" }))).toBe(true)
		expect((Telemetry.check("player_eliminated", { "Taken", "3", "Crawler" }))).toBe(true)
	end)

	it("rejects unknown events, values outside the list and missing fields", function()
		expect((Telemetry.check("run_begun", { "4", "1", "0" }))).toBe(false)
		expect((Telemetry.check("run_started", { "5", "1", "0" }))).toBe(false)
		expect((Telemetry.check("player_eliminated", { "Eaten", "3", "none" }))).toBe(false)
		expect((Telemetry.check("stop_resolved", { "2", "cleared" }))).toBe(false)
	end)

	it("checks funnel steps by position and name", function()
		expect((Telemetry.checkFunnel("onboarding", 1, "joined"))).toBe(true)
		expect((Telemetry.checkFunnel("onboarding", 2, "first_off_train"))).toBe(false)
		expect((Telemetry.checkFunnel("replay", 2, "second_run_started"))).toBe(true)
		expect((Telemetry.checkFunnel("nope", 1, "joined"))).toBe(false)
	end)
end)

describe("Telemetry buckets", function()
	it("splits run minutes at 20, 30, 40 and 50, edges going up", function()
		expect(Telemetry.runDuration(0)).toBe("<20")
		expect(Telemetry.runDuration(19.99)).toBe("<20")
		expect(Telemetry.runDuration(20)).toBe("20-30")
		expect(Telemetry.runDuration(39.5)).toBe("30-40")
		expect(Telemetry.runDuration(40)).toBe("40-50")
		expect(Telemetry.runDuration(50)).toBe("50+")
	end)

	it("splits doors-open seconds at 90, 150 and 210", function()
		expect(Telemetry.doorsOpen(89.9)).toBe("<90")
		expect(Telemetry.doorsOpen(90)).toBe("90-150")
		expect(Telemetry.doorsOpen(150)).toBe("150-210")
		expect(Telemetry.doorsOpen(210)).toBe("210+")
	end)

	it("keeps a zero tell apart from a short one", function()
		expect(Telemetry.tell(0)).toBe("0")
		expect(Telemetry.tell(0.01)).toBe("0-1.5")
		expect(Telemetry.tell(1.5)).toBe("1.5-3")
		expect(Telemetry.tell(3)).toBe("3+")
	end)

	it("buckets seconds left and crewmates near", function()
		expect(Telemetry.secondsLeft(0.5)).toBe("<1")
		expect(Telemetry.secondsLeft(1)).toBe("1-2")
		expect(Telemetry.secondsLeft(2)).toBe("2+")
		expect(Telemetry.crewNear(0)).toBe("0")
		expect(Telemetry.crewNear(1)).toBe("1")
		expect(Telemetry.crewNear(3)).toBe("2+")
	end)

	it("never invents a stop number", function()
		expect(Telemetry.stop(nil)).toBe("pre")
		expect(Telemetry.stop(0)).toBe("pre")
		expect(Telemetry.stop(3)).toBe("3")
		expect(Telemetry.stop(11, 10)).toBe("terminus")
		expect(table.find(Config.Vocab.Stop, "between") ~= nil).toBe(true)
		expect(table.find(Config.Vocab.Stop, "village") ~= nil).toBe(true)
	end)

	it("puts every bucket output in its vocabulary", function()
		for _, minutes in { 0, 25, 35, 45, 90 } do
			expect(table.find(Config.Vocab.RunDuration, Telemetry.runDuration(minutes)) ~= nil).toBe(true)
		end
		for _, seconds in { 0, 0.4, 2, 9 } do
			expect(table.find(Config.Vocab.TellBucket, Telemetry.tell(seconds)) ~= nil).toBe(true)
		end
		for n = 0, 12 do
			expect(table.find(Config.Vocab.Stop, Telemetry.stop(n)) ~= nil).toBe(true)
		end
	end)
end)

describe("Telemetry device", function()
	local base = { touch = false, keyboard = false, mouse = false, gamepad = false, tenFoot = false }

	local function with(changes: { [string]: any }): any
		local input = table.clone(base) :: any
		for key, value in changes do
			input[key] = value
		end
		return input
	end

	it("reads phones, tablets, desktops and consoles", function()
		expect(Telemetry.classify(with({ touch = true, shortSide = 390 }))).toBe("phone")
		expect(Telemetry.classify(with({ touch = true, shortSide = 820 }))).toBe("tablet")
		expect(Telemetry.classify(with({ keyboard = true, mouse = true }))).toBe("desktop")
		expect(Telemetry.classify(with({ touch = true, keyboard = true }))).toBe("desktop")
		expect(Telemetry.classify(with({ tenFoot = true, gamepad = true }))).toBe("console")
		expect(Telemetry.classify(base)).toBe("unknown")
	end)

	it("validates a client's report against the list", function()
		expect(Telemetry.device("phone")).toBe("phone")
		expect(Telemetry.device("toaster")).toBe("unknown")
		expect(Telemetry.device(nil)).toBe("unknown")
		expect(Telemetry.device(7)).toBe("unknown")
	end)
end)
