local NpcSave = require(Shared.Logic.NpcSave)
local Npcs = require(Shared.Config.Npcs)

describe("NpcSave", function()
	it("is schema version 2", function()
		expect(NpcSave.VERSION).toBe(2)
	end)

	it("has an entry for every enabled resident and none for reserved ones", function()
		local defaults = NpcSave.defaults()
		for _, id in Npcs.Order do
			if Npcs.List[id].enabled then
				expect(defaults[id].stage).toBe(1)
			else
				expect(defaults[id]).toBe(nil)
			end
		end
	end)

	it("migrates a version 1 profile without touching the rest", function()
		local v1 = { version = 1, brass = 120, owned = { hat_conductor = true } }
		NpcSave.migrate(v1)
		expect(v1.brass).toBe(120)
		expect(v1.owned.hat_conductor).toBe(true)
		expect(v1.npcs.Mabel.stage).toBe(1)
		expect(v1.npcs.Mabel.seen).toEqual({})
	end)

	it("repairs damaged entries and keeps unknown keys", function()
		local profile: any = {
			npcs = {
				Mabel = {
					stage = -3,
					done = "oops",
					seen = { mabel_greeting = true },
					failed = 7,
					extra = "keep me",
				},
				Pip = { stage = 2, done = {}, choices = {}, seen = {} }, -- written by a later build
				Someone = { anything = true },
			},
		}
		NpcSave.migrate(profile)
		local mabel = profile.npcs.Mabel
		expect(mabel.stage).toBe(1)
		expect(mabel.done).toEqual({})
		expect(mabel.seen.mabel_greeting).toBe(true)
		expect(mabel.failed).toBe(nil)
		expect(mabel.extra).toBe("keep me")
		expect(profile.npcs.Pip.stage).toBe(2)
		expect(profile.npcs.Someone.anything).toBe(true)
	end)

	it("replaces a corrupt npcs table", function()
		local profile: any = { npcs = 5 }
		NpcSave.migrate(profile)
		expect(profile.npcs.Mabel.stage).toBe(1)
	end)

	it("is idempotent", function()
		local profile: any =
			{ npcs = { Mabel = { stage = 3, done = { MabelLuggage = true }, choices = {}, seen = {} } } }
		NpcSave.migrate(profile)
		NpcSave.migrate(profile)
		expect(profile.npcs.Mabel.stage).toBe(3)
		expect(profile.npcs.Mabel.done.MabelLuggage).toBe(true)
	end)

	it("only produces values a DataStore can hold", function()
		local profile: any = { brass = 0, npcs = NpcSave.defaults() }
		profile.npcs.Mabel.stage = 3
		profile.npcs.Mabel.done.MabelLuggage = true
		profile.npcs.Mabel.seen.mabel_greeting = true
		profile.npcs.Mabel.failed = "MabelNames"
		profile.npcs.Mabel.choices.manifest = "Signed"
		expect(NpcSave.isStorable(profile)).toBe(true)
	end)

	it("rejects values a DataStore would mangle", function()
		expect(NpcSave.isStorable({ 1, 2, nil, 4 } :: any)).toBe(false)
		expect(NpcSave.isStorable({ [1] = "a", b = "c" } :: any)).toBe(false)
		expect(NpcSave.isStorable({ x = 0 / 0 })).toBe(false)
		expect(NpcSave.isStorable({ f = print } :: any)).toBe(false)
		local loop: any = {}
		loop.self = loop
		expect(NpcSave.isStorable(loop)).toBe(false)
	end)
end)
