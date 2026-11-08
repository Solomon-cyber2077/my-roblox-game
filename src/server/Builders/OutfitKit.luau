--!strict
--[[
	One reusable Victorian figure: an R6-proportioned body built from parts and dressed from
	a Config/Outfits look (frock coat, lounge coat, railway reefer or bodice; trousers and boots
	or a long skirt; waistcoat, cravat, apron, hat and a prop), bent into a pose. Feet on y = 0,
	facing the frame's -Z. Anchored and still: the body and skirt collide so people walk round,
	everything else is decor. Layers sit on distinct planes so no two faces share one.

	OutfitKit.figure(parent, cframe, look, pose?) returns the model and its body part (for a
	prompt or a speech card).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)
local Outfits = require(ReplicatedStorage.Shared.Config.Outfits)
local FaceKit = require(script.Parent.FaceKit)

export type Figure = { model: Model, body: BasePart, head: BasePart }

local OutfitKit = {}

local M = Enum.Material
local DECOR: Kit.Options = { collide = false, shadow = false }
local SHIRT = Color3.fromRGB(226, 220, 206)
local BOOTS = Color3.fromRGB(28, 24, 22)
local EYES = Color3.fromRGB(30, 26, 24)

local function pitch(degrees: number): CFrame
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

function OutfitKit.figure(parent: Instance, cframe: CFrame, look: Outfits.Look, pose: Outfits.Pose?): Figure
	local p: Outfits.Pose = pose or {}
	local model = Kit.model("Figure", parent)
	local skin, hair = Kit.rgb(look.skin), Kit.rgb(look.hair)
	local coat, trim, lower = Kit.rgb(look.coat), Kit.rgb(look.trim), Kit.rgb(look.lower)
	local function part(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		local made = Kit.block(model, size, cf, color, DECOR)
		made.Material = material or M.Fabric
		return made
	end
	local function ball(d: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		local made = Kit.ball(model, d, cf, color, DECOR)
		made.Material = material or M.SmoothPlastic
		return made
	end
	-- a finishing touch: gone under the Performance setting (Controllers/DetailController)
	local function fine(made: BasePart): BasePart
		made:AddTag("Detail")
		return made
	end
	-- the limb a piece rides on when the figure is worn by a walking body (Builders/PassengerFigure)
	local function on(made: BasePart, limb: string): BasePart
		made:SetAttribute("Limb", limb)
		return made
	end
	local sole = Color3.fromRGB(18, 16, 14)

	-- the skeleton: legs stand straight, the body tips forward at the hips by `lean`
	local hip = cframe * CFrame.new(0, 2, 0) * pitch(-(p.lean or 0))
	local torso = hip * CFrame.new(0, 1, 0)
	local neck = torso * CFrame.new(0, 1, 0) * pitch(p.head or 0)
	local head = neck * CFrame.new(0, 0.72, 0)

	-- below the waist: trousers and boots, or a long skirt with its hem (and a bustle behind)
	local skirtPart: BasePart? = nil
	if look.skirt then
		skirtPart = Kit.block(
			model,
			Vector3.new(2.3, 2.0, 1.5),
			cframe * CFrame.new(0, 1.0, 0),
			lower,
			{ material = M.Fabric, name = "Skirt" }
		)
		part(Vector3.new(2.36, 0.16, 1.56), cframe * CFrame.new(0, 0.26, 0), Kit.shade(lower, 0.75))
		for _, x in { -0.4, 0.4 } do
			part(Vector3.new(0.5, 0.24, 0.6), cframe * CFrame.new(x, 0.12, -0.62), BOOTS, M.Leather)
		end
		-- the waistband, and the pressed pleats falling to the hem
		part(Vector3.new(2.34, 0.1, 1.54), cframe * CFrame.new(0, 1.94, 0), Kit.shade(lower, 0.8))
		for i = -2, 2 do
			fine(
				part(
					Vector3.new(0.06, 1.5, 0.04),
					cframe * CFrame.new(i * 0.42, 1.08, -0.77),
					Kit.shade(lower, 0.78)
				)
			)
		end
		if look.skirt == "Bustle" then
			part(Vector3.new(1.9, 1.0, 0.9), cframe * CFrame.new(0, 1.62, 0.92), lower)
			ball(1.1, cframe * CFrame.new(0, 1.8, 1.18), Kit.shade(lower, 0.9), M.Fabric)
			-- the draped overskirt swagged across the front, and the bow over the bustle
			part(Vector3.new(2.34, 0.62, 0.06), cframe * CFrame.new(0, 1.55, -0.78), Kit.shade(lower, 1.18))
			part(Vector3.new(2.34, 0.12, 0.08), cframe * CFrame.new(0, 1.24, -0.81), trim)
			for _, x in { -0.28, 0.28 } do
				fine(ball(0.34, cframe * CFrame.new(x, 2.02, 1.42), trim, M.Fabric))
			end
		end
		if look.apron then
			local apron = Kit.rgb(look.apron)
			part(Vector3.new(1.7, 1.8, 0.06), cframe * CFrame.new(0, 1.05, -0.79), apron)
			part(Vector3.new(1.1, 1.0, 0.06), torso * CFrame.new(0, 0.3, -0.535), apron)
			part(Vector3.new(2.06, 0.18, 1.06), hip * CFrame.new(0, 0.1, 0), apron) -- the ties round the waist
		end
	else
		for _, x in { -0.5, 0.5 } do
			part(Vector3.new(0.96, 1.68, 0.96), cframe * CFrame.new(x, 1.14, 0), lower) -- tucked into the boot
			part(Vector3.new(1.0, 0.37, 1.15), cframe * CFrame.new(x, 0.265, -0.08), BOOTS, M.Leather)
			-- welted sole, stacked heel and a polished toe cap
			on(
				part(Vector3.new(0.98, 0.08, 1.24), cframe * CFrame.new(x, 0.04, -0.08), sole, M.Leather),
				if x > 0 then "Right Leg" else "Left Leg"
			)
			part(Vector3.new(0.7, 0.12, 0.14), cframe * CFrame.new(x, 0.14, 0.5), sole, M.Leather)
			local cap = fine(
				part(Vector3.new(0.9, 0.14, 0.04), cframe * CFrame.new(x, 0.2, -0.675), Kit.shade(BOOTS, 1.6))
			)
			cap.Material = M.SmoothPlastic
			cap.Reflectance = 0.08
			-- the pressed crease down the front of the trouser leg
			fine(
				part(
					Vector3.new(0.03, 1.4, 0.02),
					cframe * CFrame.new(x, 1.15, -0.49),
					Kit.shade(lower, 0.72)
				)
			)
			if look.cut == "Reefer" then -- company piping down the outside seam
				part(Vector3.new(0.03, 1.04, 0.12), cframe * CFrame.new(x * 1.99, 0.97, 0), trim)
			end
		end
	end

	-- the coat on the body, cut by kind
	local torsoPart =
		Kit.block(model, Vector3.new(2, 2, 1), torso, coat, { material = M.Fabric, name = "Body" })
	local body = skirtPart or torsoPart
	local cut = look.cut
	local buttoned = cut == "Reefer" or cut == "StaffFrock" -- two rows of brass, closed to the neck
	if look.waistcoat and not buttoned then
		part(Vector3.new(1.1, 1.4, 0.06), torso * CFrame.new(0, 0.05, -0.53), Kit.rgb(look.waistcoat))
		for i = 0, 3 do
			ball(0.12, torso * CFrame.new(0, 0.55 - i * 0.3, -0.57), trim, M.Metal)
		end
		-- the watch chain across the waistcoat
		part(
			Vector3.new(0.72, 0.05, 0.04),
			torso * CFrame.new(0.26, -0.15, -0.575) * Kit.angles(0, 0, -14),
			trim,
			M.Metal
		)
	end
	if cut == "Frock" or cut == "Sack" then
		-- the lapels, opening toward the shoulders
		for _, side in { -1, 1 } do
			part(
				Vector3.new(0.42, 1.5, 0.06),
				torso * CFrame.new(side * 0.72, 0.12, -0.555) * Kit.angles(0, 0, -side * 8),
				Kit.shade(coat, 0.75)
			)
		end
		if not look.waistcoat then -- the shirt front between them
			part(Vector3.new(0.56, 1.0, 0.04), torso * CFrame.new(0, 0.45, -0.52), SHIRT)
		end
	end
	if cut == "Frock" and look.waistcoat then -- a linen square in the breast pocket
		fine(
			part(
				Vector3.new(0.22, 0.12, 0.04),
				torso * CFrame.new(-0.66, 0.6, -0.61) * Kit.angles(0, 0, 18),
				SHIRT
			)
		)
	end
	if cut ~= "Bodice" then -- the coat's turned collar behind the neck
		part(Vector3.new(1.3, 0.28, 0.3), torso * CFrame.new(0, 1.02, 0.38), Kit.shade(coat, 0.85))
	end
	if cut == "Sack" or cut == "Reefer" then -- flapped hip pockets
		for _, side in { -1, 1 } do
			on(
				part(
					Vector3.new(0.56, 0.14, 0.06),
					hip * CFrame.new(side * 0.55, -0.14, -0.55),
					Kit.shade(coat, 0.8)
				),
				"Torso"
			)
		end
	end
	if cut == "Frock" or cut == "StaffFrock" then
		-- tails to the knee, open at the front
		part(Vector3.new(2.04, 1.7, 0.1), hip * CFrame.new(0, -0.85, 0.52), coat)
		for _, side in { -1, 1 } do
			part(Vector3.new(0.1, 1.7, 1.04), hip * CFrame.new(side * 1.03, -0.85, 0), coat)
		end
	elseif cut == "Sack" or cut == "Reefer" then
		part(Vector3.new(2.04, 0.5, 1.04), hip * CFrame.new(0, -0.25, 0), coat)
	end
	if buttoned then
		part(Vector3.new(0.08, 1.9, 0.06), torso * CFrame.new(0, -0.05, -0.53), Kit.shade(coat, 0.7))
		for _, x in { -0.42, 0.42 } do
			for i = 0, 2 do
				ball(0.16, torso * CFrame.new(x, 0.6 - i * 0.45, -0.56), trim, M.Metal)
			end
		end
		-- brass collar badges
		for _, x in { -0.36, 0.36 } do
			fine(part(Vector3.new(0.14, 0.14, 0.04), torso * CFrame.new(x, 1.05, -0.47), trim, M.Metal))
		end
	elseif cut == "Bodice" then
		for i = 0, 5 do
			ball(0.1, torso * CFrame.new(0, 0.75 - i * 0.28, -0.53), trim, M.Metal)
		end
		ball(0.2, torso * CFrame.new(0, 0.95, -0.5), trim, M.Metal) -- a brooch at the throat
	end
	-- a guard's patent-leather shoulder belt, right shoulder to left hip, with its pouch
	if look.belt then
		local leather = Color3.fromRGB(20, 18, 18)
		for _, z in { -0.6, 0.6 } do
			part(
				Vector3.new(0.22, 2.5, 0.08),
				torso * CFrame.new(0, 0, z) * Kit.angles(0, 0, 38),
				leather,
				M.Leather
			)
		end
		part(Vector3.new(0.34, 0.55, 0.7), hip * CFrame.new(-1.12, 0.05, 0), leather, M.Leather)
	end
	-- the collar (lace on a bodice), and a cravat or neckerchief (a sculpted head brings its own collar)
	local collarPart = part(
		Vector3.new(1.1, 0.3, 0.9),
		torso * CFrame.new(0, 1.05, 0),
		if cut == "Bodice" then Color3.fromRGB(236, 232, 224) else SHIRT
	)
	if look.neck then
		local tie = Kit.rgb(look.neck)
		part(Vector3.new(0.42, 0.5, 0.1), torso * CFrame.new(0, 0.66, -0.55), tie)
		ball(0.26, torso * CFrame.new(0, 0.9, -0.56), tie, M.Fabric)
	end

	-- arms: sleeves in the coat, a linen cuff, a hand
	local hands: { [number]: CFrame } = {}
	local handParts: { BasePart } = {} -- ball and thumb, left then right (Builders/FaceKit)
	for _, side in { -1, 1 } do
		local swing = if side < 0 then p.armL or 0 else p.armR or 0
		local shoulder = torso * CFrame.new(side * 1.5, 0.75, 0) * pitch(swing)
		local arm = shoulder * CFrame.new(0, -0.75, 0)
		part(Vector3.new(0.96, 2, 0.96), arm, coat)
		if cut == "Bodice" then
			ball(1.12, shoulder * CFrame.new(0, -0.05, 0), coat, M.Fabric) -- a full sleeve head
		else -- the coat's turned-back cuff above the linen
			part(Vector3.new(1.0, 0.18, 1.0), arm * CFrame.new(0, -0.64, 0), Kit.shade(coat, 0.8))
		end
		if cut == "Reefer" then -- a shoulder strap with its button
			part(Vector3.new(0.5, 0.06, 0.9), shoulder * CFrame.new(0, 0.28, 0), Kit.shade(coat, 0.85))
			fine(ball(0.12, shoulder * CFrame.new(0, 0.32, -0.32), trim, M.Metal))
		end
		part(Vector3.new(1.02, 0.22, 1.02), arm * CFrame.new(0, -0.85, 0), SHIRT)
		hands[side] = arm * CFrame.new(0, -1.15, 0)
		table.insert(handParts, ball(0.62, hands[side], skin))
		table.insert(handParts, ball(0.26, hands[side] * CFrame.new(-side * 0.2, 0.06, -0.2), skin)) -- the thumb
	end

	-- the head: a face (eyes, brows, nose, mouth, ears), whiskers, hair
	local headPart = ball(1.3, head, skin)
	headPart.Name = "Head"
	local faceParts: { BasePart } = { headPart, collarPart } -- what Builders/FaceKit's sculpted head replaces
	local whiskerParts: { BasePart } = {}
	local whites = Color3.fromRGB(232, 226, 214)
	local brow = Kit.shade(hair, 0.8)
	for _, side in { -1, 1 } do
		local x = side * 0.22
		table.insert(
			faceParts,
			part(Vector3.new(0.22, 0.12, 0.04), head * CFrame.new(x, 0.08, -0.615), whites, M.SmoothPlastic)
		)
		table.insert(
			faceParts,
			part(Vector3.new(0.1, 0.1, 0.06), head * CFrame.new(x, 0.08, -0.63), EYES, M.SmoothPlastic)
		)
		table.insert(
			faceParts,
			part(
				Vector3.new(0.24, 0.05, 0.05),
				head * CFrame.new(x, 0.25, -0.585) * Kit.angles(0, 0, -side * 6),
				brow,
				M.SmoothPlastic
			)
		)
		table.insert(
			faceParts,
			on(ball(0.3, head * CFrame.new(side * 0.64, 0, 0.04), Kit.shade(skin, 0.94)), "Head")
		)
	end
	table.insert(
		faceParts,
		part(
			Vector3.new(0.13, 0.24, 0.12),
			head * CFrame.new(0, -0.06, -0.68),
			Kit.shade(skin, 0.95),
			M.SmoothPlastic
		)
	)
	table.insert(
		faceParts,
		part(
			Vector3.new(0.3, 0.045, 0.04),
			head * CFrame.new(0, -0.32, -0.565),
			Kit.shade(skin, 0.68),
			M.SmoothPlastic
		)
	)
	-- facial hair by style (Config/Outfits `whiskers`); never sideburns. Builders/FaceKit swaps the
	-- sculpted piece of the same style in once uploaded.
	local whiskers = look.whiskers
	if whiskers then
		local walrus = whiskers == "Walrus" or whiskers == "Full"
		local handlebar = whiskers == "Handlebar"
		local sides: { number } = if whiskers == "Curtain" then {} else { -1, 1 } -- a chin curtain has no moustache
		for _, side in sides do
			local size = if walrus
				then Vector3.new(0.32, 0.12, 0.1)
				elseif handlebar then Vector3.new(0.26, 0.06, 0.07)
				else Vector3.new(0.24, 0.09, 0.08)
			local tilt = if walrus then -side * 22 else -side * 10
			table.insert(
				whiskerParts,
				part(
					size,
					head * CFrame.new(side * 0.13, -0.2, -0.6) * Kit.angles(0, 0, tilt),
					hair,
					M.Fabric
				)
			)
			if handlebar then -- the waxed tips turned up
				table.insert(
					whiskerParts,
					fine(
						part(
							Vector3.new(0.05, 0.12, 0.05),
							head * CFrame.new(side * 0.28, -0.12, -0.56) * Kit.angles(0, 0, side * 20),
							hair,
							M.Fabric
						)
					)
				)
			end
		end
		-- the beard under the moustache: size, then centre from the head's
		local beardSize: Vector3?, beardAt: CFrame? = nil, nil
		if whiskers == "VanDyke" then
			beardSize, beardAt = Vector3.new(0.26, 0.3, 0.16), CFrame.new(0, -0.62, -0.5)
		elseif whiskers == "Curtain" then -- a band along the jaw line and under the chin
			beardSize, beardAt = Vector3.new(0.9, 0.16, 0.48), CFrame.new(0, -0.62, -0.24)
		elseif whiskers == "Full" then
			beardSize, beardAt = Vector3.new(0.86, 0.6, 0.5), CFrame.new(0, -0.68, -0.26)
		end
		if beardSize and beardAt then
			table.insert(whiskerParts, on(part(beardSize, head * beardAt, hair, M.Fabric), "Head"))
		end
	end
	-- the hair (Builders/FaceKit swaps in the sculpted cut once uploaded, so it rides with the whiskers)
	if look.hairStyle ~= "Bald" then
		table.insert(whiskerParts, ball(1.32, head * CFrame.new(0, 0.18, 0.12), hair, M.SmoothPlastic))
	end
	if look.hairStyle == "Bun" then
		table.insert(whiskerParts, ball(0.6, head * CFrame.new(0, 0.32, 0.66), hair, M.SmoothPlastic))
	end

	-- the hat
	local hatColor = if look.hatColor then Kit.rgb(look.hatColor) else Color3.fromRGB(26, 24, 26)
	local crown = head * CFrame.new(0, 0.5, 0.04)
	local function disc(thick: number, d: number, cf: CFrame, color: Color3, material: Enum.Material?)
		Kit.cylinder(model, thick, d, cf * Kit.angles(0, 0, 90), color, {
			material = material or M.Fabric,
			collide = false,
			shadow = false,
		})
	end
	local hat = look.hat
	if hat == "Top" then
		disc(0.1, 1.95, crown, hatColor)
		Kit.post(model, 1.4, 1.22, crown * CFrame.new(0, 0.75, 0), hatColor, DECOR)
		Kit.post(model, 0.26, 1.26, crown * CFrame.new(0, 0.2, 0), Kit.shade(hatColor, 0.6), DECOR)
	elseif hat == "Bowler" then
		disc(0.08, 1.75, crown, hatColor)
		ball(1.3, crown * CFrame.new(0, 0.3, 0), hatColor, M.Fabric)
		Kit.post(model, 0.2, 1.33, crown * CFrame.new(0, 0.12, 0), Kit.shade(hatColor, 0.6), DECOR)
	elseif hat == "Peaked" then
		Kit.post(model, 0.55, 1.42, crown * CFrame.new(0, 0.22, 0), hatColor, DECOR)
		disc(0.12, 1.56, crown * CFrame.new(0, 0.56, 0), hatColor)
		part(
			Vector3.new(1.0, 0.08, 0.5),
			crown * CFrame.new(0, -0.02, -0.82) * Kit.angles(-10, 0, 0),
			BOOTS,
			M.Leather
		)
		part(Vector3.new(0.3, 0.24, 0.05), crown * CFrame.new(0, 0.3, -0.73), trim, M.Metal)
	elseif hat == "Lace" then
		disc(0.12, 1.0, crown * CFrame.new(0, 0.06, 0.24), Color3.fromRGB(236, 232, 224))
		Kit.post(model, 0.16, 1.2, crown * CFrame.new(0, -0.06, 0.24), Color3.fromRGB(226, 222, 214), DECOR)
	elseif hat == "Bonnet" then
		part(Vector3.new(1.5, 1.2, 0.9), head * CFrame.new(0, 0.25, 0.32), hatColor)
		part(Vector3.new(0.14, 0.9, 0.08), head * CFrame.new(0.5, -0.3, -0.5), trim)
		-- the poke brim framing the face, its ribbon bow under the chin and a silk flower
		Kit.cylinder(
			model,
			0.1,
			1.72,
			head * CFrame.new(0, 0.26, -0.12) * Kit.angles(0, 90, 0),
			Kit.shade(hatColor, 1.15),
			{ material = M.Fabric, collide = false, shadow = false }
		)
		on(fine(ball(0.26, head * CFrame.new(0.42, -0.6, -0.4), trim, M.Fabric)), "Head")
		fine(ball(0.3, head * CFrame.new(-0.62, 0.6, 0.1), Kit.shade(trim, 0.8), M.Fabric))
	elseif hat == "Flat" then
		-- a newsboy's eight-panel cap: soft crown, short peak, button on top
		Kit.cylinder(
			model,
			0.34,
			1.52,
			crown * CFrame.new(0, 0.1, 0.04) * pitch(-6) * Kit.angles(0, 0, 90),
			hatColor,
			{
				material = M.Fabric,
				collide = false,
				shadow = false,
			}
		)
		part(
			Vector3.new(0.92, 0.06, 0.44),
			crown * CFrame.new(0, -0.04, -0.82) * Kit.angles(-10, 0, 0),
			Kit.shade(hatColor, 0.8)
		)
		fine(ball(0.14, crown * CFrame.new(0, 0.3, 0.02), Kit.shade(hatColor, 0.8), M.Fabric))
	elseif hat == "Visor" then
		Kit.post(model, 0.16, 1.36, crown * CFrame.new(0, -0.05, 0), trim, DECOR)
		local shade = part(
			Vector3.new(1.1, 0.06, 0.62),
			crown * CFrame.new(0, -0.1, -0.78) * Kit.angles(-14, 0, 0),
			Color3.fromRGB(40, 120, 84),
			M.Glass
		)
		shade.Transparency = 0.25
	end

	-- what they hold
	local prop = look.prop
	if prop == "Punch" then
		part(Vector3.new(0.34, 0.22, 0.5), hands[1] * CFrame.new(0, -0.1, -0.2), trim, M.Metal)
	elseif prop == "Ledger" then
		part(
			Vector3.new(0.22, 1.0, 0.78),
			hands[-1] * CFrame.new(-0.3, 0.7, 0),
			Color3.fromRGB(96, 38, 34),
			M.Leather
		)
	elseif prop == "Tape" then
		-- a tailor's tape hung round the neck, down both lapels
		for _, x in { -0.42, 0.42 } do
			part(
				Vector3.new(0.14, 1.5, 0.03),
				torso * CFrame.new(x, 0.2, -0.58),
				Color3.fromRGB(198, 178, 108)
			)
		end
	elseif prop == "Lamp" then
		-- the guard's hand lamp, hung at the belt
		local lamp = hip * CFrame.new(1.1, -0.3, -0.3)
		Kit.post(model, 0.7, 0.5, lamp, Color3.fromRGB(40, 40, 44), DECOR)
		local lens = Kit.neon(
			model,
			Vector3.new(0.3, 0.3, 0.06),
			lamp * CFrame.new(0, 0, -0.27),
			Color3.fromRGB(196, 60, 40)
		)
		lens.CastShadow = false
	elseif prop == "Pointer" then
		local rod = hands[-1] * CFrame.new(0, -0.1, -1.4)
		part(Vector3.new(0.08, 0.08, 2.8), rod, Color3.fromRGB(40, 30, 24), M.Wood)
		ball(0.14, rod * CFrame.new(0, 0, -1.42), trim, M.Metal)
	elseif prop == "Cloth" then
		part(Vector3.new(0.5, 0.9, 0.08), hands[1] * CFrame.new(0, 0.55, -0.52), SHIRT)
	elseif prop == "Cane" then
		-- a malacca walking cane, its silver knob in the right hand, ferrule near the floor
		on(
			part(
				Vector3.new(0.1, 1.75, 0.1),
				hands[1] * CFrame.new(0, -0.9, -0.12),
				Color3.fromRGB(70, 44, 28),
				M.Wood
			),
			"Right Arm"
		)
		on(
			ball(0.24, hands[1] * CFrame.new(0, 0.02, -0.34), Color3.fromRGB(196, 196, 200), M.Metal),
			"Right Arm"
		)
		on(
			fine(part(Vector3.new(0.12, 0.12, 0.12), hands[1] * CFrame.new(0, -1.74, -0.12), trim, M.Metal)),
			"Right Arm"
		)
	elseif prop == "Papers" or prop == "Post" then
		-- a bag slung on a strap from the left shoulder to the right hip: the evening papers in canvas,
		-- or the Company's post in leather
		local papers = prop == "Papers"
		local bag = if papers then Color3.fromRGB(150, 136, 104) else Color3.fromRGB(78, 50, 32)
		local material = if papers then M.Fabric else M.Leather
		part(
			Vector3.new(0.18, 2.5, 0.06),
			torso * CFrame.new(0, 0, -0.56) * Kit.angles(0, 0, 38),
			bag,
			material
		)
		-- the bag rides behind the right hip, clear of the swinging arm
		on(part(Vector3.new(0.95, 0.75, 0.34), hip * CFrame.new(0.62, -0.2, 0.72), bag, material), "Torso")
		on(
			part(
				Vector3.new(0.99, 0.12, 0.38),
				hip * CFrame.new(0.62, 0.13, 0.72),
				Kit.shade(bag, 0.8),
				material
			),
			"Torso"
		)
		if papers then
			local newsprint = Color3.fromRGB(214, 206, 186)
			for i, x in { -0.24, 0.02, 0.26 } do
				on(
					part(
						Vector3.new(0.7, 0.5, 0.08),
						hip * CFrame.new(0.62 + x * 0.4, 0.34, 0.68 + i * 0.03) * Kit.angles(4 - i * 4, 0, 0),
						Kit.shade(newsprint, 1 - i * 0.04),
						M.SmoothPlastic
					),
					"Torso"
				)
			end
		else
			on(
				fine(part(Vector3.new(0.12, 0.16, 0.04), hip * CFrame.new(0.62, 0.0, 0.91), trim, M.Metal)),
				"Torso"
			)
		end
	elseif prop == "Reticule" then
		-- a drawstring purse hung from the left wrist
		local purse = Kit.shade(trim, 0.7)
		on(
			fine(part(Vector3.new(0.04, 0.34, 0.04), hands[-1] * CFrame.new(0, -0.3, -0.1), purse)),
			"Left Arm"
		)
		on(ball(0.5, hands[-1] * CFrame.new(0, -0.66, -0.1), purse, M.Fabric), "Left Arm")
		on(fine(ball(0.1, hands[-1] * CFrame.new(0, -0.42, -0.1), trim, M.Metal)), "Left Arm")
	elseif prop == "Hanky" then
		-- a black-edged mourning handkerchief in the right hand
		on(part(Vector3.new(0.34, 0.5, 0.04), hands[1] * CFrame.new(0, -0.38, -0.3), SHIRT), "Right Arm")
		on(
			fine(
				part(
					Vector3.new(0.36, 0.05, 0.05),
					hands[1] * CFrame.new(0, -0.62, -0.3),
					Color3.fromRGB(20, 18, 20)
				)
			),
			"Right Arm"
		)
	end

	model.PrimaryPart = body
	FaceKit.dress(head, hands, look, faceParts, whiskerParts, handParts)
	return { model = model, body = body, head = headPart }
end

return table.freeze(OutfitKit)
