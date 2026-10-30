--!strict
--[[
	Downed rules (Config/Downed). Pure, so the server (when built) and the simulator (`lune run downed`, lib/LimbSim)
	run the same transitions.

	  eligible(features, victim, rescuers, now)
	                     whether a lethal hold becomes Downed, or why not ("FlagOff", "Solo", "NoArm",
	                     "NoRescuer", "Tutorial"); a rescuer counts if living, free (not held, not Downed, not
	                     rescuing), with an arm, and able to arrive with a whole sequence's time to spare
	  new(id, victim, now, bleed)
	                     one session: one immutable deadline, one retry at most, one settlement
	  canJoin / join     a join must leave the whole rescue sequence (Config/Downed.Rescue.Length) before the deadline
	  miss(session, now) a failed sequence: reopens the slot for anyone, once, with RetryFloor of bleed left, and the
	                     Hollow pulls harder from then on; otherwise false and the caller settles "RescueFailed"
	  drag(session, crawling)
	                     the victim's net speed away from the train: DragSpeed (x MissDragMult after a miss), less
	                     CrawlSpeed while crawling, zero while a rescue sequence runs (the bleed never pauses)
	  settle(session, outcome, now)
	                     the one terminal result; later calls change nothing (duplicates are harmless)
	  tick(session, now) the deadline: at or past it, an unsettled session bleeds out ("Taken")

	Precedence at one instant: a rescue sequence that ends by the deadline wins over the deadline; departure,
	hazards and disconnects settle with their own cause whenever they happen (Downed never delays departure).

	Status predicates (CrewService will read these): a Downed player is present and recoverable, is not an active
	rescuer, and is not yet eliminated.
]]

local Shared = script.Parent.Parent
local Config = require(Shared.Config.Downed)

export type Outcome = "Rescued" | "Taken" | "RescueFailed" | "Departure" | "Hazard" | "Disconnect" | "Reset"
export type Phase = "Downed" | "Rescuing" | "Settled"
export type Session = {
	id: number,
	victim: number,
	enteredAt: number,
	deadline: number,
	phase: Phase,
	rescuer: number?,
	joinedAt: number?,
	missed: boolean, -- the one retry is spent and the drag has escalated
	outcome: Outcome?,
	settledAt: number?,
}
export type Rescuer = { id: number, alive: boolean, free: boolean, hasArm: boolean, arriveIn: number }

local Downed = {}

function Downed.bleed(override: number?): number
	return override or Config.BleedSeconds
end

function Downed.eligible(
	features: { downed: boolean, injury: boolean, tutorial: boolean? },
	victim: { hasArm: boolean },
	rescuers: { Rescuer },
	bleed: number?
): (boolean, string?)
	if not (features.downed and features.injury) then
		return false, "FlagOff"
	end
	if features.tutorial then
		return false, "Tutorial"
	end
	if not victim.hasArm then
		return false, "NoArm"
	end
	if #rescuers == 0 then
		return false, "Solo"
	end
	local window = Downed.bleed(bleed) - Config.Rescue.Length
	for _, r in rescuers do
		if r.alive and r.free and r.hasArm and r.arriveIn <= window then
			return true, nil
		end
	end
	return false, "NoRescuer"
end

function Downed.new(id: number, victim: number, now: number, bleed: number?): Session
	return {
		id = id,
		victim = victim,
		enteredAt = now,
		deadline = now + Downed.bleed(bleed),
		phase = "Downed",
		rescuer = nil,
		joinedAt = nil,
		missed = false,
		outcome = nil,
		settledAt = nil,
	}
end

function Downed.canJoin(session: Session, now: number): boolean
	return session.phase == "Downed"
		and session.rescuer == nil
		and now + Config.Rescue.Length <= session.deadline
end

function Downed.join(session: Session, rescuer: number, now: number): boolean
	if not Downed.canJoin(session, now) or rescuer == session.victim then
		return false
	end
	session.rescuer, session.joinedAt, session.phase = rescuer, now, "Rescuing"
	return true
end

function Downed.miss(session: Session, now: number): boolean
	if session.phase ~= "Rescuing" or session.missed or session.deadline - now < Config.RetryFloor then
		return false
	end
	session.phase, session.rescuer, session.joinedAt, session.missed = "Downed", nil, nil, true
	return true
end

function Downed.drag(session: Session, crawling: boolean): number
	if session.phase ~= "Downed" then
		return 0
	end
	local pull = Config.DragSpeed * (if session.missed then Config.MissDragMult else 1)
	return math.max(pull - (if crawling then Config.CrawlSpeed else 0), 0)
end

function Downed.settle(session: Session, outcome: Outcome, now: number): boolean
	if session.phase == "Settled" then
		return false
	end
	session.phase, session.outcome, session.settledAt = "Settled", outcome, now
	return true
end

function Downed.tick(session: Session, now: number): Phase
	if session.phase == "Downed" and now >= session.deadline then
		Downed.settle(session, "Taken", session.deadline)
	end
	return session.phase
end

-- Status predicates: who counts as what while a session is open.
function Downed.recoverable(session: Session?): boolean
	return session ~= nil and session.phase ~= "Settled"
end

function Downed.canRescue(session: Session?): boolean
	return session == nil or session.phase == "Settled"
end

return table.freeze(Downed)
