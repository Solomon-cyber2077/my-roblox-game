--!strict
--[[
	Recoverable arm loss (docs/direction/limb-loss-final-pass-2026-10-28.md). Every value is a
	starting hypothesis from the design, not a measurement. Pure: read by Logic/Injury,
	Logic/Rescue, Logic/CarryPriority, the services and the client.

	Enabled is the feature flag. It stays false until the release gate says go; the
	Studio-only dev command `limbs` flips it for a playtest (ReplicatedStorage attribute
	LimbLossDev).
]]

return table.freeze({
	Enabled = false,

	-- the rescue: an invitation, then one rescuer's three beats (Logic/Rescue)
	Rescue = table.freeze({
		Invite = 1.8, -- seconds the invitation stays open before any delay allowance
		InviteMax = 2.5, -- never longer than this, whatever the measured delay
		Reach = 6, -- studs from the rescuer's root to the victim's
		-- seconds a crewmate needs to notice the prompt and react; the rescue is only offered to those
		-- who could still arrive inside the invitation (Rescue.arrivalRadius). An assumption to measure.
		ReactAllowance = 0.4,
		Beats = table.freeze({ 0.7, 1.2, 1.7 }), -- seconds after the sequence starts (0.5 lead-in first)
		Window = 0.17, -- a press counts within this many seconds either side of its beat (0.12 was too hard on touch: sim)
		CompensationMax = 0.15, -- the most arrival delay a press may be credited
		Length = 2.0, -- the sequence ends this long after it starts; no extensions
		Stagger = 1.2, -- the Hollow reels this long after a successful rescue
	}),

	-- carrying (slot units, Logic/Inventory)
	OneArmPenalty = 2, -- one missing arm: capacity - this, never below 0
	-- both missing: 0 ordinary capacity

	-- recovery
	HealSeconds = 2, -- a Tonic restoring an arm takes this long and can be interrupted
	HealItem = "Tonic", -- the existing Health Bottle
	HealReach = 7, -- studs: a crewmate administering, or the armless player from the crew chest

	-- the run back to the train with no arms
	ReturnSeconds = 35,
	WarningSeconds = 5, -- the last seconds get posture and audio only: no slowdown, no flashing
	Presentation = table.freeze({
		RecoilSeconds = 0.85,
		RegrowSeconds = 1.1,
		CollapseSeconds = 1.0,
		WarningInterval = 1.25,
		LanternHandDown = 0.85,
		LanternHandForward = 0.15,
		BodyLanternBrightness = 0.65,
	}),

	-- presentation (client only, Controllers/InjuryController)
	Limbs = table.freeze({
		MaxPerClient = 4,
		SettleSeconds = 3,
		RemoveSeconds = 8,
	}),

	-- the moment an arm comes away (client only: Controllers/InjuryController, Logic/TearFeedback).
	-- Pain and panic, short of gore: a wet tear and a bone snap, a cry, the view whiting out and
	-- flooding dark from the torn side, the world going muffled under a ringing in the ears, a racing
	-- heart and gasps. Crewmates nearby hear it where it happened and see a dark burst at the shoulder.
	Tear = table.freeze({
		ShockSeconds = 3.4, -- how long the shock (muffle, ring, tunnel) lasts on the victim
		CryDelay = 0.07, -- the cry starts this long after the tear (the snap first)
		-- every player keeps one voice: a cry picked from Config/Audio PainCry* and a pitch in this range
		VoicePitchLow = 0.9,
		VoicePitchHigh = 1.16,
		-- the world going muffled (AudioController.Shock): starts after the impact, holds, lets go
		MuffleDelay = 0.12,
		MuffleAttack = 0.3,
		MuffleHold = 1.1, -- seconds at full depth after the attack
		MuffleHighDb = -30, -- EqualizerSoundEffect gains on the main mix at full depth
		MuffleMidDb = -12,
		MuffleVolume = 0.55, -- the main mix's volume share kept at full depth
		-- the ringing in the ears (its own group, so the muffle leaves it alone)
		RingPeakAt = 0.55,
		RingVolume = 0.2,
		-- the racing heart: gaps between beats from Fast to Settled over the shock
		HeartFast = 0.36,
		HeartSettled = 0.7,
		BreathAt = 1.2, -- ragged panting from here to the end of the shock (skipped during a rush,
		-- which pants already: GrabController)
		-- the body: camera shake, a kick, the screen (UI/Trauma), a controller rumble
		Shake = 1.1,
		Kick = 0.7,
		KickSeconds = 0.35,
		Haptic = 1,
		HapticSeconds = 0.4,
		-- crewmates: full reaction within NearStuds, nothing past FarStuds
		NearStuds = 14,
		FarStuds = 60,
		OnlookerShake = 0.6, -- shake is squared and rotation only: about 0.7 degrees
		OnlookerPulse = 0.35,
		CryRollOff = 150, -- studs the tear and the cry carry
		-- the burst at the shoulder and the stump's brief drip (every client)
		Droplets = 26,
		DropletSpeed = 14,
		Mist = 9,
		StumpSeconds = 1.8,
		StumpRate = 16,
	}),

	-- the dead player's witness view (Controllers/DeathCamController)
	Witness = table.freeze({
		Seconds = 2.5, -- at most, collapse included
		SkipAfter = 0.5,
		DistanceMin = 8,
		DistanceMax = 12,
		Height = 3,
		FocusDrop = 1,
		PushFraction = 0.12,
		WallClearance = 0.3,
	}),
})
