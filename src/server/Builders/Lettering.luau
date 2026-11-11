--!strict
--[[
	Lettering for the boards and plates whose words are made in the game (station names, shop
	fascias, car boards, engine plates), drawn on a SurfaceGui so any text can wear it.

	  engrave  letters cut into a plate: the fill sits in the cut, the cut's upper wall throws a
	           shadow over the top of each stroke and its lower wall catches the light below it.
	           A gilt fill is shaded as a V-cut (dark at the top facet, bright down the middle);
	           a plate can carry a bevel round its edge.
	  paint    sign-writer's paint on a board: worn thin unevenly along the line, chipped back to
	           the board in small irregular flakes, with the slight lip a brushed letter has.

	Both are deterministic: the wear and chips come from a Random seeded by the text, so a board
	rebuilt with the same words comes out the same.
]]

local Lettering = {}

export type Box = { x: number, y: number, w: number, h: number } -- the text's frame, 0..1 of the canvas

export type Engrave = {
	font: Font,
	canvas: Vector2,
	light: number, -- SurfaceGui.LightInfluence
	fill: Color3, -- what lies in the cut: wax, paint or gilt
	surface: Color3, -- the plate or board, for the cut's lit and shadowed walls
	gilt: boolean?, -- shade the fill as a gilded V-cut
	bevel: boolean?, -- a bevelled edge round the plate
	box: Box?,
}

export type Paint = {
	font: Font,
	canvas: Vector2,
	light: number,
	color: Color3, -- the paint
	ground: Color3, -- the board under it, shown where the paint has chipped
	bare: Color3?, -- what shows where the board's own edge is knocked (iron, raw wood); none if nil
	wear: number?, -- 0..1, how far the paint has gone (default 0.5)
	box: Box?,
}

local DEFAULT_BOX: Box = { x = 0.05, y = 0.13, w = 0.9, h = 0.74 }
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)
local RUST = Color3.fromRGB(86, 44, 26)
local CUT = 0.03 -- depth of a cut's lit and shadowed walls, as a share of the canvas height
local LIP = 0.018 -- a painted letter's lip

local function seedOf(text: string, canvas: Vector2): number
	local h = 7
	for i = 1, #text do
		h = (h * 131 + string.byte(text, i)) % 2147483647
	end
	return (h + math.floor(canvas.X) * 31 + math.floor(canvas.Y)) % 2147483647
end

local function surfaceGui(part: BasePart, face: Enum.NormalId, canvas: Vector2, light: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = canvas
	gui.LightInfluence = light
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = part
	return gui
end

local function label(
	gui: SurfaceGui,
	text: string,
	font: Font,
	box: Box,
	dy: number,
	color: Color3,
	z: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(box.w, box.h)
	l.Position = UDim2.new(box.x, 0, box.y, dy)
	l.FontFace = font
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.ZIndex = z
	l.Parent = gui
	return l
end

local function strip(gui: SurfaceGui, color: Color3, pos: UDim2, size: UDim2, rotation: number, from: number)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = pos
	f.Size = size
	f.ZIndex = 1
	f.Parent = gui
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new(from, 1)
	g.Parent = f
end

-- Letters cut into `part`'s `face`. Returns the fill label.
function Lettering.engrave(part: BasePart, face: Enum.NormalId, text: string, o: Engrave): TextLabel
	local box = o.box or DEFAULT_BOX
	local gui = surfaceGui(part, face, o.canvas, o.light)
	local d = math.max(1, math.floor(o.canvas.Y * CUT + 0.5))
	if o.bevel then
		-- the plate's edge planed off: lit along the top and left, in shade along the bottom and right
		local b = UDim.new(0.09, 0)
		local lit, shade = o.surface:Lerp(WHITE, 0.5), o.surface:Lerp(BLACK, 0.6)
		strip(gui, lit, UDim2.fromScale(0, 0), UDim2.new(UDim.new(1, 0), b), 90, 0.35)
		strip(
			gui,
			shade,
			UDim2.new(UDim.new(0, 0), UDim.new(0.91, 0)),
			UDim2.new(UDim.new(1, 0), b),
			-90,
			0.3
		)
		strip(gui, lit, UDim2.fromScale(0, 0), UDim2.new(UDim.new(0.04, 0), UDim.new(1, 0)), 0, 0.45)
		strip(gui, shade, UDim2.fromScale(0.96, 0), UDim2.new(UDim.new(0.04, 0), UDim.new(1, 0)), 180, 0.4)
	end
	-- the cut's lower wall in the light, its upper wall's shadow, then what fills it
	local lit = label(gui, text, o.font, box, d, o.surface:Lerp(WHITE, 0.55), 2)
	lit.TextTransparency = 0.35
	local shadow = label(gui, text, o.font, box, -d, BLACK, 3)
	shadow.TextTransparency = 0.2
	local fill = label(gui, text, o.font, box, 0, o.fill, 4)
	if o.gilt then
		-- a V-cut catches the light on its lower facet and loses it on the upper
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, o.fill:Lerp(BLACK, 0.55)),
			ColorSequenceKeypoint.new(0.45, o.fill:Lerp(BLACK, 0.15)),
			ColorSequenceKeypoint.new(0.6, o.fill:Lerp(WHITE, 0.3)),
			ColorSequenceKeypoint.new(1, o.fill),
		})
		g.Parent = fill
	end
	return fill
