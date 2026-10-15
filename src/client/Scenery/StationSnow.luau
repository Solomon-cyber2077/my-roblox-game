--!strict
--[[
	A thin sheet of snow over a docked station whose country has snow in it (a biome with
	snow-capped peaks: Mountain, Highland), client side only.

	  ground  every yard slab (Floor) gets a sheet a hair over its top, inset from its edges;
	          the platform (swept) and building foundations (indoors) stay bare
	  roofs   every pitched roof wedge gets a sheet along its slope

	Each sheet is welded to the part it lies on, so it goes down with a collapsing slab and
	away with the departing station. Under the Performance graphics setting nothing is laid.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Journey = require(Shared.Logic.Journey)
local Kit = require(Shared.Visual.Kit)

local Biomes = require(script.Parent.Biomes)

local StationSnow = {}

local SNOW = Color3.fromRGB(226, 230, 236)
local THICK = 0.08
local LIFT = 0.03 -- the sheet's underside over the surface it lies on
local INSET = 0.05 -- studs short of a slab's edges, so neighbouring sheets never touch
local ROOF = {
	[Enum.Material.Slate] = true,
	[Enum.Material.WoodPlanks] = true,
	[Enum.Material.CorrodedMetal] = true,
	[Enum.Material.Metal] = true,
}
local MIN_ROOF = 4 -- studs: smaller wedges are trim, not roofs

local function sheet(parent: Instance, on: BasePart, size: Vector3, cf: CFrame)
	local part =
		Kit.block(parent, size, cf, SNOW, { material = Enum.Material.Snow, collide = false, shadow = false })
	part.Name = "Snow"
	part.Anchored = false
	part.Massless = true
	Kit.weld(part, on)
end

function StationSnow.snowy(archetype: string): boolean
	return Biomes.get(Journey.biomeFor(archetype)).snowcap
end

function StationSnow.performance(): boolean
	return Players.LocalPlayer:GetAttribute("GraphicsQuality") == "Performance"
end

-- Lays the snow over `model` (a Station_<archetype>) into `parent`; returns how many sheets.
function StationSnow.dress(model: Model, archetype: string, parent: Instance): number
	if not StationSnow.snowy(archetype) or StationSnow.performance() then
		return 0
	end
	local count = 0
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") or part.Transparency > 0.5 then
			continue
		end
		if part.Name == "Top" and part:GetAttribute("SlabId") then
			if part:GetAttribute("SlabKind") == "Floor" then
				local s = part.Size
				sheet(
					parent,
					part,
					Vector3.new(s.X - 2 * INSET, THICK, s.Z - 2 * INSET),
					part.CFrame * CFrame.new(0, s.Y / 2 + LIFT + THICK / 2, 0)
				)
				count += 1
			end
		elseif part:IsA("WedgePart") and ROOF[part.Material] then
			local s = part.Size
			local slope = math.sqrt(s.Y * s.Y + s.Z * s.Z)
			-- the slope faces local (0, Z, -Y): up, and toward the low edge at -Z
			local normal = part.CFrame:VectorToWorldSpace(Vector3.new(0, s.Z, -s.Y) / slope)
			if s.X >= MIN_ROOF and slope >= MIN_ROOF and normal.Y > 0.3 then
				local tilt = CFrame.Angles(-math.atan2(s.Y, s.Z), 0, 0)
				sheet(
					parent,
					part,
					Vector3.new(s.X - 0.3, THICK, slope - 0.4),
					part.CFrame * tilt * CFrame.new(0, LIFT + THICK / 2, 0)
				)
				count += 1
			end
		end
	end
	return count
end

return StationSnow
