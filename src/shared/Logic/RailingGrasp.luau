--!strict
--[[
	The railing grasp's rules (docs/FINAL-DESIGN.md Prompt 4). Pure: Services/GraspService takes one
	snapshot of the server's replicated root and the static rail when a Grasp request arrives, and
	asks this module. No position history, no extrapolation, no client-reported time or position.

	  tolerance   the closing-speed term: max(0, closing) x ReplicationLagSeconds, capped at
	              MaxClosingTolerance (PROVISIONAL 0.1 s, 1.0 stud)
	  reach       Reach 3 + BaseTolerance 0.5 + tolerance: 3.5 to 4.5 studs
	  pressTime   receipt minus measured one-way latency clamped to 0..ResolutionBuffer (0.2 s); it
	              only checks the window, it never rewinds geometry
	  evaluate    accepted when the estimated press is inside [chaseStart, chaseEnd], the receipt is no
	              later than chaseEnd + 0.2 and the receipt-time gap is within reach
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)
local G = Tuning.Grasp

local RailingGrasp = {}

export type Result = {
	accepted: boolean,
	reason: string, -- caught / missed / window
	estimatedPress: number,
	gap: number,
	reach: number,
	shortfall: number,
}

function RailingGrasp.tolerance(closing: number): number
	return math.min(math.max(0, closing) * G.ReplicationLagSeconds, G.MaxClosingTolerance)
end

-- Reach accepted for a closing speed: 3 + 0.5 + the capped closing term.
function RailingGrasp.reach(closing: number): number
	return G.Reach + G.BaseTolerance + RailingGrasp.tolerance(closing)
end

--[[
	The root's speed toward the rail: velocity (vx, vy, vz) along the unit direction to the rail
	(dx, dy, dz, not normalised). Zero when the direction has no length.
]]
function RailingGrasp.closing(vx: number, vy: number, vz: number, dx: number, dy: number, dz: number): number
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	if length < 1e-9 then
		return 0
	end
	return (vx * dx + vy * dy + vz * dz) / length
end

function RailingGrasp.pressTime(receipt: number, oneWay: number): number
	return receipt - math.clamp(oneWay, 0, G.ResolutionBuffer)
end

-- What a left-behind player reads after a reach miss: the measured shortfall to 0.1 stud.
function RailingGrasp.shortfallText(shortfall: number): string
	if shortfall <= 0 then
		return "within reach"
	elseif shortfall < 0.1 then
		return "less than 0.1 stud short"
	end
	return string.format("%.1f studs short", shortfall)
end

function RailingGrasp.evaluate(
	receipt: number,
	oneWay: number,
	chaseStart: number,
	chaseEnd: number,
	gap: number,
	closingSpeed: number
): Result
	local estimatedPress = RailingGrasp.pressTime(receipt, oneWay)
	local reach = RailingGrasp.reach(closingSpeed)
	local shortfall = math.max(0, gap - reach)
	local inWindow = estimatedPress >= chaseStart
		and estimatedPress <= chaseEnd
		and receipt <= chaseEnd + G.ResolutionBuffer
	local accepted = inWindow and gap <= reach
	return {
		accepted = accepted,
		reason = if not inWindow then "window" elseif accepted then "caught" else "missed",
		estimatedPress = estimatedPress,
		gap = gap,
		reach = reach,
		shortfall = shortfall,
	}
end

return table.freeze(RailingGrasp)
