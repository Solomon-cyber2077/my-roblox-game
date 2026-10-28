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
		Beats = table.freeze({ 0.7, 1.2, 1.7 }), -- seconds after the sequence starts (0.5 lead-in first)
		Window = 0.12, -- a press counts within this many seconds either side of its beat
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
