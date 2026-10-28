-- Export production poses and lantern geometry for the Blender comparison.
-- Run from the worktree: lune run tools/limbloss/export
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Loader = require("../../.lune/lib/Loader")
require("../../.lune/lib/Shim").install()
local P = Loader.requireNode(Loader.roots.Client.Animation.CrewPoses)
local Cosmetics = Loader.requireNode(Loader.roots.Shared.Visual.CosmeticModels)
local Injury = Loader.requireNode(Loader.roots.Shared.Config.Injury)
local C = roblox.CFrame
local V = roblox.Vector3
local A = C.Angles
local I = C.identity
local rot = A(-math.pi / 2, 0, math.pi)
local samples = {}
local function base(speed)
	return P.locomote({
		now = 2,
		seed = 1,
		speed = speed or 0,
		vertical = 0,
		grounded = true,
		phase = 0.7,
		sitting = false,
		load = 0,
		sprinting = false,
		exhausted = false,
		landing = 0,
		lookYaw = 0,
		lookPitch = 0,
		dread = 0.2,
		turn = 0,
	})
end
local function add(name, missing, pose, after)
	local root = C.new(0, 3, 0)
	local torso = root * rot * (pose.RootJoint or I) * rot:Inverse()
	local frames = {
		Torso = torso,
		Head = torso * C.new(0, 1, 0) * rot * (pose.Neck or I) * (C.new(0, -0.5, 0) * rot):Inverse(),
	}
	for _, side in { -1, 1 } do
		local label = if side == 1 then "Right" else "Left"
		local r = A(0, side * math.pi / 2, 0)
		frames[label .. " Arm"] = torso
			* C.new(side, 0.5, 0)
			* r
			* (pose[label .. " Shoulder"] or I)
			* (C.new(-side * 0.5, 0.5, 0) * r):Inverse()
		frames[label .. " Leg"] = torso
			* C.new(side, -1, 0)
			* r
			* (pose[label .. " Hip"] or I)
			* (C.new(side * 0.5, 1, 0) * r):Inverse()
	end
	local parts = {}
	local function part(label, cf, size, color, shape)
		table.insert(parts, {
			name = label,
			cf = { cf:GetComponents() },
			size = { size.X, size.Y, size.Z },
			color = color,
			shape = shape or "Block",
		})
	end
	for label, cf in frames do
		local hidden = (label == "Left Arm" and string.find(missing, "L"))
			or (label == "Right Arm" and string.find(missing, "R"))
		if not hidden then
			local size = if label == "Torso"
				then V.new(2, 2, 1)
				elseif label == "Head" then V.new(2, 1, 1)
				else V.new(1, 2, 1)
			local color = if label == "Head"
				then { 0.64, 0.49, 0.34 }
				elseif string.find(label, "Leg") then { 0.10, 0.14, 0.15 }
				else { 0.30, 0.12, 0.10 }
			part(label, cf, size, color)
		end
	end
	local mount = torso * C.new(1.4, -0.75, 0.05)
	if after and missing == "L" then
		mount = frames["Right Arm"]
			* C.new(0, -Injury.Presentation.LanternHandDown, -Injury.Presentation.LanternHandForward)
	elseif after and missing == "R" then
		mount = frames["Left Arm"]
			* C.new(0, -Injury.Presentation.LanternHandDown, -Injury.Presentation.LanternHandForward)
	end
	local lantern = Cosmetics.lantern(
		{ body = { 145, 110, 62 }, glass = { 255, 190, 100 }, light = { 255, 190, 100 }, style = "Classic" },
		mount
	)
	for _, p in lantern:GetDescendants() do
		if p:IsA("BasePart") then
			part(p.Name, p.CFrame, p.Size, { p.Color.R, p.Color.G, p.Color.B }, tostring(p.Shape))
		end
	end
	lantern:Destroy()
	table.insert(samples, { name = name, missing = missing, parts = parts })
end
local standing = base()
add("BEFORE / LEFT LOSS", "L", standing, false)
add("BEFORE / RIGHT LOSS", "R", standing, false)
add("BEFORE / LAST FIVE", "LR", base(12), false)
add("BEFORE / REGROWTH", "", standing, false)
add("BEFORE / DEATH", "LR", P.limp(2, 1), false)
add("AFTER / LEFT LOSS", "L", P.injured(standing, "L", "L", 0.3, 0, 0, 0, 0), true)
add("AFTER / RIGHT LOSS", "R", P.injured(standing, "R", "R", 0.3, 0, 0, 0, 0), true)
add("AFTER / LAST FIVE", "LR", P.injured(base(12), "LR", nil, 0, 0, 1, 0, 0), true)
add("AFTER / REGROWTH", "", P.injured(standing, "", "L", 0, 0.5, 0, 0, 0), true)
add("AFTER / DEATH", "LR", P.injured(P.limp(2, 1), "LR", nil, 0, 0, 0, 0, 1), true)
-- Regression assertions use production poses, not duplicated motion math.
for _, missing in { "", "L", "R", "LR" } do
	for _, age in { 0, 0.1, 0.3, 0.5, 1, 2 } do
		local gait = base(12)
		local out = P.injured(gait, missing, "L", age, 0, 1, 0, 0)
		assert(
			out["Right Hip"] == gait["Right Hip"] and out["Left Hip"] == gait["Left Hip"],
			"injury changed gait"
		)
		for _, cf in out do
			for _, n in { cf:GetComponents() } do
				assert(n == n and math.abs(n) < 100, "nonfinite pose")
			end
		end
	end
end
local untouched = P.injured(standing, "", nil, 0, 0, 0, 0, 0)
for key, value in standing do
	assert(untouched[key] == value, "healthy pose changed")
end
local recovered = P.injured(standing, "", "L", 2, 2, 0, 0, 0)
for key, value in standing do
	assert(recovered[key] == value, "expired injury pose failed to return to baseline")
end
for _, age in { 0, 0.1, 0.3, 0.5, 1, 2 } do
	for _, cf in P.injured(standing, "LR", nil, 0, 0, 0, 0, age) do
		for _, n in { cf:GetComponents() } do
			assert(n == n and math.abs(n) < 100, "nonfinite collapse")
		end
	end
end
assert(Injury.Enabled == false, "feature flag changed")
fs.writeFile(
	"tools/limbloss/poses.json",
	serde.encode("json", { samples = samples, witness = Injury.Witness }, true)
)
print("32 pose cases and flag-off assertion passed; exported 10 production pose samples")
