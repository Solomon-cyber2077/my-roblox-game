--!strict
--[[
	Foley numbers: the small sounds of a body moving and handling things, beside the footsteps
	(Tuning.Footsteps). Read by Logic/Footsteps and Controllers/FootstepController.

	A default jump (JumpHeight 7.2 under gravity 196.2) comes down at about 53 studs a second, a
	step off a one-stud ledge at about 20, a ten-stud drop at about 63.
]]

return table.freeze({
	-- landing: slower than LandSoft makes no sound of its own (a step down is just a step); from
	-- LandSoft both feet come down on the surface's takes; from LandHard a body thud joins them
	LandSoft = 24,
	LandHard = 66,
	-- the landing's level over the step takes, from LandSoft up to LandHard
	LandGainMin = 1.1,
	LandGainMax = 1.8,
	-- seconds between the two feet of a landing
	LandFootGap = 0.06,
	-- a push-off counts as a jump from this upward speed (studs a second); a bump or a ramp is slower
	JumpRise = 20,
	-- seconds before the same body's jump can sound again (a bunny hop is one whump a jump, not a chatter)
	JumpGap = 0.3,
	-- breaking into a sprint (walk 21, sprint 31): crossing SprintFrom plays one harder step, a scuff
	-- as the boots dig in; it re-arms once the body slows under SprintRearm
	SprintFrom = 27,
	SprintRearm = 23,
	ScuffGain = 1.5,
})
