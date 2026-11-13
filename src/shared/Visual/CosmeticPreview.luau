--!strict
-- ViewportFrames do not render ParticleEmitters: use a fixed, reusable set of parts.
local Kit = require(script.Parent.Kit)
local Cosmetics = require(script.Parent.Parent.Config.Cosmetics)
local ClothingConfig = require(script.Parent.Parent.Config.CrewClothing)
local ClothingRules = require(script.Parent.Parent.Logic.CrewClothing)
local ClothingVisual = require(script.Parent.CrewClothing)
local Preview = {}
local METAL = { material = Enum.Material.Metal, collide = false }
local DARK = Color3.fromRGB(30, 32, 38)
local COUNT = 12

function Preview.build(def: Cosmetics.CosmeticDef): Model?
	if def.category == "Uniform" then
		local recipe = ClothingConfig.ById[def.id]
		if not recipe or not ClothingRules.available(recipe) then
			return nil
		end
		-- A synchronous segmented mannequin keeps changing cards free of asset-fetch races.
		local model = Kit.model("UniformPreview")
		local skin = Color3.fromRGB(202, 164, 132)
		local function segment(name: string, size: Vector3, position: Vector3, color: Color3): BasePart
			local part = Kit.block(model, size, CFrame.new(position), color, { collide = false })
			part.Name = name
			return part
		end
		local root = segment("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 1.8, 0), skin)
		root.Transparency = 1
		model.PrimaryPart = root
		segment("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 2, 0), DARK)
		segment("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, 1, 0), DARK)
		segment("Head", Vector3.new(2, 1, 1), Vector3.new(0, 3.3, 0), skin)
		for _, side in { "Left", "Right" } do
			local sign = if side == "Left" then -1 else 1
			segment(side .. "UpperArm", Vector3.new(1, 1.2, 1), Vector3.new(sign * 1.5, 2.2, 0), skin)
			segment(side .. "LowerArm", Vector3.new(1, 0.6, 1), Vector3.new(sign * 1.5, 1.3, 0), skin)
			segment(side .. "Hand", Vector3.new(1, 0.2, 1), Vector3.new(sign * 1.5, 0.9, 0), skin)
			segment(side .. "UpperLeg", Vector3.new(1, 1, 1), Vector3.new(sign * 0.5, 0.3, 0), skin)
			segment(side .. "LowerLeg", Vector3.new(1, 0.8, 1), Vector3.new(sign * 0.5, -0.6, 0), skin)
			segment(side .. "Foot", Vector3.new(1, 0.2, 1), Vector3.new(sign * 0.5, -1.1, 0), skin)
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.RigType = Enum.HumanoidRigType.R15
		humanoid.Parent = model
		if ClothingVisual.Apply(model, recipe) == nil then
			model:Destroy()
			return nil
		end
		return model
	end
	local look = def.look
	if def.category == "Trail" then
		if look.style == "None" then
			return nil
		end
		local model = Kit.model("TrailPreview")
		model:SetAttribute("TrailStyle", look.style)
		for i = 1, COUNT do
			local color = Kit.rgb(look.color):Lerp(Kit.rgb(look.color2), i / COUNT)
			local smoke = look.style == "Steam" or look.style == "Mist"
			local p = if smoke
				then Kit.ball(model, 0.2, CFrame.new(), color, { collide = false })
				else Kit.block(
					model,
					Vector3.new(0.06, 0.16, 0.06),
					CFrame.new(),
					color,
					{ material = Enum.Material.Neon, collide = false }
				)
			p.Name = tostring(i)
			p.CastShadow = false
		end
		return model
	end
	if def.category ~= "Livery" then
		return nil
	end
	local model = Kit.model("LiveryPreview")
	local body, trim, roof, accent =
		Kit.rgb(look.body), Kit.rgb(look.trim), Kit.rgb(look.roof), Kit.rgb(look.accent)
	local tier = Cosmetics.RarityOrder[def.rarity]
	local chassis = Kit.block(model, Vector3.new(3.8, 0.18, 1.1), CFrame.new(0, -0.5, 0), DARK, METAL)
	model.PrimaryPart = chassis
	local shell = Kit.block(
		model,
		Vector3.new(3.5, 1.15, 1),
		CFrame.new(0, 0.16, 0),
		body,
		{ material = if tier == 4 then Enum.Material.Metal else Enum.Material.Wood, collide = false }
	)
	if tier == 4 then
		shell.Reflectance = 0.12
	end
	Kit.block(model, Vector3.new(3.85, 0.16, 1.2), CFrame.new(0, 0.84, 0), roof, METAL)
	Kit.block(model, Vector3.new(2.8, 0.12, 0.76), CFrame.new(0, 0.98, 0), roof, METAL)
	for _, side in { -1, 1 } do
		for i = -2, 2 do
			Kit.block(
				model,
				Vector3.new(0.4, 0.38, 0.02),
				CFrame.new(i * 0.54, 0.4, side * 0.52),
				Kit.rgb(look.lamp):Lerp(DARK, 0.35),
				{ material = Enum.Material.Glass, collide = false }
			)
		end
		for _, x in { -1.57, 1.57 } do
			Kit.block(model, Vector3.new(0.17, 0.92, 0.035), CFrame.new(x, 0.14, side * 0.53), accent, METAL)
		end
		for stripe = 1, (if tier >= 3 then 2 else 1) do
			Kit.block(
				model,
				Vector3.new(3.45, 0.025, 0.035),
				CFrame.new(0, -0.24 + stripe * 0.12, side * 0.54),
				trim,
				METAL
			)
		end
		for _, x in { -1.2, 1.2 } do
			Kit.cylinder(
				model,
				0.16,
				0.55,
				CFrame.new(x, -0.62, side * 0.54) * Kit.angles(0, 90, 0),
				DARK,
				METAL
			)
			Kit.cylinder(
				model,
				0.18,
				0.18,
				CFrame.new(x, -0.62, side * 0.54) * Kit.angles(0, 90, 0),
				trim,
				METAL
			)
		end
		-- Physical L T O lettering remains visible in a ViewportFrame.
		local strokes = {
			{ -0.38, 0, 0.025, 0.14 },
			{ -0.33, -0.06, 0.12, 0.025 },
			{ 0, 0, 0.025, 0.14 },
			{ 0, 0.06, 0.14, 0.025 },
			{ 0.3, 0.06, 0.13, 0.025 },
			{ 0.3, -0.06, 0.13, 0.025 },
			{ 0.24, 0, 0.025, 0.14 },
			{ 0.36, 0, 0.025, 0.14 },
		}
		for _, stroke in strokes do
			Kit.block(
				model,
				Vector3.new(stroke[3], stroke[4], 0.02),
				CFrame.new(stroke[1], -0.31 + stroke[2], side * 0.525),
				trim,
				METAL
			)
		end
		if tier == 4 then
			local crest = Kit.ball(model, 0.14, CFrame.new(1.45, 0.77, side * 0.58), trim, METAL)
			crest:SetAttribute("CycleA", trim)
			crest:SetAttribute("CycleB", Kit.rgb(look.lamp))
		end
	end
	return model
end

function Preview.step(model: Model, time: number)
	local style = model:GetAttribute("TrailStyle")
	if not style then
		return
	end
	for i, child in model:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		local phase = (
			time * (if style == "Sparks" then 1.7 else if style == "Cinder" then 1.1 else 0.55)
			+ i / COUNT
		) % 1
		local lane = math.sin(i * 2.4)
		local x, y, z, size, fade
		if style == "Steam" then
			x, y, z = -1.2 + phase * 2.4, phase * 1.3 - 0.55, lane * 0.22
			size, fade = 0.18 + phase * 0.55, 0.45 + phase * 0.55
		elseif style == "Mist" then
			x, y, z = -1.4 + phase * 2.8, math.sin(phase * 7 + i) * 0.13 - 0.3, lane * 0.45
			size, fade = 0.24 + math.sin(phase * math.pi) * 0.5, 0.55 + math.abs(phase - 0.5) * 0.9
		elseif style == "Sparks" then
			x, y, z = lane * phase * 1.7, -0.45 + 3.5 * phase - 4 * phase * phase, math.cos(i) * phase * 0.45
			size, fade = 0.07 * (1 - phase) + 0.02, phase
		else
			x, y, z = lane * 0.6 + math.sin(phase * 5 + i) * 0.2, phase * 1.8 - 0.7, lane * 0.3
			size, fade = 0.1 * (1 - phase) + 0.03, phase
		end
		child.Size = if style == "Sparks"
			then Vector3.new(size, size * 3, size)
			else Vector3.new(size, size, size)
		child.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, lane * phase * 6)
		child.Transparency = fade
	end
end

return table.freeze(Preview)
