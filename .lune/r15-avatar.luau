-- Pose coordinate conventions and clothing anchors for the R15 migration.
local roblox = require("@lune/roblox")
local Loader = require("./lib/Loader")
require("./lib/Shim").install()
local Pose = Loader.requireNode(Loader.roots.Client.Animation.R15Pose)
local Rig = Loader.requireNode(Loader.roots.Shared.Visual.AvatarRig)
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local function near(a, b, message)
	assert((a - b).Magnitude < 0.00001, message)
end
local neutral = Pose.convert({}, 0, 0, false, false)
local count = 0
for _, frame in neutral do
	count += 1
	near(frame.Position, Vector3.zero, "Neutral translation drift")
	near(frame.UpVector, Vector3.yAxis, "Neutral rotation drift")
end
assert(count == 15, "Every R15 joint needs a target")
local lift = Pose.convert({ RootJoint = CFrame.new(0, 0, 1) }, 0, 0, false, false)
near(lift.Root.Position, Vector3.yAxis, "Authored root lift must remain vertical")
local arms = Pose.convert({
	["Right Shoulder"] = CFrame.Angles(0, 0, math.pi / 2),
	["Left Shoulder"] = CFrame.Angles(0, 0, -math.pi / 2),
}, 0, 0, false, false)
near(arms.RightShoulder:VectorToWorldSpace(-Vector3.yAxis), -Vector3.zAxis, "Right arm must reach forwards")
near(arms.LeftShoulder:VectorToWorldSpace(-Vector3.yAxis), -Vector3.zAxis, "Left arm must reach forwards")
local gait = Pose.convert({}, math.pi / 2, 1, false, true)
assert(gait.RightKnee ~= CFrame.identity and gait.LeftKnee == CFrame.identity, "Swing leg alone flexes")
local held = Pose.convert({}, math.pi / 2, 1, false, false)
near(held.RightKnee.UpVector, Vector3.yAxis, "Grabs must not inherit gait")
local basis = CFrame.Angles(0.2, 0.7, -0.4)
near(
	(basis * Pose.inJoint(arms.RightShoulder, basis) * basis:Inverse()).UpVector,
	arms.RightShoulder.UpVector,
	"Non-identity motor basis must preserve pose"
)
local model = roblox.Instance.new("Model")
for i, name in { "RightUpperArm", "RightLowerArm", "RightHand" } do
	local part = roblox.Instance.new("Part")
	part.Name = name
	part.Size = Vector3.one
	part.CFrame = CFrame.new(1.5, 4 - i, 0)
	part.Position = part.CFrame.Position
	part.Parent = model
end
assert(Rig.Part(model, "Right Arm").Name == "RightUpperArm", "Legacy arm resolves to upper segment")
assert(Rig.Anchor(model, "Right Arm", Vector3.new(1.5, 1, 0)).Name == "RightHand", "Held prop follows hand")
near(
	Rig.Frame(model, "Right Arm").Position,
	Vector3.new(1.5, 2.5, 0),
	"Authored two-stud limb frame keeps top edge"
)
assert(Rig.Part(model, "Left Arm") == nil, "Missing limbs remain absent")
model:Destroy()
print("R15 avatar: 15 channels, neutral, reach, lift, gait, joint axes and clothing anchors passed")
