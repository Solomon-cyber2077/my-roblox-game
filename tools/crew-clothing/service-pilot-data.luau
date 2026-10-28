-- Isolated DataService fixture for the service pilot place.
-- This file is mapped twice in the pilot: as the fixture DataService and as
-- the mutable pilot CrewClothing config (the production config is frozen).
if script.Parent.Name == "Config" then
	local recipe = {
		id = "uniform_stoker",
		name = "Stoker",
		starter = true,
		shirt = 101979354774166,
		pants = 104204802579148,
		wornShirt = 90317117594409,
		wornPants = 100087790691733,
		validated = true,
		accessories = {
			{
				name = "Gear",
				mesh = 90362864770621,
				texture = 85553773814164,
				limb = "Torso",
				size = { 1.625, 1.83, 0.231 },
				offset = { 0.0425, 0.065, -0.6155 },
				yaw = 180,
				triangles = 372,
			},
		},
	}
	-- Copy the production config so the full catalog (award uniforms, records) still loads,
	-- then swap in the validated Stoker pilot recipe.
	local base = require(script.Parent:FindFirstChild("CrewClothingProduction") :: ModuleScript) :: any
	local list = {}
	local byId = {}
	for _, entry in base.List do
		local chosen = entry
		if entry.id == recipe.id then
			chosen = table.clone(entry)
			for key, value in recipe do
				chosen[key] = value
			end
		end
		table.insert(list, chosen)
		byId[chosen.id] = chosen
	end
	local config = table.clone(base)
	config.Enabled = true
	config.WearEnabled = false
	config.List = list
	config.ById = byId
	return config
end

local DataService = {}

local profiles = {}

local profileChanged = Instance.new("BindableEvent")
local profileLoaded = Instance.new("BindableEvent")
DataService.ProfileChanged = profileChanged.Event
DataService.ProfileLoaded = profileLoaded.Event

function DataService.GetProfile(player)
	return profiles[player]
end

function DataService.SetProfile(player, profile)
	profiles[player] = profile
	profileLoaded:Fire(player)
end

function DataService.ClearProfile(player)
	profiles[player] = nil
end

return DataService
