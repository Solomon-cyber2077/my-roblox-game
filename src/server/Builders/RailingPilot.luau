--!strict
--[[
	Performance train pilot: a low-part stand-in for the guard's van veranda balustrade,
	which is baked into the GuardsVanFittings mesh (top brass rail, mid and bottom rails,
	about 41 four-sided balusters every 0.42 studs and 14 knobs, roughly 1000 triangles;
	the balusters shimmer from a distance). Built once into
	ServerStorage.PerformanceTrain_Pilot at the run train's position, so it can be dragged
	into Workspace to compare. Nothing in the game uses it; the live railing is untouched.
	Each run of railing: three rails, two end posts and one see-through infill panel that
	reads as the balusters from afar, all plain blocks (12 triangles each).
]]

local ServerStorage = game:GetService("ServerStorage")

local Kit = require(game:GetService("ReplicatedStorage").Shared.Visual.Kit)

local RailingPilot = {}

local BRASS = Color3.fromRGB(150, 120, 74)
local IRON = Color3.fromRGB(58, 58, 62)
local DECK = -96 -- the veranda deck's far end (train x)
local VAN_X0 = -90 -- the van's rear wall
local SIDE_Z = -6.25 -- the far side's rail line
local RAILS = {
	{ y = 3.2, t = 0.13, color = BRASS },
	{ y = 1.75, t = 0.08, color = IRON },
	{ y = 0.3, t = 0.1, color = IRON },
}
local INFILL_T = 0.05
local INFILL_SEE = 0.55 -- the balusters cover about half the gap from a distance

-- One straight run from a to b (train space, both on the floor) at rail heights.
local function run(folder: Folder, origin: CFrame, a: Vector3, b: Vector3, name: string)
	local length = (b - a).Magnitude
	local frame = origin * Kit.between(a, b) -- -Z along the run
	local opts = { material = Enum.Material.Metal, collide = false, shadow = false }
	for i, rail in RAILS do
		local part = Kit.block(
			folder,
			Vector3.new(rail.t, rail.t, length),
			frame * CFrame.new(0, rail.y, 0),
			rail.color,
			opts
		)
		part.Name = `{name}Rail{i}`
		part.CanQuery = false
		part.CanTouch = false
	end
	for i, dz in { -length / 2, length / 2 } do
		local post =
			Kit.block(folder, Vector3.new(0.12, 3.0, 0.12), frame * CFrame.new(0, 1.75, dz), IRON, opts)
		post.Name = `{name}Post{i}`
		post.CanQuery = false
		post.CanTouch = false
	end
	local infill = Kit.block(
		folder,
		Vector3.new(INFILL_T, 2.9, length),
		frame * CFrame.new(0, 1.75, 0),
		IRON,
		{ material = Enum.Material.Metal, collide = false, shadow = false, transparency = INFILL_SEE }
	)
	infill.Name = `{name}Infill`
	infill.CanQuery = false
	infill.CanTouch = false
end

function RailingPilot.build(origin: CFrame)
	if ServerStorage:FindFirstChild("PerformanceTrain_Pilot") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "PerformanceTrain_Pilot"
	local rearX = DECK + 0.15
	run(folder, origin, Vector3.new(rearX, 0, -5.95), Vector3.new(rearX, 0, 5.95), "Rear")
	run(folder, origin, Vector3.new(DECK + 0.6, 0, SIDE_Z), Vector3.new(VAN_X0 - 0.3, 0, SIDE_Z), "Side")
	folder.Parent = ServerStorage
end

return RailingPilot
