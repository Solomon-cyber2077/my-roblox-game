--!strict
--[[
	A tree's crown as one Blender mesh (Config/TreeCrowns, tools/trees/build.py) in place of its Part
	balls: a ball is 432 triangles whatever its size, a crown mesh a few hundred, and it keeps the
	species' shape. Stations (Builders/TreeCrowns, server) and the landscape (Scenery/Props, client)
	both use it. The server loads each crown once and keeps a copy in ReplicatedStorage.TreeCrowns;
	the landscape clones those while it builds a chunk, so its balls are swapped before Chunk.finish
	welds the chunk. Where no crown is there yet (no id, not loaded, a headless build) the balls stay.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crowns = {}

Crowns.FOLDER = "TreeCrowns"

-- The server's shared copy of a crown, if it has loaded.
function Crowns.shared(key: string): MeshPart?
	-- (pcall: the headless audit's stand-in ReplicatedStorage has no FindFirstChild)
	local ok, folder = pcall(function()
		return ReplicatedStorage:FindFirstChild(Crowns.FOLDER)
	end)
	if not ok then
		return nil
	end
	local found = if folder then folder:FindFirstChild(key) else nil
	return if found and found:IsA("MeshPart") then found else nil
end

-- One of the two oak crowns, picked by where the tree stands (no draw from a layout's Rng).
function Crowns.oak(frame: CFrame): string
	local p = frame.Position
	return if math.floor(p.X + p.Z) % 2 == 0 then "crown_oak_a" else "crown_oak_b"
end

-- Puts a copy of `template` where `balls` are (the first is the main mass) and removes them. The
-- mesh fills the balls' box measured along `frame`'s axes and takes the main ball's look.
function Crowns.place(template: MeshPart, balls: { BasePart }, frame: CFrame): MeshPart?
	if #balls == 0 or balls[1].Parent == nil then
		return nil
	end
	local main = balls[1]
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, b in balls do
		local p = frame:PointToObjectSpace(b.Position)
		local r = Vector3.one * b.Size.X / 2
		lo, hi = lo:Min(p - r), hi:Max(p + r)
	end
	local mesh = template:Clone()
	mesh.Name = "Crown"
	mesh.Size = hi - lo
	mesh.CFrame = frame * CFrame.new((lo + hi) / 2)
	mesh.Color = main.Color
	mesh.Material = main.Material
	mesh.CastShadow = main.CastShadow
	mesh.Anchored = main.Anchored
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false
	if main:HasTag("Detail") then
		mesh:AddTag("Detail")
	end
	mesh.Parent = main.Parent
	for _, b in balls do
		b:Destroy()
	end
	return mesh
end

-- Swaps the balls at once when the crown is already shared (the landscape's case).
function Crowns.swapShared(balls: { BasePart }, frame: CFrame, key: string)
	local template = Crowns.shared(key)
	if template then
		Crowns.place(template, balls, frame)
	end
end

return Crowns
