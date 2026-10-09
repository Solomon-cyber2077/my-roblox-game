local NpcQuest = require(Shared.Logic.NpcQuest)
local Quests = require(Shared.Config.NpcQuests)
local Npcs = require(Shared.Config.Npcs)

describe("NpcQuest", function()
	it("takes the run's errand from the crew's lowest unfinished stage", function()
		expect(NpcQuest.runStage({ 3, 1, 2 }, 3)).toBe(1)
		expect(NpcQuest.runStage({ 4, 2 }, 3)).toBe(2)
		expect(NpcQuest.runStage({ 4, 4 }, 3)).toBe(nil)
		expect(NpcQuest.runStage({}, 3)).toBe(nil)
	end)

	it("starts Mabel's chain in order and offers nothing once it is finished", function()
		expect((NpcQuest.start("Mabel", { 1 }) :: any).quest).toBe("MabelLuggage")
		expect((NpcQuest.start("Mabel", { 3, 2 }) :: any).quest).toBe("MabelNames")
		expect((NpcQuest.start("Mabel", { 3 }) :: any).quest).toBe("MabelManifest")
		expect(NpcQuest.start("Mabel", { 4, 4 })).toBe(nil)
	end)

	it("never starts errands for reserved residents", function()
		expect(NpcQuest.start("Pip", { 1 })).toBe(nil)
		expect(NpcQuest.start("Conductor", { 1 })).toBe(nil)
		expect(NpcQuest.start("Nobody", { 1 })).toBe(nil)
	end)

	it("moves Offered -> Active -> Done and fails only what is unfinished", function()
		local rq = NpcQuest.start("Mabel", { 1 }) :: any
		expect(rq.status).toBe("Offered")
		NpcQuest.accept(rq)
		expect(rq.status).toBe("Active")
		NpcQuest.complete(rq)
		NpcQuest.finish(rq)
		expect(rq.status).toBe("Done")

		local missed = NpcQuest.start("Mabel", { 2 }) :: any
		NpcQuest.accept(missed)
		NpcQuest.finish(missed)
		expect(missed.status).toBe("Failed")
		NpcQuest.complete(missed)
		expect(missed.status).toBe("Failed")
	end)

	it("hides a Find item only while active, unfound and within its stops", function()
		local rq = NpcQuest.start("Mabel", { 1 }) :: any
		expect(NpcQuest.shouldSpawn(rq, 1)).toBe(false) -- nobody has taken it on yet
		NpcQuest.accept(rq)
		expect(NpcQuest.shouldSpawn(rq, 1)).toBe(true)
		expect(NpcQuest.shouldSpawn(rq, 3)).toBe(true)
		expect(NpcQuest.shouldSpawn(rq, 4)).toBe(false)
		rq.found = true
		expect(NpcQuest.shouldSpawn(rq, 2)).toBe(false)
		expect(NpcQuest.canDeliver(rq, true)).toBe(true)
		expect(NpcQuest.canDeliver(rq, false)).toBe(false)
	end)

	it("completes the Survive errand at the Terminus, not a Find", function()
		local find = NpcQuest.start("Mabel", { 1 }) :: any
		local survive = NpcQuest.start("Mabel", { 3 }) :: any
		expect(NpcQuest.completesAtTerminus(find)).toBe(false)
		expect(NpcQuest.completesAtTerminus(survive)).toBe(true)
		expect(NpcQuest.shouldSpawn(NpcQuest.accept(survive), 5)).toBe(false)
	end)

	it("advances players at the errand's stage and pays helpers a little", function()
		local rq = NpcQuest.start("Mabel", { 2, 3, 4 }) :: any
		local story = NpcQuest.credit(rq, 2, 10)
		expect(story.advance).toBe(true)
		expect(story.brass).toBe(Quests.MabelNames.brass)
		local ahead = NpcQuest.credit(rq, 4, 10)
		expect(ahead.advance).toBe(false)
		expect(ahead.brass).toBe(10)
		local joinerBehind = NpcQuest.credit(rq, 1, 10)
		expect(joinerBehind.advance).toBe(false)
	end)

	it("keeps errand rewards inside the agreed 20-40 Brass band", function()
		for _, quest in Quests do
			expect(quest.brass).toBeBetween(20, 40)
			expect(Npcs.List[quest.npc]).toBeTruthy()
		end
	end)

	it("tells the tracker what to do next", function()
		local rq = NpcQuest.start("Mabel", { 1 }) :: any
		expect(NpcQuest.trackerText(rq)).toBe("Talk to Mabel Orrin.")
		NpcQuest.accept(rq)
		expect(NpcQuest.trackerText(rq)).toBe(Quests.MabelLuggage.brief)
		rq.found = true
		expect(NpcQuest.trackerText(rq)).toBe(Quests.MabelLuggage.carried)
	end)
end)
