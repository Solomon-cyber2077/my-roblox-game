--!strict
--[[
	Puts the sculpted heads and hands (Config/FaceKit) on a kit figure (Builders/OutfitKit) once their
	meshes are uploaded: the head picked from the look (female by a skirt or bodice, old by grey
	hair), the sculpted hair (a bun or a short parted cut), the look's style of facial hair, a hand at
	each cuff. Each MeshPart takes the person's skin (hair and whiskers their hair colour) as its Color
	under the texture, and a matte Plastic surface so the lamps
	do not turn the face white.

	The swap waits for the meshes to load, then follows the parts it replaces: anchored with an
	anchored figure, or welded to the same limb when Builders/PassengerFigure has put the figure on a
	walking body. A figure hidden in the meantime (Builders/NpcFigure's rig took over) is left alone.
	Until every mesh it needs has an id, the part-built face and hands stay.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.FaceKit)
local Outfits = require(ReplicatedStorage.Shared.Config.Outfits)

local FaceKit = {}

export type Placed = { key: string, cframe: CFrame, color: Color3 }

-- Where each figure would wear each mesh, kept only while `recording` (`lune run preview Hall` sets it).
FaceKit.placed = {} :: { Placed }
FaceKit.recording = false

local TURN = CFrame.Angles(0, math.pi, 0) -- the uploaded meshes face +Z; turned round on their own centre
local WRIST = 0.19 -- from the kit hand ball's centre up to the cuff's foot

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function grey(c: { number }): boolean
	local hi, lo = math.max(c[1], c[2], c[3]), math.min(c[1], c[2], c[3])
	return hi > 140 and hi - lo < 30
end

local function at(key: string, anchor: CFrame): CFrame
	local c = Config.Pieces[key].centre
	return anchor * CFrame.new(c[1], c[2], c[3])
end

function FaceKit.headFor(look: Outfits.Look): string
	local female = look.skirt ~= nil or look.cut == "Bodice"
	return `head_{if female then "f" else "m"}_{if grey(look.hair) then "old" else "young"}`
end

local function assets(): any?
	local ok, service = pcall(function()
		return game:GetService("AssetService")
	end)
	return if ok then service else nil
end

-- `head` and `hands` are the kit's anchors as built; `face`, `whiskers` and `handParts` the parts the
-- meshes replace (face[1] the head ball, handParts in pairs: ball, thumb, left then right).
function FaceKit.dress(
	head: CFrame,
	hands: { [number]: CFrame },
	look: Outfits.Look,
	face: { BasePart },
	whiskers: { BasePart },
	handParts: { BasePart }
)
	local skin, hair = rgb(look.skin), rgb(look.hair)
	local wanted: { { key: string, ref: BasePart, offset: CFrame, color: Color3, built: CFrame } } = {}
	local headKey = FaceKit.headFor(look)
	local seat = CFrame.new(Config.Seat[1], Config.Seat[2], Config.Seat[3])
	table.insert(
		wanted,
		{ key = headKey, ref = face[1], offset = at(headKey, seat), color = skin, built = head }
	)
	-- the sculpted hair: a woman's middle parting and bun, or a man's short parted cut
	local hairKey = if look.hairStyle == "Bald"
		then nil
		elseif look.hairStyle == "Bun" then "hair_bun"
		else "hair_short"
	if hairKey and Config.Pieces[hairKey] then
		table.insert(wanted, {
			key = hairKey,
			ref = face[1],
			offset = at(hairKey, seat),
			color = hair,
			built = head,
		})
	end
	-- the sculpted facial hair of the look's style (Config/FaceKit whiskers_<style>)
	local whiskerKey = if look.whiskers then `whiskers_{string.lower(look.whiskers)}` else nil
	if whiskerKey and Config.Pieces[whiskerKey] and #whiskers > 0 then
		table.insert(wanted, {
			key = whiskerKey,
			ref = face[1],
			offset = at(whiskerKey, seat),
			color = hair,
			built = head,
		})
	end
	for i, side in { -1, 1 } do
		local ball = handParts[i * 2 - 1]
		local key = if side > 0 then "hand_r" else "hand_l"
		local wrist = CFrame.new(0, WRIST, 0)
		table.insert(
			wanted,
			{ key = key, ref = ball, offset = at(key, wrist), color = skin, built = hands[side] }
		)
	end
	for _, list in { face, whiskers, handParts } do
		for _, part in list do
			part:SetAttribute("Meshed", true) -- given way to a mesh once uploaded (the preview drops it)
		end
	end
	if FaceKit.recording then
		for _, w in wanted do
			table.insert(FaceKit.placed, { key = w.key, cframe = w.built * w.offset, color = w.color })
		end
	end
	for _, w in wanted do
		if Config.Ids[w.key] == nil then
			return
		end
	end
	local service = assets()
	if service == nil then
		return
	end
	local looks = script.Parent.Parent:FindFirstChild("FaceLooks")
	task.spawn(function()
		local made: { MeshPart } = {}
		for _, w in wanted do
			local asset = Config.Ids[w.key]
			local ok, mesh = pcall(function()
				return service:CreateMeshPartAsync(`rbxassetid://{asset.mesh}`)
			end)
			if not ok or mesh == nil then
				warn(`FaceKit: {w.key} did not load: {mesh}`)
				for _, m in made do
					m:Destroy()
				end
				return
			end
			table.insert(made, mesh :: MeshPart)
		end
		for i, w in wanted do
			local ref = w.ref
			if ref.Parent == nil or ref.Transparency >= 1 then
				for _, m in made do
					m:Destroy()
				end
				return
			end
			local mesh = made[i]
			mesh.Name = w.key
			local size = Config.Pieces[w.key].size
			mesh.Size = Vector3.new(size[1], size[2], size[3]) -- as built, whatever units the importer read
			-- the texture as an Overlay SurfaceAppearance (src/server/FaceLooks.model.json), so the person's
			-- own Color shows through its clear parts; a plain TextureID would show them black
			local skinLook = looks and looks:FindFirstChild(w.key)
			local faceless = not Config.PaintedFaces and string.sub(w.key, 1, 5) == "head_"
			-- faceless: plain skin, the person's own Color on the sculpted head with no painted features
			if skinLook and not faceless then
				skinLook:Clone().Parent = mesh
			elseif not faceless then
				mesh.TextureID = `rbxassetid://{Config.Ids[w.key].texture}`
			end
			mesh.Color = w.color
			mesh.Material = Enum.Material.Plastic
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.CastShadow = false
			mesh.Massless = true
			mesh.CFrame = ref.CFrame * w.offset * TURN
			mesh.Anchored = ref.Anchored
			local weld = ref:FindFirstChildOfClass("WeldConstraint")
			if weld and weld.Part0 then
				local joint = Instance.new("WeldConstraint")
				joint.Part0 = weld.Part0
				joint.Part1 = mesh
				joint.Parent = mesh
			end
			mesh.Parent = ref.Parent
		end
		for _, list in { face, whiskers, handParts } do
			for _, part in list do
				part:Destroy()
			end
		end
	end)
end

return FaceKit
