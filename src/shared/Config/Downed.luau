--!strict
--[[
	Downed (docs/direction/2026-10-29-downed-sol-final-pass.md, numbers from docs/direction/2026-10-30-downed-direction.md): when a lethal Hollow
	hold runs out on someone with an arm left, the crew gets one readable chance to tear them free while the Hollow
	drags them away. Every value is a starting candidate for the simulator (`lune run downed`), not a measurement.

	Enabled is the feature flag. It stays false whatever the checks say until the owner turns it on, and it needs
	Config/Injury.Enabled too (the rescue tears an arm).
]]

return table.freeze({
	Enabled = false,

	BleedSeconds = 20, -- one fixed deadline from entry; never extended, never paused
	BleedCandidates = table.freeze({ 15, 20, 25 }), -- swept by `lune run downed`

	-- movement (studs a second, absolute: not shares of a walk speed)
	DragSpeed = 4, -- the assigned Hollow pulls the victim away from the train this fast at most
	CrawlSpeed = 3, -- the victim crawling against it: full opposition leaves ~1 stud a second of drag
	MissDragMult = 1.1, -- after a missed rescue the Hollow pulls harder (4.4 studs a second), for the rest of the session

	-- easier than the ordinary rescue (Config/Injury.Rescue): the victim's life rides on one crewmate's thumb
	Rescue = table.freeze({
		Beats = table.freeze({ 0.8, 1.6 }),
		Window = 0.25,
		CompensationMax = 0.15,
		Length = 1.9, -- the last beat's window plus a little
	}),
	RetryFloor = 4, -- a miss reopens the slot once, for anyone, if at least this much bleed is left

	-- a successful rescue, on both of them; does not stack
	Adrenaline = table.freeze({ Seconds = 15, SpeedMult = 1.15, StaminaRegenMult = 1.5 }),

	-- how the crew finds them
	Beacon = table.freeze({ Color = table.freeze({ 235, 240, 245 }), Pulse = 0.8 }), -- bone white: amber means the train
	Heartbeat = table.freeze({ Bpm = 60, Radius = 50 }),
})
