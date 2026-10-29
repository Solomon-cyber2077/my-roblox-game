--[[
	Simulated people for the limb-loss playtest (lib/LimbSim). Who plays, when, on what, and how
	they feel, so a session behaves like a real player's rather than a fixed persona's.

	Every number here is an assumption, stated so it can be replaced by real telemetry after launch
	(Logic/Telemetry already records device, first-run and timing events):
	  - age: Roblox skews young but most users are now 13+ (9-12 25%, 13-17 40%, 18-24 25%, 25+ 10%)
	  - device: mostly mobile (phone 50%, tablet 13%, laptop 15%, desktop 14%, console 8%)
	  - connection: by device and region; the evening peak (19-23 h local) adds delay and spread; mobile
	    data adds both; rare spikes
	  - when they play: school-age players on weekdays after school into the evening, later and longer
	    on weekends; adults in the evening and late night
	  - reaction and timing: slower and looser for the youngest and with fatigue; tighter with practice
	  - emotions: fear, frustration, fun, boredom and fatigue (0..1) move with what happens in the run
	    and change behaviour: fear tightens caution and loosens timing, frustration and fatigue loosen
	    timing and raise the chance of quitting, boredom raises risk-taking, fun keeps them playing
	This is a model of people, not people: it cannot discover what nobody thought to model. Use it to
	rank risks and to compare tunings, and check its calls against real players before trusting them.
]]

local Humans = {}

local DEVICES = {
	Phone = {
		platform = "Mobile",
		latency = 0.05,
		move = 0.84,
		awareness = 0.65,
		hudMiss = 0.14,
		input = "touch",
	},
	Tablet = {
		platform = "Mobile",
		latency = 0.045,
		move = 0.88,
		awareness = 0.8,
		hudMiss = 0.06,
		input = "touch",
	},
	Laptop = {
		platform = "PC",
		latency = 0.025,
		move = 0.9,
		awareness = 0.75,
		hudMiss = 0.05,
		input = "keyboard",
	},
	Desktop = {
		platform = "PC",
		latency = 0.012,
		move = 0.97,
		awareness = 0.95,
		hudMiss = 0.02,
		input = "keyboard",
	},
	Console = {
		platform = "Console",
		latency = 0.035,
		move = 0.9,
		awareness = 0.8,
		hudMiss = 0.05,
		input = "gamepad",
	},
}
Humans.Devices = DEVICES

local REGIONS = { -- share, base round trip to the server in seconds
	{ "NA", 0.45, 0.06 },
	{ "EU", 0.25, 0.11 },
	{ "LatAm", 0.12, 0.17 },
	{ "Asia", 0.1, 0.2 },
	{ "Oceania", 0.08, 0.22 },
}

local NAMES = {
	"Ava",
	"Leo",
	"Mia",
	"Noah",
	"Zoe",
	"Kai",
	"Ivy",
	"Eli",
	"Ruby",
	"Max",
	"Luna",
	"Sam",
	"Nia",
	"Owen",
	"Jade",
	"Theo",
	"Aria",
	"Finn",
	"Maya",
	"Jude",
	"Priya",
	"Omar",
	"Hana",
	"Diego",
	"Sofia",
	"Ezra",
	"Tess",
	"Ravi",
	"Lila",
	"Remy",
	"Cleo",
	"Arlo",
}

local function pick(rng, weighted)
	local u, acc = rng:next(), 0
	for _, w in weighted do
		acc += w[2]
		if u <= acc then
			return w[1], w
		end
	end
	return weighted[#weighted][1], weighted[#weighted]
end

local function clamp(x, lo, hi)
	return math.max(lo, math.min(hi, x))
end

local function gauss(rng)
	local u1 = math.max(rng:next(), 1e-9)
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * rng:next())
end
Humans.gauss = gauss

