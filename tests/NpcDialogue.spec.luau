local NpcDialogue = require(Shared.Logic.NpcDialogue)
local Npcs = require(Shared.Config.Npcs)

local function ctx(overrides: { [string]: any }?): any
	local base: { [string]: any } = {
		inRun = false,
		travelling = false,
		status = nil,
		quest = nil,
		stage = 1,
		failed = false,
		flags = {},
		choices = {},
		seen = {},
		heardThisRun = {},
		talks = 0,
	}
	for key, value in overrides or {} do
		base[key] = value
	end
	return base
end

local lines = Npcs.List.Mabel.lines

local function pick(overrides: { [string]: any }?): string
	local line = NpcDialogue.pick(lines, ctx(overrides))
	return if line then line.id else "none"
end

describe("NpcDialogue", function()
	it("gives every enabled resident exactly 15 distinct lines covering every topic", function()
		for _, id in Npcs.Order do
			local def = Npcs.List[id]
			if def.enabled then
				expect(#def.lines).toBe(15)
				local ids, texts, topics = {}, {}, {}
				for _, line in def.lines do
					expect(ids[line.id]).toBe(nil)
					expect(texts[line.text]).toBe(nil)
					ids[line.id], texts[line.text], topics[line.topic] = true, true, true
				end
				for _, topic in NpcDialogue.REQUIRED_TOPICS do
					expect(topics[topic]).toBe(true)
				end
			end
		end
	end)

	it("greets a stranger once, then moves to small talk", function()
		expect(pick()).toBe("mabel_greeting")
		expect(pick({ seen = { mabel_greeting = true } })).toBe("mabel_smalltalk")
	end)

	it("offers the run's errand first, matched to the errand, not the player's stage", function()
		expect(pick({ inRun = true, status = "Offered", quest = "MabelLuggage", stage = 3 })).toBe(
			"mabel_offer_luggage"
		)
		expect(pick({ inRun = true, status = "Offered", quest = "MabelNames", stage = 2 })).toBe(
			"mabel_offer_names"
		)
	end)

	it("says each errand and run-state line once per run", function()
		local heard = { mabel_greeting = true }
		local seen = { mabel_greeting = true }
		local c =
			{ inRun = true, status = "Active", quest = "MabelLuggage", seen = seen, heardThisRun = heard }
		expect(pick(c)).toBe("mabel_active")
		heard.mabel_active = true
		expect(pick(c)).toBe("mabel_smalltalk")
	end)

	it("reacts to run state in priority order", function()
		local flags = { CrewDown = true, LowSupplies = true, NearTerminus = true }
		local seen = { mabel_greeting = true }
		expect(pick({ inRun = true, flags = flags, seen = seen })).toBe("mabel_down")
		expect(pick({ inRun = true, flags = flags, seen = seen, heardThisRun = { mabel_down = true } })).toBe(
			"mabel_low"
		)
		expect(pick({ inRun = true, flags = { Danger = true }, seen = seen })).toBe("mabel_danger")
		expect(pick({ inRun = true, flags = { CloseCall = true }, seen = seen })).toBe("mabel_closecall")
		expect(pick({ inRun = true, flags = { NearTerminus = true }, seen = seen })).toBe("mabel_terminus")
	end)

	it("celebrates a finished errand before anything else", function()
		expect(pick({ inRun = true, status = "Done", flags = { CrewDown = true } })).toBe("mabel_done")
	end)

	it("remembers a failed errand from an earlier run, in the lobby", function()
		expect(pick({ failed = true, seen = { mabel_greeting = true } })).toBe("mabel_failed")
	end)

	it("unlocks lore only with story progress and after the small talk was heard", function()
		local seen = { mabel_greeting = true, mabel_smalltalk = true }
		local function pool(stage: number, s: { [string]: boolean }): { [string]: boolean }
			local out = {}
			for talks = 0, 5 do
				out[pick({ stage = stage, seen = s, talks = talks })] = true
			end
			return out
		end
		expect(pool(1, seen).mabel_lore).toBe(nil)
		expect(pool(2, { mabel_greeting = true }).mabel_lore).toBe(nil)
		expect(pool(2, seen).mabel_lore).toBe(true)
	end)

	it("gives stop hints only between stops", function()
		local seen = { mabel_greeting = true, mabel_smalltalk = true }
		expect(pick({ inRun = true, travelling = true, seen = seen })).toBe("mabel_hint")
		expect(pick({ inRun = true, travelling = false, seen = seen })).toBe("mabel_smalltalk")
	end)

	it("filters lines by a recorded story choice", function()
		local custom = {
			{ id = "keep", topic = "Recall", text = "kept", when = { choice = { "fuel", "Keep" } } },
			{ id = "burn", topic = "Recall", text = "burnt", when = { choice = { "fuel", "Burn" } } },
		}
		local c = ctx({ choices = { fuel = "Burn" } })
		expect((NpcDialogue.pick(custom :: any, c) :: any).id).toBe("burn")
		expect(NpcDialogue.pick(custom :: any, ctx())).toBe(nil)
	end)
end)
