--!strict
--[[
	The bounded crew rescue (Config/Injury Rescue). Pure, so the server (Services/HollowService,
	the only judge) and the specs agree.

	When a hold's clock runs out on someone who still has an arm, the server opens a session
	instead of finishing them. Two phases, each on the server clock:

	  invitation  open for Invite seconds plus half the slowest eligible round trip, never
	              longer than InviteMax. The first eligible crewmate whose join arrives becomes
	              the one rescuer; nobody can join after, and joining never extends anything.
	  sequence    starts when the join is accepted. Three beats at Beats seconds after the
	              start. One press per beat, judged at the instant the rescuer says they pressed,
	              trusted only within `compensation` of its arrival (half their round trip,
	              capped at CompensationMax). A press counts within Window of its beat. Presses
	              must arrive by the sequence's end (Length); there are no rolling extensions.

	Three hits rescue; a miss, a beat left unpressed past its window, a timeout or an empty
	invitation fails, and the caller resolves the existing lethal outcome. A session resolves
	exactly once.

	This bounds replayed, stale, forged, future and non-finite times. It does not make a rhythm
	input human-proof: a client that knows the schedule can automate it.
]]

local Config = require(script.Parent.Parent.Config.Injury)

local C = Config.Rescue

export type Phase = "Invite" | "Sequence" | "Rescued" | "Failed"

export type Session = {
	id: number,
	phase: Phase,
	openedAt: number,
	inviteEndsAt: number,
	rescuer: number?, -- the rescuer's UserId
	startsAt: number?, -- the sequence's start (server time)
	compensation: number, -- the rescuer's credited arrival delay
	hits: { [number]: boolean }, -- beat index -> hit (present once judged)
	why: string?, -- why it failed: "Empty", "Miss", "Late", "Gone"
}

local Rescue = {}

Rescue.BeatCount = #C.Beats

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

-- One-way delay from a measured round trip (Player:GetNetworkPing, seconds), capped.
function Rescue.compensation(roundTrip: any): number
	local rtt = if finite(roundTrip) and roundTrip > 0 then roundTrip else 0
	return math.min(rtt / 2, C.CompensationMax)
end

-- The invitation's length given the slowest eligible crewmate's round trip.
function Rescue.inviteSeconds(slowestRoundTrip: any): number
	local rtt = if finite(slowestRoundTrip) and slowestRoundTrip > 0 then slowestRoundTrip else 0
	return math.min(C.Invite + rtt / 2, C.InviteMax)
end

--[[
	How far from the victim a crewmate moving at `speed` (studs/s) with this round trip can be and
	still arrive inside an invitation of `inviteSeconds`: Reach plus the walk left after reacting
	(ReactAllowance) and their join's one-way trip. Offering the rescue to anyone further away only
	promises what cannot happen.
]]
function Rescue.arrivalRadius(speed: number, inviteSeconds: number, roundTrip: any): number
	local rtt = if finite(roundTrip) and roundTrip > 0 then roundTrip else 0
	return C.Reach + speed * math.max(inviteSeconds - C.ReactAllowance - rtt / 2, 0)
end

function Rescue.new(id: number, now: number, slowestRoundTrip: any): Session
	return {
		id = id,
		phase = "Invite",
		openedAt = now,
		inviteEndsAt = now + Rescue.inviteSeconds(slowestRoundTrip),
		rescuer = nil,
		startsAt = nil,
		compensation = 0,
		hits = {},
		why = nil,
	}
end

function Rescue.beatAt(session: Session, beat: number): number?
	local offset = C.Beats[beat]
	if session.startsAt == nil or offset == nil then
		return nil
	end
	return (session.startsAt :: number) + offset
end

function Rescue.endsAt(session: Session): number?
	return if session.startsAt then (session.startsAt :: number) + C.Length else nil
end

function Rescue.resolved(session: Session): boolean
	return session.phase == "Rescued" or session.phase == "Failed"
end

local function fail(session: Session, why: string)
	session.phase = "Failed"
	session.why = why
end

--[[
	A crewmate asks to rescue, arriving at server time `now`. The caller has already checked
	they are eligible (alive, not held, within Reach, in line of sight). Returns whether they
	became the rescuer.
]]
function Rescue.join(session: Session, userId: number, now: number, roundTrip: any): boolean
	if session.phase ~= "Invite" or session.rescuer ~= nil or now > session.inviteEndsAt then
		return false
	end
	session.rescuer = userId
	session.phase = "Sequence"
	session.startsAt = now
	session.compensation = Rescue.compensation(roundTrip)
	return true
end

--[[
	The instant to judge a press the rescuer says they made at `claimed` that arrived at
	`arrived`: the claim held within [arrived - compensation, arrived]. nil when the claim is
	not a finite number.
]]
function Rescue.pressTime(session: Session, claimed: any, arrived: number): number?
	if not finite(claimed) then
		return nil
	end
	return math.clamp(claimed, arrived - session.compensation, arrived)
end

--[[
	One press for `beat` from `userId`, made at `claimed` (rescuer's view of server time) and
	arriving at `arrived`. Returns the outcome for the caller to log: "Hit", "Miss" or the
	reason it was ignored ("NotRescuer", "Phase", "Beat", "Replay", "Time", "Late").
	An ignored press changes nothing.
]]
function Rescue.press(session: Session, userId: number, beat: any, claimed: any, arrived: number): string
	if session.phase ~= "Sequence" then
		return "Phase"
	end
	if session.rescuer ~= userId then
		return "NotRescuer"
	end
	if type(beat) ~= "number" or beat % 1 ~= 0 or C.Beats[beat] == nil then
		return "Beat"
	end
	if session.hits[beat] ~= nil then
		return "Replay"
	end
	local endsAt = Rescue.endsAt(session) :: number
	if arrived > endsAt then
		return "Late"
	end
	local at = Rescue.pressTime(session, claimed, arrived)
	if at == nil then
		return "Time"
	end
	local hit = math.abs(at - (Rescue.beatAt(session, beat) :: number)) <= C.Window
	session.hits[beat] = hit
	if not hit then
		fail(session, "Miss")
		return "Miss"
	end
	local all = true
	for i = 1, Rescue.BeatCount do
		if session.hits[i] ~= true then
			all = false
		end
	end
	if all then
		session.phase = "Rescued"
	end
	return "Hit"
end

--[[
	Advances the session to server time `now`: an invitation nobody took fails, a beat whose
	window (plus the rescuer's compensation) has passed unpressed fails, and the sequence's end
	fails anything unfinished. Returns the phase.
]]
function Rescue.tick(session: Session, now: number): Phase
	if Rescue.resolved(session) then
		return session.phase
	end
	if session.phase == "Invite" then
		if now > session.inviteEndsAt then
			fail(session, "Empty")
		end
		return session.phase
	end
	for beat = 1, Rescue.BeatCount do
		local at = Rescue.beatAt(session, beat) :: number
		if session.hits[beat] == nil and now > at + C.Window + session.compensation then
			fail(session, "Late")
			return session.phase
		end
	end
	if now > (Rescue.endsAt(session) :: number) then
		fail(session, "Late")
	end
	return session.phase
end

-- The rescuer left, died or was grabbed, or the victim is gone: it fails once.
function Rescue.abandon(session: Session)
	if not Rescue.resolved(session) then
		fail(session, "Gone")
	end
end

return table.freeze(Rescue)
