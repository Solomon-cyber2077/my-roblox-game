--!strict
--[[
	Visual language: "railway ephemera". Steel panels with brass rules for live
	information, cream ticket stock for anything you hold or earn, signal red
	for danger. Condensed display type for clocks and headings, a humanist sans
	for reading, a typewriter face for ledgers and receipts, chalk for the train's slates.
	Square corners, flat fills and hairline rules: no glows, no gradients, no pills.
]]

local Theme = {}

Theme.Color = table.freeze({
	steel = Color3.fromRGB(26, 27, 31),
	steelLight = Color3.fromRGB(40, 42, 48),
	steelLine = Color3.fromRGB(72, 74, 82),
	paper = Color3.fromRGB(236, 226, 200),
	paperShade = Color3.fromRGB(214, 200, 168),
	ink = Color3.fromRGB(34, 30, 28),
	inkSoft = Color3.fromRGB(96, 86, 74),
	brass = Color3.fromRGB(201, 160, 82),
	brassLight = Color3.fromRGB(232, 196, 120),
	signal = Color3.fromRGB(206, 58, 44),
	signalDark = Color3.fromRGB(120, 30, 24),
	go = Color3.fromRGB(122, 196, 138),
	caution = Color3.fromRGB(240, 172, 64),
	sky = Color3.fromRGB(120, 196, 220),
	white = Color3.fromRGB(246, 242, 232),
	textDim = Color3.fromRGB(176, 170, 158),
	black = Color3.fromRGB(0, 0, 0),
	coal = Color3.fromRGB(70, 70, 76),
	parts = Color3.fromRGB(150, 156, 166),
	hull = Color3.fromRGB(122, 196, 138),
})

Theme.Font = table.freeze({
	display = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
	displayMedium = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium),
	body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	bodyBold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	type = Font.new("rbxasset://fonts/families/SpecialElite.json"),
	sign = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold),
	chalk = Font.new("rbxasset://fonts/families/PatrickHand.json"),
})

Theme.Rarity = table.freeze({
	Standard = Color3.fromRGB(150, 146, 136),
	Fine = Color3.fromRGB(120, 196, 138),
	Rare = Color3.fromRGB(110, 170, 236),
	Legendary = Color3.fromRGB(232, 182, 84),
})

Theme.Status = table.freeze({
	Aboard = { text = "ABOARD", color = Color3.fromRGB(122, 196, 138) },
	Afield = { text = "AFIELD", color = Color3.fromRGB(240, 172, 64) },
	Straggler = { text = "RUNNING", color = Color3.fromRGB(120, 196, 220) },
	Eliminated = { text = "LOST", color = Color3.fromRGB(206, 58, 44) },
	Lobby = { text = "DEPOT", color = Color3.fromRGB(176, 170, 158) },
})

Theme.Corner = 2
Theme.Tween = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.TweenSlow = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

return table.freeze(Theme)
