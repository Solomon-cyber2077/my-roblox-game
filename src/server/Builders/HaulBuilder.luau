--!strict
-- Dimensions blocked in Blender: tools/haul/blockout.py. Fictional railway fittings.
local Shared = game:GetService("ReplicatedStorage").Shared
local Kit = require(Shared.Visual.Kit)
local ItemModel = require(Shared.Visual.ItemModel)
local B = {}
local iron = Color3.fromRGB(42, 45, 47)
local wood = Color3.fromRGB(100, 69, 42)
local function part(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	return Kit.block(m, size, cf, color, { name = name, material = Enum.Material.Metal, collide = false })
end
function B.crate(parent: Instance, cf: CFrame): Model
	local m = Kit.model("Sealed payroll crate", parent)
	local body = part(m, "Case", Vector3.new(2.6, 1.6, 2.6), cf, wood)
	body.Material = Enum.Material.Wood
	m.PrimaryPart = body
	for _, z in { -0.85, 0.85 } do
		part(m, "Binding", Vector3.new(2.65, 0.08, 0.15), cf * CFrame.new(0, 0.85, z), iron)
	end
	local seal = part(
		m,
		"Wax seal",
		Vector3.new(0.35, 0.1, 0.35),
		cf * CFrame.new(0, 0.85, 0),
		Color3.fromRGB(97, 24, 18)
	)
	seal.Material = Enum.Material.SmoothPlastic
	local light = Instance.new("PointLight")
	light.Name = "Pool"
	light.Brightness = 0.15
	light.Range = 8
	light.Color = Color3.fromRGB(240, 195, 125)
	light.Parent = body
	return m
end

function B.ticket(parent: Instance, cf: CFrame): Model
	local m = Kit.model("Burnt railway ticket", parent)
	local card = part(m, "Charred ticket", Vector3.new(0.9, 0.06, 0.55), cf, Color3.fromRGB(184, 155, 108))
	card.Material = Enum.Material.Wood
	m.PrimaryPart = card
	for _, x in { -0.38, 0.38 } do
		local scorch = part(
			m,
			"Scorch",
			Vector3.new(0.08, 0.07, 0.5),
			cf * CFrame.new(x, 0.01, 0),
			Color3.fromRGB(38, 30, 25)
		)
		scorch.Material = Enum.Material.SmoothPlastic
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(256, 160)
	gui.Parent = card
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "S&WCR • THIRD\nTO TERMINUS\nNo. 01884 • 18 OCT 1888"
	label.TextColor3 = Color3.fromRGB(45, 32, 24)
	label.TextSize = 21
	label.Font = Enum.Font.Antique
	label.Parent = gui
	return m
end

function B.stores(parent: Instance, origin: CFrame): (Model, BasePart, BasePart)
	local m = Kit.model("Haul strongbox", parent)
	-- side-on in the gap between the Stores car's crate stacks (x 8 to 11 on the far wall), its
	-- lock to the aisle; it used to sit inside a crate
	local cf = origin * CFrame.new(9.25, 1.1, -4.55) * CFrame.Angles(0, math.rad(90), 0)
	local body = part(m, "Locked strongbox", Vector3.new(3.2, 1.8, 2.2), cf, iron)
	body.CanCollide = true
	m.PrimaryPart = body
	part(m, "Lid", Vector3.new(3.3, 0.15, 2.3), cf * CFrame.new(0, 0.98, 0), iron)
	part(m, "Lock", Vector3.new(0.15, 0.5, 0.4), cf * CFrame.new(-1.68, 0.4, 0), Color3.fromRGB(140, 104, 45))
	local marker = part(
		m,
		"Payroll delivery",
		Vector3.new(3.5, 0.08, 3.5),
		origin * CFrame.new(16, 0.1, -1.2), -- on the aisle floor, clear of the crates
		Color3.fromRGB(178, 160, 121)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.CanvasSize = Vector2.new(256, 256)
	gui.Parent = marker
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "PAYROLL\nRECEIVING"
	label.TextColor3 = iron
	label.TextSize = 32
	label.Font = Enum.Font.Antique
	label.Parent = gui
	return m, body, marker
end
function B.stack(parent: Model, ids: { string })
	local old = parent:FindFirstChild("Haul")
	if old then
		old:Destroy()
	end
	local tray = Kit.model("Haul", parent)
	local base = (parent.PrimaryPart :: BasePart).CFrame
	-- Bounded representative stacks, never a floating balance. Exact contents stay server-side.
	for i = 1, math.min(#ids, 18) do
		local item = ItemModel.build(
			ids[i],
			base
				* CFrame.new(
					((i - 1) % 3 - 1) * 0.8,
					1.12 + math.floor((i - 1) / 6) * 0.17,
					math.floor(((i - 1) % 6) / 3) * 0.7 - 0.35
				),
			0.45
		)
		item.Parent = tray
		for _, p in item:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.Reflectance = 0.16
			end
		end
	end
end
return B
