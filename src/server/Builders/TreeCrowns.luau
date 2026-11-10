--!strict
--[[
	Station trees' crowns as meshes (Visual/Crowns has the why). Loads each crown in Config/TreeCrowns
	once on the server, swaps a station tree's balls for it, and shares a copy in
	ReplicatedStorage.TreeCrowns for the landscape (publish, at boot).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ids = require(ReplicatedStorage.Shared.Config.TreeCrowns)
local Crowns = require(ReplicatedStorage.Shared.Visual.Crowns)

local TreeCrowns = {}

local templates: { [string]: MeshPart } = {}
local failed: { [string]: boolean } = {}
local loading: { [string]: boolean } = {}

local function assets(): any?
	local ok, service = pcall(function()
		return game:GetService("AssetService")
	end)
	return if ok then service else nil
end

local function template(key: string): MeshPart?
	while loading[key] do
		task.wait()
	end
	if failed[key] or templates[key] then
		return templates[key]
	end
	local service = assets()
	if service == nil or Ids[key] == nil then
		failed[key] = true
		return nil
	end
	loading[key] = true
	local ok, made = pcall(function()
		return service:CreateMeshPartAsync(`rbxassetid://{Ids[key]}`)
	end)
	loading[key] = false
	if not ok or made == nil then
		warn(`TreeCrowns: {key} did not load: {made}`)
		failed[key] = true
		return nil
	end
	templates[key] = made :: MeshPart
	return made :: MeshPart
end

-- Swaps `balls` (the crown, first one the main mass) for the `key` mesh once it has loaded. `frame`
-- is the tree's own frame: the crown's box is measured along its axes.
function TreeCrowns.swap(balls: { BasePart }, frame: CFrame, key: string)
	if Ids[key] == nil or #balls == 0 or assets() == nil then
		return
	end
	task.spawn(function()
		local made = template(key)
		if made then
			Crowns.place(made, balls, frame)
		end
	end)
end

-- Loads every crown and shares a copy for the landscape (WorldService.Start).
function TreeCrowns.publish()
	if assets() == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = Crowns.FOLDER
	folder.Parent = ReplicatedStorage
	for key in Ids do
		task.spawn(function()
			local made = template(key)
			if made then
				local copy = made:Clone()
				copy.Name = key
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
				copy.Parent = folder
			end
		end)
	end
end

return TreeCrowns
