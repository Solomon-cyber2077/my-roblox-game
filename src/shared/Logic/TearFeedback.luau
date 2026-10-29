--!strict
--[[
	The shape of the moment an arm comes away (Config/Injury Tear), as pure numbers so the client
	(Controllers/InjuryController, Controllers/AudioController) and the specs agree. `t` is seconds
	since the tear.

	  shock    0..1, the screen's shock (UI/Trauma): full at once and held as long as the muffle
	           is, then let go smoothly by ShockSeconds
	  muffle   0..1, how far the world's sound has gone dull: nothing for MuffleDelay (the tear and
	           the snap land clean), up over MuffleAttack, held for MuffleHold, then let go
	           smoothly by ShockSeconds
	  ring     0..1, the ringing in the ears: swells to its peak at RingPeakAt, fades out by the end
	  heartGap seconds to the next heartbeat: racing at first, settling as the shock passes
	  nearby   0..1, how hard a crewmate `distance` studs away takes it in
	  voice    the cry (1..count) and pitch a player keeps, from their UserId alone
]]

local Config = require(script.Parent.Parent.Config.Injury)

local C = Config.Tear

local TearFeedback = {}

local function smooth(x: number): number
	local u = math.clamp(x, 0, 1)
	return u * u * (3 - 2 * u)
end

-- Held at 1 until the muffle's hold ends, then let go smoothly by ShockSeconds.
local function release(t: number): number
	local fallFrom = C.MuffleDelay + C.MuffleAttack + C.MuffleHold
	if t <= fallFrom then
		return 1
	end
	return 1 - smooth((t - fallFrom) / (C.ShockSeconds - fallFrom))
end

function TearFeedback.muffle(t: number): number
	local rise = t - C.MuffleDelay
	if rise <= 0 or t >= C.ShockSeconds then
		return 0
	end
	if rise < C.MuffleAttack then
		return smooth(rise / C.MuffleAttack)
	end
	return release(t)
end

function TearFeedback.shock(t: number): number
	if t < 0 or t >= C.ShockSeconds then
		return 0
	end
	return release(t)
end

function TearFeedback.ring(t: number): number
	if t <= 0 or t >= C.ShockSeconds then
		return 0
	end
	if t < C.RingPeakAt then
		return smooth(t / C.RingPeakAt)
	end
	return 1 - smooth((t - C.RingPeakAt) / (C.ShockSeconds - C.RingPeakAt))
end

function TearFeedback.heartGap(t: number): number
	local u = smooth(t / C.ShockSeconds)
	return C.HeartFast + (C.HeartSettled - C.HeartFast) * u
end

function TearFeedback.nearby(distance: number): number
	if distance <= C.NearStuds then
		return 1
	end
	return 1 - smooth((distance - C.NearStuds) / (C.FarStuds - C.NearStuds))
end

-- A stable hash of a UserId (guests and Studio test players are negative).
local function hash(userId: number): number
	local n = math.abs(math.floor(userId)) % 2147483647
	n = (n * 1103515245 + 12345) % 2147483648
	return n
end

function TearFeedback.voice(userId: number, count: number): (number, number)
	local h = hash(userId)
	local index = (h % math.max(count, 1)) + 1
	local u = ((h // 7) % 1000) / 999
	return index, C.VoicePitchLow + (C.VoicePitchHigh - C.VoicePitchLow) * u
end

return TearFeedback
