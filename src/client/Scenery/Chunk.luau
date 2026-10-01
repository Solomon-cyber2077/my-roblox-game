--!strict
--[[
	A chunk is one Model with a single anchored, invisible Root. Builders place
	parts in chunk-local space (Root at the origin), then Chunk.finish welds
	every part to Root and unanchors it, so the controller moves a whole chunk
	with one CFrame in Workspace:BulkMoveTo.

	All chunk parts are decor: no collision, no touch, and no queries, except
	parts that set the Occluder attribute (tunnel shells), which stay queryable
	so the default camera pulls in instead of clipping through rock.
]]

local Chunk = {}

export type Chunk = {
	key: string,
	layer: string,
	x0: number, -- land x of the chunk origin
	x1: number, -- land x where the chunk's track-side extent ends (for hiding and windows)
	model: Model,
	root: BasePart,
	rotors: { Motor6D },
	flickers: { PointLight },
	hideable: boolean, -- drops out of sight under a docked station's own track
}

function Chunk.begin(name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root
	return model, root
end

function Chunk.finish(
	key: string,
	layer: string,
	x0: number,
	x1: number,
	model: Model,
	root: BasePart,
	parent: Instance,
	hideable: boolean
): Chunk
	local rotors: { Motor6D } = {}
	local flickers: { PointLight } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant ~= root then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = descendant:GetAttribute("Occluder") == true
				descendant.Massless = true
				if descendant:GetAttribute("Jointed") ~= true then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = root
					weld.Part1 = descendant
					weld.Parent = descendant
					descendant.Anchored = false
				end
			end
		elseif descendant:IsA("Motor6D") then
			table.insert(rotors, descendant)
		elseif descendant:IsA("PointLight") and descendant:GetAttribute("Flicker") ~= nil then
			table.insert(flickers, descendant)
		end
	end
	model.Parent = parent
	return {
		key = key,
		layer = layer,
		x0 = x0,
		x1 = x1,
		model = model,
		root = root,
		rotors = rotors,
		flickers = flickers,
		hideable = hideable,
	}
end

function Chunk.destroy(chunk: Chunk)
	chunk.model:Destroy()
end

return Chunk