-- When this person sits down to play: local hour (fractional) and whether it is a weekday.
local function playtime(rng, age: number): (number, boolean)
	local weekday = rng:next() < 5 / 7
	local hour
	if age < 18 then
		if weekday then
			hour = pick(rng, { { 16, 0.25 }, { 18, 0.3 }, { 20, 0.3 }, { 22, 0.1 }, { 7, 0.05 } })
		else
			hour =
				pick(rng, { { 10, 0.2 }, { 13, 0.25 }, { 16, 0.2 }, { 19, 0.2 }, { 22, 0.1 }, { 1, 0.05 } })
		end
	else
		hour = pick(rng, { { 12, 0.1 }, { 18, 0.15 }, { 20, 0.3 }, { 22, 0.3 }, { 0, 0.15 } })
	end
	return (hour + rng:next() * 2) % 24, weekday
end

-- How tired they are when they start: late for their age, and a weekday night for school-age players.
local function startFatigue(age: number, hour: number, weekday: boolean): number
	local late = if hour >= 22 or hour < 5 then 1 elseif hour >= 20 then 0.5 else 0
	local school = if age < 18 and weekday then 0.15 else 0
	local early = if hour >= 5 and hour < 8 then 0.3 else 0
	return clamp(0.08 + late * (if age < 18 then 0.45 else 0.3) + school + early, 0, 0.85)
end

-- Round trip and its spread for this connection at this hour.
function Humans.network(rng, regionBase: number, connection: string, hour: number)
	local peak = hour >= 19 and hour < 23
	local rtt = regionBase
		* (if peak then 1.25 else 1)
		* (if connection == "mobile" then 1.35 elseif connection == "ethernet" then 0.9 else 1)
	local spread = 0.008
		+ (if connection == "mobile" then 0.03 elseif connection == "wifi" then 0.012 else 0.004)
		+ (if peak then 0.01 else 0)
	return rtt * (0.85 + rng:next() * 0.3), spread
end

