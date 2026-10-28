local Config = require(Shared.Config.Injury)
local Rescue = require(Shared.Logic.Rescue)

local C = Config.Rescue

-- A session whose rescuer joined at server time 100 with round trip `rtt`.
local function started(rtt: number): Rescue.Session
	local s = Rescue.new(1, 99, 0)
	expect(Rescue.join(s, 7, 100, rtt)).toBe(true)
	return s
end

-- A rescuer who presses `late` seconds off each beat on their own screen, `oneWay` from the server.
local function play(rtt: number, late: number, jitter: { number }?): Rescue.Phase
	local s = started(rtt)
	for beat = 1, Rescue.BeatCount do
		local at = (Rescue.beatAt(s, beat) :: number) + late
		local arrive = at + rtt / 2 + (if jitter then jitter[beat] else 0)
		Rescue.tick(s, arrive)
		if Rescue.resolved(s) then
			return s.phase
		end
		Rescue.press(s, 7, beat, at, arrive)
	end
	return Rescue.tick(s, 103)
end

describe("Rescue", function()
	it("caps the invitation at InviteMax", function()
		expect(Rescue.inviteSeconds(0)).toBeCloseTo(C.Invite)
		expect(Rescue.inviteSeconds(0.3)).toBeCloseTo(C.Invite + 0.15)
		expect(Rescue.inviteSeconds(5)).toBe(C.InviteMax)
		expect(Rescue.inviteSeconds(0 / 0)).toBeCloseTo(C.Invite)
	end)

	it("takes one rescuer only, and no join after the invitation", function()
		local s = Rescue.new(1, 0, 0)
		expect(Rescue.join(s, 1, 0.5, 0)).toBe(true)
		expect(Rescue.join(s, 2, 0.6, 0)).toBe(false)
		expect(s.rescuer).toBe(1)
		local late = Rescue.new(2, 0, 0)
		expect(Rescue.join(late, 1, C.InviteMax + 0.1, 0)).toBe(false)
		expect(Rescue.tick(late, C.InviteMax + 0.1)).toBe("Failed")
	end)

	it("rescues on three on-beat presses at 0, 150 and 300ms round trip", function()
		for _, rtt in { 0, 0.15, 0.3 } do
			expect(play(rtt, 0)).toBe("Rescued")
		end
	end)

	it("holds within the window at 500ms without jitter, and fails with 80ms of late jitter", function()
		expect(play(0.5, 0)).toBe("Rescued")
		expect(play(0.5, 0, { 0, 0.08, 0 })).toBe("Failed")
	end)

	it("fails a press outside the window", function()
		expect(play(0.1, C.Window + 0.02)).toBe("Failed")
		expect(play(0.1, -(C.Window + 0.02))).toBe("Failed")
	end)

	it("ignores replays, other players, bad beats and non-finite times", function()
		local s = started(0)
		local beat1 = Rescue.beatAt(s, 1) :: number
		expect(Rescue.press(s, 8, 1, beat1, beat1)).toBe("NotRescuer")
		expect(Rescue.press(s, 7, 0, beat1, beat1)).toBe("Beat")
		expect(Rescue.press(s, 7, 1.5, beat1, beat1)).toBe("Beat")
		expect(Rescue.press(s, 7, 1, 0 / 0, beat1)).toBe("Time")
		expect(Rescue.press(s, 7, 1, math.huge, beat1)).toBe("Time")
		expect(Rescue.press(s, 7, 1, beat1, beat1)).toBe("Hit")
		expect(Rescue.press(s, 7, 1, beat1, beat1 + 0.01)).toBe("Replay")
	end)

	it("never credits a future claim or more than the capped compensation", function()
		local s = started(2) -- a huge round trip is capped
		expect(s.compensation).toBe(C.CompensationMax)
		local beat1 = Rescue.beatAt(s, 1) :: number
		-- arriving 0.4s late while claiming the exact beat: held to arrival - cap, a miss
		expect(Rescue.press(s, 7, 1, beat1, beat1 + 0.4)).toBe("Miss")
		local f = started(0)
		local b = Rescue.beatAt(f, 1) :: number
		-- claiming a time after arrival is clamped to arrival
		expect(Rescue.pressTime(f, b + 5, b - 0.3)).toBe(b - 0.3)
	end)

	it("fails a skipped beat and anything after the end, and resolves once", function()
		local s = started(0)
		local beat1 = Rescue.beatAt(s, 1) :: number
		expect(Rescue.tick(s, beat1 + C.Window + 0.01)).toBe("Failed")
		expect(s.why).toBe("Late")
		Rescue.abandon(s)
		expect(s.why).toBe("Late")
		local e = started(0)
		local stop = Rescue.endsAt(e) :: number
		expect(Rescue.press(e, 7, 3, stop, stop + 0.01)).toBe("Late")
	end)

	it("abandons once when the rescuer is gone", function()
		local s = started(0)
		Rescue.abandon(s)
		expect(s.phase).toBe("Failed")
		expect(s.why).toBe("Gone")
	end)
end)
