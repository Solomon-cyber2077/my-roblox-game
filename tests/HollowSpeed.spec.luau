local fs = require("@lune/fs")

local DifficultyModel = require(Shared.Logic.DifficultyModel)
local Haul = require(Shared.Config.Haul)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

-- The speeds MovementController actually gives the crew: it must read them from Tuning.Crew.
local function crewSpeeds(): (number, number)
	local source = fs.readFile("src/client/Controllers/MovementController.luau")
	assert(
		string.find(source, "local base = if sprinting then crew.SprintSpeed else crew.WalkSpeed", 1, true),
		"MovementController no longer sets speed from crew.SprintSpeed / crew.WalkSpeed"
	)
	assert(
		string.find(source, "local crew = Tuning.Crew", 1, true),
		"MovementController's crew is not Tuning.Crew"
	)
	return Tuning.Crew.WalkSpeed, Tuning.Crew.SprintSpeed
end

describe("Hollow speed", function()
	it("stays below sprint, while haul speeds preserve the chase-distance rules", function()
		local walk, sprint = crewSpeeds()
		local duo = walk * (1 - Haul.DuoPenalty)
		local solo = walk * (1 - Haul.SoloPenalty)
		local spread = Tuning.Hollow.PaceSpread
		local halt = Stations.List.Halt
		local slowestChase = math.huge
		for _, d in { 0, 0.25, 0.5, 0.75, 1 } do
			local params = DifficultyModel.params(d, halt, 1, nil)
			for name, kind in Tuning.HollowKinds do
				for _, pace in { 1 - spread, 1 + spread } do
					local chase = params.hollowChase * kind.chase * pace
					if chase >= sprint then
						error(`{name} at D {d} chases at {chase}, not below the sprint ({sprint})`)
					end
					slowestChase = math.min(slowestChase, chase)
					if chase <= solo then
						error(`{name} at D {d} chases at {chase}, not above the solo carry speed ({solo})`)
					end
				end
			end
		end
		if duo <= slowestChase then
			error(`duo carry speed ({duo}) cannot hold distance from the slowest Hollow ({slowestChase})`)
		end
	end)
end)
