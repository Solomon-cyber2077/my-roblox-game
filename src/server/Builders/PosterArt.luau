--!strict
--[[
	The Depot Hall's posters, drawn with Frames and text on a 560 x 720 SurfaceGui canvas.
	Each is a different kind of printed thing the line would put up, laid out the way that
	kind of thing is laid out:

	  coast    a railway travel lithograph for Wyvern Sands: banded dusk sky, the sun half under
	           the sea, a headland with a lighthouse and the train on its viaduct, the company footer
	  fog      a bye-law notice on grey-green card: ruled border, NOTICE, the warning in
	           blackletter, telegraph poles walking off into a fog bank, by order of
	  coal     a letterpress bill on buff paper, many faces on one sheet: HANDS WANTED for the
	           Relief, a woodcut of a shovel in a heap of coal, the Depot's notice (Config/Premise)
	  moon     a printed night notice: the blood moon and its halo over black hills, three of the
	           TallOnes standing on the horizon, one lamp post still lit

	Every sheet has been up a while: a torn corner, damp stains, soot gathered along the foot.
	No cream: paper is the line's grey-green card or a dark buff the lamps cannot turn cream.
	PosterArt.draw(gui, kind) fills the gui; PosterArt.paper(kind) is the part's colour.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Premise = require(ReplicatedStorage.Shared.Config.Premise)

local PosterArt = {}

local rgb = Color3.fromRGB

local W, H = 560, 720

local function font(name: string, weight: Enum.FontWeight?, style: Enum.FontStyle?): Font
	return Font.new(
		`rbxasset://fonts/families/{name}.json`,
		weight or Enum.FontWeight.Regular,
		style or Enum.FontStyle.Normal
	)
end

local OSWALD = font("Oswald", Enum.FontWeight.Bold)
local SERIF = font("Merriweather")
local SERIF_ITALIC = font("Merriweather", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
local SERIF_BOLD = font("Merriweather", Enum.FontWeight.Bold)
local GOTHIC = font("GrenzeGotisch", Enum.FontWeight.Bold)
local BODONI = Font.new(Font.fromEnum(Enum.Font.Bodoni).Family, Enum.FontWeight.Bold)

local PAPER: { [string]: Color3 } = {
	coast = rgb(22, 52, 64),
	fog = rgb(166, 192, 182),
	coal = rgb(164, 136, 96), -- dark buff
	moon = rgb(18, 20, 36),
}

-- A filled rectangle in canvas pixels; rotated about its centre when `rot` is given.
local function box(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	rot: number?
): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x + w / 2, y + h / 2)
	f.Size = UDim2.fromOffset(w, h)
	f.Rotation = rot or 0
	f.Parent = parent
	return f
end

local function disc(parent: Instance, color: Color3, cx: number, cy: number, d: number): Frame
	local f = box(parent, color, cx - d / 2, cy - d / 2, d, d)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = f
	return f
end

local function words(
	parent: Instance,
	text: string,
	face: Font,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	align: Enum.TextXAlignment?
): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(x, y)
	t.Size = UDim2.fromOffset(w, h)
	t.FontFace = face
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	t.Parent = parent
	return t
end

local function rule(parent: Instance, color: Color3, x: number, y: number, w: number, thick: number?)
	box(parent, color, x, y, w, thick or 2)
end

local function outline(
	parent: Instance,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	thick: number
)
	local f = box(parent, color, x, y, w, h)
	f.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thick
	stroke.Parent = f
	return f
end

local function fade(frame: Frame, rotation: number, keys: { { number } })
	local points = {}
	for _, k in keys do
		table.insert(points, NumberSequenceKeypoint.new(k[1], k[2]))
	end
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new(points)
	g.Parent = frame
end

-- Wear on a sheet that has hung a while: a torn corner showing the brick, damp stains, soot at the foot.
local function worn(g: Instance, corner: number)
	for i, stain in { { 470, 120, 120 }, { 90, 560, 90 }, { 380, 470, 60 } } do
		local d = disc(g, rgb(70, 52, 34), stain[1], stain[2], stain[3])
		d.BackgroundTransparency = 0.82 + i * 0.03
	end
	local soot = box(g, rgb(14, 12, 12), 0, H - 120, W, 120)
	fade(soot, 90, { { 0, 1 }, { 1, 0.45 } })
	local x = if corner > 0 then W - 46 else -46
	box(g, rgb(80, 46, 38), x, -46, 92, 92, 45)
end

local DRAW: { [string]: (Instance) -> () } = {}

function DRAW.coast(g: Instance)
	-- dusk sky in hard lithograph bands, darkest at the top
	local bands =
		{ rgb(22, 52, 64), rgb(30, 70, 80), rgb(52, 98, 102), rgb(96, 140, 134), rgb(150, 178, 168) }
	for i, c in bands do
		box(g, c, 0, (i - 1) * 86, W, 86)
	end
	-- the sun, half under the sea
	disc(g, rgb(234, 124, 76), 230, 440, 230)
	disc(g, rgb(244, 156, 98), 230, 440, 150)
	-- the sea and the sun's broken light on it
	box(g, rgb(20, 46, 66), 0, 440, W, 170)
	box(g, rgb(28, 62, 84), 0, 440, W, 18)
	for i, w in { 150, 110, 120, 70, 84, 40 } do
		box(g, rgb(234, 124, 76), 230 - w / 2 + ((i % 2) * 2 - 1) * 10, 456 + i * 22, w, 6)
	end
	-- the headland on the right, a lighthouse on its point, and the viaduct the train crosses
	box(g, rgb(14, 28, 34), 380, 330, 200, 280)
	box(g, rgb(14, 28, 34), 330, 392, 120, 220, -16)
	box(g, rgb(14, 28, 34), 472, 250, 26, 84)
	box(g, rgb(226, 236, 238), 472, 274, 26, 10)
	disc(g, rgb(255, 214, 140), 485, 246, 18)
	local lamp = box(g, rgb(255, 214, 140), 485, 236, 120, 20, -8)
	fade(lamp, 0, { { 0, 0.4 }, { 1, 1 } })
	box(g, rgb(14, 28, 34), 0, 382, 330, 22)
	for i = 0, 5 do
		box(g, rgb(14, 28, 34), 14 + i * 56, 404, 18, 60)
	end
	-- the train: engine, two coaches, a ribbon of smoke streaming back
	box(g, rgb(10, 14, 18), 196, 354, 74, 28)
	box(g, rgb(10, 14, 18), 120, 360, 70, 22)
	box(g, rgb(10, 14, 18), 44, 360, 70, 22)
	box(g, rgb(10, 14, 18), 252, 338, 10, 18)
	for i = 1, 5 do
		local puff = disc(g, rgb(196, 214, 210), 248 - i * 34, 326 - i * 6, 30 - i * 3)
		puff.BackgroundTransparency = 0.25 + i * 0.12
	end
	for i = 0, 3 do
		box(g, rgb(255, 214, 140), 132 + i * 20 + (if i > 1 then 22 else 0), 366, 8, 6)
	end
	-- the title across the top of the sky
	words(g, "WYVERN SANDS", OSWALD, rgb(214, 234, 230), 30, 26, 500, 82)
	words(g, "BY THE NIGHT EXPRESS", BODONI, rgb(244, 156, 98), 30, 112, 500, 56)
	-- the company's footer
	box(g, rgb(12, 16, 20), 0, 610, W, 110)
	rule(g, rgb(206, 168, 92), 0, 610, W, 4)
	words(g, "S. & W. C. R.", OSWALD, rgb(206, 168, 92), 30, 622, 300, 40, Enum.TextXAlignment.Left)
	words(
		g,
		"ALL STOPS TO THE TERMINUS",
		OSWALD,
		rgb(146, 158, 166),
		330,
		630,
		200,
		26,
		Enum.TextXAlignment.Right
	)
	words(
		g,
		"Ten stops, one sunrise. Return tickets regrettably unavailable.",
		SERIF_ITALIC,
		rgb(196, 206, 210),
		30,
		672,
		500,
		30,
		Enum.TextXAlignment.Left
	)
	worn(g, 1)
end

function DRAW.fog(g: Instance)
	local ink = rgb(30, 36, 40)
	outline(g, ink, 18, 18, W - 36, H - 36, 3)
	outline(g, ink, 28, 28, W - 56, H - 56, 1)
	words(g, "N O T I C E", SERIF_BOLD, ink, 60, 52, 440, 34)
	rule(g, ink, 200, 96, 160, 2)
	words(g, "Mind the Fog", GOTHIC, rgb(120, 24, 26), 50, 112, 460, 120)
	-- a diamond between two rules
	rule(g, ink, 120, 252, 130, 2)
	rule(g, ink, 310, 252, 130, 2)
	box(g, ink, 272, 245, 16, 16, 45)
	words(g, "It is not weather.\nIt has never been weather.", SERIF_ITALIC, ink, 70, 278, 420, 92)
	-- telegraph poles walking off into a fog bank, each one fainter
	box(g, rgb(150, 166, 162), 46, 500, 468, 4)
	for i = 0, 5 do
		local x = 70 + i * 82
		local h = 150 - i * 16
		local pole = box(g, ink, x, 500 - h, 6, h)
		local arm = box(g, ink, x - 18, 500 - h + 12, 42, 5)
		pole.BackgroundTransparency = i * 0.17
		arm.BackgroundTransparency = i * 0.17
	end
	for i, y in { 430, 456, 478 } do
		local bank = box(g, rgb(226, 236, 236), 46, y, 468, 40 - i * 6)
		fade(bank, 0, { { 0, 0.95 }, { 0.5, 0.25 + i * 0.1 }, { 1, 0.05 } })
	end
	rule(g, ink, 60, 560, 440, 1)
	words(
		g,
		"Passengers seeing the fog approach a stopping train will return to it at once and will not wait to be told.",
		SERIF,
		ink,
		60,
		572,
		440,
		64
	)
	words(g, "BYE-LAW 7", SERIF_BOLD, ink, 60, 652, 160, 22, Enum.TextXAlignment.Left)
	words(
		g,
		"By Order · The Line Superintendent",
		SERIF_ITALIC,
		ink,
		220,
		652,
		280,
		22,
		Enum.TextXAlignment.Right
	)
end

function DRAW.coal(g: Instance)
	local ink = rgb(26, 22, 20)
	local red = rgb(132, 34, 30)
	outline(g, ink, 16, 16, W - 32, H - 32, 4)
	words(g, "SEVERN & WESTERN COUNTIES RAILWAY", SERIF_BOLD, ink, 40, 34, 480, 26)
	rule(g, ink, 40, 68, 480, 2)
	words(g, "WANTED", OSWALD, red, 40, 76, 480, 108)
	words(g, Premise.Notice.Wanted, BODONI, ink, 40, 188, 480, 62)
	words(g, Premise.Notice.For, SERIF_ITALIC, ink, 80, 252, 400, 36)
	-- the woodcut: a shovel driven into a heap of coal
	local woodcut = box(g, rgb(150, 122, 84), 140, 304, 280, 170)
	woodcut.BackgroundTransparency = 0.4
	box(g, ink, 236, 320, 12, 150, -28)
	box(g, ink, 262, 306, 40, 12, -28)
	box(g, ink, 180, 420, 70, 52, -28)
	for i, l in { { 200, 452, 40, 12 }, { 260, 446, 54, 38 }, { 330, 450, 44, 20 }, { 380, 456, 34, 60 } } do
		box(
			g,
			if i % 2 == 0 then ink else rgb(54, 46, 40),
			l[1] - l[3] / 2,
			l[2] - l[3] / 2,
			l[3],
			l[3],
			l[4]
		)
	end
	rule(g, ink, 40, 496, 480, 2)
	words(g, Premise.Notice.Body, SERIF_BOLD, ink, 60, 508, 440, 70)
	words(g, Premise.Notice.Motto, SERIF_ITALIC, red, 40, 584, 480, 30)
	rule(g, ink, 40, 626, 480, 1)
	words(g, Premise.Notice.Apply, SERIF, ink, 40, 636, 480, 24)
	words(g, "BY ORDER · 1889", SERIF_BOLD, ink, 40, 664, 480, 22)
	worn(g, 1)
end

function DRAW.moon(g: Instance)
	local sky = box(g, rgb(40, 34, 62), 0, 0, W, H)
	fade(sky, 90, { { 0, 1 }, { 1, 0 } })
	-- the blood moon in its halo, with darker seas
	local halo = disc(g, rgb(196, 56, 46), 280, 300, 330)
	halo.BackgroundTransparency = 0.82
	disc(g, rgb(196, 56, 46), 280, 300, 210)
	for _, sea in { { 240, 266, 54 }, { 316, 330, 40 }, { 300, 250, 24 }, { 250, 340, 30 } } do
		local d = disc(g, rgb(140, 34, 30), sea[1], sea[2], sea[3])
		d.BackgroundTransparency = 0.2
	end
	-- black hills and three TallOnes on the skyline
	local hill = rgb(8, 8, 12)
	box(g, hill, -60, 470, 420, 300, -9)
	box(g, hill, 240, 480, 420, 300, 7)
	box(g, hill, 0, 520, W, 200)
	for _, t in { { 176, 300, 0 }, { 214, 250, 3 }, { 404, 280, -4 } } do
		local x, h, lean = t[1], t[2], t[3]
		box(g, hill, x, 486 - h, 9, h, lean)
		disc(g, hill, x + 4 + lean * 2, 486 - h - 8, 18)
		box(g, hill, x - 9, 486 - h + 30, 4, h * 0.55, lean + 8)
		box(g, hill, x + 14, 486 - h + 30, 4, h * 0.55, lean - 8)
	end
	-- one lamp post still lit in the foreground, its glow pooled round it
	local glow = disc(g, rgb(255, 196, 120), 92, 516, 150)
	glow.BackgroundTransparency = 0.78
	box(g, hill, 88, 516, 8, 170)
	box(g, rgb(255, 206, 140), 80, 500, 24, 26)
	box(g, hill, 76, 494, 32, 8)
	words(g, "NOTICE TO PASSENGERS", SERIF_BOLD, rgb(196, 206, 214), 30, 24, 500, 30)
	rule(g, rgb(196, 206, 214), 160, 60, 240, 2)
	words(g, "WHEN THE MOON IS RED", BODONI, rgb(214, 70, 58), 30, 70, 500, 70)
	words(
		g,
		"Keep to the lamplight.\nWave at nothing that waves back.",
		SERIF_ITALIC,
		rgb(196, 206, 214),
		40,
		616,
		480,
		56
	)
	words(g, "By Order · S. & W. C. R.", SERIF, rgb(150, 160, 170), 40, 676, 480, 22)
	worn(g, -1)
end

PosterArt.Kinds = table.freeze({ "coast", "fog", "coal", "moon" })

function PosterArt.paper(kind: string): Color3
	return PAPER[kind]
end

function PosterArt.draw(gui: SurfaceGui, kind: string)
	gui.CanvasSize = Vector2.new(W, H)
	local canvas = Instance.new("Frame")
	canvas.Name = "Poster"
	canvas.BorderSizePixel = 0
	canvas.BackgroundColor3 = PAPER[kind]
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.ClipsDescendants = true
	canvas.Parent = gui
	DRAW[kind](canvas)
end

return table.freeze(PosterArt)
