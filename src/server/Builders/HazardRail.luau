--!strict
--[[
	A hazard rail along a station's far edge, where the ground drops into the sinkhole
	(fix pass part 2, C.5: the first stop only, a stand-in until part 3's proper edge).

	Yellow-and-black striped posts every POST_GAP studs with a yellow top rail and a red mid
	rail, a painted hazard line on the ground in front of it, all EDGE_BACK studs in from the
	far edge (inside the boundary fence and its trees). Only over Floor slabs: a building's
	foundation makes its own edge. Every piece is welded to the slab under it, so it goes
	down with the ground. The top rails carry the SinkholeEdge tag the tutorial's "edge"
	prompt looks for (Config/Tutorial EdgeTag).

	Build it after StationBuilder.build and before the station moves (the parts are welded
	unanchored, like the rest of the station).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tutorial = require(Shared.Config.Tutorial)
local Kit = require(Shared.Visual.Kit)
local LayoutGen = require(Shared.Logic.LayoutGen)

local StationBuilder = require(script.Parent.StationBuilder)

local HazardRail = {}

local POST_GAP = 8
local EDGE_BACK = 4.5 -- studs in from the far edge
local HEIGHT = 3.4
local YELLOW = Color3.fromRGB(226, 182, 58)
local BLACK = Color3.fromRGB(26, 24, 22)
local RED = Color3.fromRGB(170, 40, 32)

local function fix(part: BasePart, base: BasePart)
	part.Anchored = false
	Kit.weld(part, base)
end

-- `docked` is the station frame the builder used (StationService DOCKED).
function HazardRail.build(built: StationBuilder.Built, plan: LayoutGen.Plan, docked: CFrame): Model
	local model = Kit.model("HazardRail", built.model)
	local z = plan.depth - EDGE_BACK
	local half = plan.length / 2 - 2
	local function L(x: number, y: number): CFrame
		return docked * CFrame.new(x, y, z)
	end
	local function slabUnder(x: number): BasePart?
		local slab = LayoutGen.slabAt(plan, x, z)
		if slab == nil or slab.kind ~= "Floor" then
			return nil
		end
		return built.slabParts[slab.id]
	end
	local posted: { [number]: boolean } = {} -- a post shared by two lengths of rail is built once
	local x = -half
	while x + POST_GAP <= half + 1e-6 do
		local a, b = x, x + POST_GAP
		local baseA, baseB = slabUnder(a), slabUnder(b)
		if baseA and baseB then
			for _, px in { a, b } do
				if posted[px] then
					continue
				end
				posted[px] = true
				local base = if px == a then baseA else baseB
				fix(Kit.post(model, HEIGHT, 0.4, L(px, HEIGHT / 2), YELLOW, { name = "HazardPost" }), base)
				for band = 1, 2 do
					fix(Kit.post(model, 0.45, 0.44, L(px, band * 1.1), BLACK, { collide = false }), base)
				end
			end
			local top = Kit.block(
				model,
				Vector3.new(POST_GAP, 0.28, 0.28),
				L((a + b) / 2, HEIGHT - 0.2),
				YELLOW,
				{ name = "HazardRailTop" }
			)
			top:AddTag(Tutorial.EdgeTag)
			fix(top, baseA)
			fix(
				Kit.block(model, Vector3.new(POST_GAP, 0.22, 0.22), L((a + b) / 2, HEIGHT * 0.5), RED, {}),
				baseA
			)
			-- the painted line in front of the rail, on the train's side
			fix(
				Kit.block(
					model,
					Vector3.new(POST_GAP, 0.06, 0.7),
					docked * CFrame.new((a + b) / 2, 0.03, z - 1.4),
					YELLOW,
					{ collide = false, shadow = false }
				),
				baseA
			)
		end
		x = b
	end
	return model
end

return HazardRail
