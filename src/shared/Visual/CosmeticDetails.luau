--!strict
-- Small, shared decorative additions used by both worn items and shop models.
local Kit = require(script.Parent.Kit)
local Details = {}
local METAL = { material = Enum.Material.Metal }
local BRASS = Color3.fromRGB(214, 178, 96)

function Details.lantern(model: Model, look: { [string]: any }, frame: CFrame)
	local lens = model:FindFirstChild("Lens") :: Part
	local style = look.style
	local body = Kit.rgb(look.body)
	local center = frame * CFrame.new(0, -0.9, 0)
	local width, height = 0.68, 0.7
	if style == "Signal" then
		lens.Shape = Enum.PartType.Block
		width, height = 0.62, 0.75
	elseif style == "Squat" then
		lens.Shape = Enum.PartType.Ball
		width, height = 0.8, 0.55
	elseif style == "Prism" then
		lens.Shape = Enum.PartType.Block
		width, height = 0.52, 0.9
		center *= Kit.angles(0, 45, 0)
	elseif style == "Crown" then
		width, height = 0.62, 0.8
	end
	if lens.Shape == Enum.PartType.Cylinder then
		lens.Size = Vector3.new(height, width, width)
		lens.CFrame = center * Kit.angles(0, 0, 90)
	else
		lens.Size = Vector3.new(width, height, width)
		lens.CFrame = center
	end
	lens.Material = Enum.Material.Glass
	lens.Transparency = 0.32
	lens:SetAttribute("FlickerSpeed", if style == "Squat" then 12 else if style == "Prism" then 2 else 5)
	lens:SetAttribute("FlickerAmount", if style == "Squat" then 0.2 else 0.08)
	local flame = Kit.ball(model, 0.24, center, Kit.rgb(look.light), { material = Enum.Material.Neon })
	flame.Name = "Flame"
	flame.Size = Vector3.new(0.18, height * 0.7, 0.18)
	if look.light2 then
		flame:SetAttribute("CycleA", Kit.rgb(look.light))
		flame:SetAttribute("CycleB", Kit.rgb(look.light2))
	end
	-- An open bail, with a visible gap above the chimney.
	for _, side in { -1, 1 } do
		Kit.block(model, Vector3.new(0.07, 0.38, 0.07), frame * CFrame.new(side * 0.28, -0.2, 0), body, METAL)
	end
	local rails = if style == "Classic" then 2 else if style == "Crown" then 6 else 4
	for i = 1, rails do
		local angle = i * math.pi * 2 / rails + math.pi / 4
		local x, z = math.cos(angle) * (width * 0.82), math.sin(angle) * (width * 0.82)
		Kit.block(model, Vector3.new(0.055, height + 0.12, 0.055), center * CFrame.new(x, 0, z), body, METAL)
	end
	if style == "Signal" then
		-- A railway signal shutter and red enamel maker's plate.
		Kit.block(model, Vector3.new(0.5, 0.08, 0.28), frame * CFrame.new(0, -0.55, -0.42), body, METAL)
		Kit.block(
			model,
			Vector3.new(0.25, 0.09, 0.035),
			frame * CFrame.new(0, -1.33, -0.43),
			Color3.fromRGB(172, 44, 32),
			METAL
		)
	elseif style == "Filigree" or style == "Crown" then
		for _, y in { -0.56, -1.26 } do
			Kit.post(model, 0.06, width + 0.16, frame * CFrame.new(0, y, 0), BRASS, METAL)
		end
		if style == "Crown" then
			for i = 1, 5 do
				local a = i * math.pi * 2 / 5
				Kit.ball(
					model,
					0.09,
					frame * CFrame.new(math.cos(a) * 0.34, -0.28, math.sin(a) * 0.34),
					BRASS,
					METAL
				)
			end
		end
	end
end

function Details.headwear(model: Model, look: { [string]: any }, frame: CFrame)
	local style = look.style
	local trim = Kit.rgb(look.secondary)
	if style == "Conductor" then
		Kit.post(model, 0.1, 1.6, frame * CFrame.new(0, -0.08, 0), trim, METAL)
		for _, side in { -1, 1 } do
			Kit.ball(model, 0.12, frame * CFrame.new(side * 0.58, -0.05, -0.57), trim, METAL)
		end
		if look.detail == "Rescue" then
			for _, size in { Vector3.new(0.22, 0.06, 0.04), Vector3.new(0.06, 0.2, 0.04) } do
				Kit.block(
					model,
					size,
					frame * CFrame.new(0, 0.2, -0.79),
					Color3.fromRGB(245, 239, 214),
					METAL
				)
			end
		elseif look.detail == "Punch" then
			for _, side in { -1, 1 } do
				Kit.block(
					model,
					Vector3.new(0.045, 0.28, 0.05),
					frame * CFrame.new(side * 0.07, 0.18, -0.8) * Kit.angles(0, 0, side * 22),
					trim,
					METAL
				)
			end
		end
	elseif style == "Goggles" then
		Kit.block(model, Vector3.new(0.2, 0.06, 0.06), frame * CFrame.new(0, -0.25, -0.84), trim, METAL)
		for _, side in { -1, 1 } do
			Kit.block(
				model,
				Vector3.new(0.1, 0.03, 0.02),
				frame * CFrame.new(side * 0.28, -0.18, -0.81) * Kit.angles(0, 0, -25),
				Color3.fromRGB(235, 255, 255),
				{ material = Enum.Material.Neon }
			)
		end
	elseif style == "LampCap" then
		Kit.block(model, Vector3.new(0.1, 0.08, 1.15), frame * CFrame.new(0, 0.61, 0), BRASS, METAL)
		Kit.cylinder(model, 0.1, 0.53, frame * CFrame.new(0, 0.05, -0.9) * Kit.angles(0, 90, 0), BRASS, METAL)
	elseif style == "TopHat" then
		for _, y in { 0.01, 0.25, 1.23 } do
			Kit.post(model, 0.045, 1.49, frame * CFrame.new(0, y, 0), BRASS, METAL)
		end
		Kit.post(model, 0.045, 2.08, frame * CFrame.new(0, -0.015, 0), BRASS, METAL)
		local jewel = Kit.ball(
			model,
			0.2,
			frame * CFrame.new(0, 0.17, -0.78),
			Color3.fromRGB(80, 200, 180),
			{ material = Enum.Material.Glass }
		)
		jewel.Size = Vector3.new(0.18, 0.25, 0.1)
		for _, side in { -1, 1 } do
			for i = 1, 3 do
				Kit.block(
					model,
					Vector3.new(0.2, 0.035, 0.04),
					frame
						* CFrame.new(side * (0.13 + i * 0.07), 0.14 + i * 0.065, -0.74)
						* Kit.angles(0, 0, side * 25),
					BRASS,
					METAL
				)
			end
		end
	end
end

return table.freeze(Details)
