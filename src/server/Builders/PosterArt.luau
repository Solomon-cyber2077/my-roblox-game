--!strict
--[[
	The Depot Hall's posters, drawn with Frames and text on a 560 x 720 SurfaceGui canvas.
	Each is a different kind of printed thing the line would put up, laid out the way that
	kind of thing is laid out:

	  coast    a railway travel lithograph: banded dusk sky, the sun half under the sea,
	           a headland with a lighthouse and the train on its viaduct, a company footer
	  fog      a bye-law notice on grey-green card: ruled border, NOTICE, the warning in
	           blackletter, telegraph poles walking off into a fog bank, by order of
	  coal     a propaganda bill: red ground, a black diagonal, a shovel and coal lumps
	  counted  a typed regulation on a blue form, ruled, with a red COUNTED stamp
	  brother  a handwritten appeal on torn ruled notebook paper, a photograph clipped on
	  moon     a night warning: the blood moon and its halo over black hills, three of the
	           TallOnes standing on the horizon, one lamp post still lit

	No cream anywhere: paper is the line's grey-green card, a blue form or blue-ruled pad.
	PosterArt.draw(gui, kind) fills the gui; PosterArt.paper(kind) is the part's colour.
]]

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
local TYPE = font("SpecialElite")
local GOTHIC = font("GrenzeGotisch", Enum.FontWeight.Bold)
local HAND = font("Kalam")
local HAND_BOLD = font("Kalam", Enum.FontWeight.Bold)