end

-- Sign-writer's paint on `part`'s `face`, worn and chipped. Returns the paint's label.
function Lettering.paint(part: BasePart, face: Enum.NormalId, text: string, o: Paint): TextLabel
	local box = o.box or DEFAULT_BOX
	local wear = o.wear or 0.5
	local rng = Random.new(seedOf(text, o.canvas))
	local gui = surfaceGui(part, face, o.canvas, o.light)
	local lip = math.max(1, math.floor(o.canvas.Y * LIP + 0.5))
	local lipShadow = label(gui, text, o.font, box, lip, BLACK, 1)
	lipShadow.TextTransparency = 0.72
	local paint = label(gui, text, o.font, box, 0, o.color, 2)
	-- worn thinner and dirtier in places along the line, never gone
	local thin = { NumberSequenceKeypoint.new(0, rng:NextNumber(0, 0.3) * wear) }
	local dirt = { ColorSequenceKeypoint.new(0, o.color) }
	for i = 1, 6 do
		local at = i / 7 + rng:NextNumber(-0.05, 0.05)
		table.insert(thin, NumberSequenceKeypoint.new(at, rng:NextNumber(0, 0.7) * wear))
		table.insert(
			dirt,
			ColorSequenceKeypoint.new(at, o.color:Lerp(o.ground, rng:NextNumber(0, 0.45) * wear))
		)
	end
	table.insert(thin, NumberSequenceKeypoint.new(1, rng:NextNumber(0, 0.3) * wear))
	table.insert(dirt, ColorSequenceKeypoint.new(1, o.color))
	local worn = Instance.new("UIGradient")
	worn.Rotation = rng:NextNumber(-8, 8)
	worn.Transparency = NumberSequence.new(thin)
	worn.Color = ColorSequence.new(dirt)
	worn.Parent = paint
	-- flakes chipped off down to what is under the paint: small and jagged, many at the strokes'
	-- edges, a few larger ones where something has struck it
	local under = o.bare or o.ground:Lerp(BLACK, 0.6)
	local aspect = o.canvas.X / o.canvas.Y
	local flakes = math.clamp(math.floor(#text * 3 * wear + 0.5), 6, 40) -- capped: every flake is drawn each frame
	for i = 1, flakes do
		local chip = Instance.new("Frame")
		chip.BorderSizePixel = 0
		chip.BackgroundColor3 = under:Lerp(RUST, rng:NextNumber(0, 0.5))
		local h = if i % 6 == 0 then rng:NextNumber(0.05, 0.08) else rng:NextNumber(0.012, 0.035)
		chip.Size = UDim2.fromScale(h * rng:NextNumber(0.6, 2.2) / aspect, h)
		chip.Position =
			UDim2.fromScale(box.x + rng:NextNumber(0, box.w), box.y + box.h * rng:NextNumber(0.08, 0.92))
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Rotation = rng:NextNumber(0, 180)
		chip.BackgroundTransparency = rng:NextNumber(0, 0.25)
		chip.ZIndex = 3
		chip.Parent = gui
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(rng:NextNumber(0.05, 0.3), 0)
		round.Parent = chip
	end
	-- the board's own edge knocked back to what is under it
	local bare = o.bare
	if bare then
		for _ = 1, rng:NextInteger(4, 7) do
			local chip = Instance.new("Frame")
			chip.BorderSizePixel = 0
			chip.BackgroundColor3 = bare
			local h = rng:NextNumber(0.05, 0.13)
			chip.Size = UDim2.fromScale(h * rng:NextNumber(0.6, 1.8) / aspect, h)
			local edge = rng:NextInteger(1, 4)
			local x = if edge == 1
				then rng:NextNumber(0, 0.02)
				elseif edge == 2 then rng:NextNumber(0.98, 1)
				else rng:NextNumber(0.02, 0.98)
			local y = if edge == 3
				then rng:NextNumber(0, 0.04)
				elseif edge == 4 then rng:NextNumber(0.96, 1)
				else rng:NextNumber(0.05, 0.95)
			chip.Position = UDim2.fromScale(x, y)
			chip.AnchorPoint = Vector2.new(0.5, 0.5)
			chip.Rotation = rng:NextNumber(0, 180)
			chip.ZIndex = 3
			chip.Parent = gui
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.4, 0)
			round.Parent = chip
		end
	end
	return paint
end

return Lettering
