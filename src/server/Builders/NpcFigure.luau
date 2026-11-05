--!strict
--[[
	A resident of the train (Config/Npcs), dressed from the shared period kit
	(Builders/OutfitKit) at `cframe`: feet on y = 0, facing the frame's -Z. Anchored and
	still; the body and skirt collide so the crew walk round them.

	A resident with a Blender figure (`def.mesh`) gets it once it loads: the mesh stands over the
	kit figure, whose parts turn invisible but keep their collision and the Talk prompt. Plugins
	cannot write MeshId, so the mesh is made here from its id (AssetService), on its own thread so
	server start never waits on it. A failed load, or a headless build (the Lune audit), leaves the
	kit figure showing.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Npcs = require(ReplicatedStorage.Shared.Config.Npcs)
local OutfitKit = require(script.Parent.OutfitKit)

export type Figure = { model: Model, body: BasePart }

local NpcFigure = {}

local function dress(def: Npcs.NpcDef, model: Model, cframe: CFrame)
	local spec = def.mesh
	if spec == nil then
		return
	end
	local ok, AssetService = pcall(function()
		return game:GetService("AssetService")
	end)
	if not ok or AssetService == nil then
		return
	end
	local loaded, mesh = pcall(function()
		return (AssetService :: any):CreateMeshPartAsync(`rbxassetid://{spec.meshId}`)
	end)
	if not loaded or mesh == nil or model.Parent == nil then
		if not loaded then
			warn(`NpcFigure: {def.id} mesh ({spec.meshId}) did not load: {mesh}`)
		end
		return
	end
	local part = mesh :: MeshPart
	part.Name = "Figure"
	part.TextureID = `rbxassetid://{spec.textureId}`
	part.Color = Color3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	-- the mesh's box is centred on its bounds: lift it so its feet sit on the floor
	part.CFrame = cframe * CFrame.new(0, part.Size.Y / 2, 0)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") or child:IsA("Decal") then
			(child :: any).Transparency = 1
		end
	end
	part.Parent = model
end

function NpcFigure.build(def: Npcs.NpcDef, cframe: CFrame, parent: Instance): Figure
	local figure = OutfitKit.figure(parent, cframe, def.look :: Npcs.Look, { armR = 30 })
	figure.model.Name = `Npc_{def.id}`
	if def.mesh then
		task.spawn(dress, def, figure.model, cframe)
	end
	return { model = figure.model, body = figure.body }
end

return NpcFigure
