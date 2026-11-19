--!strict
--[[
	The Brute's skeleton and block build (Builders/HollowBuilder brute), its grab holds (Config/Grabs) and the
	scale its poses move by (Animation/HollowPoses). Two bodies:
	  Block  the build the Test Launch has: 8.5 studs, shoulders 4 studs wide
	  Giant  the remake (tools/brute/build.py, G): a heavy man with ordinary proportions, 12 studs if it stood
	         straight. Its root box is taller than a building door (Config/Buildings DoorHeight 9), so it can't
	         walk in; the Reach grab is how it takes someone standing at a door or window.
	`current` is Giant only while Tuning.BruteRemake.Enabled is on.
	Positions are { x, y, z } in the parent part's frame, sizes in studs, angles in degrees.
]]

local Tuning = require(script.Parent.Tuning)

export type Body = {
	hip: number, -- Humanoid.HipHeight
	root: { number },
	scale: number, -- how far its poses move, against the Block body
	pelvis: { number },
	chest: { number },
	head: { number },
	jaw: { number },
	rootC0: { number },
	waistC0: { number },
	lean: number,
	chestC1: { number },
	neckC0: { number },
	neckTilt: number,
	headC1: { number },
	jawC0: { number },
	jawC1: { number },
	shoulder: { number },
	upper: number,
	fore: number,
	upperL: number?, -- the left arm's own lengths, when it differs from the right
	foreL: number?,
	armThick: number,
	handL: { number },
	handR: { number },
	hipAt: { number },
	thigh: number,
	shin: number,
	legThick: number,
	foot: { number },
	blade: { size: { number }, y: number }, -- the shovel blade's block, under the right hand
	holds: { [string]: { number } }, -- each grab's hold position (Config/Grabs hold.pos)
	lift: boolean, -- the Stoker's grab: lifted high in the burnt left hand, pinned on a miss, then the shovel
}

local Block: Body = {
	hip = 4.1,
	root = { 3.4, 3.2, 2.0 },
	scale = 1,
	pelvis = { 2.5, 1.3, 1.6 },
	chest = { 3.6, 3.2, 2.1 },
	head = { 1.15, 1.15, 1.2 },
	jaw = { 1.0, 0.38, 1.0 },
	rootC0 = { 0, -0.85, 0 },
	waistC0 = { 0, 0.62, 0 },
	lean = -24,
	chestC1 = { 0, -1.6, 0 },
	neckC0 = { 0, 1.42, -0.75 },
	neckTilt = 20,
	headC1 = { 0, -0.35, 0 },
	jawC0 = { 0, -0.55, 0.3 },
	jawC1 = { 0, 0.12, 0.45 },
	shoulder = { 2.05, 1.0, 0.1 },
	upper = 2.5,
	fore = 2.4,
	armThick = 1.05,
	handL = { 1.15, 0.95, 1.0 },
	handR = { 0.5, 0.5, 0.5 },
	hipAt = { 0.75, -0.55, 0 },
	thigh = 2.0,
	shin = 1.85,
	legThick = 0.95,
	foot = { 1.0, 0.55, 1.5 },
	blade = { size = { 1.7, 2.3, 0.16 }, y = -1.35 },
	holds = {
		Fist = { -1.6, 0.4, -3.8 },
		Shovel = { 0.9, -5.15, -5.2 },
		Bearhug = { 0, -1.1, -2.9 },
		Slam = { 0.9, -5.15, -5.2 },
		Reach = { 0.4, -3.0, -4.6 },
	},
	lift = false,
}

local Giant: Body = {
	hip = 5.2,
	root = { 2.8, 4.0, 2.2 },
	scale = 1.26, -- root height over the ground, 7.2 against 5.7
	pelvis = { 2.6, 1.6, 2.0 },
	chest = { 3.0, 3.2, 2.3 },
	head = { 1.4, 1.6, 1.5 },
	jaw = { 1.2, 0.45, 1.2 },
	rootC0 = { 0, -1.1, 0 },
	waistC0 = { 0, 0.85, 0 },
	lean = -12,
	chestC1 = { 0, -1.6, 0 },
	neckC0 = { 0, 1.75, -0.8 },
	neckTilt = 16,
	headC1 = { 0, -0.55, 0 },
	jawC0 = { 0, -0.79, 0.36 },
	jawC1 = { 0, 0.144, 0.54 },
	shoulder = { 1.5, 1.05, 0.05 },
	upper = 2.35,
	fore = 2.15,
	-- the burnt left arm is shorter (owner 2026-11-19: "his left arm shorter"; the scan rebuild's round 7)
	upperL = 1.95,
	foreL = 1.78,
	armThick = 1.1,
	handL = { 1.2, 1.05, 1.1 },
	handR = { 0.55, 0.6, 0.55 },
	hipAt = { 0.8, -0.4, 0 },
	thigh = 2.6,
	shin = 2.55,
	legThick = 1.3,
	foot = { 1.25, 0.55, 1.9 },
	blade = { size = { 1.85, 1.5, 0.16 }, y = -3.4 },
	holds = {
		Fist = { -1.7, 1.2, -4.2 },
		Shovel = { 0.9, -6.6, -4.9 },
		Bearhug = { 0, -0.2, -2.5 },
		Slam = { -0.9, -6.6, -4.9 }, -- under the burnt left hand (the Stoker's pin)
		-- hauled out through the opening: held up in front of it at a sill's height, both hands on them
		Reach = { 0.3, -2.6, -5.0 },
		-- held up in the burnt left hand, higher than any other Hollow lifts its prey
		Lift = { -1.3, 1.5, -3.7 },
	},
	lift = true,
}

return {
	Block = Block,
	Giant = Giant,
	current = if Tuning.BruteRemake.Enabled then Giant else Block,
}