local PAPER: { [string]: Color3 } = {
	coast = rgb(22, 52, 64),
	fog = rgb(166, 192, 182),
	coal = rgb(150, 44, 40),
	counted = rgb(150, 178, 204), -- a blue form, so the lanterns cannot warm it to cream
	brother = rgb(186, 206, 224),
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
	words(g, "SEE THE COAST", OSWALD, rgb(214, 234, 230), 30, 26, 500, 82)
	words(g, "AT DAWN", OSWALD, rgb(244, 156, 98), 30, 110, 500, 76)
	-- the company's footer
	box(g, rgb(12, 16, 20), 0, 610, W, 110)
	rule(g, rgb(206, 168, 92), 0, 610, W, 4)
	words(g, "LAST TRAIN OUT", OSWALD, rgb(206, 168, 92), 30, 622, 300, 40, Enum.TextXAlignment.Left)
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
	local black = rgb(18, 16, 16)
	local white = rgb(230, 236, 238)
	-- a black diagonal across the red ground
	box(g, black, -120, 330, 820, 150, -24)
	-- the shovel: a long handle with a grip, the blade biting into the lumps
	box(g, rgb(150, 44, 40), 120, 300, 340, 22, -38)
	box(g, white, 128, 316, 330, 14, -38)
	box(g, white, 386, 190, 52, 16, -38)
	box(g, white, 70, 470, 120, 110, -38)
	-- coal lumps heaped at the foot, sharp-edged
	for i, l in
		{
			{ 70, 600, 70, 10 },
			{ 150, 586, 92, 30 },
			{ 260, 604, 64, 52 },
			{ 330, 576, 104, 18 },
			{ 450, 600, 76, 40 },
		}
	do
		box(
			g,
			if i % 2 == 0 then black else rgb(40, 36, 36),
			l[1] - l[3] / 2,
			l[2] - l[3] / 2,
			l[3],
			l[3],
			l[4]
		)
	end
	words(g, "COAL IS", OSWALD, white, 34, 30, 380, 104, Enum.TextXAlignment.Left)
	words(g, "COURAGE", OSWALD, black, 34, 128, 492, 120, Enum.TextXAlignment.Left)
	box(g, black, 0, 660, W, 60)
	words(
		g,
		"Every sack you carry is a mile someone else gets to live.",
		SERIF_ITALIC,
		white,
		24,
		670,
		512,
		40
	)
end

function DRAW.counted(g: Instance)
	local ink = rgb(36, 40, 46)
	local blue = rgb(104, 130, 160)
	-- a typed sheet: a header block, ruled lines, the regulation, the guard's initials
	words(g, "LAST TRAIN OUT · PLATFORM 1", TYPE, ink, 40, 34, 480, 26, Enum.TextXAlignment.Left)
	words(g, "REGULATION 14", TYPE, ink, 40, 70, 480, 50, Enum.TextXAlignment.Left)
	rule(g, ink, 40, 128, 480, 3)
	for y = 170, 620, 38 do
		rule(g, blue, 40, y, 480, 1)
	end
	words(g, "PASSENGERS ARE REMINDED", TYPE, ink, 40, 140, 480, 28, Enum.TextXAlignment.Left)
	words(
		g,
		"1. Count your friends at every stop.\n\n2. If the number goes up,\n    do not get back on.\n\n3. If the number goes down,\n    count again.",
		TYPE,
		ink,
		44,
		182,
		470,
		296,
		Enum.TextXAlignment.Left
	)
	words(g, "— the Guard", TYPE, ink, 300, 560, 220, 30, Enum.TextXAlignment.Right)
	-- the stamp: red, crooked, a little worn
	local red = rgb(176, 36, 34)
	local stamp = box(g, red, 70, 500, 250, 92, -12)
	stamp.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = red
	stroke.Thickness = 6
	stroke.Transparency = 0.15
	stroke.Parent = stamp
	local inner = words(stamp, "COUNTED", OSWALD, red, 12, 8, 226, 76)
	inner.TextTransparency = 0.15
	rule(g, ink, 40, 650, 480, 1)
	words(g, "Form G.14 · Retain in the hall", TYPE, ink, 40, 660, 480, 22, Enum.TextXAlignment.Left)
end

function DRAW.brother(g: Instance)
	local ink = rgb(40, 52, 98)
	-- ruled notebook paper and a red margin
	for y = 120, 700, 36 do
		rule(g, rgb(140, 172, 206), 0, y, W, 2)
	end
	box(g, rgb(196, 86, 92), 74, 0, 3, H)
	-- holes along the top where it tore off the pad's wire
	for i = 0, 12 do
		disc(g, rgb(40, 34, 30), 24 + i * 42, 22, 14)
	end
	-- the photograph, clipped on at an angle
	local photo = box(g, rgb(222, 228, 230), 330, 70, 180, 214, 6)
	box(photo, rgb(60, 66, 70), 12, 12, 156, 160)
	disc(photo, rgb(110, 118, 122), 90, 70, 58)
	box(photo, rgb(110, 118, 122), 46, 104, 88, 70)
	words(photo, "Tom, 14", HAND, rgb(60, 66, 70), 12, 178, 156, 28)
	box(g, rgb(150, 156, 160), 404, 56, 34, 40, 6)
	words(g, "Lost: one brother", HAND_BOLD, ink, 96, 116, 230, 104, Enum.TextXAlignment.Left)
	words(
		g,
		"Tom. Got off at Ashgrove for a lark.\nIf you see him, tell him I kept the lamp lit.",
		HAND,
		ink,
		96,
		300,
		430,
		208,
		Enum.TextXAlignment.Left
	)
	words(g, "— Ellie", HAND_BOLD, ink, 300, 528, 220, 60, Enum.TextXAlignment.Right)
	words(g, "(ask at the tea room)", HAND, ink, 96, 612, 300, 40, Enum.TextXAlignment.Left)
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
	words(g, "THE MOON IS NOT", OSWALD, rgb(220, 228, 236), 30, 28, 500, 64)
	words(g, "YOUR FRIEND", OSWALD, rgb(214, 70, 58), 30, 90, 500, 70)
	words(
		g,
		"Keep to the lamplight. Wave at nothing that waves back.",
		SERIF_ITALIC,
		rgb(196, 206, 214),
		40,
		640,
		480,
		52
	)
end

PosterArt.Kinds = table.freeze({ "coast", "fog", "coal", "counted", "brother", "moon" })

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
