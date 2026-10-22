local Audio = require(Shared.Config.Audio)
local AudioPriority = require(Shared.Config.AudioPriority)

local function rankOf(groupName: string?): number?
	for rank, tier in AudioPriority.Tiers do
		if table.find(tier.groups, groupName) then
			return rank
		end
	end
	return nil
end

local function cueRank(name: string): number?
	local cue = Audio[name]
	local key = cue.group or cue.mix
	if key == "Outdoor" then
		key = "Ambience" -- Outdoor sits inside Ambience
	end
	return rankOf(key)
end

describe("The audio priority table", function()
	it("orders warnings, threat, feedback, ambience, then the lobby piano", function()
		local names = {}
		for _, tier in AudioPriority.Tiers do
			table.insert(names, tier.name)
		end
		expect(table.concat(names, ",")).toBe("Warnings,Threat,Feedback,Ambience,Piano")
	end)

	it("puts each named cue in its tier", function()
		for _, name in { "WarnTick", "WarnBell", "WarnWhistle", "WarnWhistleLong" } do
			expect(cueRank(name)).toBe(1)
		end
		for _, name in { "HollowSwipe", "HollowSlam", "HollowScream", "HollowWake", "DoorForce", "Heartbeat" } do
			expect(cueRank(name)).toBe(2)
		end
		for _, name in { "Hit", "Loot", "Deposit", "Click", "MenuClick", "Breath", "StepStone1" } do
			if Audio[name] then
				expect(cueRank(name)).toBe(3)
			end
		end
		for _, name in { "Drone", "Wind", "Rain", "TrainRun", "StationEerie", "DepotHall" } do
			expect(cueRank(name)).toBe(4)
		end
		expect(cueRank("LobbyPiano")).toBe(5)
	end)

	it("gives every cue's group or mix a home", function()
		for name, cue in Audio do
			local key = cue.group or cue.mix
			if key ~= nil then
				expect(cueRank(name) ~= nil).toBe(true)
			end
		end
	end)

	it("never caps warnings or threat, and hushes for 0.4 s", function()
		expect(AudioPriority.Tiers[1].voices).toBe(0)
		expect(AudioPriority.Tiers[2].voices).toBe(0)
		expect(AudioPriority.IntentHush.Seconds).toBe(0.4)
		expect(AudioPriority.IntentHush.Ambience).toBeLessThan(1)
		expect(AudioPriority.IntentHush.Steps).toBeLessThan(1)
	end)
end)
