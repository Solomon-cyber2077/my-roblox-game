--!strict
--[[
	Blender props (Config/HallProps: tools/hallwear/build.py's meshes, each on its own base, centred)
	standing in for part-built ones: give a cluster of parts and where each mesh stands, and once
	every mesh in the list has an id and loads, the meshes replace the visible parts while the
	colliding parts stay on, invisible, as the props' room. Anything missing or failing keeps the
	parts (in a headless build there is no AssetService at all).

	The same swap as Builders/HallWear's, for props elsewhere (the train's saloon, Builders/
	TrainInterior). `placed` keeps each mesh's stand while `recording` (`lune run preview` sets it).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HallProps = require(ReplicatedStorage.Shared.Config.HallProps)

local PropMeshes = {}

export type Placed = { key: string, cframe: CFrame, scale: number }

PropMeshes.placed = {} :: { Placed }
PropMeshes.recording = false

local function assets(): any?
	local ok, service = pcall(function()
		return game:GetService("AssetService")
	end)
	return if ok then service else nil
end

function PropMeshes.dress(cluster: Model, list: { Placed })
	cluster:SetAttribute("Meshed", true) -- these parts give way to meshes (and the preview drops them)
	if PropMeshes.recording then
		for _, item in list do
			table.insert(PropMeshes.placed, item)
		end
	end
	for _, item in list do
		if HallProps[item.key] == nil then
			return
		end
	end
	local service = assets()
	if service == nil then
		return
	end
	task.spawn(function()
		local meshes: { MeshPart } = {}
		for _, item in list do
			local asset = HallProps[item.key]
			local ok, made = pcall(function()
				return service:CreateMeshPartAsync(`rbxassetid://{asset.mesh}`)
			end)
			if not ok or made == nil then
				warn(`PropMeshes: {item.key} did not load: {made}`)
				for _, m in meshes do
					m:Destroy()
				end
				return
			end
			local mesh = made :: MeshPart
			mesh.Name = item.key
			mesh.TextureID = `rbxassetid://{asset.texture}`
			mesh.Color = Color3.new(1, 1, 1)
			mesh.Size *= item.scale
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.CFrame = item.cframe * CFrame.new(0, mesh.Size.Y / 2, 0)
			table.insert(meshes, mesh)
		end
		for _, part in cluster:GetDescendants() do
			if part:IsA("BasePart") then
				if part.CanCollide then
					part.Transparency = 1
				else
					part:Destroy()
				end
			end
		end
		for _, mesh in meshes do
			mesh.Parent = cluster
		end
	end)
end

return PropMeshes
