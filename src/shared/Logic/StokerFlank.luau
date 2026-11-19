--!strict
--[[
	The Stoker's cunning approach (code id Brute, Tuning.BruteRemake.Flank): having seen someone, he sometimes
	doesn't come straight on but swings wide and comes round to their side or back, the shovel lifted so only
	his footsteps are heard. Pure: positions in, points and verdicts out (Services/HollowService walks him).

	  tries     whether this sighting starts a flank (distance band and a 0..1 roll under Chance)
	  plan      the two legs: a bow out to one side of the straight line, then the spot beside and behind them
	  goal      the leg he walks now, from where they stand and face at this moment
	  ends      why the flank is over, or nil while it goes on
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local F = Tuning.BruteRemake.Flank

export type Flank = { side: number, leg: number, startedAt: number }

local StokerFlank = {}

-- Points are flat (x, z) pairs on the ground; facings are (x, z) directions.
export type Point = { x: number, z: number }

local function len(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

function StokerFlank.tries(distance: number, roll: number): boolean
	return F.Enabled and distance >= F.Min and distance <= F.Max and roll < F.Chance
end

-- A new flank at `now`; `roll` in 0..1 picks the side he swings out to (-1 left of the line, 1 right).
function StokerFlank.plan(now: number, roll: number): Flank
	return { side = if roll < 0.5 then -1 else 1, leg = 1, startedAt = now }
end

-- Where he walks now. Leg 1: the bow, out from the middle of the straight line toward his side.
-- Leg 2: Radius from them, Behind radians round from where they face, on his side.
function StokerFlank.goal(flank: Flank, own: Point, prey: Point, facing: Point): Point
	local lx, lz = prey.x - own.x, prey.z - own.z
	local distance = len(lx, lz)
	if flank.leg == 1 and distance > 0.1 then
		-- across the line (its right-hand normal on the ground), times the side
		local ax, az = -lz / distance * flank.side, lx / distance * flank.side
		return {
			x = own.x + lx * 0.5 + ax * distance * F.Swing,
			z = own.z + lz * 0.5 + az * distance * F.Swing,
		}
	end
	local fx, fz = facing.x, facing.z
	local f = len(fx, fz)
	if f > 0.1 then
		fx, fz = fx / f, fz / f
	elseif distance > 0.1 then
		fx, fz = -lx / distance, -lz / distance
	else
		fx, fz = 0, 1
	end
	local angle = F.Behind * flank.side
	local c, s = math.cos(angle), math.sin(angle)
	-- the facing turned by `angle` about the vertical
	local rx, rz = fx * c - fz * s, fx * s + fz * c
	return { x = prey.x + rx * F.Radius, z = prey.z + rz * F.Radius }
end

-- The next leg once he reaches this one's goal (within Arrive studs): leg 1 -> 2; past leg 2, "Round".
function StokerFlank.advance(flank: Flank, own: Point, goal: Point): string?
	if len(goal.x - own.x, goal.z - own.z) > F.Arrive then
		return nil
	end
	if flank.leg == 1 then
		flank.leg = 2
		return nil
	end
	return "Round"
end

-- Why it is over: "Seen" (they face him from inside SeenRange and he is in sight), "Late" (Seconds passed),
-- or nil.
function StokerFlank.ends(
	flank: Flank,
	now: number,
	own: Point,
	prey: Point,
	facing: Point,
	visible: boolean
): string?
	if now - flank.startedAt >= F.Seconds then
		return "Late"
	end
	local tx, tz = own.x - prey.x, own.z - prey.z
	local t, f = len(tx, tz), len(facing.x, facing.z)
	if
		visible
		and t <= F.SeenRange
		and t > 0.1
		and f > 0.1
		and (tx * facing.x + tz * facing.z) / (t * f) >= F.Seen
	then
		return "Seen"
	end
	return nil
end

return StokerFlank
