--!strict
-- Retarget the authored choreography into body-space R15 joint rotations.
local Pose = {}
type Frames = { [string]: CFrame }
local I = CFrame.identity
local ROOT = CFrame.Angles(-math.pi / 2, 0, math.pi)
local RIGHT = CFrame.Angles(0, math.pi / 2, 0)
local LEFT = CFrame.Angles(0, -math.pi / 2, 0)
local CHANNELS: { [string]: { string | CFrame } } = {
	Root = { "RootJoint", ROOT },
	Neck = { "Neck", ROOT },
	RightShoulder = { "Right Shoulder", RIGHT },
	LeftShoulder = { "Left Shoulder", LEFT },
	RightHip = { "Right Hip", RIGHT },
	LeftHip = { "Left Hip", LEFT },
}

function Pose.convert(
	source: Frames,
	phase: number,
	amount: number,
	sitting: boolean,
	articulated: boolean
): Frames
	local out: Frames = {}
	for name, channel in CHANNELS do
		local basis = channel[2] :: CFrame
		out[name] = basis * (source[channel[1] :: string] or I) * basis:Inverse()
	end
	out.Waist = I
	for _, side in { "Left", "Right" } do
		local swing = math.sin(phase + (if side == "Left" then math.pi else 0))
		local knee = if not articulated
			then 0
			elseif sitting then math.pi / 2
			else math.max(0, swing) * 0.85 * amount
		local elbow = if not articulated then 0 elseif sitting then 0.35 else 0.12 + 0.5 * amount
		out[side .. "Elbow"] = CFrame.Angles(elbow, 0, 0)
		out[side .. "Wrist"] = I
		out[side .. "Knee"] = CFrame.Angles(-knee, 0, 0)
		out[side .. "Ankle"] = if sitting then I else CFrame.Angles(knee * 0.35, 0, 0)
		-- Compensate the proximal rotation so bending does not double the swing.
		out[side .. "Shoulder"] *= CFrame.Angles(-elbow * 0.5, 0, 0)
		if not sitting then
			out[side .. "Hip"] *= CFrame.Angles(knee * 0.5, 0, 0)
		end
	end
	return out
end

function Pose.inJoint(frame: CFrame, c0: CFrame): CFrame
	local basis = c0.Rotation
	return basis:Inverse() * frame * basis
end

return Pose
