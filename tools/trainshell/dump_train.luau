--[[
	Builds the train headless and writes every part to JSON, so Blender can model the
	exterior against the measured original.  lune run tools/trainshell/dump_train.luau out.json
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local Loader = require("../../.lune/lib/Loader")
local Shim = require("../../.lune/lib/Shim")
Shim.install()

local TrainBuilder = Loader.requireNode(Loader.roots.Server.Builders.TrainBuilder)
local built = TrainBuilder.build(roblox.CFrame.new(), nil)

local out = {}
for _, p in built.model:GetDescendants() do
	if p:IsA("BasePart") then
		local cf = p.CFrame
		local c = { cf:GetComponents() }
		local attrs = {}
		for k, v in p:GetAttributes() do
			attrs[k] = if typeof(v) == "string" or typeof(v) == "number" or typeof(v) == "boolean" then v else tostring(v)
		end
		local shape = "Block"
		if p.ClassName == "Part" then
			shape = p.Shape.Name
		end
		local texts = {}
		for _, d in p:GetDescendants() do
			if d:IsA("TextLabel") then
				table.insert(texts, d.Text)
			end
		end
		table.insert(out, {
			name = p.Name,
			class = p.ClassName,
			shape = shape,
			size = { p.Size.X, p.Size.Y, p.Size.Z },
			cf = c,
			color = { math.floor(p.Color.R * 255 + 0.5), math.floor(p.Color.G * 255 + 0.5), math.floor(p.Color.B * 255 + 0.5) },
			material = p.Material.Name,
			transparency = p.Transparency,
			collide = p.CanCollide,
			parent = p.Parent.Name,
			attrs = attrs,
			texts = texts,
		})
	end
end
fs.writeFile(process.args[1] or "train_dump.json", serde.encode("json", out, false))
print(#out .. " parts")
