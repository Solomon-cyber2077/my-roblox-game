--!strict
--[[
	The Hollows' body language as numbers (docs/FINAL-DESIGN.md Prompt 3). Pure: Controllers/
	HollowAnimator applies these to Animation/HollowPoses' output on every client.

	  aim       the head's yaw toward its target (or a prowl's slow scan), lagging LookLag and capped
	            per kind (Stalker 70, Crawler 50, Brute 35 degrees)
	  lean      the torso leaning into acceleration and out of deceleration, clamped
	  blend     how a state change moves the body: ordinary changes (Prowl, Stalk, Hunt, Recover,
	            Repelled) blend over BlendSeconds with ease-out; coil, windup and lunge snap
	  plants    which feet came down between two gait phases: the step sound plays on these, never
	            on a timer
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)

local M = Tuning.HollowMotion

local HollowMotion = {}

local BLENDED = { Prowl = true, Stalk = true, Hunt = true, Recover = true, Repelled = true }
local SNAP = { Coil = true, Windup = true, Lunge = true }

-- Radians the head of `kind` may turn from straight ahead.
function HollowMotion.cap(kind: string): number
	local caps = M.LookCap :: { [string]: number }
	return math.rad(caps[kind] or caps.Stalker)
end

--[[
	The yaw toward a target at (x, z) in the Hollow's root frame (-Z ahead, +X right): positive turns
	the head left. Capped per kind.
]]
function HollowMotion.yawTo(kind: string, x: number, z: number): number
	if x * x + z * z < 1e-6 then
		return 0
	end
	local cap = HollowMotion.cap(kind)
	return math.clamp(math.atan2(-x, -z), -cap, cap)
end

-- A prowling head's slow scan at time `t`.
function HollowMotion.scan(kind: string, t: number, seed: number): number
	local amount = math.min(math.rad(M.ScanDegrees), HollowMotion.cap(kind))
	return amount * math.sin(t * M.ScanRate * 2 * math.pi + seed)
end

-- Eases `current` toward `goal` with the head's lag (time constant LookLag).
function HollowMotion.follow(current: number, goal: number, dt: number): number
	return current + (goal - current) * (1 - math.exp(-math.max(dt, 0) / M.LookLag))
end

-- Torso pitch for a forward acceleration (studs/s^2): negative leans forward, clamped to LeanMax.
function HollowMotion.lean(accel: number): number
	return -math.clamp(accel * M.LeanPerAccel, -M.LeanMax, M.LeanMax)
end

-- Seconds a change from pose `from` to `to` blends over: 0 snaps.
function HollowMotion.blendSeconds(from: string, to: string): number
	if SNAP[to] then
		return 0
	end
	if BLENDED[from] and BLENDED[to] then
		return M.BlendSeconds
	end
	return 0
end

function HollowMotion.easeOut(t: number): number
	local u = 1 - math.clamp(t, 0, 1)
	return 1 - u * u * u
end

local TAU = 2 * math.pi

-- Whether the angle `at` (mod 2 pi) was crossed going from `before` to `after` (after >= before).
local function crossed(before: number, after: number, at: number): boolean
	if after <= before then
		return false
	end
	local k = math.ceil((before - at) / TAU)
	return at + k * TAU <= after and at + k * TAU > before
end

--[[
	Feet set down between two gait phases. The bipeds plant a heel as each hip reaches its forward
	swing (left at pi/2, right at 3pi/2); each of the Crawler's four limbs plants as its swing ends
	(its cycle wraps), the arms and legs paired as Animation/HollowPoses walks them.
]]
function HollowMotion.plants(kind: string, before: number, after: number): { string }
	local out: { string } = {}
	if kind == "Crawler" then
		local limbs: { { name: string, offset: number } } = {
			{ name = "LArm", offset = 0 },
			{ name = "RArm", offset = math.pi },
			{ name = "LLeg", offset = math.pi },
			{ name = "RLeg", offset = 0 },
		}
		for _, limb in limbs do
			-- the limb's cycle is (phase + offset) mod 2 pi: it wraps where phase = -offset
			if crossed(before, after, -limb.offset) then
				table.insert(out, limb.name)
			end
		end
	else
		if crossed(before, after, math.pi / 2) then
			table.insert(out, "L")
		end
		if crossed(before, after, 3 * math.pi / 2) then
			table.insert(out, "R")
		end
	end
	return out
end

return table.freeze(HollowMotion)
