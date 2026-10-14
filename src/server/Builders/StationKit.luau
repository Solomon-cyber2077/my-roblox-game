--!strict
--[[
	Dresses station props in the Blender kit (Config/StationKit). Plugins cannot write MeshId, so
	the meshes are made here from their ids (AssetService), once, at server start (Preload).
	A dressed prop keeps its primitives for collision, lights and glow: the solid ones are made
	invisible where the mesh now covers them, Neon parts and anything carrying a light stay.
	No mesh id, a failed load or a headless build (the Lune audit): the prop is left as it was.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.StationKit)

local StationKit = {}

local templates: { [string]: MeshPart? } = {}

-- Loads every piece that has a mesh id. Yields; call it from a spawned thread.
function StationKit.Preload()
	local ok, AssetService = pcall(function()
		return game:GetService("AssetService")
	end)
	if not ok or AssetService == nil then
		return
	end
	for name, piece in Config.Pieces do
		local id = piece.meshId
		if id and not templates[name] then
			local loaded, mesh = pcall(function()
				return (AssetService :: any):CreateMeshPartAsync(`rbxassetid://{id}`)
			end)
			if loaded and mesh then
				mesh.Name = name
				mesh.Color = Color3.new(1, 1, 1)
				mesh.Anchored = false
				mesh.CanCollide = false
				mesh.CanQuery = false
				mesh.CanTouch = false
				mesh.CastShadow = false
				templates[name] = mesh
			else
				warn(`StationKit: {name} ({id}) did not load: {mesh}`)
			end
		end
	end
end

-- Puts the kit's mesh over a prop built at `frame` (its foot centre), `length` along X for
-- the pieces that stretch. Returns the mesh, or nil when the prop stays primitive.
function StationKit.dress(kind: string, piece: Model, frame: CFrame, length: number?): MeshPart?
	local name = Config.ByProp[kind]
	if name == nil then
		return nil
	end
	local template = templates[name]
	if not template then
		return nil
	end
	local def = Config.Pieces[name]
	for _, part in piece:GetDescendants() do
		if part:IsA("BasePart") and part.Material ~= Enum.Material.Neon then
			if part:FindFirstChildWhichIsA("Light") == nil then
				part.Transparency = 1
			end
		end
	end
	local mesh = template:Clone()
	local scale = if def.stretch and length then length / def.size[1] else 1
	mesh.Size = Vector3.new(def.size[1] * scale, def.size[2], def.size[3])
	if def.material then
		mesh.Material = (Enum.Material :: any)[def.material]
	end
	mesh.CFrame = frame * CFrame.new(def.centre[1] * scale, def.centre[2], def.centre[3])
	mesh.Parent = piece
	return mesh
end

return StationKit
