local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Loader = require("./lib/Loader")
require("./lib/Shim").install()
local builder = Loader.requireNode(Loader.roots.Server.Builders.HollowBuilder)
local poses = Loader.requireNode(Loader.roots.Client.Animation.HollowPoses)
local kind = process.args[1] or "Stalker"
local model = builder.build(roblox.CFrame.new(), kind)
local rig = poses.rigOf(model)
local pose = poses.pose(
	rig,
	{ state = "Prowl", speed = 4, phase = 0.8, now = 2, seed = 17, elapsed = 2, grabTime = 0 }
)
local root = model:FindFirstChild("HumanoidRootPart")
local frames, links = { [root] = root.CFrame }, {}
for _, item in model:GetDescendants() do
	if item:IsA("Motor6D") then
		table.insert(links, {
			a = item.Part0,
			b = item.Part1,
			offset = item.C0 * (pose[item.Name] or roblox.CFrame.new()) * item.C1:Inverse(),
		})
	elseif item:IsA("Weld") and item.Part0 and item.Part1 then
		table.insert(links, { a = item.Part0, b = item.Part1, offset = item.C0 * item.C1:Inverse() })
	elseif item:IsA("WeldConstraint") and item.Part0 and item.Part1 then
		table.insert(
			links,
			{ a = item.Part0, b = item.Part1, offset = item.Part0.CFrame:Inverse() * item.Part1.CFrame }
		)
	end
end
for _ = 1, #links do
	local changed = false
	for _, link in links do
		if frames[link.a] and not frames[link.b] then
			frames[link.b] = frames[link.a] * link.offset
			changed = true
		end
	end
	if not changed then
		break
	end
end
local parts = {}
for _, part in model:GetDescendants() do
	if part:IsA("BasePart") and part.Transparency < 1 then
		assert(frames[part], "photo rig could not resolve frame for " .. part:GetFullName())
		local shape = if part:IsA("WedgePart")
			then "Wedge"
			elseif part:IsA("Part") then part.Shape.Name
			else "Block"
		table.insert(parts, {
			name = part.Name,
			shape = shape,
			size = { part.Size.X, part.Size.Y, part.Size.Z },
			color = { part.Color.R, part.Color.G, part.Color.B },
			frame = { (frames[part] or part.CFrame):GetComponents() },
		})
	end
end
fs.writeFile(
	process.args[2] or "hollow-photo.json",
	serde.encode("json", { kind = kind, parts = parts }, true)
)
print(kind, #parts, "parts; IK shortfall", poses.shortfall())
