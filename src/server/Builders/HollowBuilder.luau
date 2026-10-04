--!strict
--[[
	The Hollows, built from primitives on a Humanoid rig. Three kinds share one
	skeleton of Motor6Ds so the client can animate every joint procedurally
	(HollowAnimator) with no animation assets:

	  Stalker  the lost porter: too tall, too thin, in the rags of a railway greatcoat.
	           No eyes, only sockets with a pinprick of shine, and a jaw that drops open.
	  Crawler  the passenger: a tall woman in a ruined nightgown, folded wrong onto limbs
	           far too long, elbows and knees above her back, her head upside down.
	  Brute    the stoker: a soot-black hulk in a leather apron, embers smouldering in the
	           cracks of its chest, one forearm ending in a shovel blade.

	Skeleton (Part0 -> Part1, joint name):
	  Root -> Pelvis (RootJoint), Pelvis -> Chest (Waist), Chest -> Head (Neck), Head -> Jaw (Jaw)
	  Chest -> UpperArm (L/RShoulder) -> Forearm (L/RElbow) -> Hand (L/RWrist)
	  Pelvis -> Thigh (L/RHip) -> Shin (L/RKnee)
	Limb bones are cylinders whose joint sits at their top end, so a Transform swings
	the limb about that joint. Only the invisible root collides.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)

local HollowBuilder = {}

local rgb = Color3.fromRGB

type Spec = {
	hip: number, -- Humanoid.HipHeight
	root: Vector3,
}

local SPECS: { [string]: Spec } = {
	Stalker = { hip = 3.9, root = Vector3.new(2.4, 2.6, 1.4) },
	Crawler = { hip = 2.6, root = Vector3.new(3.4, 1.8, 6.0) },
	Brute = { hip = 4.1, root = Vector3.new(3.4, 3.2, 2.0) },
}

local ICHOR = rgb(18, 12, 14)
local MOUTH = rgb(46, 12, 14)
local TOOTH = rgb(196, 184, 148)
local SHINE = rgb(236, 226, 170)
local BRASS = rgb(124, 100, 58)

-- Helpers ---------------------------------------------------------------------------------

local function loose(part: BasePart): BasePart
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	return part
end

local function block(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = loose(Kit.block(model, size, CFrame.new(), color, { material = material, collide = false }))
	part.Name = name
	return part
end

-- A limb bone: a cylinder of `length` whose top end is the joint (see boneC1).
local function bone(
	model: Model,
	name: string,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = loose(
		Kit.cylinder(model, length, diameter, CFrame.new(), color, { material = material, collide = false })
	)
	part.Name = name
	return part
end

local function boneC1(length: number): CFrame
	return CFrame.Angles(0, 0, -math.pi / 2) * CFrame.new(0, length / 2, 0)
end

local function joint(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = part0
	return motor
end

local function stick(to: BasePart, part: BasePart, offset: CFrame): BasePart
	loose(part)
	local weld = Instance.new("Weld")
	weld.Part0 = to
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	return part
end

-- Decorations, welded to a body part at `offset` in that part's frame.
local function deco(
	model: Model,
	to: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return stick(
		to,
		Kit.block(model, size, CFrame.new(), color, { material = material, collide = false }),
		offset
	)
end

local function decoWedge(
	model: Model,
	to: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return stick(
		to,
		Kit.wedge(model, size, CFrame.new(), color, { material = material, collide = false }),
		offset
	)
end

local function decoBall(
	model: Model,
	to: BasePart,
	diameter: number,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return stick(
		to,
		Kit.ball(model, diameter, CFrame.new(), color, { material = material, collide = false }),
		offset
	)
end

local function decoRod(
	model: Model,
	to: BasePart,
	length: number,
	diameter: number,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	return stick(
		to,
		Kit.cylinder(model, length, diameter, CFrame.new(), color, { material = material, collide = false }),
		offset
	)
end

local function shine(model: Model, to: BasePart, offset: CFrame, size: number)
	local eye =
		stick(to, Kit.neon(model, Vector3.one * size, CFrame.new(), SHINE, Enum.PartType.Ball), offset)
	eye.Name = "Eye"
	eye.Transparency = 0.15
end

-- A limb from `parent`: upper bone, lower bone and an end piece. Returns the end piece.
local function limb(
	model: Model,
	side: string,
	names: { string }, -- upper, lower, end part names
	joints: { string }, -- the three joint names
	parent: BasePart,
	at: CFrame,
	upper: number,
	lower: number,
	thick: number,
	upperColor: Color3,
	lowerColor: Color3,
	upperMaterial: Enum.Material?,
	lowerMaterial: Enum.Material?,
	endSize: Vector3,
	endColor: Color3
): (BasePart, BasePart, BasePart)
	local a = bone(model, side .. names[1], upper, thick, upperColor, upperMaterial)
	local b = bone(model, side .. names[2], lower, thick * 0.82, lowerColor, lowerMaterial)
	local c = block(model, side .. names[3], endSize, endColor, lowerMaterial)
	joint(side .. joints[1], parent, a, at, boneC1(upper))
	-- a bone's own frame runs along X, with its far end at -X
	joint(
		side .. joints[2],
		a,
		b,
		CFrame.new(-upper / 2, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2),
		boneC1(lower)
	)
	joint(
		side .. joints[3],
		b,
		c,
		CFrame.new(-lower / 2, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2),
		CFrame.new(0, endSize.Y / 2, 0)
	)
	return a, b, c
end

local function emitter(parent: BasePart, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

-- Kinds -----------------------------------------------------------------------------------

local function stalker(model: Model, root: BasePart)
	local SKIN = rgb(150, 156, 146)
	local SKIN_DARK = rgb(118, 124, 114)
	local COAT = rgb(44, 58, 50)
	local LAPEL = rgb(30, 40, 34)
	local TROUSER = rgb(40, 40, 44)
	local cloth = Enum.Material.Fabric
	local skin = Enum.Material.SmoothPlastic

	local pelvis = block(model, "Pelvis", Vector3.new(1.7, 0.9, 0.95), COAT, cloth)
	local chest = block(model, "Chest", Vector3.new(1.9, 2.8, 1.05), COAT, cloth)
	local head = block(model, "Head", Vector3.new(0.95, 1.25, 1.05), SKIN, skin)
	local jaw = block(model, "Jaw", Vector3.new(0.78, 0.32, 0.9), SKIN_DARK, skin)
	joint("RootJoint", root, pelvis, CFrame.new(0, -0.65, 0), CFrame.new())
	joint("Waist", pelvis, chest, CFrame.new(0, 0.42, 0) * Kit.angles(-20, 0, 0), CFrame.new(0, -1.4, 0))
	joint("Neck", chest, head, CFrame.new(0, 1.42, -0.32) * Kit.angles(4, 0, 0), CFrame.new(0, -0.6, 0.12))
	joint("Jaw", head, jaw, CFrame.new(0, -0.56, 0.3), CFrame.new(0, 0.1, 0.42))

	-- the open coat over a starved ribcage
	local ribs = deco(model, chest, Vector3.new(0.72, 2.0, 0.1), CFrame.new(0, 0.2, -0.575), SKIN_DARK, skin)
	for i = 0, 4 do
		decoRod(model, ribs, 0.78 - i * 0.05, 0.09, CFrame.new(0, 0.7 - i * 0.34, -0.06), SKIN, skin)
	end
	for _, side in { -1, 1 } do
		decoWedge(
			model,
			chest,
			Vector3.new(0.12, 2.3, 0.5),
			CFrame.new(side * 0.52, 0.05, -0.6) * Kit.angles(0, side * 90, 0),
			LAPEL,
			cloth
		)
		decoBall(model, chest, 0.14, CFrame.new(side * 0.62, -0.75, -0.6), BRASS, Enum.Material.Metal)
	end
	-- coat tails in tatters, hanging past the knees
	for i, x in { -0.62, 0.05, 0.6 } do
		deco(
			model,
			pelvis,
			Vector3.new(0.5 + (i % 2) * 0.12, 2.5 + i * 0.25, 0.08 + i * 0.01),
			CFrame.new(x, -1.55 - i * 0.12, 0.42 + i * 0.015) * Kit.angles(-3 - i * 3, 0, (i - 2) * 5),
			COAT,
			cloth
		)
	end

	-- a crushed porter's cap and the skull behind the face
	decoBall(model, head, 1.08, CFrame.new(0, 0.32, 0.12), SKIN_DARK, skin)
	decoRod(model, head, 0.34, 1.16, CFrame.new(0.05, 0.86, 0.08) * Kit.angles(0, 0, 98), LAPEL, cloth)
	decoWedge(
		model,
		head,
		Vector3.new(1.0, 0.12, 0.4),
		CFrame.new(0.05, 0.72, -0.62) * Kit.angles(0, 180, 0),
		LAPEL,
		cloth
	)
	deco(
		model,
		head,
		Vector3.new(0.22, 0.16, 0.05),
		CFrame.new(0.05, 0.86, -0.53),
		BRASS,
		Enum.Material.Metal
	)

	-- no eyes: dark sockets with a pinprick of shine deep inside
	for _, side in { -0.22, 0.22 } do
		deco(model, head, Vector3.new(0.3, 0.24, 0.08), CFrame.new(side, 0.12, -0.53), ICHOR, skin)
		shine(model, head, CFrame.new(side, 0.1, -0.58), 0.07)
	end
	deco(model, head, Vector3.new(0.6, 0.22, 0.08), CFrame.new(0, -0.38, -0.53), MOUTH, skin)
	for i = -2, 2 do
		decoWedge(
			model,
			head,
			Vector3.new(0.07, 0.16, 0.05),
			CFrame.new(i * 0.12, -0.36, -0.59) * Kit.angles(0, 0, 180),
			TOOTH,
			skin
		)
	end
	for i = -1, 1 do
		decoWedge(model, jaw, Vector3.new(0.07, 0.18, 0.05), CFrame.new(i * 0.16, 0.24, -0.38), TOOTH, skin)
	end

	-- arms far too long, with fingers to match
	for _, side in { "L", "R" } do
		local s = if side == "L" then -1 else 1
		local _, _, hand = limb(
			model,
			side,
			{ "UpperArm", "Forearm", "Hand" },
			{ "Shoulder", "Elbow", "Wrist" },
			chest,
			CFrame.new(s * 1.12, 1.12, 0),
			2.5,
			2.35,
			0.4,
			COAT,
			SKIN,
			cloth,
			skin,
			Vector3.new(0.42, 0.5, 0.22),
			SKIN_DARK
		)
		for f = -1, 1 do
			local finger = deco(
				model,
				hand,
				Vector3.new(0.07, 1.05 - math.abs(f) * 0.15, 0.07),
				CFrame.new(f * 0.13, -0.72 + math.abs(f) * 0.07, 0) * Kit.angles(0, 0, f * 6),
				SKIN,
				skin
			)
			decoWedge(
				model,
				finger,
				Vector3.new(0.06, 0.24, 0.1),
				CFrame.new(0, -0.62, -0.02) * Kit.angles(180, 0, 0),
				ICHOR,
				skin
			)
		end
		local thigh, shin, foot = limb(
			model,
			side,
			{ "Thigh", "Shin", "Foot" },
			{ "Hip", "Knee", "Ankle" },
			pelvis,
			CFrame.new(s * 0.5, -0.4, 0),
			2.1,
			1.85,
			0.46,
			TROUSER,
			SKIN,
			cloth,
			skin,
			Vector3.new(0.4, 0.2, 0.9),
			SKIN_DARK
		)
		local _ = thigh
		-- trousers torn off at the knee
		decoRod(model, shin, 0.32, 0.5, CFrame.new(0.72, 0, 0), TROUSER, cloth)
		local _ = foot
	end

	-- black ichor drips from the jaw; a low mist drags at the feet
	emitter(jaw, {
		Name = "Drip",
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(ICHOR),
		Size = NumberSequence.new(0.14),
		Squash = NumberSequence.new(1.4),
		Rate = 2.5,
		Lifetime = NumberRange.new(0.6, 0.9),
		Speed = NumberRange.new(0, 0.2),
		Acceleration = Vector3.new(0, -38, 0),
		LightInfluence = 1,
	})
	emitter(root, {
		Name = "FootMist",
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(rgb(52, 54, 60)),
		Rate = 5,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Bottom,
		Acceleration = Vector3.new(0, 0.5, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		}),
		RotSpeed = NumberRange.new(-15, 15),
	})
end

--[[
	The passenger: a tall woman in a ruined nightgown, folded wrong. She goes on all fours
	on limbs far too long, elbows and knees jutting high over her back like a spider,
	her head turned upside down under the end of her spine, her hair dragging on the
	ground. Lace at her throat, frills at her sleeves, a sash and a locket from a wedding
	that never happened, a bonnet hanging off the back of her skull.
]]
local function crawler(model: Model, root: BasePart)
	local GOWN = rgb(206, 196, 176)
	local GOWN_DARK = rgb(160, 148, 128)
	local LACE = rgb(232, 226, 210)
	local STAIN = rgb(98, 56, 44)
	local SKIN = rgb(150, 144, 140)
	local SKIN_DARK = rgb(112, 106, 104)
	local BRUISE = rgb(92, 84, 96)
	local HAIR = rgb(20, 18, 20)
	local SASH = rgb(74, 88, 116)
	local cloth = Enum.Material.Fabric
	local skin = Enum.Material.SmoothPlastic

	local pelvis = block(model, "Pelvis", Vector3.new(2.2, 1.3, 1.6), GOWN, cloth)
	local chest = block(model, "Chest", Vector3.new(2.4, 3.6, 1.4), GOWN, cloth)
	local head = block(model, "Head", Vector3.new(1.3, 1.5, 1.35), SKIN, skin)
	local jaw = block(model, "Jaw", Vector3.new(1.0, 0.42, 1.1), SKIN_DARK, skin)
	joint("RootJoint", root, pelvis, CFrame.new(0, 0.2, 1.7), CFrame.new())
	-- the spine runs forward along the ground, its front end a little raised
	joint("Waist", pelvis, chest, CFrame.new(0, 0.2, -0.7) * Kit.angles(-84, 0, 0), CFrame.new(0, -1.85, 0))
	-- and the head hangs under the end of it, upside down, looking ahead
	joint("Neck", chest, head, CFrame.new(0, 1.9, -0.1) * Kit.angles(70, 0, 180), CFrame.new(0, -0.7, 0))
	joint("Jaw", head, jaw, CFrame.new(0, -0.66, 0.36), CFrame.new(0, 0.12, 0.5))

	-- the gown: torn open down the back over a spine that shows, stained at the front
	for i = 0, 5 do
		decoBall(model, chest, 0.42 - i * 0.02, CFrame.new(0, 1.35 - i * 0.55, 0.62), SKIN_DARK, skin)
	end
	deco(model, chest, Vector3.new(0.9, 3.0, 0.08), CFrame.new(0, -0.1, 0.71), SKIN, skin)
	for _, side in { -1, 1 } do
		-- ragged edges of the tear
		deco(
			model,
			chest,
			Vector3.new(0.14, 2.8, 0.12),
			CFrame.new(side * 0.52, -0.2, 0.74) * Kit.angles(0, 0, side * 4),
			GOWN_DARK,
			cloth
		)
	end
	deco(model, chest, Vector3.new(1.3, 1.5, 0.08), CFrame.new(0.4, 0.5, -0.71), STAIN, cloth)
	deco(model, chest, Vector3.new(0.8, 0.9, 0.08), CFrame.new(-0.6, -0.9, -0.715), STAIN, cloth)
	-- a lace collar round the throat, its points hanging toward the ground
	deco(model, chest, Vector3.new(2.6, 0.32, 1.6), CFrame.new(0, 1.66, 0), LACE, cloth)
	for i = -3, 3 do
		decoWedge(
			model,
			chest,
			Vector3.new(0.3, 0.42, 0.1),
			CFrame.new(i * 0.34, 1.62, -0.86) * Kit.angles(-90, 0, 0),
			LACE,
			cloth
		)
	end
	-- the locket, swinging under her
	decoRod(
		model,
		chest,
		0.9,
		0.06,
		CFrame.new(0, 1.3, -0.9) * Kit.angles(0, 0, 90),
		BRASS,
		Enum.Material.Metal
	)
	decoBall(model, chest, 0.42, CFrame.new(0, 0.82, -1.0), BRASS, Enum.Material.Metal)
	deco(model, chest, Vector3.new(0.26, 0.3, 0.08), CFrame.new(0, 0.82, -1.22), LACE, skin)

	-- the skirt in tatters, its strips dragging on the ground behind her
	for i, spec in
		{
			{ x = -0.85, z = 0.55, w = 0.6, len = 3.0 },
			{ x = -0.3, z = 0.72, w = 0.7, len = 2.6 },
			{ x = 0.35, z = 0.7, w = 0.55, len = 3.2 },
			{ x = 0.9, z = 0.5, w = 0.6, len = 2.8 },
			{ x = -1.05, z = -0.2, w = 0.5, len = 2.4 },
			{ x = 1.06, z = -0.25, w = 0.5, len = 2.7 },
		}
	do
		deco(
			model,
			pelvis,
			Vector3.new(spec.w, spec.len, 0.07 + i * 0.004),
			CFrame.new(spec.x, -0.4 - spec.len / 2, spec.z) * Kit.angles(-6 + i * 2, 0, (i - 3.5) * 3),
			if i % 3 == 0 then GOWN_DARK else GOWN,
			cloth
		)
	end
	deco(model, pelvis, Vector3.new(2.32, 0.4, 1.72), CFrame.new(0, 0.3, 0), SASH, cloth)
	for _, side in { -1, 1 } do
		deco(
			model,
			pelvis,
			Vector3.new(0.22, 1.9, 0.06),
			CFrame.new(side * 0.25, -0.6, 0.9) * Kit.angles(-8, 0, side * 10),
			SASH,
			cloth
		)
	end
	deco(model, pelvis, Vector3.new(0.7, 0.6, 0.08), CFrame.new(-0.4, -0.2, 0.83), STAIN, cloth)

	-- the face: too many eyes, a mouth full of teeth
	for i, offset in { { -0.3, 0.18 }, { 0.3, 0.18 }, { -0.13, 0.42 }, { 0.17, 0.44 }, { 0.43, 0.38 } } do
		deco(model, head, Vector3.new(0.22, 0.2, 0.06), CFrame.new(offset[1], offset[2], -0.68), ICHOR, skin)
		shine(model, head, CFrame.new(offset[1], offset[2], -0.72), if i <= 2 then 0.1 else 0.06)
	end
	deco(model, head, Vector3.new(0.86, 0.26, 0.08), CFrame.new(0, -0.42, -0.66), MOUTH, skin)
	for i = -3, 3 do
		decoWedge(
			model,
			head,
			Vector3.new(0.07, 0.22, 0.05),
			CFrame.new(i * 0.115, -0.4, -0.72) * Kit.angles(0, 0, 180),
			TOOTH,
			skin
		)
	end
	for i = -2, 2 do
		decoWedge(model, jaw, Vector3.new(0.07, 0.22, 0.05), CFrame.new(i * 0.15, 0.3, -0.5), TOOTH, skin)
	end
	-- hair from the crown: the head is upside down, so it hangs to the ground
	for i = -3, 4 do
		local long = 2.2 + ((i * 7) % 5) * 0.2
		deco(
			model,
			head,
			Vector3.new(0.16 + (i % 2) * 0.05, long, 0.1),
			CFrame.new(i * 0.15 - 0.07, 0.7 + long / 2, 0.15 + (i % 3) * 0.12)
				* Kit.angles(-6 + (i % 3) * 5, 0, i * 2),
			HAIR,
			cloth
		)
	end
	-- the bonnet, hanging off the back of her skull by its ribbon
	decoRod(model, head, 0.9, 1.5, CFrame.new(0, 0.35, 0.38) * Kit.angles(0, 90, 0), LACE, cloth)
	decoRod(model, head, 0.2, 1.62, CFrame.new(0, 0.35, -0.12) * Kit.angles(0, 90, 0), GOWN_DARK, cloth)
	for _, side in { -1, 1 } do
		deco(
			model,
			head,
			Vector3.new(0.14, 1.6, 0.05),
			CFrame.new(side * 0.6, -0.3, 0.5) * Kit.angles(0, 0, side * -12),
			SASH,
			cloth
		)
	end

	-- limbs far too long, elbows and knees above her back (Animation/HollowPoses walks them)
	for _, side in { "L", "R" } do
		local s = if side == "L" then -1 else 1
		local upper, forearm, hand = limb(
			model,
			side,
			{ "UpperArm", "Forearm", "Hand" },
			{ "Shoulder", "Elbow", "Wrist" },
			chest,
			CFrame.new(s * 1.3, 1.45, 0) * Kit.angles(90, 0, 0),
			3.2,
			3.5,
			0.46,
			GOWN,
			SKIN,
			cloth,
			skin,
			Vector3.new(0.8, 0.26, 1.0),
			SKIN_DARK
		)
		-- a frilled cuff at the elbow, knuckles at the wrist
		decoRod(model, upper, 0.36, 0.72, CFrame.new(-1.45, 0, 0), LACE, cloth)
		decoBall(model, forearm, 0.48, CFrame.new(-1.72, 0, 0), SKIN_DARK, skin)
		deco(model, forearm, Vector3.new(1.1, 0.3, 0.4), CFrame.new(0.3, 0.12, 0.08), BRUISE, skin)
		for f = -1.5, 1.5 do
			decoWedge(
				model,
				hand,
				Vector3.new(0.1, 0.12, 0.72),
				CFrame.new(f * 0.2, -0.02, -0.82),
				ICHOR,
				skin
			)
		end
		local thigh, shin, foot = limb(
			model,
			side,
			{ "Thigh", "Shin", "Foot" },
			{ "Hip", "Knee", "Ankle" },
			pelvis,
			CFrame.new(s * 0.8, -0.3, 0.2),
			2.8,
			3.2,
			0.5,
			SKIN,
			SKIN,
			skin,
			skin,
			Vector3.new(0.55, 0.26, 1.2),
			SKIN_DARK
		)
		decoBall(model, thigh, 0.56, CFrame.new(-1.38, 0, 0), SKIN_DARK, skin)
		deco(model, shin, Vector3.new(1.2, 0.35, 0.42), CFrame.new(-0.4, 0.1, 0.12), BRUISE, skin)
		for t = -1, 1 do
			decoWedge(
				model,
				foot,
				Vector3.new(0.12, 0.12, 0.5),
				CFrame.new(t * 0.17, -0.02, -0.8),
				SKIN_DARK,
				skin
			)
		end
	end

	emitter(root, {
		Name = "Dust",
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(rgb(70, 66, 62)),
		Rate = 0,
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(80, 80),
		EmissionDirection = Enum.NormalId.Bottom,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	-- a cold breath from the upside-down mouth
	emitter(jaw, {
		Name = "Breath",
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(rgb(176, 180, 186)),
		Rate = 2,
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(0.4, 0.9),
		EmissionDirection = Enum.NormalId.Front,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.1) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
end

local function brute(model: Model, root: BasePart)
	local SOOT = rgb(46, 40, 38)
	local BURN = rgb(98, 46, 36)
	local APRON = rgb(66, 44, 30)
	local STRAP = rgb(40, 28, 20)
	local IRON = rgb(78, 72, 66)
	local RUST = rgb(104, 62, 40)
	local EMBER = rgb(255, 122, 42)
	local skin = Enum.Material.Slate
	local leather = Enum.Material.Leather

	local pelvis = block(model, "Pelvis", Vector3.new(2.5, 1.3, 1.6), APRON, leather)
	local chest = block(model, "Chest", Vector3.new(3.6, 3.2, 2.1), SOOT, skin)
	local head = block(model, "Head", Vector3.new(1.15, 1.15, 1.2), SOOT, skin)
	local jaw = block(model, "Jaw", Vector3.new(1.0, 0.38, 1.0), BURN, skin)
	joint("RootJoint", root, pelvis, CFrame.new(0, -0.85, 0), CFrame.new())
	joint("Waist", pelvis, chest, CFrame.new(0, 0.62, 0) * Kit.angles(-24, 0, 0), CFrame.new(0, -1.6, 0))
	joint("Neck", chest, head, CFrame.new(0, 1.42, -0.75) * Kit.angles(20, 0, 0), CFrame.new(0, -0.35, 0))
	joint("Jaw", head, jaw, CFrame.new(0, -0.55, 0.3), CFrame.new(0, 0.12, 0.45))

	-- hunched shoulders, burn scars and the leather apron
	for _, side in { -1, 1 } do
		decoBall(model, chest, 1.9, CFrame.new(side * 1.45, 1.15, 0.2), SOOT, skin)
		deco(
			model,
			chest,
			Vector3.new(0.3, 3.5, 0.12),
			CFrame.new(side * 0.75, 0.1, -1.23) * Kit.angles(0, 0, side * -8),
			STRAP,
			leather
		)
	end
	deco(model, chest, Vector3.new(2.2, 2.3, 0.14), CFrame.new(0, -0.45, -1.12), APRON, leather)
	deco(model, pelvis, Vector3.new(2.3, 2.2, 0.14), CFrame.new(0, -1.25, -0.86), APRON, leather)

	-- embers in the cracks of its chest: the only warm thing about it
	local cracks = {
		{ size = Vector3.new(0.12, 1.4, 0.06), at = CFrame.new(-1.2, 0.3, -1.08) * Kit.angles(0, 0, 25) },
		{ size = Vector3.new(0.1, 0.9, 0.06), at = CFrame.new(-1.45, -0.5, -1.08) * Kit.angles(0, 0, -15) },
		{ size = Vector3.new(0.12, 1.2, 0.06), at = CFrame.new(1.25, 0.1, -1.08) * Kit.angles(0, 0, -30) },
		{ size = Vector3.new(0.1, 1.6, 0.06), at = CFrame.new(0.4, 0.6, 1.08) * Kit.angles(0, 0, 40) },
		{ size = Vector3.new(0.1, 1.1, 0.06), at = CFrame.new(-0.6, -0.4, 1.08) * Kit.angles(0, 0, -20) },
	}
	local core: BasePart? = nil
	for _, crack in cracks do
		local glow = stick(chest, Kit.neon(model, crack.size, CFrame.new(), EMBER), crack.at)
		glow.Name = "Ember"
		core = core or glow
	end
	local warmth = Kit.pointLight(chest, EMBER, 1.1, 11, false)
	warmth.Name = "EmberGlow"
	for _, side in { -0.24, 0.24 } do
		local slit = stick(
			head,
			Kit.neon(model, Vector3.new(0.24, 0.07, 0.06), CFrame.new(), EMBER),
			CFrame.new(side, 0.12, -0.6)
		)
		slit.Name = "Eye"
	end
	for i = -1, 1 do
		decoWedge(
			model,
			jaw,
			Vector3.new(0.12, 0.2, 0.08),
			CFrame.new(i * 0.28, 0.27, -0.42),
			TOOTH,
			Enum.Material.SmoothPlastic
		)
	end

	for _, side in { "L", "R" } do
		local s = if side == "L" then -1 else 1
		local _, forearm, hand = limb(
			model,
			side,
			{ "UpperArm", "Forearm", "Hand" },
			{ "Shoulder", "Elbow", "Wrist" },
			chest,
			CFrame.new(s * 2.05, 1.0, 0.1),
			2.5,
			2.4,
			1.05,
			SOOT,
			SOOT,
			skin,
			skin,
			if side == "L" then Vector3.new(1.15, 0.95, 1.0) else Vector3.new(0.5, 0.5, 0.5),
			if side == "L" then SOOT else IRON
		)
		if side == "R" then
			-- the shovel it was stoking with, grown into the arm
			decoRod(model, forearm, 0.5, 1.2, CFrame.new(-1.15, 0, 0), RUST, Enum.Material.CorrodedMetal)
			local blade = deco(
				model,
				hand,
				Vector3.new(1.7, 2.3, 0.16),
				CFrame.new(0, -1.35, 0),
				IRON,
				Enum.Material.CorrodedMetal
			)
			blade.Name = "Blade"
			deco(
				model,
				blade,
				Vector3.new(1.5, 0.4, 0.2),
				CFrame.new(0, -1.0, 0),
				RUST,
				Enum.Material.CorrodedMetal
			)
		else
			for k = -1, 1 do
				decoBall(model, hand, 0.42, CFrame.new(k * 0.36, -0.42, -0.4), BURN, skin)
			end
		end
		local _, shin, boot = limb(
			model,
			side,
			{ "Thigh", "Shin", "Foot" },
			{ "Hip", "Knee", "Ankle" },
			pelvis,
			CFrame.new(s * 0.75, -0.55, 0),
			2.0,
			1.85,
			0.95,
			APRON,
			SOOT,
			leather,
			skin,
			Vector3.new(1.0, 0.55, 1.5),
			STRAP
		)
		decoRod(model, shin, 0.5, 0.95, CFrame.new(-0.7, 0, 0), STRAP, leather)
		local _ = boot
	end

	emitter(chest, {
		Name = "Soot",
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(rgb(30, 28, 28)),
		Rate = 4,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) }),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	if core then
		emitter(core, {
			Name = "Sparks",
			Texture = "rbxasset://textures/particles/fire_sparks_main.dds",
			Color = ColorSequence.new(EMBER),
			LightEmission = 1,
			Rate = 6,
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(50, 50),
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.18),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Acceleration = Vector3.new(0, 4, 0),
		})
	end
end

local KINDS: { [string]: (Model, BasePart) -> () } = {
	Stalker = stalker,
	Crawler = crawler,
	Brute = brute,
}

-- Public ------------------------------------------------------------------------------------

-- Height of the root's centre above the floor when standing.
function HollowBuilder.rootHeight(kind: string): number
	local spec = SPECS[kind] or SPECS.Stalker
	return spec.hip + spec.root.Y / 2
end

function HollowBuilder.build(at: CFrame, kind: string?): (Model, Humanoid)
	local id = if kind and SPECS[kind] then kind else "Stalker"
	local spec = SPECS[id]
	local model = Kit.model("Hollow")
	model:SetAttribute("Kind", id)

	local root = Kit.block(model, spec.root, at, Color3.new(), { transparency = 1, shadow = false })
	root.Name = "HumanoidRootPart"
	root.Anchored = false
	root.CanCollide = true

	KINDS[id](model, root)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = spec.hip
	humanoid.MaxHealth = 10000
	humanoid.Health = 10000
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 0
	humanoid.AutoJumpEnabled = false
	humanoid.MaxSlopeAngle = 50
	humanoid.Parent = model
	for _, state in
		{
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Jumping,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end

	model.PrimaryPart = root
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Hollows"
			part.CanTouch = false
		end
	end
	return model, humanoid
end

HollowBuilder.Kinds = { "Stalker", "Crawler", "Brute" }

return HollowBuilder
