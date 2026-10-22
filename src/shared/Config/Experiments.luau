--!strict
--[[
	The experiments (docs/FINAL-DESIGN.md A.4 and Prompt 10). Rules in Logic/Experiments.

	Randomized per crew at run start: when a starting crew has an eligible player, the arm is
	derived from the run seed and the experiment's salt, and every eligible player in the crew
	runs it. Each eligible player's first exposed arm is stored for good (profile.telemetry.cohorts)
	and logged once (cohort_assigned; arm A or B, the Telemetry vocabulary's names for the arms).
	E1 and E2 use independent salts, so together they cross 2x2.

	  E1  the first-run route: A Short Line, B Long Line. Eligible: a new player (Logic/Routes).
	      Exposed at run start.
	  E2  the stop-1 sighting: A sighting, B none. Eligible: a crew on tutorial tier 1 (the only
	      runs that stage the sighting). Exposed when stop 1's doors open (the eligibility point
	      both arms log), and only for players present then.

	Enabled is false until the public soft launch (G2): with an experiment off, the route policy
	is Short for any crew with a new player and the sighting follows Config/Tutorial
	Sighting.Enabled. Studio's Dev `experiment` forces an arm.
]]

export type Def = {
	id: string, -- Telemetry ExperimentId
	salt: string,
	arms: { string }, -- the arm values the game reads; index 1 is logged as A, 2 as B
	enabled: boolean,
}

local E1: Def = table.freeze({
	id = "E1",
	salt = "e1-route",
	arms = table.freeze({ "Short", "Long" }),
	enabled = false,
})

local E2: Def = table.freeze({
	id = "E2",
	salt = "e2-sighting",
	arms = table.freeze({ "Sighting", "None" }),
	enabled = false,
})

return table.freeze({
	E1 = E1,
	E2 = E2,
	Order = table.freeze({ "E1", "E2" }),
	ArmNames = table.freeze({ "A", "B" }), -- Telemetry Arm for arms[1], arms[2]
})
