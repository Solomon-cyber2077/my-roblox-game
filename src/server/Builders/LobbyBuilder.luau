--!strict
--[[
	The Depot Hall: a glass-roofed terminus where players wait between runs.
	Holds the departure board (ready status), the Outfitter kiosk (shop), the
	Ledger board (milestones) and a display train wearing the crew's livery.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Visual.Kit)
local TrainBuilder = require(script.Parent.TrainBuilder)

export type Built = {
	model: Model,
	spawnPoints: { CFrame },
	board: BasePart,
	outfitter: BasePart,
	ledger: BasePart,
	displayTrain: Model,
}

local LobbyBuilder = {}

local C = {
	marble = Color3.fromRGB(214, 204, 186),
	inlay = Color3.fromRGB(150, 120, 86),
	brick = Color3.fromRGB(128, 78, 60),
	iron = Color3.fromRGB(44, 46, 52),
	glass = Color3.fromRGB(190, 210, 220),
	warm = Color3.fromRGB(255, 210, 150),
	board = Color3.fromRGB(22, 26, 34),
	brass = Color3.fromRGB(201, 160, 82),
	canvas = Color3.fromRGB(132, 46, 52),
	wood = Color3.fromRGB(110, 80, 54),
}

local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(800, 160)
	gui.LightInfluence = 0.1
	gui.Parent = part
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.FontFace = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold)
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextScaled = true
	textLabel.Parent = gui
end

function LobbyBuilder.build(origin: CFrame, parent: Instance): Built
	local model = Kit.model("DepotHall")
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	-- Floor and platform -------------------------------------------------------------------
	Kit.block(model, Vector3.new(224, 2, 92), at(0, -1, 25), C.marble, { material = Enum.Material.Marble })
	for x = -100, 100, 20 do
		Kit.block(model, Vector3.new(0.6, 0.05, 92), at(x, 0.02, 25), C.inlay, { collide = false })
	end
	for z = -10, 60, 14 do
		Kit.block(model, Vector3.new(224, 0.05, 0.6), at(0, 0.02, z), C.inlay, { collide = false })
	end
	Kit.block(
		model,
		Vector3.new(224, 0.3, 1.4),
		at(0, 0.15, -20.3),
		Color3.fromRGB(196, 188, 172),
		{ material = Enum.Material.Concrete }
	)
	Kit.block(
		model,
		Vector3.new(224, 0.06, 0.7),
		at(0, 0.03, -18.6),
		Color3.fromRGB(226, 182, 58),
		{ collide = false }
	)
	Kit.block(model, Vector3.new(224, 6, 0.6), at(0, -3, -21), C.brick, { material = Enum.Material.Brick })

	-- Display train on its own track -----------------------------------------------------
	Kit.block(
		model,
		Vector3.new(224, 1, 16),
		at(0, -6.75, -28),
		Color3.fromRGB(70, 66, 62),
		{ material = Enum.Material.Pebble }
	)
	Kit.block(model, Vector3.new(224, 4, 30), at(0, -9.25, -28), C.brick, { material = Enum.Material.Brick })
	for x = -110, 110, 3 do
		Kit.block(
			model,
			Vector3.new(1.3, 0.5, 9),
			at(x, -6.0, -28),
			Color3.fromRGB(74, 56, 40),
			{ material = Enum.Material.Wood, collide = false }
		)
	end
	for _, side in { -1, 1 } do
		Kit.block(
			model,
			Vector3.new(224, 0.55, 0.5),
			at(0, -5.475, -28 + side * 2.6),
			Color3.fromRGB(120, 116, 112),
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	local display = TrainBuilder.build(at(0, 0, -28), model)
	display.model.Name = "DisplayTrain"
	for _, blocker in display.doorBlockers do
		blocker.CanCollide = true
	end

	-- Walls ---------------------------------------------------------------------------------
	Kit.block(model, Vector3.new(224, 34, 2), at(0, 17, 72), C.brick, { material = Enum.Material.Brick })
	for x = -90, 90, 30 do
		Kit.block(
			model,
			Vector3.new(10, 14, 0.4),
			at(x, 18, 70.8),
			C.warm,
			{ material = Enum.Material.Neon, transparency = 0.45, collide = false }
		)
		Kit.block(model, Vector3.new(11, 15, 0.3), at(x, 18, 70.9), C.iron, { collide = false })
	end
	for _, x in { -112, 112 } do
		Kit.block(model, Vector3.new(2, 34, 92), at(x, 17, 25), C.brick, { material = Enum.Material.Brick })
	end
	-- invisible bounds
	local bounds: { { size: Vector3, cframe: CFrame } } = {
		{ size = Vector3.new(230, 80, 2), cframe = at(0, 40, -44) },
		{ size = Vector3.new(230, 80, 2), cframe = at(0, 40, 73) },
		{ size = Vector3.new(2, 80, 120), cframe = at(-113, 40, 15) },
		{ size = Vector3.new(2, 80, 120), cframe = at(113, 40, 15) },
	}
	for _, bound in bounds do
		Kit.block(model, bound.size, bound.cframe, Color3.new(), { transparency = 1, shadow = false })
	end

	-- Columns and the arched glass roof ---------------------------------------------------
	for x = -99, 99, 22 do
		for _, z in { -14, 44 } do
			Kit.post(model, 22, 1.2, at(x, 11, z), C.iron, { material = Enum.Material.Metal })
			Kit.post(model, 1.2, 2.4, at(x, 0.6, z), C.iron, { material = Enum.Material.Metal })
			Kit.block(
				model,
				Vector3.new(2.4, 1, 2.4),
				at(x, 22, z),
				C.iron,
				{ material = Enum.Material.Metal }
			)
		end
		-- arch truss across the hall
		local segments = 8
		local z0, z1, rise, base = -44, 72, 22, 22
		local previous: Vector3? = nil
		for i = 0, segments do
			local t = i / segments
			local z = z0 + (z1 - z0) * t
			local y = base + rise * math.sin(math.pi * t)
			local point = Vector3.new(x, y, z)
			if previous then
				local mid = (previous + point) / 2
				local length = (point - previous).Magnitude
				Kit.block(
					model,
					Vector3.new(0.8, 0.8, length + 0.4),
					origin * CFrame.lookAt(mid, point),
					C.iron,
					{ material = Enum.Material.Metal, collide = false }
				)
			end
			previous = point
		end
		local lamp = Kit.neon(model, Vector3.new(1.6, 1.6, 1.6), at(x, 18, 15), C.warm, Enum.PartType.Ball)
		Kit.pointLight(lamp, C.warm, 1.6, 40, false)
		Kit.block(model, Vector3.new(0.15, 24, 0.15), at(x, 30, 15), C.iron, { collide = false })
	end
	for i = 0, 7 do
		local t0, t1 = i / 8, (i + 1) / 8
		local z0, z1 = -44 + 116 * t0, -44 + 116 * t1
		local y0, y1 = 22 + 22 * math.sin(math.pi * t0), 22 + 22 * math.sin(math.pi * t1)
		local a, b = Vector3.new(0, y0 + 0.6, z0), Vector3.new(0, y1 + 0.6, z1)
		Kit.block(
			model,
			Vector3.new(224, 0.3, (b - a).Magnitude),
			origin * CFrame.lookAt((a + b) / 2, b),
			C.glass,
			{
				material = Enum.Material.Glass,
				transparency = 0.7,
				collide = false,
				shadow = false,
			}
		)
	end

	-- Departure board ------------------------------------------------------------------------
	Kit.block(model, Vector3.new(44, 17, 1), at(0, 17, 70.4), C.iron, { material = Enum.Material.Metal })
	local board = Kit.block(model, Vector3.new(42, 15, 0.6), at(0, 17, 69.7), C.board, { collide = false })
	board.Name = "DepartureBoard"
	Kit.block(
		model,
		Vector3.new(16, 3, 0.8),
		at(0, 27.2, 70),
		C.brass,
		{ material = Enum.Material.Metal, collide = false }
	)
	local plate = Kit.block(model, Vector3.new(15, 2.4, 0.4), at(0, 27.2, 69.5), C.board, { collide = false })
	label(plate, Enum.NormalId.Front, "DEPARTURES", Color3.fromRGB(240, 232, 210))

	-- Outfitter kiosk ------------------------------------------------------------------------
	local kx, kz = 54, 36
	Kit.block(model, Vector3.new(14, 4, 4), at(kx, 2, kz), C.wood, { material = Enum.Material.WoodPlanks })
	Kit.block(
		model,
		Vector3.new(14.6, 0.4, 4.6),
		at(kx, 4.2, kz),
		C.brass,
		{ material = Enum.Material.Metal }
	)
	Kit.block(
		model,
		Vector3.new(14, 9, 1),
		at(kx, 4.5, kz + 6),
		C.wood,
		{ material = Enum.Material.WoodPlanks }
	)
	for _, x in { -6.5, 6.5 } do
		Kit.post(model, 11, 0.6, at(kx + x, 5.5, kz - 1.5), C.iron, { material = Enum.Material.Metal })
	end
	for i = 0, 6 do
		Kit.block(
			model,
			Vector3.new(2, 0.3, 8),
			at(kx - 6 + i * 2, 11.2, kz + 2) * Kit.angles(-12, 0, 0),
			if i % 2 == 0 then C.canvas else Color3.fromRGB(226, 214, 186),
			{ material = Enum.Material.Fabric, collide = false }
		)
	end
	local outfitterSign =
		Kit.block(model, Vector3.new(12, 2.4, 0.4), at(kx, 13.2, kz - 1.8), C.board, { collide = false })
	label(outfitterSign, Enum.NormalId.Front, "OUTFITTER", Color3.fromRGB(240, 210, 150))
	local outfitter = Kit.block(
		model,
		Vector3.new(12, 6, 4),
		at(kx, 3, kz - 2.5),
		Color3.new(),
		{ transparency = 1, collide = false, shadow = false }
	)
	outfitter.Name = "OutfitterPrompt"
	for i = 1, 4 do
		local post = at(kx - 6 + i * 2.4, 6.4, kz + 5.2)
		Kit.post(model, 0.8, 1.2, post, Color3.fromHSV(i / 5, 0.45, 0.7), { collide = false })
	end
	local kioskLamp = Kit.neon(model, Vector3.new(1, 1, 1), at(kx, 10, kz), C.warm, Enum.PartType.Ball)
	Kit.pointLight(kioskLamp, C.warm, 1.4, 22, false)

	-- Ledger board -----------------------------------------------------------------------------
	local lx, lz = -54, 36
	Kit.block(
		model,
		Vector3.new(14, 10, 1),
		at(lx, 6, lz + 4),
		C.wood,
		{ material = Enum.Material.WoodPlanks }
	)
	local ledgerFace = Kit.block(
		model,
		Vector3.new(12.6, 8.6, 0.3),
		at(lx, 6, lz + 3.4),
		Color3.fromRGB(236, 226, 200),
		{ collide = false }
	)
	label(ledgerFace, Enum.NormalId.Front, "LINE MASTERY", Color3.fromRGB(40, 34, 28))
	for _, x in { -6.5, 6.5 } do
		Kit.post(model, 12, 0.5, at(lx + x, 6, lz + 4), C.iron, { material = Enum.Material.Metal })
	end
	local ledger = Kit.block(
		model,
		Vector3.new(12, 6, 4),
		at(lx, 3, lz + 1),
		Color3.new(),
		{ transparency = 1, collide = false, shadow = false }
	)
	ledger.Name = "LedgerPrompt"

	-- Benches and luggage -------------------------------------------------------------------
	for _, x in { -80, -30, 30, 80 } do
		for _, z in { 8, 52 } do
			Kit.block(
				model,
				Vector3.new(10, 0.4, 2),
				at(x, 1.7, z),
				C.wood,
				{ material = Enum.Material.WoodPlanks }
			)
			Kit.block(
				model,
				Vector3.new(10, 2, 0.3),
				at(x, 2.9, z + 1),
				C.wood,
				{ material = Enum.Material.WoodPlanks }
			)
			for _, dx in { -4.5, 4.5 } do
				Kit.block(
					model,
					Vector3.new(0.4, 1.7, 2),
					at(x + dx, 0.85, z),
					C.iron,
					{ material = Enum.Material.Metal }
				)
			end
		end
	end
	for i, x in { -18, 20 } do
		Kit.block(model, Vector3.new(6, 1, 3), at(x, 1.4, 58), C.iron, { material = Enum.Material.Metal })
		for j = 0, 2 do
			Kit.block(
				model,
				Vector3.new(2.2, 1.6, 1.8),
				at(x - 2 + j * 2, 2.7, 58) * Kit.angles(0, (i + j) * 7, 0),
				Color3.fromHSV((i * 3 + j) / 9, 0.4, 0.45),
				{ material = Enum.Material.Leather }
			)
		end
	end

	local spawnPoints: { CFrame } = {}
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		table.insert(spawnPoints, at(math.cos(angle) * 14, 3, 24 + math.sin(angle) * 9))
	end

	Kit.setCollisionGroup(model, "Default")
	Kit.setCollisionGroup(display.model, "Train")
	model.Parent = parent

	return {
		model = model,
		spawnPoints = spawnPoints,
		board = board,
		outfitter = outfitter,
		ledger = ledger,
		displayTrain = display.model,
	}
end

return LobbyBuilder
