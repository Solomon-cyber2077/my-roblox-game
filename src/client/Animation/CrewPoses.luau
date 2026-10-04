--!strict
--[[
	The crew's bodies in motion: blocky R6 characters animated procedurally, as pure CFrame
	math (CharacterAnimator plays it on every client). A pose maps the R6 joint names to
	Motor6D.Transform values.

	R6 joints and how their transforms turn (each rotation is in the joint's own frame):
	  RootJoint, Neck   Angles(forward, roll left, turn left); a RootJoint translation is
	                    (left, back, up)
	  Shoulders, hips   Angles(-out, -spread * side, forward * side), side 1 right, -1 left:
	                    forward swings the limb ahead of the body, out raises it sideways
	                    (while it hangs), spread opens it sideways (while it points ahead)

	The look is meant to be human and afraid, like the crew in a horror game: breath you
	can see in the shoulders, a nervous glance over the shoulder, a run that pitches
	forward and pumps the arms, a sprint flat out, a stumble on landing, hands on the
	knees when the breath runs out, arms wrapped round a load. In a Hollow's hands every
	grab (Config/Grabs) has the victim's own struggle, harder the more they mash and
	weaker as they fade.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Grabs = require(Shared.Config.Grabs)
local Grab = require(Shared.Logic.Grab)

export type Pose = { [string]: CFrame }

export type Input = {
	now: number,
	seed: number,
	speed: number, -- horizontal studs per second
	vertical: number, -- vertical velocity
	grounded: boolean,
	phase: number, -- stride phase, radians (CrewPoses.cadence)
	sitting: boolean,
	load: number, -- 0..1 how full their arms are
	sprinting: boolean,
	exhausted: boolean, -- run out of breath (the local player only)
	landing: number, -- 0..1 the jolt of a landing, fading
	lookYaw: number, -- radians the head turns from the body (left +)
	lookPitch: number, -- radians it looks down (+) or up (-)
	dread: number, -- 0..1 a Hollow close by
	turn: number, -- radians per second the body turns (left +)
}

local CrewPoses = {}

local RIGHT, LEFT = 1, -1

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function smoothstep(a: number, b: number, x: number): number
	local t = clamp01((x - a) / (b - a))
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- A shoulder or hip: forward swing, out to the side while it hangs, open while it points ahead.
local function limb(side: number, forward: number, out: number?, spread: number?): CFrame
	return CFrame.Angles(-(out or 0), -(spread or 0) * side, forward * side)
end

-- The torso on the root: lean forward, roll left, turn left; then lift it (up), push it back, move it left.
local function body(
	lean: number,
	roll: number,
	yaw: number,
	up: number?,
	back: number?,
	left: number?
): CFrame
	return CFrame.new(left or 0, back or 0, up or 0) * CFrame.Angles(lean, roll, yaw)
end

local function head(nod: number, roll: number, yaw: number): CFrame
	return CFrame.Angles(nod, roll, yaw)
end

local function set(out: Pose, rightArm: CFrame, leftArm: CFrame, rightLeg: CFrame, leftLeg: CFrame)
	out["Right Shoulder"] = rightArm
	out["Left Shoulder"] = leftArm
	out["Right Hip"] = rightLeg
	out["Left Hip"] = leftLeg
end

-- Radians per second the stride's phase runs at `speed`: longer strides as the pace picks up.
function CrewPoses.cadence(speed: number): number
	if speed < 0.5 then
		return 0
	end
	return speed / (3.2 + speed * 0.12) * math.pi
end

-- On foot, in the air or seated.
function CrewPoses.locomote(input: Input): Pose
	local out: Pose = {}
	local now = input.now
	local seed = input.seed
	local dread = input.dread
	local rate = 1.4 + 1.6 * dread + (if input.exhausted then 2.6 else 0)
	local breath = math.sin(now * rate + seed)
	local depth = 0.012 + 0.02 * dread + (if input.exhausted then 0.05 else 0)

	if input.sitting then
		-- seated: legs over the seat's edge, hands on the knees, gazing out of the window
		local gaze = math.noise(now * 0.12, seed % 97) * 1.4
		out.RootJoint = body(-0.06 + depth * breath, 0, 0, depth * breath)
		set(
			out,
			limb(RIGHT, 0.6 + 0.02 * breath, 0.06),
			limb(LEFT, 0.6 + 0.02 * breath, 0.06),
			limb(RIGHT, math.pi / 2, 0.05),
			limb(LEFT, math.pi / 2, 0.05)
		)
		out.Neck = head(0.06 + input.lookPitch, 0, math.clamp(gaze + input.lookYaw, -1.3, 1.3))
		return out
	end

	if not input.grounded then
		-- in the air: arms thrown up to jump, flailing out as they fall, legs reaching for the ground
		local rising = clamp01(input.vertical / 22)
		local falling = clamp01(-input.vertical / 45)
		local flail = math.sin(now * 13 + seed) * 0.35 * falling
		set(
			out,
			limb(RIGHT, 1.7 * rising + 0.5 * falling, 0.25 + 0.9 * falling + flail, 0),
			limb(LEFT, 1.4 * rising + 0.4 * falling, 0.25 + 0.9 * falling - flail, 0),
			limb(RIGHT, 0.55 * rising - 0.1 * falling, 0.08 + 0.25 * falling),
			limb(LEFT, -0.3 * rising + 0.25 * falling, 0.08 + 0.2 * falling)
		)
		out.RootJoint = body(0.08 * rising - 0.06 * falling, 0, 0)
		out.Neck = head(0.25 * falling - 0.1 * rising + input.lookPitch * 0.5, 0, input.lookYaw * 0.6)
		return out
	end

	local speed = input.speed
	local moving = smoothstep(0.5, 6, speed)
	local run = smoothstep(12, 21, speed)
	local sprint = math.max(smoothstep(23, 30, speed), if input.sprinting then run else 0)
	local carry = clamp01(input.load)
	local p = input.phase
	local s, c = math.sin(p), math.cos(p)

	-- legs: a walk's easy swing, a run's long stride, flat out in a sprint
	local legSwing = moving * (lerp(0.42, 0.8, run) + 0.22 * sprint)
	-- arms: swing opposite the legs, pumping hard in a sprint; a load holds them in front
	local armSwing = moving * (lerp(0.36, 0.95, run) + 0.3 * sprint) * (1 - 0.75 * carry)
	local armBias = moving * lerp(0.04, 0.35, run) + 0.12 * sprint + 0.8 * carry
	local armOut = 0.05 + 0.08 * run + 0.06 * carry + 0.04 * dread
	local exhausted = if input.exhausted then 1 else 0
	local lean = moving * (lerp(0.03, 0.18, run) + 0.14 * sprint) - 0.06 * carry + 0.15 * exhausted
	local bob = moving * math.abs(c) * lerp(0.07, 0.22, run)
	local twist = -s * moving * lerp(0.05, 0.13, run)
	local roll = c * moving * 0.035 + math.clamp(input.turn * 0.04, -0.14, 0.14) * run
	local crouch = 0.05 * run + 0.35 * input.landing + 0.06 * dread * (1 - moving)

	set(
		out,
		limb(RIGHT, armBias - armSwing * s, armOut, 0.1 * carry),
		limb(LEFT, armBias + armSwing * s, armOut, 0.1 * carry),
		limb(RIGHT, legSwing * s + 0.15 * input.landing, 0.02),
		limb(LEFT, -legSwing * s + 0.1 * input.landing, 0.02)
	)
	out.RootJoint = body(lean + 0.25 * input.landing, roll, twist, bob - crouch)
	-- the head steadies against the bob and twist, and looks where it is told
	out.Neck = head(-lean * 0.75 + input.lookPitch, 0, -twist * 0.9 + input.lookYaw)

	-- standing still: breath in the shoulders, weight shifting, glancing round at every sound
	local still = 1 - moving
	if still > 0.01 then
		local shift = math.noise(now * 0.25, seed % 89) * 0.06
		local glance = math.noise(now * (0.35 + 0.9 * dread), seed % 61 + 7) * (0.5 + 0.9 * dread)
		local winded = exhausted * still
		out.RootJoint = out.RootJoint
			* body((0.03 + depth * breath) * still + 0.45 * winded, shift * still, 0, depth * breath * still)
		local armRest = 0.05 + 0.02 * breath + 0.5 * winded
		out["Right Shoulder"] = out["Right Shoulder"]
			* limb(RIGHT, armRest * still, (0.04 + 0.03 * breath + 0.06 * dread) * still)
		out["Left Shoulder"] = out["Left Shoulder"]
			* limb(LEFT, armRest * still, (0.04 + 0.03 * breath + 0.06 * dread) * still)
		out["Right Hip"] = out["Right Hip"] * limb(RIGHT, 0.04 * still, (0.03 + shift) * still)
		out["Left Hip"] = out["Left Hip"] * limb(LEFT, -0.03 * still, (0.03 - shift) * still)
		out.Neck = out.Neck * head((-0.35 * winded - 0.02 * breath) * still, 0, glance * still * (1 - winded))
	end
	-- on the run with a Hollow behind: a look back over the shoulder, now and then
	if dread > 0.35 and run > 0.5 then
		local look = smoothstep(0.55, 0.75, math.noise(now * 0.6, seed % 53 + 3) + 0.5)
		out.Neck = out.Neck * head(-0.1 * look, 0, 1.15 * look * (if seed % 2 == 0 then 1 else -1))
	end
	return out
end

-- Gone limp: on the ground, or in a Hollow's hands.
function CrewPoses.limp(now: number, seed: number): Pose
	local out: Pose = {}
	local sway = math.sin(now * 1.1 + seed) * 0.05
	out.RootJoint = body(0.1, sway, 0)
	set(out, limb(RIGHT, 0.1, 0.18), limb(LEFT, 0.15, 0.22), limb(RIGHT, 0.05, 0.08), limb(LEFT, -0.04, 0.1))
	out.Neck = head(0.65, 0.35, 0.2)
	return out
end

--[[
	In a Hollow's hands. t: seconds into the hold. struggle: 0..1 how hard they are fighting
	(their own presses on this client; others get a steady fight). life: 0..1 their health.
]]
function CrewPoses.grabbed(
	style: string,
	t: number,
	struggle: number,
	life: number,
	now: number,
	seed: number
): Pose
	local def = Grabs.ById[style]
	if def == nil then
		return CrewPoses.limp(now, seed)
	end
	if life <= 0 then
		return CrewPoses.limp(now, seed)
	end
	local out: Pose = {}
	local k = Grab.squeeze(def, t)
	local amp = (0.45 + 0.55 * clamp01(struggle)) * (0.35 + 0.65 * clamp01(life))
	local a = math.sin(t * 9.5 + seed)
	local b = math.sin(t * 9.5 + seed + 1.3)
	local writhe = math.sin(t * 3.7 + seed) * amp
	if style == "Throttle" then
		-- dangling by the throat: both hands at the hand that holds it, legs kicking at nothing
		local pry = math.sin(t * 6.3) * 0.18 * amp
		set(
			out,
			limb(RIGHT, 2.45 + pry, -0.3, -0.25),
			limb(LEFT, 2.45 - pry, -0.3, -0.25),
			limb(RIGHT, 0.2 + 0.5 * a * amp, 0.05),
			limb(LEFT, 0.2 + 0.5 * b * amp, 0.05)
		)
		out.RootJoint = body(0.06 * writhe, 0.08 * writhe, 0.18 * writhe, 0.12 * k)
		out.Neck = head(-0.5 - 0.25 * k, 0, 0.15 * math.sin(t * 7))
	elseif style == "Embrace" or style == "Bearhug" then
		-- crushed to its chest: arms pinned and shoving, head turned away from its mouth
		local shove = math.sin(t * 5.1 + seed) * 0.25 * amp
		local away = math.sin(t * 1.4 + seed) * 0.95
		local bear = style == "Bearhug"
		set(
			out,
			limb(RIGHT, (if bear then 0.95 else 0.35) + shove, if bear then 0.15 else 0.5),
			limb(LEFT, (if bear then 0.95 else 0.35) - shove, if bear then 0.15 else 0.5),
			limb(RIGHT, 0.15 + 0.35 * a * amp, 0.06),
			limb(LEFT, 0.15 + 0.35 * b * amp, 0.06)
		)
		out.RootJoint = body((if bear then -0.14 else -0.05) - 0.1 * k, 0.12 * writhe, 0.25 * writhe)
		out.Neck = head(if bear then -0.7 - 0.2 * k else -0.2, 0, if bear then 0.2 * writhe else away)
	elseif style == "Drag" or style == "Latch" then
		-- face down, clawing at the ground ahead while it hauls them back by the legs
		local claw = math.sin(t * 5.5 + seed)
		local held = if style == "Latch" then -0.3 else -0.35
		set(
			out,
			limb(RIGHT, 2.75 + 0.4 * claw * amp, 0.15),
			limb(LEFT, 2.75 - 0.4 * claw * amp, 0.15),
			limb(RIGHT, held, 0.04),
			limb(LEFT, if style == "Latch" then held else -0.15 + 0.45 * b * amp, 0.12)
		)
		-- every yank pulls the body back toward the feet
		out.RootJoint = body(0, 0.08 * claw * amp, 0.1 * claw * amp, -0.55 * k)
		out.Neck = head(-0.6, 0, 0.7 * math.sin(t * 1.1 + seed))
	elseif style == "Pin" or style == "Shovel" then
		-- on their back: arms pushing up at what is on them, legs kicking, head thrashing
		local push = math.sin(t * 4.3 + seed) * 0.25 * amp
		local blade = style == "Shovel"
		set(
			out,
			limb(RIGHT, 1.5 + push - 0.3 * k, if blade then -0.25 else -0.1, if blade then -0.2 else 0),
			limb(LEFT, 1.5 - push - 0.3 * k, if blade then -0.25 else -0.1, if blade then -0.2 else 0),
			limb(RIGHT, 0.3 + 0.5 * a * amp, 0.1),
			limb(LEFT, 0.3 + 0.5 * b * amp, 0.1)
		)
		out.RootJoint = body(0, 0.1 * writhe, 0.2 * writhe, -0.15 * k)
		out.Neck = head(-0.15, 0, 0.8 * math.sin(t * 2.3 + seed))
	elseif style == "Ride" then
		-- forced to their knees, reaching back over their shoulders to tear it off
		local tear = math.sin(t * 4.7 + seed) * 0.3 * amp
		set(
			out,
			limb(RIGHT, 2.9 + tear, 0.35),
			limb(LEFT, 2.9 - tear, 0.35),
			limb(RIGHT, -1.4, 0.08),
			limb(LEFT, -1.4, 0.08)
		)
		out.RootJoint = body(0.45 + 0.12 * k + 0.08 * writhe, 0.1 * writhe, 0.15 * writhe)
		out.Neck = head(0.25, 0, -0.6 + 0.2 * math.sin(t * 3))
	elseif style == "Fist" then
		-- in its fist: pushing at its fingers, legs kicking high above the ground
		local shove = math.sin(t * 5.7 + seed) * 0.2 * amp
		set(
			out,
			limb(RIGHT, 0.55 + shove, 0.45),
			limb(LEFT, 0.55 - shove, 0.45),
			limb(RIGHT, 0.12 + 0.4 * a * amp, 0.05),
			limb(LEFT, 0.12 + 0.4 * b * amp, 0.05)
		)
		out.RootJoint = body(0.05 * writhe, 0.1 * writhe + 0.08 * k, 0.15 * writhe, 0.1 * k)
		out.Neck = head(-0.45 - 0.2 * k, 0, 0.2 * math.sin(t * 6.1))
	end
	return out
end

return CrewPoses
