--!strict
--[[
	The stops' buildings, client side: the few lamps that still work in a dead building
	stutter and dip (each on its own rhythm, locally, so nothing goes over the wire). A chase
	dims them (VisibilityController.LightScale).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Registry = require(script.Parent.Parent.Registry)

local BuildingVisuals = {}

local lamps: { [PointLight]: number } = {}

local function add(instance: Instance)
	if instance:IsA("PointLight") then
		lamps[instance] = math.random() * 100
	end
end

function BuildingVisuals.Init() end

function BuildingVisuals.Start()
	for _, light in CollectionService:GetTagged("LTO_BuildingLamp") do
		add(light)
	end
	CollectionService:GetInstanceAddedSignal("LTO_BuildingLamp"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("LTO_BuildingLamp"):Connect(function(instance)
		lamps[instance :: PointLight] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local clock = os.clock()
		local scale = if Registry.VisibilityController then Registry.VisibilityController.LightScale() else 1
		for light, seed in lamps do
			local base = ((light:GetAttribute("Base") :: number?) or 0.8) * scale
			if light:GetAttribute("Flicker") then
				-- mostly on, with stutters and the odd long dip
				local hum = math.noise(clock * 7, seed)
				local dip = math.noise(clock * 0.6, seed + 31)
				local level = if dip < -0.3 then 0.1 elseif hum < -0.25 then 0.35 else 1
				light.Brightness = base * level
			elseif light.Brightness ~= base then
				light.Brightness = base
			end
		end
	end)
end

return BuildingVisuals
