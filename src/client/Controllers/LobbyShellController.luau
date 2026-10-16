--!strict
-- Reusable Blender castings and small procedural surface maps. The server parts
-- remain the collision shapes and the Performance/unsupported-device fallback.
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

type MeshData = { vertices: { { number } }, triangles: { { number } }, size: { number } }
local Meshes = require(ReplicatedStorage.Shared.Visual.LobbyMeshes) :: { [string]: MeshData }
local LobbyShellController = {}
local MAP_SIZE = 128
local templates: { [string]: MeshPart } = {}
local images: { [string]: EditableImage } = {}
local replacements: { [BasePart]: MeshPart } = {}
local surfaces: { [BasePart]: { Texture } } = {}
local prepared = false
local preparing = false

local function performance(): boolean
	return Players.LocalPlayer:GetAttribute("GraphicsQuality") == "Performance"
end

local function surfaceMap(kind: string): EditableImage
	local image = assert(AssetService:CreateEditableImage({ Size = Vector2.new(MAP_SIZE, MAP_SIZE) }))
	local pixels = buffer.create(MAP_SIZE * MAP_SIZE * 4)
	for y = 0, MAP_SIZE - 1 do
		for x = 0, MAP_SIZE - 1 do
			local row = math.floor(y / 16)
			local width = if row % 2 == 0 then 32 else 16 -- English bond: stretchers / headers
			local joint = y % 16 < 2 or (x + (if row % 2 == 0 then 0 else 8)) % width < 2
			local grain = math.noise(x / 9, y / 9) * 20 + math.noise(x / 31, y / 27) * 35
			local value = math.clamp(math.floor(214 + grain), 0, 255)
			local alpha = 70
			if kind == "Brick" then
				value = if joint then 170 else math.clamp(math.floor(220 + grain), 0, 255)
				alpha = 255
			elseif kind == "Tile" then
				joint = x % 32 < 2 or y % 32 < 2
				value = if joint then 24 else 230
				alpha = if joint then 150 else 25
			else
				-- Only the existing flag faces receive this map; the emblem stays clear.
				value = math.clamp(math.floor(130 + grain), 0, 255)
				alpha = 50
			end
			local offset = (y * MAP_SIZE + x) * 4
			for channel = 0, 2 do
				buffer.writeu8(pixels, offset + channel, value)
			end
			buffer.writeu8(pixels, offset + 3, alpha)
		end
	end
	image:WritePixelsBuffer(Vector2.zero, image.Size, pixels)
	return image
end

local function apply(part: BasePart)
	local detailed = not performance()
	local mesh: MeshPart? = replacements[part]
	local name = part:GetAttribute("LobbyMesh")
	if not mesh and detailed and typeof(name) == "string" and templates[name] then
		local added: MeshPart = templates[name]:Clone()
		added.Name = "LobbyCasting"
		added.Size = part:GetAttribute("LobbyMeshSize") :: Vector3
		added.CFrame = part:GetAttribute("LobbyMeshCFrame") :: CFrame
		added.Color = part.Color
		added.Material = part.Material
		added.Anchored = true
		added.CanCollide = false
		added.CanTouch = false
		added.CanQuery = false
		added.CastShadow = part.CastShadow
		added.Parent = part
		replacements[part] = added
		mesh = added
	end
	if mesh then
		part.LocalTransparencyModifier = if detailed then 1 else 0
		mesh.Transparency = if detailed then 0 else 1
	end
	local kind = part:GetAttribute("LobbySurface")
	local maps: { Texture }? = surfaces[part]
	if not maps and detailed and typeof(kind) == "string" and images[kind] then
		local added: { Texture } = {}
		local faces: { Enum.NormalId } = if kind == "Stone"
			then { Enum.NormalId.Top }
			else { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
		for _, face in ipairs(faces) do
			local texture = Instance.new("Texture")
			texture.Name = "LobbyWear"
			texture.Color3 = part.Color
			texture.Face = face
			texture.ColorMapContent = Content.fromObject(images[kind])
			texture.StudsPerTileU = if kind == "Tile" then 4 else 8
			texture.StudsPerTileV = texture.StudsPerTileU
			texture.Parent = part
			table.insert(added, texture)
		end
		surfaces[part] = added
		maps = added
	end
	if maps then
		for _, texture in maps do
			texture.Transparency = if detailed then 0 else 1
		end
	end
end

local function refresh()
	if preparing then
		return
	end
	if not prepared and not performance() then
		preparing = true
		-- Each mesh/image is made once and shared by every instance in the hall.
		for name, data in Meshes do
			local ok, err = pcall(function()
				local editable = assert(AssetService:CreateEditableMesh())
				local vertices = {}
				for _, v in data.vertices do
					table.insert(vertices, editable:AddVertex(Vector3.new(v[1], v[2], v[3])))
				end
				for _, face in data.triangles do
					editable:AddTriangle(vertices[face[1]], vertices[face[2]], vertices[face[3]])
				end
				templates[name] = AssetService:CreateMeshPartAsync(Content.fromObject(editable))
			end)
			if not ok then
				warn("[LobbyShell] Using simple casting for " .. name .. ": " .. tostring(err))
			end
		end
		for _, kind in { "Brick", "Tile", "Stone" } do
			local ok, result = pcall(surfaceMap, kind)
			if ok then
				images[kind] = result
			else
				warn("[LobbyShell] Using base material for " .. kind .. ": " .. tostring(result))
			end
		end
		prepared = true
		preparing = false
	end
	local hall = Workspace:FindFirstChild("DepotHall")
	if hall then
		for _, part in hall:GetDescendants() do
			if
				part:IsA("BasePart")
				and (part:GetAttribute("LobbyMesh") or part:GetAttribute("LobbySurface"))
			then
				apply(part)
			end
		end
	end
end

function LobbyShellController.Init() end

function LobbyShellController.Start()
	Workspace.DescendantAdded:Connect(function(part: Instance)
		if part:IsA("BasePart") then
			task.defer(function()
				if part.Parent and (part:GetAttribute("LobbyMesh") or part:GetAttribute("LobbySurface")) then
					apply(part)
				end
			end)
		end
	end)
	Workspace.DescendantRemoving:Connect(function(part: Instance)
		if part:IsA("BasePart") then
			replacements[part] = nil
			surfaces[part] = nil
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("GraphicsQuality"):Connect(refresh)
	task.spawn(refresh)
end

return LobbyShellController
