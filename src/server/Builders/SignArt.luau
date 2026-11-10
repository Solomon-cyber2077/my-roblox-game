--!strict
--[[
	Lays a period sign's mesh (Config/Signage) on the face of the part that carries its SurfaceGui.
	The mesh's front looks out of that face, its back a hair proud of it; it wears its texture
	set's SurfaceAppearance from Server.SignLooks and is tagged Detail, so Performance hides it.
	The SurfaceGuis on that face are tagged DetailFallback: they show only while it is hidden
	(Controllers/DetailController), so the old print never shows through the new one.

	SignArt.dress(part, face, name) returns at once; the meshes load in their own threads (all of
	them on the first call, once per id) and each sign is parented beside its part, welded to it
	when the part is not anchored. Headless, or with the mesh or look missing, it does nothing.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signage = require(ReplicatedStorage.Shared.Config.Signage)

local SignArt = {}

-- The uploaded sign meshes face +Z (the import turns the export's -Z front round), so each is turned on
-- its own centre to look out of the face; unturned, only its back shows and the wall reads blank.
local TURN = CFrame.Angles(0, math.pi, 0)

local templates: { [number]: MeshPart } = {}
local loading: { [number]: boolean } = {}
local preloaded = false

local function template(id: number): MeshPart?
	while loading[id] do
		task.wait()
	end
	if templates[id] then
		return templates[id]
	end
	local okService, AssetService = pcall(game.GetService, game, "AssetService")
	if not okService then
		return nil
	end
	loading[id] = true
	local ok, part = pcall(function()
		return (AssetService :: AssetService):CreateMeshPartAsync(Content.fromAssetId(id), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Automatic,
		})
	end)
	loading[id] = nil
	if ok and part then
		templates[id] = part
		return part
	end
	warn(`[SignArt] mesh {id} did not load: {part}`)
	return nil
end

-- The face's centre and a frame looking out of it, upright where the face allows.
local function faceFrame(part: BasePart, face: Enum.NormalId): CFrame
	local normal = Vector3.FromNormalId(face)
	local centre = part.CFrame:PointToWorldSpace(normal * part.Size / 2)
	local out = part.CFrame:VectorToWorldSpace(normal)
	local up = if math.abs(normal.Y) > 0.5 then part.CFrame.LookVector else part.CFrame.UpVector
	return CFrame.lookAt(centre, centre + out, up)
end

function SignArt.dress(part: BasePart, face: Enum.NormalId, name: string)
	local spec = Signage.Signs[name]
	if not Signage.Enabled or spec == nil then
		return
	end
	local looks = script.Parent.Parent:FindFirstChild("SignLooks")
	local look = if looks then looks:FindFirstChild(spec.look) else nil
	if look == nil then
		return -- headless, or the looks are not synced
	end
	if not preloaded then
		-- every sign at once, so a model cloned soon after it is built already has its signs
		preloaded = true
		for _, other in Signage.Signs do
			task.spawn(template, other.mesh)
		end
	end
	task.spawn(function()
		local mesh = template(spec.mesh)
		local parent = part.Parent
		if mesh == nil or parent == nil then
			return
		end
		local sign = mesh:Clone()
		sign.Name = `Sign_{name}`
		sign.Color = Color3.new(1, 1, 1)
		sign.Anchored = part.Anchored
		sign.CanCollide = false
		sign.CanQuery = false
		sign.CanTouch = false
		sign.CastShadow = false
		sign.CFrame = faceFrame(part, face) * CFrame.new(0, 0, -(Signage.Gap + sign.Size.Z / 2)) * TURN
		look:Clone().Parent = sign
		if not part.Anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = sign
			weld.Parent = sign
		end
		sign:AddTag("Detail")
		for _, gui in part:GetChildren() do
			if gui:IsA("SurfaceGui") and gui.Face == face then
				CollectionService:AddTag(gui, "DetailFallback")
			end
		end
		sign.Parent = parent
	end)
end

return SignArt
