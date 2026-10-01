--!strict
--[[
	Builds wearable cosmetics from their `look` table in Config/Cosmetics.
	Used by CosmeticService on characters and by the Outfitter preview.

	Every builder returns a Model whose parts are positioned relative to
	`frame` (the attachment point) and are massless and non-collidable.
]]

local Kit = require(script.Parent.Kit)

local CosmeticModels = {}

local function finish(model: Model): Model
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
	end
	return model
end

-- Lantern hanging at `frame` (handle at the top).
function CosmeticModels.lantern(look: { [string]: any }, frame: CFrame): Model
	local model = Kit.model("Lantern")
	local body = Kit.rgb(look.body)
	local glass = Kit.rgb(look.glass)
	local style = look.style or "Classic"
	local height = if style == "Squat" then 1.0 else 1.3
	local width = if style == "Squat" then 0.95 else 0.8

	local handle = Kit.cylinder(
		model,
		0.12,
		0.7,
		frame * CFrame.new(0, 0, 0) * Kit.angles(0, 90, 0),
		body,
		{ material = Enum.Material.Metal }
	)
	handle.Name = "Handle"
	Kit.cylinder(
		model,
		0.25,
		width + 0.15,
		frame * CFrame.new(0, -0.45, 0) * Kit.angles(0, 0, 90),
		body,
		{ material = Enum.Material.Metal }
	)
	local lens = Kit.cylinder(
		model,
		height * 0.62,
		width,
		frame * CFrame.new(0, -0.45 - height * 0.36, 0) * Kit.angles(0, 0, 90),
		glass,
		{ material = Enum.Material.Neon, transparency = 0.15 }
	)
	lens.Name = "Lens"
	Kit.cylinder(
		model,
		0.22,
		width + 0.2,
		frame * CFrame.new(0, -0.45 - height * 0.74, 0) * Kit.angles(0, 0, 90),
		body,
		{ material = Enum.Material.Metal }
	)
	if style == "Filigree" then
		for i = 0, 3 do
			local angle = math.rad(i * 90 + 45)
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (width / 2 + 0.03)
			Kit.block(
				model,
				Vector3.new(0.08, height * 0.66, 0.08),
				frame * CFrame.new(offset + Vector3.new(0, -0.45 - height * 0.36, 0)),
				body,
				{ material = Enum.Material.Metal }
			)
		end
	end
	local light = Kit.pointLight(lens, Kit.rgb(look.light), 1.6, 16, false)
	light.Name = "Glow"
	if look.light2 then
		lens:SetAttribute("CycleA", Kit.rgb(look.light))
		lens:SetAttribute("CycleB", Kit.rgb(look.light2))
	end
	if look.sparkle then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Rate = 6
		sparkles.Lifetime = NumberRange.new(0.6, 1.1)
		sparkles.Speed = NumberRange.new(0.5, 1.2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		sparkles.LightEmission = 1
		sparkles.Color = ColorSequence.new(glass)
		sparkles.Parent = lens
	end
	model.PrimaryPart = handle
	return finish(model)
end

-- Headwear sitting on a head whose top-centre is `frame`.
function CosmeticModels.headwear(look: { [string]: any }, frame: CFrame): Model?
	local style = look.style
	if style == nil or style == "None" then
		return nil
	end
	local model = Kit.model("Headwear")
	local primary = Kit.rgb(look.primary)
	local secondary = Kit.rgb(look.secondary)
	local anchor: BasePart

	if style == "Conductor" then
		anchor = Kit.cylinder(
			model,
			0.55,
			1.45,
			frame * CFrame.new(0, 0.05, 0) * Kit.angles(0, 0, 90),
			primary,
			{ material = Enum.Material.Fabric }
		)
		Kit.cylinder(
			model,
			0.18,
			1.7,
			frame * CFrame.new(0, 0.38, 0) * Kit.angles(0, 0, 90),
			primary,
			{ material = Enum.Material.Fabric }
		)
		Kit.block(
			model,
			Vector3.new(0.9, 0.08, 0.5),
			frame * CFrame.new(0, -0.18, -0.85) * Kit.angles(-12, 0, 0),
			Kit.shade(primary, 0.6),
			{ material = Enum.Material.SmoothPlastic }
		)
		Kit.block(
			model,
			Vector3.new(0.3, 0.22, 0.06),
			frame * CFrame.new(0, 0.2, -0.74),
			secondary,
			{ material = Enum.Material.Metal }
		)
	elseif style == "Goggles" then
		anchor = Kit.block(
			model,
			Vector3.new(1.32, 0.18, 1.32),
			frame * CFrame.new(0, -0.35, 0),
			primary,
			{ material = Enum.Material.Leather }
		)
		for _, side in { -1, 1 } do
			local lens = Kit.cylinder(
				model,
				0.2,
				0.42,
				frame * CFrame.new(0.28 * side, -0.25, -0.66) * Kit.angles(0, 90, 0),
				secondary,
				{ material = Enum.Material.Metal }
			)
			Kit.cylinder(
				model,
				0.06,
				0.32,
				lens.CFrame * CFrame.new(0.1, 0, 0),
				Color3.fromRGB(150, 210, 220),
				{ material = Enum.Material.Glass, transparency = 0.2 }
			)
		end
	elseif style == "LampCap" then
		anchor =
			Kit.ball(model, 1.5, frame * CFrame.new(0, -0.1, 0), primary, { material = Enum.Material.Metal })
		Kit.cylinder(
			model,
			0.12,
			1.75,
			frame * CFrame.new(0, -0.3, 0) * Kit.angles(0, 0, 90),
			primary,
			{ material = Enum.Material.Metal }
		)
		local lamp = Kit.cylinder(
			model,
			0.25,
			0.45,
			frame * CFrame.new(0, 0.05, -0.72) * Kit.angles(0, 90, 0),
			secondary,
			{ material = Enum.Material.Neon }
		)
		local beam = Kit.spotLight(lamp, secondary, 1.4, 28, 50, Enum.NormalId.Left)
		beam.Shadows = false
	else -- TopHat
		anchor = Kit.cylinder(
			model,
			1.35,
			1.25,
			frame * CFrame.new(0, 0.55, 0) * Kit.angles(0, 0, 90),
			primary,
			{ material = Enum.Material.Fabric }
		)
		Kit.cylinder(
			model,
			0.12,
			1.95,
			frame * CFrame.new(0, -0.08, 0) * Kit.angles(0, 0, 90),
			primary,
			{ material = Enum.Material.Fabric }
		)
		Kit.cylinder(
			model,
			0.22,
			1.27,
			frame * CFrame.new(0, 0.12, 0) * Kit.angles(0, 0, 90),
			secondary,
			{ material = Enum.Material.Fabric }
		)
	end

	model.PrimaryPart = anchor
	return finish(model)
end

-- Emitter attached to the feet. Returns the emitter to parent under a foot attachment.
function CosmeticModels.trail(look: { [string]: any }): ParticleEmitter?
	local style = look.style
	if style == nil or style == "None" then
		return nil
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "TrailEmitter"
	local a, b = Kit.rgb(look.color), Kit.rgb(look.color2)
	emitter.Color = ColorSequence.new(a, b)
	emitter.LightEmission = if style == "Steam" or style == "Mist" then 0 else 1
	emitter.Rate = 0 -- driven by movement on the client
	emitter.LockedToPart = false
	emitter.EmissionDirection = Enum.NormalId.Top
	if style == "Cinder" then
		emitter.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
		emitter.Lifetime = NumberRange.new(0.4, 0.8)
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(35, 35)
		emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		emitter.Acceleration = Vector3.new(0, -8, 0)
	elseif style == "Steam" then
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.2) })
		emitter.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	elseif style == "Sparks" then
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
		emitter.Speed = NumberRange.new(3, 6)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		emitter.Acceleration = Vector3.new(0, -14, 0)
	else -- Mist
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Lifetime = NumberRange.new(1.2, 2)
		emitter.Speed = NumberRange.new(0.2, 0.6)
		emitter.SpreadAngle = Vector2.new(180, 20)
		emitter.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
		emitter.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	end
	emitter:SetAttribute("Style", style)
	return emitter
end

return table.freeze(CosmeticModels)
