--!strict
--[[
	The Hollows' bodies in motion, as pure CFrame math (no services): HollowAnimator plays
	it on every client, and the audit poses rigs headless to check where the hands land.

	A pose maps joint names to Motor6D.Transform values. Everything is worked out in the
	Hollow's root frame: the root part at the origin, -Z ahead, the ground at rig.ground.

	  rigOf    the skeleton read from a built model: each joint's C0, C1 and parent, each
	           limb bone's length
	  reach    two-bone IK: a hand or foot set down at a point, its elbow or knee bent
	           toward a pole. The Crawler walks on it; every kind grabs with it
	  pose     the whole body for a state: gaits (the Stalker's limp, the Brute's stomp,
	           the Crawler's spider walk on planted hands and feet), sleeping, emerging,
	           the windup and the strike, cowering, reeling, and three grabs per kind
	           (Config/Grabs), each squeezing on the grab's own rhythm
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Grabs = require(Shared.Config.Grabs)
local Tuning = require(Shared.Config.Tuning)
local Grab = require(Shared.Logic.Grab)

export type Pose = { [string]: CFrame }

export type Joint = { name: string, part0: string, part1: string, c0: CFrame, c1: CFrame }

export type Rig = {
	kind: string,
	joints: { [string]: Joint }, -- by joint name
	byPart: { [string]: Joint }, -- the joint that moves each part
	lengths: { [string]: number }, -- limb bones by part name
	ends: { [string]: number }, -- hands and feet by part name: their height
	ground: number, -- the ground's y in the root frame
}

export type Input = {
	state: string,
	elapsed: number, -- seconds into the state
	speed: number, -- horizontal studs per second
	phase: number, -- the gait's phase in radians (HollowAnimator advances it by cadence)
	now: number,
	seed: number,
	emerge: string, -- Rise, Climb or Wake
	stunned: boolean,
	windup: number, -- seconds the windup takes for this kind
	grab: string?, -- the grab's id while holding someone
	grabTime: number, -- seconds into the hold
}

local HollowPoses = {}

local I = CFrame.identity
local ROOT = "HumanoidRootPart"
local shortfall = 0 -- how far the last pose's limbs fell short of their targets

local function A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(x, y, z)
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function easeOut(t: number): number
	local u = 1 - clamp01(t)
	return 1 - u * u * u
end

local function smooth(t: number): number
	local u = clamp01(t)
	return u * u * (3 - 2 * u)
end

-- Rig --------------------------------------------------------------------------------------------

function HollowPoses.rigOf(model: Model): Rig
	local rig: Rig = {
		kind = (model:GetAttribute("Kind") :: string?) or "Stalker",
		joints = {},
		byPart = {},
		lengths = {},
		ends = {},
		ground = -5,
	}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			local joint: Joint = {
				name = d.Name,
				part0 = (d.Part0 :: BasePart).Name,
				part1 = (d.Part1 :: BasePart).Name,
				c0 = d.C0,
				c1 = d.C1,
			}
			rig.joints[d.Name] = joint
			rig.byPart[joint.part1] = joint
		elseif d:IsA("BasePart") then
			local name = d.Name
			for _, bone in { "UpperArm", "Forearm", "Thigh", "Shin" } do
				if string.sub(name, 2) == bone then
					rig.lengths[name] = d.Size.X
				end
			end
			for _, piece in { "Hand", "Foot" } do
				if string.sub(name, 2) == piece then
					rig.ends[name] = d.Size.Y
				end
			end
		end
	end
	local root = model:FindFirstChild(ROOT) :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root and humanoid then
		rig.ground = -(humanoid.HipHeight + root.Size.Y / 2)
	end
	return rig
end

-- The root-frame CFrame of a part under `pose`.
function HollowPoses.frameOf(rig: Rig, pose: Pose, part: string): CFrame
	if part == ROOT then
		return I
	end
	local joint = rig.byPart[part]
	if joint == nil then
		return I
	end
	return HollowPoses.frameOf(rig, pose, joint.part0)
		* joint.c0
		* (pose[joint.name] or I)
		* joint.c1:Inverse()
end

local LIMBS = {
	Arm = { "Shoulder", "Elbow", "Wrist", "UpperArm", "Forearm", "Hand" },
	Leg = { "Hip", "Knee", "Ankle", "Thigh", "Shin", "Foot" },
}

--[[
	Two-bone IK. Sets `side`'s ("L" or "R") arm or leg so its wrist or ankle reaches
	`target` (root frame; clamped to the limb's length), bending the elbow or knee toward
	`pole` (a direction). `palm`, when given, turns the hand or foot to that orientation
	(root frame); otherwise it carries on straight from the forearm.

	A limb bone hangs along its joint frame's -Y (HollowBuilder.limb), and each joint's
	frame is the previous one moved down the bone, so the elbow is J * T1 * (0, -L1, 0)
	and the wrist J * T1 * (0, -L1, 0) * T2 * (0, -L2, 0).
]]
function HollowPoses.reach(
	rig: Rig,
	pose: Pose,
	side: string,
	limb: string,
	target: Vector3,
	pole: Vector3,
	palm: CFrame?
)
	local names = LIMBS[limb]
	local first = side .. names[1]
	local joint = rig.joints[first]
	local l1, l2 = rig.lengths[side .. names[4]], rig.lengths[side .. names[5]]
	if joint == nil or l1 == nil or l2 == nil then
		return
	end
	local frame = HollowPoses.frameOf(rig, pose, joint.part0) * joint.c0
	local p = frame:PointToObjectSpace(target)
	local q = frame:VectorToObjectSpace(pole)
	local d = math.clamp(p.Magnitude, math.abs(l1 - l2) + 0.05, l1 + l2 - 0.05)
	shortfall = math.max(shortfall, p.Magnitude - d)
	local u = if p.Magnitude > 1e-4 then p.Unit else Vector3.new(0, -1, 0)
	local w = q - u * q:Dot(u)
	if w.Magnitude < 1e-4 then
		w = u:Cross(if math.abs(u.X) < 0.9 then Vector3.xAxis else Vector3.zAxis)
	end
	w = w.Unit
	local a = math.acos(math.clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1))
	local dir1 = u * math.cos(a) + w * math.sin(a)
	local dir2 = (u * d - dir1 * l1).Unit
	local bend = math.acos(math.clamp(dir1:Dot(dir2), -1, 1))
	local v = dir2 - dir1 * dir2:Dot(dir1)
	v = if v.Magnitude > 1e-5 then v.Unit else -w
	local y = -dir1
	local z = -v
	local upper = CFrame.fromMatrix(Vector3.zero, y:Cross(z), y, z)
	local lower = A(bend, 0, 0)
	pose[first] = upper
	pose[side .. names[2]] = lower
	if palm then
		local wrist = frame * upper * CFrame.new(0, -l1, 0) * lower * CFrame.new(0, -l2, 0)
		pose[side .. names[3]] = wrist.Rotation:Inverse() * palm.Rotation
	else
		pose[side .. names[3]] = I
	end
end

-- Where a limb's wrist or ankle is under `pose` (the audit checks grabs with it).
function HollowPoses.tip(rig: Rig, pose: Pose, side: string, limb: string): Vector3
	local names = LIMBS[limb]
	local lower = side .. names[5]
	local frame = HollowPoses.frameOf(rig, pose, lower)
	return (frame * CFrame.new(-rig.lengths[lower] / 2, 0, 0)).Position
end

-- Grabs --------------------------------------------------------------------------------------------

-- Where `def` holds its victim's root, in the Hollow's root frame (as HollowService puts it).
function HollowPoses.holdFrame(def: Grabs.Def): CFrame
	local h = def.hold
	local up = Vector3.new(h.up[1], h.up[2], h.up[3]).Unit
	local back = -Vector3.new(h.face[1], h.face[2], h.face[3]).Unit
	return CFrame.fromMatrix(Vector3.new(h.pos[1], h.pos[2], h.pos[3]), up:Cross(back).Unit, up, back)
end

-- Hands that close round something: fingers across it, palm toward it (-Z of the hand faces it).
local function grip(fingers: Vector3, faces: Vector3): CFrame
	local y = -fingers.Unit
	local z = -faces.Unit
	return CFrame.fromMatrix(Vector3.zero, y:Cross(z).Unit, y, z)
end
local LEVEL = I
local DOWN = grip(Vector3.new(0, -1, 0), Vector3.new(0, 0, -1))

-- Contact points on the victim (their own frame: an R6 body, -Z its front), for the audit too.
-- Facing the Hollow, the victim's left is the Hollow's right: L and R here are the Hollow's hands.
local CONTACTS: { [string]: { [string]: Vector3 } } = {
	Throttle = { R = Vector3.new(0.05, 1.05, -0.5) },
	Embrace = { L = Vector3.new(0.75, 0.2, 0.75), R = Vector3.new(-0.75, 0.2, 0.75) },
	Drag = { R = Vector3.new(0.5, -2.7, 0.35) },
	Pin = { L = Vector3.new(1.8, 0.7, 0.6), R = Vector3.new(-1.8, 0.7, 0.6) },
	Latch = { L = Vector3.new(-0.5, -2.7, 0.75), R = Vector3.new(0.5, -2.7, 0.75) },
	Ride = { L = Vector3.new(-0.7, 0.4, -0.8), R = Vector3.new(0.7, 0.4, -0.8) },
	Fist = { L = Vector3.new(0, 0.35, -1.0) },
	Shovel = { R = Vector3.new(0, 0.3, -2.9) },
	Bearhug = { L = Vector3.new(0.8, 0.25, 0.8), R = Vector3.new(-0.8, 0.25, 0.8) },
}
HollowPoses.Contacts = CONTACTS

local function stalkerGrab(rig: Rig, out: Pose, def: Grabs.Def, t: number, now: number, seed: number)
	local v = HollowPoses.holdFrame(def)
	local k = Grab.squeeze(def, t)
	local shake = math.sin(now * 31 + seed) * 0.03
	local c = CONTACTS[def.id]
	if def.id == "Throttle" then
		-- holds them up at arm's length by the throat, its head cocked, leaning in to bite
		out.RootJoint = CFrame.new(0, -0.1, 0.2) * A(0.06, 0, 0)
		out.Waist = A(0.08 - 0.18 * k, -0.2, 0)
		out.LHip, out.RHip = A(0.3, 0, -0.12), A(-0.25, 0, 0.12)
		out.LKnee, out.RKnee = A(-0.4, 0, 0), A(-0.2, 0, 0)
		out.LAnkle, out.RAnkle = A(0.12, 0, 0), A(0.05, 0, 0)
		out.Neck = A(-0.35 - 0.25 * k, -0.15, 0.4 + shake)
		out.Jaw = A(-0.4 - 0.55 * k, 0, 0)
		HollowPoses.reach(
			rig,
			out,
			"R",
			"Arm",
			v * (c.R + Vector3.new(0, 0.08 * k, 0)),
			Vector3.new(0.7, -0.6, 0.6),
			grip(Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))
		)
		local rake = math.sin(t * 5.3 + seed) * 0.4
		HollowPoses.reach(
			rig,
			out,
			"L",
			"Arm",
			v * Vector3.new(-0.3 + rake, 0.15 - 0.4 * k, -0.85),
			Vector3.new(-0.8, -0.4, 0.5),
			nil
		)
	elseif def.id == "Embrace" then
		-- folds them into its ribs, bowed over them, its jaw at their head
		out.RootJoint = CFrame.new(0, -0.45, 0.35) * A(-0.08, 0, 0)
		out.Waist = A(-0.3 - 0.1 * k, 0, 0)
		out.LHip, out.RHip = A(0.55, 0, -0.15), A(0.5, 0, 0.15)
		out.LKnee, out.RKnee = A(-0.9, 0, 0), A(-0.85, 0, 0)
		out.LAnkle, out.RAnkle = A(0.3, 0, 0), A(0.3, 0, 0)
		out.Neck = A(-0.55 - 0.3 * k, math.sin(now * 2.1 + seed) * 0.15, shake)
		out.Jaw = A(-0.6 - 0.45 * k, 0, 0)
		local inward = 0.25 * k
		HollowPoses.reach(
			rig,
			out,
			"L",
			"Arm",
			v * (c.L + Vector3.new(inward, 0, 0)),
			Vector3.new(-1, 0.1, -0.3),
			grip(Vector3.new(1, 0, 0), Vector3.new(0, 0, 1))
		)
		HollowPoses.reach(
			rig,
			out,
			"R",
			"Arm",
			v * (c.R - Vector3.new(inward, 0, 0)),
			Vector3.new(1, 0.1, -0.3),
			grip(Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1))
		)
	else
		-- crouched, it hauls them by the ankle toward the fog, a yank on every beat
		local yank = k * 0.7
		out.RootJoint = CFrame.new(0, -2.5, 0.2 + yank) * A(-0.35, 0, 0)
		out.Waist = A(-0.75 + 0.15 * k, 0.1, 0)
		out.LHip, out.RHip = A(1.25, 0, -0.2), A(0.95, 0, 0.2)
		out.LKnee, out.RKnee = A(-1.9, 0, 0), A(-1.6, 0, 0)
		out.LAnkle, out.RAnkle = A(0.6, 0, 0), A(0.55, 0, 0)
		out.Neck = A(0.45, math.sin(now * 1.3 + seed) * 0.3, 0.3 + shake)
		out.Jaw = A(-0.3 - 0.4 * k, 0, 0)
		HollowPoses.reach(
			rig,
			out,
			"R",
			"Arm",
			v * c.R + Vector3.new(0, 0.3, yank * 0.6),
			Vector3.new(0.7, 0.2, 0.6),
			DOWN
		)
		HollowPoses.reach(
			rig,
			out,
			"L",
			"Arm",
			Vector3.new(-2.1, rig.ground + 0.5, -2.4),
			Vector3.new(-0.7, 0.3, 0.5),
			LEVEL
		)
	end
end

local function bruteGrab(rig: Rig, out: Pose, def: Grabs.Def, t: number, now: number, seed: number)
	local v = HollowPoses.holdFrame(def)
	local k = Grab.squeeze(def, t)
	local c = CONTACTS[def.id]
	local heave = math.sin(now * 2.4 + seed) * 0.04
	if def.id == "Fist" then
		-- lifts them in its fist to its face and closes its hand
		out.RootJoint = CFrame.new(0, -0.2, 0.2) * A(0.05, 0, 0.05)
		out.Waist = A(0.1 + heave, 0.25, 0)
		out.LHip, out.RHip = A(0.2, 0, -0.1), A(-0.15, 0, 0.1)
		out.LKnee, out.RKnee = A(-0.3, 0, 0), A(-0.2, 0, 0)
		out.Neck = A(-0.1 - 0.15 * k, 0.35, 0)
		out.Jaw = A(-0.35 - 0.6 * k, 0, 0)
		HollowPoses.reach(
			rig,
			out,
			"L",
			"Arm",
			v * c.L + Vector3.new(0, 0.5, 0),
			Vector3.new(-0.8, -0.6, 0.4),
			LEVEL
		)
		-- the shovel arm hangs heavy at its side
		out.RShoulder = A(0.15 - 0.1 * k, 0, 0.22)
		out.RElbow = A(0.35, 0, 0)
	elseif def.id == "Shovel" then
		-- pins them under the shovel blade and leans its weight on it
		local lean = 0.35 * k
		out.RootJoint = CFrame.new(0, -1.1 - lean, -0.2) * A(-0.2, 0, -0.08)
		out.Waist = A(-0.55 - 0.25 * k, -0.15, 0)
		out.LHip, out.RHip = A(0.7, 0, -0.25), A(0.2, 0, 0.25)
		out.LKnee, out.RKnee = A(-1.1, 0, 0), A(-0.5, 0, 0)
		out.Neck = A(0.25, -0.1, 0)
		out.Jaw = A(-0.25 - 0.55 * k, 0, 0)
		HollowPoses.reach(
			rig,
			out,
			"R",
			"Arm",
			v * c.R - Vector3.new(0, 0.3 * k, 0),
			Vector3.new(0.8, 0.3, 0.4),
			LEVEL
		)
		-- the fist balled on its knee, pounding the ground on the beat
		HollowPoses.reach(
			rig,
			out,
			"L",
			"Arm",
			Vector3.new(-2.6, rig.ground + 1.4 + 1.6 * (1 - k), -3.4),
			Vector3.new(-0.8, 0.2, 0.5),
			LEVEL
		)
	else
		-- crushes them to the embers in its chest, roaring over their head
		out.RootJoint = CFrame.new(0, -0.3, 0.15) * A(0.12 + 0.08 * k, 0, 0)
		out.Waist = A(-0.05 + heave, 0, 0)
		out.LHip, out.RHip = A(0.25, 0, -0.15), A(0.2, 0, 0.15)
		out.LKnee, out.RKnee = A(-0.45, 0, 0), A(-0.4, 0, 0)
		out.Neck = A(0.25 + 0.2 * k, 0, 0)
		out.Jaw = A(-0.5 - 0.5 * k, 0, 0)
		local inward = 0.3 * k
		HollowPoses.reach(
			rig,
			out,
			"L",
			"Arm",
			v * (c.L + Vector3.new(inward, 0, 0)),
			Vector3.new(-1, 0, -0.2),
			LEVEL
		)
		HollowPoses.reach(
			rig,
			out,
			"R",
			"Arm",
			v * (c.R - Vector3.new(inward, 0, 0)),
			Vector3.new(1, 0, -0.2),
			LEVEL
		)
	end
end

-- The Crawler ------------------------------------------------------------------------------------

-- Where each of the Crawler's hands and feet rests (x, z in the root frame) and where its
-- elbow or knee points: up and out, over its back.
local CRAWL = {
	{ side = "L", limb = "Arm", x = -3.6, z = -4.6, offset = 0, pole = Vector3.new(-0.7, 1, 0.3) },
	{ side = "R", limb = "Arm", x = 3.6, z = -4.6, offset = math.pi, pole = Vector3.new(0.7, 1, 0.3) },
	{ side = "L", limb = "Leg", x = -3.0, z = 3.8, offset = math.pi, pole = Vector3.new(-0.7, 1, -0.3) },
	{ side = "R", limb = "Leg", x = 3.0, z = 3.8, offset = 0, pole = Vector3.new(0.7, 1, -0.3) },
}
local DUTY = 0.62 -- share of a step a foot stays planted

-- The Crawler's step length at a speed (its feet never slide: the cadence follows).
local function crawlStep(speed: number): number
	return math.clamp(speed * 0.4, 0.6, 4)
end

local function plant(rig: Rig, out: Pose, spot: typeof(CRAWL[1]), dx: number, dz: number, lift: number)
	local height = rig.ends[spot.side .. (if spot.limb == "Arm" then "Hand" else "Foot")] or 0.26
	HollowPoses.reach(
		rig,
		out,
		spot.side,
		spot.limb,
		Vector3.new(spot.x + dx, rig.ground + height + lift, spot.z + dz),
		spot.pole,
		LEVEL
	)
end

local function crawlerGait(rig: Rig, out: Pose, input: Input, hunt: boolean)
	local p = input.phase
	local speed = input.speed
	local stride = math.min(speed / 12, 1.4)
	local step = crawlStep(speed)
	local now, seed = input.now, input.seed
	local a = math.sin(p)
	-- low and long when it hunts; the spine rolls with the gait, the head scans
	out.RootJoint = CFrame.new(0, math.abs(a) * 0.22 * stride - (if hunt then 0.45 else 0), 0)
		* A(0, a * 0.08 * stride, a * 0.06 * stride)
	out.Waist = A(if hunt then -0.12 else 0, -a * 0.1 * stride, 0)
	out.Neck = A(if hunt then -0.2 else 0, math.sin(now * 1.7 + seed) * 0.45, 0)
	out.Jaw = A(if hunt then -0.4 - 0.3 * math.abs(math.sin(now * 17)) else -0.12, 0, 0)
	for i, spot in CRAWL do
		if speed < 0.8 then
			-- still: one long finger after another lifts and taps the ground
			local tap = (now * 0.8 + i * 0.25 + seed * 0.01) % 1
			local lift = if tap < 0.12 then math.sin(tap / 0.12 * math.pi) * 0.5 else 0
			plant(rig, out, spot, 0, 0, lift)
		else
			local cycle = ((p + spot.offset) % (2 * math.pi)) / (2 * math.pi)
			local dz, lift
			if cycle < DUTY then
				-- planted: the foot stays put while the body passes over it
				dz = (cycle / DUTY - 0.5) * step
				lift = 0
			else
				local s = (cycle - DUTY) / (1 - DUTY)
				dz = (0.5 - smooth(s)) * step
				lift = math.sin(s * math.pi) * (0.6 + 0.9 * stride)
			end
			plant(rig, out, spot, 0, dz, lift)
		end
	end
end

local function crawlerDormant(rig: Rig, out: Pose, now: number, seed: number)
	local breathe = math.sin(now * 1.3 + seed) * 0.05
	out.RootJoint = CFrame.new(0, -2.0 + breathe, 0) * A(0, 0, 0.3)
	out.Waist = A(-0.1, 0.2, 0)
	out.Neck = A(0.5, 0.4, 0)
	out.Jaw = A(-0.15, 0, 0)
	for _, spot in CRAWL do
		local tuck = if spot.limb == "Arm" then Vector3.new(-1.8, 0, 1.4) else Vector3.new(-1.4, 0, -1.2)
		plant(rig, out, spot, tuck.X * (if spot.side == "L" then -1 else 1), tuck.Z, 0)
	end
end

local function crawlerEmerge(rig: Rig, out: Pose, input: Input, t: number)
	local under = 1 - easeOut(t)
	local depth = 6
	local claw = math.sin(input.now * 14 + input.seed) * 0.4 * under
	if input.emerge == "Climb" then
		out.RootJoint = CFrame.new(0, -depth * under, 3.5 * under) * A(0.9 * under, 0, 0)
	else
		out.RootJoint = CFrame.new(0, -depth * under, 0) * A(0.5 * under, 0, 0)
	end
	out.Neck = A(-0.4 * under, math.sin(input.now * 9) * 0.3 * under, 0)
	out.Jaw = A(-1.0 * clamp01((t - 0.6) / 0.2), 0, 0)
	for _, spot in CRAWL do
		if spot.limb == "Arm" then
			-- the hands haul it up over the lip of the ground
			plant(rig, out, spot, 0, claw - 0.4 * under, 0)
		else
			plant(rig, out, spot, 0, 0, 0)
		end
	end
end

local function crawlerAttack(rig: Rig, out: Pose, input: Input, windup: number?, strike: number?)
	if windup then
		-- rears up like a mantis: forelimbs high and spread, the head hanging open-mouthed
		local e = easeOut(windup)
		local shake = math.sin(input.now * 50) * 0.05 * e
		out.RootJoint = CFrame.new(0, 0.4 * e, 0.9 * e) * A(0.35 * e, 0, 0)
		out.Waist = A(0.55 * e, 0, 0)
		out.Neck = A(0.4 * e + shake, shake, 0)
		out.Jaw = A(-1.15 * e, 0, 0)
		for _, spot in CRAWL do
			if spot.limb == "Arm" then
				local s = if spot.side == "L" then -1 else 1
				HollowPoses.reach(
					rig,
					out,
					spot.side,
					"Arm",
					Vector3.new(s * (3.6 + 0.8 * e), rig.ground + 0.3 + 5.2 * e, -4.6 + 0.6 * e),
					Vector3.new(s, 0.6, 0.5),
					grip(Vector3.new(0, 0.3, -1), Vector3.new(-s, 0, 0))
				)
			else
				plant(rig, out, spot, 0, 0.8 * e, 0)
			end
		end
	elseif strike then
		-- the pounce: it throws itself forward, claws first
		local s = easeOut(strike)
		out.RootJoint = CFrame.new(0, math.sin(math.pi * s) * 1.2, -2.6 * s) * A(0.2 * (1 - s), 0, 0)
		out.Waist = A(0.15 * s, 0, 0)
		out.Jaw = A(-1.1 * (1 - s), 0, 0)
		for _, spot in CRAWL do
			if spot.limb == "Arm" then
				local x = if spot.side == "L" then -1.9 else 1.9
				HollowPoses.reach(
					rig,
					out,
					spot.side,
					"Arm",
					Vector3.new(x, rig.ground + 0.4 + 1.2 * (1 - s), -7.6 * s - 4.6 * (1 - s)),
					spot.pole,
					LEVEL
				)
			else
				-- the hind feet drag after the lunge
				plant(rig, out, spot, 0, -1.2 * s, 0)
			end
		end
	end
end

local function crawlerCower(rig: Rig, out: Pose, now: number, reeling: number?)
	local shiver = math.sin(now * 40) * 0.05
	if reeling then
		-- thrown off its prey: it scrabbles back, limbs everywhere
		local e = 1 - clamp01(reeling)
		out.RootJoint = CFrame.new(0, 0.5 * e, 1.8 * e) * A(0.35 * e, 0, shiver)
		out.Neck = A(-0.5, math.sin(now * 13) * 0.6, 0)
		out.Jaw = A(-0.8, 0, 0)
		for i, spot in CRAWL do
			-- the footholds go back with the body, the limbs scrabbling round them
			local flail = math.sin(now * 11 + i * 1.7) * 0.9 * e
			plant(rig, out, spot, flail * 0.4, 1.8 * e + flail * 0.7, 0.5 * e + math.max(flail, 0))
		end
		return
	end
	out.RootJoint = CFrame.new(0, -1.3, 0.8) * A(0, 0, shiver)
	out.Waist = A(0.2, 0, 0)
	out.Neck = A(0.6, 0.7 + shiver, 0)
	out.Jaw = A(-0.5, 0, 0)
	for _, spot in CRAWL do
		local s = if spot.side == "L" then 1 else -1
		plant(rig, out, spot, s * 1.2, if spot.limb == "Arm" then 1.5 else -1.2, 0)
	end
end

local function crawlerGrab(rig: Rig, out: Pose, def: Grabs.Def, t: number, now: number, seed: number)
	local v = HollowPoses.holdFrame(def)
	local k = Grab.squeeze(def, t)
	local c = CONTACTS[def.id]
	local chatter = math.abs(math.sin(now * 19 + seed))
	if def.id == "Pin" then
		-- spread over them, hands pinning their shoulders, the upside-down head at their face
		out.RootJoint = CFrame.new(0, -1.15 - 0.3 * k, -0.6) * A(-0.05, 0, 0)
		out.Waist = A(-0.1 - 0.12 * k, 0, 0)
		out.Neck = A(0.3 + 0.35 * k, math.sin(now * 5 + seed) * 0.25, 0)
		out.Jaw = A(-0.5 - 0.5 * chatter, 0, 0)
		for _, spot in CRAWL do
			if spot.limb == "Arm" then
				local target = v * (if spot.side == "L" then c.L else c.R)
				HollowPoses.reach(
					rig,
					out,
					spot.side,
					"Arm",
					Vector3.new(target.X, rig.ground + 0.4, target.Z),
					spot.pole,
					LEVEL
				)
			else
				plant(rig, out, spot, 0, -0.6, 0)
			end
		end
	elseif def.id == "Latch" then
		-- low behind them, both hands locked round their ankles, hauling back on the beat
		local yank = 0.7 * k
		out.RootJoint = CFrame.new(0, -0.9, 0.4 + yank) * A(-0.12, 0, 0)
		out.Waist = A(-0.1, 0, 0)
		out.Neck = A(0.3, math.sin(now * 7 + seed) * 0.5, 0)
		out.Jaw = A(-0.4 - 0.4 * chatter, 0, 0)
		for _, spot in CRAWL do
			if spot.limb == "Arm" then
				local ankle = v * (if spot.side == "L" then c.L else c.R)
				HollowPoses.reach(
					rig,
					out,
					spot.side,
					"Arm",
					ankle + Vector3.new(0, 0.3, yank * 0.5),
					spot.pole,
					DOWN
				)
			else
				plant(rig, out, spot, 0, 0.4, 0)
			end
		end
	else
		-- on their back: it rides them down, arms locked round their chest, biting at their neck
		-- its head comes round beside theirs, at the side of the neck
		out.RootJoint = CFrame.new(0.9, -0.5 + 0.15 * k, -1.2)
			* A(-0.2, -0.12, math.sin(now * 3 + seed) * 0.08)
		out.Waist = A(-0.15 + 0.1 * k, 0, 0)
		out.Neck = A(0.75 + 0.3 * k, 0.35, 0)
		out.Jaw = A(-0.6 - 0.45 * chatter, 0, 0)
		for _, spot in CRAWL do
			if spot.limb == "Arm" then
				local s = if spot.side == "L" then -1 else 1
				local hold = v * (if spot.side == "L" then c.L else c.R)
				HollowPoses.reach(
					rig,
					out,
					spot.side,
					"Arm",
					hold - Vector3.new(s * 0.2 * k, 0, 0),
					Vector3.new(s, 0.3, 0.2),
					LEVEL
				)
			else
				plant(rig, out, spot, 0, -1.5, 0)
			end
		end
	end
end

-- The bipeds (the Stalker and the Brute) --------------------------------------------------------------

local function stalkerGait(out: Pose, p: number, stride: number, hunt: boolean, now: number, seed: number)
	local lean = if hunt then -0.5 else -0.1
	local l, r = math.sin(p), math.sin(p + math.pi)
	-- the left leg strides, the right drags: a limp
	out.LHip = A(l * 0.62 * stride, 0, -0.04)
	out.RHip = A(r * 0.4 * stride, 0, 0.06)
	out.LKnee = A(-math.max(0, math.cos(p)) * 1.1 * stride - 0.06, 0, 0)
	out.RKnee = A(-math.max(0, math.cos(p + math.pi)) * 0.45 * stride - 0.05, 0, 0)
	out.LAnkle = A(math.max(0, -math.cos(p)) * 0.3 * stride, 0, 0)
	out.RAnkle = A(0.25 * stride, 0, 0)
	local bob = math.abs(l) * 0.22 * stride
	out.RootJoint = CFrame.new(0, bob - 0.1 * stride, 0)
		* A(lean * 0.4, l * 0.08 * stride, l * 0.1 * stride + 0.06)
	out.Waist = A(lean * 0.6 + math.sin(p * 2) * 0.03, l * 0.12 * stride, 0)
	if hunt then
		local reach = l * 0.8 * stride
		out.LShoulder = A(-0.6 + reach, 0, -0.25)
		out.RShoulder = A(-0.6 - reach, 0, 0.25)
		out.LElbow = A(0.55, 0, 0)
		out.RElbow = A(0.55, 0, 0)
		out.Neck = A(0.55, 0, 0)
		out.Jaw = A(-0.25 - 0.1 * math.sin(now * 9 + seed), 0, 0)
	else
		out.LShoulder = A(-r * 0.25 * stride + 0.05, 0, -0.06 - 0.04 * math.sin(p * 0.5))
		out.RShoulder = A(-l * 0.25 * stride + 0.05, 0, 0.06 + 0.04 * math.sin(p * 0.5))
		out.LElbow = A(0.15 + 0.1 * math.max(0, l), 0, 0)
		out.RElbow = A(0.15 + 0.1 * math.max(0, r), 0, 0)
		out.Neck = A(-0.1, 0.25 * math.sin(now * 0.7 + seed), 0.38)
		out.Jaw = A(-0.12, 0, 0)
	end
	out.LWrist = A(0.2, 0, 0)
	out.RWrist = A(0.2, 0, 0)
end

local function bruteGait(out: Pose, p: number, stride: number, hunt: boolean, now: number, seed: number)
	local l, r = math.sin(p), math.sin(p + math.pi)
	out.LHip = A(l * 0.45 * stride, 0, -0.05)
	out.RHip = A(r * 0.45 * stride, 0, 0.05)
	out.LKnee = A(-math.max(0, math.cos(p)) * 0.8 * stride - 0.1, 0, 0)
	out.RKnee = A(-math.max(0, math.cos(p + math.pi)) * 0.8 * stride - 0.1, 0, 0)
	out.RootJoint = CFrame.new(0, -math.abs(l) * 0.25 * stride, 0) * A(0, l * 0.1 * stride, l * 0.12 * stride)
	out.Waist = A((if hunt then -0.25 else 0) + math.sin(now * 1.2 + seed) * 0.03, -l * 0.15 * stride, 0)
	-- the fist swings; the shovel arm hangs heavy and scrapes
	out.LShoulder = A(-r * 0.5 * stride, 0, -0.2)
	out.RShoulder = A(-l * 0.2 * stride + 0.1, 0, 0.18)
	out.LElbow = A(0.4, 0, 0)
	out.RElbow = A(0.2, 0, 0)
	out.Neck = A(if hunt then 0.3 else 0.1, math.sin(now * 0.6 + seed) * 0.2, 0)
	out.Jaw = A(if hunt then -0.3 else -0.1, 0, 0)
end

local function bipedDormant(kind: string, now: number, seed: number): Pose
	local breathe = math.sin(now * 1.3 + seed) * 0.04
	if kind == "Brute" then
		return {
			RootJoint = CFrame.new(0, -2.3, 0.4) * A(-0.1, 0, 0),
			LHip = A(1.3, 0, -0.1),
			RHip = A(0.4, 0, 0.1),
			LKnee = A(-1.6, 0, 0),
			RKnee = A(-1.9, 0, 0),
			Waist = A(-0.55 + breathe, 0, 0),
			Neck = A(-0.7, 0, 0),
			LShoulder = A(0.3, 0, -0.1),
			RShoulder = A(0.6, 0, 0.1),
			LElbow = A(0.6, 0, 0),
			RElbow = A(0.3, 0, 0),
		}
	end
	return {
		RootJoint = CFrame.new(0, -2.9, 0.6) * A(-0.15, 0, 0.08),
		LHip = A(1.45, 0, -0.12),
		RHip = A(1.35, 0, 0.18),
		LKnee = A(-0.25, 0, 0),
		RKnee = A(-0.55, 0, 0),
		Waist = A(-0.55 + breathe, 0, 0.1),
		Neck = A(-0.75, 0.2, 0.35),
		LShoulder = A(0.1, 0, -0.15),
		RShoulder = A(0.25, 0, 0.12),
		LElbow = A(0.2, 0, 0),
		RElbow = A(0.4, 0, 0),
		Jaw = A(-0.2, 0, 0),
	}
end

local function bipedEmerge(kind: string, out: Pose, input: Input, t: number)
	local under = 1 - easeOut(t)
	local depth = if kind == "Brute" then 10 else 9
	local claw = math.sin(input.now * 14 + input.seed) * 0.18 * under
	if input.emerge == "Climb" then
		out.RootJoint = CFrame.new(0, -depth * under, 3.5 * under) * A(-0.9 * under, 0, 0)
		out.LShoulder = A(1.7 + 0.9 * under + claw, 0, -0.3)
		out.RShoulder = A(1.7 + 0.9 * under - claw, 0, 0.3)
		out.LElbow = A(0.9 * under, 0, 0)
		out.RElbow = A(0.9 * under, 0, 0)
		out.Neck = A(0.4 * under, 0, 0)
	else
		out.RootJoint = CFrame.new(0, -depth * under, 0) * A(-0.6 * under, 0, 0)
		out.LShoulder = A(2.8 * under + claw, 0, -0.3 * under)
		out.RShoulder = A(2.8 * under - claw, 0, 0.3 * under)
		out.LElbow = A(0.6 * under, 0, 0)
		out.RElbow = A(0.6 * under, 0, 0)
		out.Neck = A(-0.8 * under + 0.3 * t, 0, 0)
	end
	-- it screams as it frees itself
	out.Jaw = A(-0.9 * clamp01((t - 0.65) / 0.2) * clamp01((1 - t) / 0.1 + 0.3), 0, 0)
end

local function bipedAttack(kind: string, out: Pose, windup: number?, strike: number?, now: number)
	if windup then
		local e = easeOut(windup)
		local shake = math.sin(now * 50) * 0.04 * e
		if kind == "Brute" then
			out.Waist = A(0.35 * e, 0, 0)
			out.LShoulder = A(2.9 * e, 0, -0.25 * e)
			out.RShoulder = A(2.9 * e, 0, 0.25 * e)
			out.LElbow = A(0.3 * e, 0, 0)
			out.RElbow = A(0.3 * e, 0, 0)
			out.Neck = A(0.5 * e + shake, 0, 0)
			out.Jaw = A(-0.8 * e, 0, 0)
		else
			out.Waist = A(-0.1 + 0.45 * e, 0, 0)
			out.LShoulder = A(2.6 * e, 0, -0.35 * e)
			out.RShoulder = A(2.6 * e, 0, 0.35 * e)
			out.LElbow = A(0.5 * e, 0, 0)
			out.RElbow = A(0.5 * e, 0, 0)
			out.Neck = A(0.5 * e + shake, shake, 0)
			out.Jaw = A(-0.95 * e, 0, 0)
		end
	elseif strike then
		local s = easeOut(strike)
		if kind == "Brute" then
			out.RootJoint = CFrame.new(0, -0.6 * s, -0.4 * s)
			out.Waist = A(0.35 - 1.05 * s, 0, 0)
			out.LShoulder = A(2.9 - 2.4 * s, 0, -0.25)
			out.RShoulder = A(2.9 - 2.4 * s, 0, 0.25)
			out.Neck = A(0.3, 0, 0)
			out.Jaw = A(-0.8 * (1 - s), 0, 0)
		else
			out.RootJoint = CFrame.new(0, 0, -0.8 * s)
			out.Waist = A(0.35 - 0.85 * s, 0, 0)
			out.LShoulder = A(2.6 - 2.25 * s, 0, -0.35 * (1 - s))
			out.RShoulder = A(2.6 - 2.25 * s, 0, 0.35 * (1 - s))
			out.LElbow = A(0.5 * (1 - s), 0, 0)
			out.RElbow = A(0.5 * (1 - s), 0, 0)
			out.Neck = A(0.5, 0, 0)
			out.Jaw = A(-0.95 * (1 - s) - 0.1, 0, 0)
		end
	end
end

local function bipedCower(out: Pose, now: number, stunned: boolean, reeling: number?)
	local shiver = math.sin(now * 40) * 0.05
	if reeling then
		-- thrown off its prey: it staggers back clutching at the air, head shaking
		local e = 1 - clamp01(reeling)
		out.RootJoint = CFrame.new(0, -0.2 * e, 0.8 * e) * A(-0.25 * e, 0, shiver)
		out.Waist = A(-0.3 * e, 0, 0)
		out.LShoulder = A(1.8 * e + math.sin(now * 9) * 0.5, 0, -0.6 * e)
		out.RShoulder = A(1.6 * e + math.sin(now * 8 + 1) * 0.5, 0, 0.6 * e)
		out.LElbow = A(0.8, 0, 0)
		out.RElbow = A(0.8, 0, 0)
		out.Neck = A(-0.3, math.sin(now * 14) * 0.5 * e, 0)
		out.Jaw = A(-0.9, 0, 0)
		return
	end
	out.LShoulder = A(2.1 + shiver, 0, 0.55)
	out.RShoulder = A(2.1 - shiver, 0, -0.55)
	out.LElbow = A(1.5, 0, 0)
	out.RElbow = A(1.5, 0, 0)
	out.Waist = A((if stunned then 0.35 else 0.15) + shiver, 0, 0)
	out.Neck = A(-0.4, (if stunned then 0 else 0.8) + shiver, 0)
	out.Jaw = A(-0.5, 0, 0)
	out.RootJoint = CFrame.new(0, -0.4, 0.3) * A(0, 0, shiver)
end

-- Cadence -----------------------------------------------------------------------------------------

-- Radians per second the gait's phase runs at `speed`. The Crawler's feet stay planted:
-- each one covers its step while the body passes over it.
function HollowPoses.cadence(kind: string, speed: number): number
	if kind == "Crawler" then
		if speed < 0.8 then
			return 1.5
		end
		return 2 * math.pi * DUTY * speed / crawlStep(speed)
	end
	local strideLength = if kind == "Brute" then 9 else 7.5
	return 1.5 + speed / strideLength * math.pi
end

-- The pose ---------------------------------------------------------------------------------------

-- How many studs the last pose's hands or feet fell short of where they were sent (the audit
-- holds every grab and every step of the Crawler's gait to it).
function HollowPoses.shortfall(): number
	return shortfall
end

-- The whole body for this moment. Joints the state leaves alone rest at identity.
function HollowPoses.pose(rig: Rig, input: Input): Pose
	shortfall = 0
	local kind = rig.kind
	local out: Pose = {}
	local state = input.state
	local hunt = state == "Hunt" or state == "Windup" or state == "Recover"
	local stride = math.min(input.speed / 12, 1.4)
	local crawler = kind == "Crawler"
	local function gait(target: Pose, isHunting: boolean, speedOverride: number?)
		if crawler then
			local inner = table.clone(input)
			inner.speed = speedOverride or input.speed
			crawlerGait(rig, target, inner, isHunting)
		elseif kind == "Brute" then
			bruteGait(
				target,
				input.phase,
				if speedOverride then 0 else stride,
				isHunting,
				input.now,
				input.seed
			)
		else
			stalkerGait(
				target,
				input.phase,
				if speedOverride then 0 else stride,
				isHunting,
				input.now,
				input.seed
			)
		end
	end

	if state == "Grab" and input.grab then
		local def = Grabs.ById[input.grab]
		if def then
			if crawler then
				crawlerGrab(rig, out, def, input.grabTime, input.now, input.seed)
			elseif kind == "Brute" then
				bruteGrab(rig, out, def, input.grabTime, input.now, input.seed)
			else
				stalkerGrab(rig, out, def, input.grabTime, input.now, input.seed)
			end
			return out
		end
	end
	if state == "Dormant" then
		if crawler then
			crawlerDormant(rig, out, input.now, input.seed)
			return out
		end
		return bipedDormant(kind, input.now, input.seed)
	end
	if state == "Emerge" and input.emerge == "Wake" then
		-- it unfolds in jerks, not smoothly
		local t = clamp01(input.elapsed / Tuning.Hollow.EmergeSeconds)
		local jerk = math.floor(t * 5) / 5 + (t * 5 % 1) ^ 6 / 5
		local asleep: Pose = {}
		local standing: Pose = {}
		if crawler then
			crawlerDormant(rig, asleep, input.now, input.seed)
		else
			asleep = bipedDormant(kind, input.now, input.seed)
		end
		gait(standing, true, 0)
		for name, value in asleep do
			out[name] = value:Lerp(standing[name] or I, jerk)
		end
		for name, value in standing do
			if (out[name] :: CFrame?) == nil then
				out[name] = I:Lerp(value, jerk)
			end
		end
		if t < 0.25 then
			out.Neck = A(0.35, 0, 0) -- the head comes up first
		end
		out.Jaw = A(-0.9 * clamp01((t - 0.7) / 0.15), 0, 0)
		return out
	end
	if state == "Emerge" then
		local t = clamp01(input.elapsed / Tuning.Hollow.EmergeSeconds)
		if crawler then
			crawlerEmerge(rig, out, input, t)
		else
			gait(out, false, 0)
			bipedEmerge(kind, out, input, t)
		end
		return out
	end
	if input.stunned or state == "Stunned" then
		if crawler then
			crawlerCower(rig, out, input.now, nil)
		else
			bipedCower(out, input.now, true, nil)
		end
		return out
	end
	if state == "Reel" then
		local t = input.elapsed / Tuning.Grab.Stagger
		if crawler then
			crawlerCower(rig, out, input.now, t)
		else
			gait(out, false)
			bipedCower(out, input.now, false, t)
		end
		return out
	end
	if state == "Repelled" then
		if crawler then
			crawlerCower(rig, out, input.now, nil)
		else
			gait(out, false)
			bipedCower(out, input.now, false, nil)
		end
		return out
	end
	gait(out, hunt)
	if state == "Windup" then
		local w = clamp01(input.elapsed / input.windup)
		if crawler then
			crawlerAttack(rig, out, input, w, nil)
		else
			bipedAttack(kind, out, w, nil, input.now)
		end
	elseif state == "Recover" and input.elapsed < 0.3 then
		local s = clamp01(input.elapsed / 0.18)
		if crawler then
			crawlerAttack(rig, out, input, nil, s)
		else
			bipedAttack(kind, out, nil, s, input.now)
		end
	end
	return out
end

return HollowPoses
