--!strict
--[[
	Visual language: "night mail". Soot-iron panels with brass rules for live information,
	grey-green Edmondson card for anything you hold or earn (third-class stock, never cream),
	signal red for danger and a fog teal for what is selected or new. Condensed display type for
	clocks and headings, a humanist sans for reading, a typewriter face for ledgers and receipts,
	chalk for the train's slates. Square corners, flat fills and hairline rules: no glows, no
	pills. Buttons are enamel plates with a keel underneath that collapses when pressed.
]]

local Theme = {}

Theme.Color = table.freeze({
	steel = Color3.fromRGB(19, 22, 26),
	steelLight = Color3.fromRGB(35, 40, 46),
	steelLine = Color3.fromRGB(64, 72, 80),
	paper = Color3.fromRGB(182, 198, 192),
	paperShade = Color3.fromRGB(140, 160, 154),
	ink = Color3.fromRGB(20, 24, 28),
	inkSoft = Color3.fromRGB(66, 80, 86),
	brass = Color3.fromRGB(201, 160, 82),
	brassLight = Color3.fromRGB(232, 196, 120),
	signal = Color3.fromRGB(206, 58, 44),
	signalDark = Color3.fromRGB(120, 30, 24),
	go = Color3.fromRGB(122, 196, 138),
	goInk = Color3.fromRGB(34, 98, 58), -- success printed on card stock (go is too pale to read there)
	caution = Color3.fromRGB(240, 172, 64),
	sky = Color3.fromRGB(120, 196, 220),
	white = Color3.fromRGB(230, 236, 238),
	textDim = Color3.fromRGB(146, 158, 166),
	black = Color3.fromRGB(0, 0, 0),
	coal = Color3.fromRGB(70, 70, 76),
	parts = Color3.fromRGB(150, 156, 166),
	hull = Color3.fromRGB(122, 196, 138),
	fog = Color3.fromRGB(104, 168, 160),
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
	Standard = Color3.fromRGB(140, 150, 156),
	Fine = Color3.fromRGB(120, 196, 138),
	Rare = Color3.fromRGB(110, 170, 236),
	Legendary = Color3.fromRGB(232, 182, 84),
})

Theme.Status = table.freeze({
	Aboard = { text = "ABOARD", color = Color3.fromRGB(122, 196, 138) },
	Afield = { text = "AFIELD", color = Color3.fromRGB(240, 172, 64) },
	Straggler = { text = "RUNNING", color = Color3.fromRGB(120, 196, 220) },
	Eliminated = { text = "LOST", color = Color3.fromRGB(206, 58, 44) },
	Lobby = { text = "DEPOT", color = Color3.fromRGB(146, 158, 166) },
})

Theme.Corner = 2
Theme.Tween = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.TweenSlow = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

return table.freeze(Theme)
