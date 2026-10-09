--!strict
--[[
	Visual language: "blood moon mail". A Victorian night train lit by gaslamps and a red moon.
	Dark material dominates: soot iron, oxblood leather, bottle-green lacquer, mahogany, all
	framed in blackened brass. Paper survives as aged, smoke-stained card (amber-buff, never cream
	or white) for anything you hold or earn, burnt at the edges. Moon red and ember mark danger,
	selection and the last seconds; bone and brass carry text on dark, near-black ink on card.
	Oswald for labels and clocks, Merriweather for reading, Special Elite for stamps and ledgers,
	Fondamento for handwriting, chalk for the train's slates. Materials are baked textures
	(tools/uiart, docs/ASSET_CREDITS.md) listed in Theme.Image; Ui.panel and Ui.ticket apply them.
]]

local Theme = {}

Theme.Color = table.freeze({
	-- dark material
	steel = Color3.fromRGB(17, 18, 21), -- soot iron
	steelLight = Color3.fromRGB(38, 34, 32), -- raised iron, warm in the lamp
	steelLine = Color3.fromRGB(78, 64, 50), -- engraved rule (blackened brass)
	leather = Color3.fromRGB(52, 16, 15), -- oxblood
	lacquer = Color3.fromRGB(18, 44, 40), -- bottle green
	mahogany = Color3.fromRGB(58, 26, 16),
	-- aged card
	paper = Color3.fromRGB(170, 140, 96), -- smoked amber-buff card
	paperShade = Color3.fromRGB(112, 92, 64),
	ink = Color3.fromRGB(22, 15, 12),
	inkSoft = Color3.fromRGB(56, 40, 30),
	-- metal and light
	brass = Color3.fromRGB(196, 154, 78),
	brassLight = Color3.fromRGB(232, 194, 120),
	amber = Color3.fromRGB(224, 162, 74), -- lamp
	ember = Color3.fromRGB(217, 102, 31),
	signal = Color3.fromRGB(179, 38, 30), -- moon red
	signalDark = Color3.fromRGB(122, 16, 20), -- deep blood
	go = Color3.fromRGB(132, 190, 128),
	goInk = Color3.fromRGB(30, 82, 46), -- success printed on card stock (go is too pale to read there)
	caution = Color3.fromRGB(232, 158, 60),
	sky = Color3.fromRGB(120, 186, 196),
	white = Color3.fromRGB(232, 220, 196), -- bone: text on dark, never a fill
	textDim = Color3.fromRGB(168, 152, 128),
	black = Color3.fromRGB(0, 0, 0),
	coal = Color3.fromRGB(70, 66, 64),
	parts = Color3.fromRGB(150, 146, 136),
	hull = Color3.fromRGB(132, 190, 128),
	fog = Color3.fromRGB(104, 168, 160),
})

Theme.Font = table.freeze({
	display = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
	displayMedium = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium),
	body = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular),
	bodyBold = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold),
	type = Font.new("rbxasset://fonts/families/SpecialElite.json"),
	hand = Font.new("rbxasset://fonts/families/Fondamento.json"),
	sign = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Bold),
	chalk = Font.new("rbxasset://fonts/families/PatrickHand.json"),
})

--[[
	Baked textures (sources: tools/uiart). Nine-slice images list their SliceCenter; the panel and
	card overlays carry only shading, wear and rim, so the fill colour stays BackgroundColor3.
]]
local function nine(id: string, a: number, b: number): { id: string, slice: Rect }
	return table.freeze({ id = id, slice = Rect.new(a, a, b, b) })
end

Theme.Image = table.freeze({
	panel = nine("rbxassetid://140292892695785", 64, 192), -- iron shading, inner shadow, brass rim
	card = nine("rbxassetid://101501418688540", 64, 192), -- smoke, foxing, burnt edge
	frame = nine("rbxassetid://97701061052459", 40, 88), -- brass rim alone
	burn = nine("rbxassetid://79552105034233", 40, 88), -- ragged edge darkening (white, tint it)
	glow = nine("rbxassetid://126483110202170", 48, 80), -- soft halo (white, tint it)
	plate = nine("rbxassetid://83125399395448", 40, 88), -- glossy enamel slab (white, tint it)
	paperGrain = "rbxassetid://135069167135621", -- tile 256
	ironGrain = "rbxassetid://81562162973696", -- tile 256
	grunge = "rbxassetid://111320878966112", -- stamp knock-outs (white, tint with the paper)
	vignette = "rbxassetid://94310403534832", -- radial, stretched
	punch = "rbxassetid://113622556584864",
	rivet = "rbxassetid://72430109178072",
	wax = "rbxassetid://80794293604608",
	bezel = "rbxassetid://122710553651185",
})

-- Rim thickness of the panel and card nine-slices on screen (fraction of the 64px source border).
Theme.Slice = table.freeze({ panel = 0.22, panelLarge = 0.3, card = 0.35 })

Theme.Rarity = table.freeze({
	Standard = Color3.fromRGB(160, 150, 134),
	Fine = Color3.fromRGB(132, 190, 128),
	Rare = Color3.fromRGB(110, 170, 236),
	Legendary = Color3.fromRGB(232, 182, 84),
})

Theme.Status = table.freeze({
	Aboard = { text = "ABOARD", color = Color3.fromRGB(132, 190, 128) },
	Afield = { text = "AFIELD", color = Color3.fromRGB(224, 162, 74) },
	Straggler = { text = "RUNNING", color = Color3.fromRGB(120, 196, 220) },
	Eliminated = { text = "LOST", color = Color3.fromRGB(214, 64, 48) },
	Lobby = { text = "DEPOT", color = Color3.fromRGB(168, 152, 128) },
})

Theme.Corner = 2
Theme.Tween = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.TweenSlow = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

return table.freeze(Theme)