-- One simulated person.
function Humans.new(rng, id: number)
	local age =
		math.floor(pick(rng, { { 10, 0.25 }, { 15, 0.4 }, { 20, 0.25 }, { 28, 0.1 } }) + rng:next() * 4 - 1.5)
	local deviceId = pick(
		rng,
		{ { "Phone", 0.5 }, { "Tablet", 0.13 }, { "Laptop", 0.15 }, { "Desktop", 0.14 }, { "Console", 0.08 } }
	)
	local device = DEVICES[deviceId]
	local connection = if deviceId == "Desktop" or deviceId == "Console"
		then (if rng:next() < 0.4 then "ethernet" else "wifi")
		elseif deviceId == "Phone" then (if rng:next() < 0.3 then "mobile" else "wifi")
		else "wifi"
	local region, regionRow = pick(rng, {
		{ REGIONS[1][1], REGIONS[1][2] },
		{ REGIONS[2][1], REGIONS[2][2] },
		{ REGIONS[3][1], REGIONS[3][2] },
		{ REGIONS[4][1], REGIONS[4][2] },
		{ REGIONS[5][1], REGIONS[5][2] },
	})
	local base = 0.08
	for _, r in REGIONS do
		if r[1] == region then
			base = r[3]
		end
	end
	local _ = regionRow
	local hour, weekday = playtime(rng, age)
	local rtt, spread = Humans.network(rng, base, connection, hour)
	local runsBefore = math.floor(math.max(0, gauss(rng) * 6 + 5) ^ (if rng:next() < 0.3 then 0 else 1))
	local practice = clamp(runsBefore / 25, 0, 1)
	local youth = clamp((14 - age) / 6, 0, 1)
	local motive = pick(
		rng,
		{ { "social", 0.3 }, { "thrill", 0.25 }, { "mastery", 0.15 }, { "explore", 0.15 }, { "chill", 0.15 } }
	)
	local traits = {
		skill = clamp(0.25 + practice * 0.5 + gauss(rng) * 0.12, 0.05, 0.98),
		reaction = clamp(0.32 + youth * 0.12 + gauss(rng) * 0.06 - practice * 0.05, 0.16, 0.8),
		jitter = clamp(0.055 + youth * 0.025 + gauss(rng) * 0.012 - practice * 0.015, 0.02, 0.13),
		greed = clamp(0.5 + (if motive == "thrill" then 0.2 else 0) + gauss(rng) * 0.18, 0, 1),
		caution = clamp(0.45 - (if motive == "thrill" then 0.15 else 0) + gauss(rng) * 0.18, 0, 1),
		teamwork = clamp(0.45 + (if motive == "social" then 0.3 else 0) + gauss(rng) * 0.18, 0, 1),
		panic = clamp(0.4 + youth * 0.2 - practice * 0.2 + gauss(rng) * 0.15, 0, 1),
		readsUi = clamp(0.55 - youth * 0.25 + practice * 0.25 - device.hudMiss + gauss(rng) * 0.12, 0.05, 1),
		tolerance = clamp(0.5 + (if motive == "mastery" then 0.15 else 0) + gauss(rng) * 0.18, 0.05, 1),
		thrill = clamp(
			0.45
				+ (if motive == "thrill" then 0.3 elseif motive == "chill" then -0.25 else 0)
				+ gauss(rng) * 0.15,
			0,
			1
		),
	}
	local sessionMinutes = math.floor(
		clamp(
			(if weekday and age < 18 then 28 else 45)
				* (0.6 + rng:next() * 0.9)
				* (if hour >= 22 or hour < 5 then 0.7 else 1),
			8,
			120
		)
	)
	return {
		id = id,
		name = NAMES[(id - 1) % #NAMES + 1],
		age = age,
		deviceId = deviceId,
		device = device,
		connection = connection,
		region = region,
		rtt = rtt,
		netSpread = spread,
		localHour = math.floor(hour * 10) / 10,
		weekday = weekday,
		sessionMinutes = sessionMinutes,
		runsBefore = runsBefore,
		motive = motive,
		traits = traits,
		mood = {
			fear = 0.1,
			frustration = 0.05 + rng:next() * 0.1,
			fun = 0.35 + rng:next() * 0.2,
			boredom = 0.1,
			fatigue = startFatigue(age, hour, weekday),
		},
		deaths = 0,
		streak = 0, -- deaths in a row (tilt)
		spoke = {}, -- topic -> last time said (cooldowns)
	}
end

-- The profile written into a trace (format v3).
function Humans.profile(h)
	local traits = {}
	for k, v in h.traits do
		traits[k] = math.floor(v * 100) / 100
	end
	return {
		age = h.age,
		platform = h.device.platform,
		device = h.deviceId,
		connection = h.connection,
		region = h.region,
		rttMs = math.floor(h.rtt * 1000),
		localHour = h.localHour,
		weekday = h.weekday,
		sessionMinutes = h.sessionMinutes,
		runsBefore = h.runsBefore,
		traits = traits,
		motive = h.motive,
	}
end

-- Effective timing spread for a press right now: traits, fear, fatigue and frustration all loosen it.
function Humans.jitter(h): number
	local m = h.mood
	return h.traits.jitter * (1 + h.traits.panic * m.fear * 0.8 + m.fatigue * 0.5 + m.frustration * 0.3)
end

function Humans.reaction(h): number
	return h.traits.reaction * (1 + h.mood.fatigue * 0.6 + h.mood.fear * 0.2)
end

-- A press's one-way trip this instant: the round trip's half plus this connection's spread, sometimes a spike.
function Humans.oneWay(rng, h): number
	local spike = if rng:next() < (if h.connection == "mobile" then 0.03 else 0.01)
		then rng:range(0.1, 0.35)
		else 0
	return h.rtt / 2 + math.abs(gauss(rng)) * h.netSpread + spike, spike
end

local function nudge(m, key, by)
	m[key] = clamp(m[key] + by, 0, 1)
end
Humans.nudge = nudge

-- Mood drift every tick: fear decays, boredom grows when nothing happens, fatigue creeps up over the
-- session they meant to play (a late start begins tired, so it tips over sooner).
function Humans.drift(h, dt: number, threat: number, idle: boolean)
	local m = h.mood
	m.fear = clamp(m.fear + (threat * 0.5 - m.fear * 0.25) * dt, 0, 1)
	m.boredom = clamp(m.boredom + (if idle then 0.004 * (1 - h.traits.thrill * 0.5) else -0.01) * dt, 0, 1)
	m.fatigue = clamp(m.fatigue + 0.55 / (h.sessionMinutes * 60) * dt, 0, 1)
	m.frustration = clamp(m.frustration - 0.004 * dt, 0, 1)
	m.fun = clamp(
		m.fun + ((threat > 0.2 and threat < 0.8) and 0.004 or -0.002) * dt * (0.5 + h.traits.thrill),
		0,
		1
	)
end

-- How the player feels about an event (and so what they do next).
local REACTIONS = {
	grabbed = { fear = 0.35, fun = 0.03 },
	escaped = { fear = -0.15, fun = 0.15, frustration = -0.05 },
	rescued = { fun = 0.12, frustration = 0.08, fear = -0.1 },
	rescuedOther = { fun = 0.2, frustration = -0.05 },
	rescueFailedOther = { frustration = 0.18, fun = -0.05 },
	armLost = { frustration = 0.12, fear = 0.15 },
	itemsLost = { frustration = 0.15 },
	healed = { fun = 0.08, frustration = -0.08 },
	died = { frustration = 0.3, fun = -0.12, fear = -0.2 },
	lagMiss = { frustration = 0.25 },
	loot = { fun = 0.04, boredom = -0.05 },
	boarded = { fear = -0.2, fun = 0.03 },
	crewDied = { frustration = 0.08, fear = 0.08 },
}

function Humans.feel(h, what: string)
	local r = REACTIONS[what]
	if r then
		for key, by in r do
			nudge(h.mood, key, by * (if key == "frustration" then 1.4 - h.traits.tolerance else 1))
		end
	end
	if what == "died" then
		h.deaths += 1
		h.streak += 1
	elseif what == "escaped" or what == "boarded" then
		h.streak = 0
	end
end

-- Do they leave after this stop? (reason or nil)
function Humans.quits(rng, h, minutesPlayed: number): string?
	local m = h.mood
	if minutesPlayed >= h.sessionMinutes then
		return if m.fatigue > 0.5 then "tired" else "time"
	end
	local p = 0.01
		+ m.frustration * 0.2 * (1.3 - h.traits.tolerance)
		+ m.boredom * 0.18
		+ math.max(m.fatigue - 0.5, 0) * 0.4
		+ h.streak * 0.04
		- m.fun * 0.15
	if rng:next() < clamp(p, 0, 0.9) then
		return if m.frustration > m.boredom and m.frustration > 0.4
			then "frustrated"
			elseif m.boredom > 0.4 then "bored"
			elseif m.fatigue > 0.5 then "tired"
			else "time" -- called away, dinner, a friend online elsewhere: not the game's doing
	end
	return nil
end

-- 0..1: how likely they come back for another session, from how the session left them.
function Humans.returnChance(h): number
	local m = h.mood
	local social = if h.motive == "social" then 0.1 else 0
	local x = 0.4
		+ m.fun * 0.6
		- m.frustration * 0.55
		- m.boredom * 0.3
		- math.max(m.fatigue - 0.6, 0) * 0.3
		+ social
	return clamp(x, 0.02, 0.98)
end

--[[
	What they say. Each line is chosen for a topic that something in the run actually triggered; the
	words change with age and device so the feed reads like different people. Cooldown per topic.
]]
local LINES = {
	rescue_timing = {
		"the rescue timing is so tight",
		"i pressed on the mark and it said miss??",
		"those 3 beats are impossible on my phone",
		"ok the pull thing is hard",
	},
	rescue_unreachable = {
		"it said rescue but i was way too far",
		"how am i supposed to get there in 2 seconds",
		"couldn't reach them, the prompt was useless",
	},
	nobody_near = {
		"nobody was near me, just died",
		"where was everyone",
		"solo grab = death, cool",
	},
	lag = {
		"LAG",
		"that was lag i swear",
		"my wifi is dying",
		"ping spike right on the beat",
	},
	items_lost = {
		"wait where did my stuff go",
		"lost half my loot when my arm came off??",
		"it dropped my tonic, i needed that",
	},
	items_lost_understood = {
		"ok it dropped the stuff on the right, makes sense",
		"good thing i put the tonic first",
	},
	unclear_timer = {
		"what's the number on top for",
		"i didn't see the countdown",
		"why did i just die on the platform",
	},
	near_miss_timer = {
		"I WAS AT THE DOOR",
		"died literally at the train door",
		"half a second off, that's brutal",
	},
	armless_run = {
		"no arms just run run run",
		"ok i have no arms, going back",
	},
	healed = { "arm back lets go", "tonic saved me", "thanks for the tonic!!" },
	praise_rescue = { "YOOO you saved me", "clutch rescue", "thanks for pulling me out", "that was sick" },
	praise_escape = { "got out!", "ez escape", "phew" },
	praise_tension = { "this game is scary lol", "the hollows are creepy, love it", "my heart is racing" },
	hollow_again = {
		"it grabbed me again right away",
		"just escaped and it's back on me",
	},
	boring_wait = {
		"spectating is boring",
		"how long till the next run",
		"waiting...",
	},
	dark = { "it's so dark i can't see anything", "turn up the brightness?" },
	social_help = { "help me!!", "someone come get me", "im grabbed by the building" },
	social_call = { "get back to the train!", "come on, it's leaving", "who has a tonic" },
	tired = { "one more then bed", "im so tired lol", "gtg soon" },
	quit_frustrated = { "im done", "this is rigged, bye", "rage quitting" },
	quit_bored = { "kinda boring, gonna play something else", "bye" },
	quit_tired = { "gotta sleep, gn", "bed time bye" },
	quit_time = { "gtg", "mom says off, bye", "out of time, later" },
	touch_button = { "the pull button is too small", "my thumb was on the button and it didn't count" },
}

function Humans.say(rng, h, topic: string, t: number, cooldown: number?): string?
	local last = h.spoke[topic]
	if last and t - last < (cooldown or 25) then
		return nil
	end
	local lines = LINES[topic]
	if lines == nil then
		return nil
	end
	h.spoke[topic] = t
	local line = lines[rng:int(1, #lines)]
	if h.age >= 18 and string.lower(line) == line and rng:next() < 0.6 then
		line = string.upper(string.sub(line, 1, 1)) .. string.sub(line, 2)
	end
	return line
end

Humans.KIND = {
	rescue_timing = "complaint",
	rescue_unreachable = "complaint",
	nobody_near = "complaint",
	lag = "complaint",
	items_lost = "confusion",
	items_lost_understood = "praise",
	unclear_timer = "confusion",
	near_miss_timer = "complaint",
	armless_run = "social",
	healed = "praise",
	praise_rescue = "praise",
	praise_escape = "praise",
	praise_tension = "praise",
	hollow_again = "complaint",
	boring_wait = "complaint",
	dark = "complaint",
	social_help = "social",
	social_call = "social",
	tired = "social",
	touch_button = "complaint",
	quit_frustrated = "quit",
	quit_bored = "quit",
	quit_tired = "quit",
	quit_time = "quit",
}

return Humans
