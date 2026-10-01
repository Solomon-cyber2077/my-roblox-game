--!strict
--[[
	Builds an item's model from the primitive list in Config/Items. The server
	uses it for world pickups; the client uses it for backpack icons inside
	ViewportFrames, so both always match.
]]

local Shared = script.Parent.Parent
local Items = require(Shared.Config.Items)
local Kit = require(script.Parent.Kit)

local ItemModel = {}

local SHAPES = {
	Block = "Block",
	Ball = "Ball",
	Cylinder = "Cylinder",
	Wedge = "Wedge",
}

local function material(name: string): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value then value else Enum.Material.SmoothPlastic
end

-- Returns a model whose PrimaryPart sits at `cframe`. Parts are anchored and non-collidable.
function ItemModel.build(itemId: string, cframe: CFrame, scale: number?): Model
	local def = Items[itemId]
	assert(def, `unknown item {itemId}`)
	local s = scale or 1
	local model = Kit.model(itemId)
	local primary: BasePart? = nil
	for _, prim in def.model do
		local offset = prim.offset or { 0, 0, 0 }
		local rot = prim.rot or { 0, 0, 0 }
		local frame = cframe
			* CFrame.new(offset[1] * s, offset[2] * s, offset[3] * s)
			* Kit.angles(rot[1], rot[2], rot[3])
		local size = Vector3.new(prim.size[1], prim.size[2], prim.size[3]) * s
		local color = Kit.rgb(prim.color)
		local options = {
			material = if prim.neon then Enum.Material.Neon else material(prim.material),
			collide = false,
			transparency = if prim.material == "Glass" and not prim.neon then 0.25 else 0,
		}
		local part: BasePart
		local shape = SHAPES[prim.shape]
		if shape == "Wedge" then
			part = Kit.wedge(model, size, frame, color, options)
		else
			part = Kit.block(model, size, frame, color, options)
			if shape == "Ball" then
				(part :: Part).Shape = Enum.PartType.Ball
			elseif shape == "Cylinder" then
				(part :: Part).Shape = Enum.PartType.Cylinder
			end
		end
		if primary == nil then
			primary = part
			part.Name = "Body"
		end
	end
	model.PrimaryPart = primary
	return model
end

-- Radius of a sphere that contains the model, for camera framing.
function ItemModel.radius(itemId: string): number
	local def = Items[itemId]
	local radius = 0.5
	for _, prim in def.model do
		local offset = prim.offset or { 0, 0, 0 }
		local reach = Vector3.new(offset[1], offset[2], offset[3]).Magnitude
			+ Vector3.new(prim.size[1], prim.size[2], prim.size[3]).Magnitude / 2
		radius = math.max(radius, reach)
	end
	return radius
end

return table.freeze(ItemModel)
