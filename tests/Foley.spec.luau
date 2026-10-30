local Audio = require(Shared.Config.Audio)
local Foley = require(Shared.Logic.Foley)
local Items = require(Shared.Config.Items)

describe("Handling sounds", function()
	it("gives coal, parts and relics a sound of their own", function()
		expect(Foley.pickup("CoalSack")).toBe("PickupCoal")
		expect(Foley.pickup("Scrap")).toBe("PickupParts")
		expect(Foley.pickup("Tonic")).toBe("Loot") -- a tool keeps the plain sound
		expect(Foley.pickup("NoSuchItem")).toBe("Loot")
		for id, def in Items do
			if def.kind == "Relic" and (def.coal or 0) == 0 and (def.parts or 0) == 0 then
				expect(Foley.pickup(id)).toBe("PickupRelic")
			end
		end
	end)

	it("pours coal and tips parts, coal first, and nothing for an empty delivery", function()
		expect(table.concat(Foley.deposit(4, 2), ",")).toBe("DepositCoal,DepositParts")
		expect(table.concat(Foley.deposit(0, 3), ",")).toBe("DepositParts")
		expect(#Foley.deposit(0, 0)).toBe(0)
	end)

	it("has a cue for every sound it can pick, each kept from repeating in a burst", function()
		for _, name in
			{
				"PickupCoal",
				"PickupParts",
				"PickupRelic",
				"DepositCoal",
				"DepositParts",
				"Deny",
				"PromptShow",
				"ModalOpen",
				"ModalClose",
			}
		do
			expect(Audio[name] ~= nil).toBe(true)
			expect((Audio[name].gap or 0) > 0).toBe(true)
		end
	end)

	it("keeps a pack of Hollows and a collapsing yard from filling the mix", function()
		expect(Audio.HollowStep.voices).toBe(3)
		expect(Audio.HollowScrabble.voices ~= nil and Audio.HollowScrabble.gap ~= nil).toBe(true)
		expect(Audio.Collapse.voices ~= nil and Audio.Collapse.gap ~= nil).toBe(true)
		expect(Audio.Rumble.voices ~= nil and Audio.Rumble.gap ~= nil).toBe(true)
	end)

	it("gives each event its own recording where one was doing six jobs", function()
		local heartbeat = Audio.Heartbeat.id
		expect(Audio.Hit.id ~= heartbeat).toBe(true)
		expect(Audio.Winded.id ~= heartbeat).toBe(true)
		expect(Audio.HollowSlam.id ~= Audio.Rumble.id).toBe(true)
	end)

	it(
		"has a cue for the life aboard, at the stops, the lantern, the tool in hand and the crew pass",
		function()
			for _, name in
				{
					"CarCreak1",
					"CarCreak2",
					"CupRattle",
					"ChainCreak",
					"CrowCall",
					"CrowCall2",
					"LanternRattle",
					"ItemEquip",
					"ItemStow",
					"XpTick",
					"RankUp",
				}
			do
				expect(Audio[name] ~= nil).toBe(true)
			end
			expect(Audio.PingWhistle.with).toBe("LanternRattle")
			expect(Audio.HollowBreath.loop).toBe(true)
			expect(Audio.HollowBreath.mix).toBe("Cues")
		end
	)

	it("gives every Hollow kind a breath of its own and keeps the timings sane", function()
		local Tuning = require(Shared.Config.Tuning)
		local Timing = require(Shared.Config.Foley)
		for kind in Tuning.HollowKinds do
			expect(Timing.BreathPitch[kind] ~= nil).toBe(true)
		end
		expect(Timing.BreathPitch.Brute).toBeLessThan(Timing.BreathPitch.Stalker)
		expect(Timing.BreathPitch.Stalker).toBeLessThan(Timing.BreathPitch.Crawler)
		for _, range in { Timing.CreakEvery, Timing.ChainEvery, Timing.ChainRange } do
			expect(range[1]).toBeLessThan(range[2])
		end
		expect(Timing.XpTicks > 0 and Timing.XpTickSeconds > 0).toBe(true)
	end)
end)
