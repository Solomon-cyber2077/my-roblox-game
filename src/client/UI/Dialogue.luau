--!strict
--[[
	What a resident says when you talk to them (NpcService, the Dialogue remote). It looks like
	speaking through their window: a mahogany booking-office front with the resident's
	portrait behind a brass grille (Theme.Portrait), an engraved brass name plate, the line
	typed in lamplit bone on a leather blotter, the company's COUNTED stamp, and a punched
	ticket tab to leave. The window sizes itself to the line. CLOSE, the backdrop or gamepad B
	closes it.
]]

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Net = require(script.Parent.Parent.Net)
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Dialogue = {}

type Said = { npc: string, name: string, role: string, text: string }

local WIDTH = 680
local RIM = 36 -- the mahogany rails and the gilt bead, inside which everything sits
local PORTRAIT = Vector2.new(184, 215)
local GAP = 14
local PLATE_H = 46
local TAB = Vector2.new(140, 44)
local TAB_CARD = Color3.fromRGB(164, 130, 88) -- tea-stained card, smoked
local TEXT_SIZE = 20
local TEXT_PAD = Vector2.new(22, 18)

function Dialogue.mount(gui: ScreenGui)
	local modal = Modal.new(gui, "Resident", Vector2.new(WIDTH, 300))
	local frame = modal.frame
	modal.header.Visible = false
	modal.body.Visible = false
	-- the booking-office front: mahogany rails round a dark wood middle with its own grain
	frame.Image = Theme.Image.mahogany.id
	frame.SliceCenter = Theme.Image.mahogany.slice
	frame.SliceScale = 0.5
	frame.BackgroundColor3 = Theme.Color.wood
	frame.BackgroundTransparency = 0
	frame.ClipsDescendants = true -- the lamp's pool stays on the wood
	frame.ImageColor3 = Color3.fromRGB(196, 172, 156) -- the rails sit in the carriage's shadow, not its lamp
	local function layer(props: { [string]: any }): ImageLabel
		props.BackgroundTransparency = 1
		return Ui.new("ImageLabel", props) :: ImageLabel
	end
	layer({
		Name = "Grain",
		Size = UDim2.new(1, -40, 1, -40),
		Position = UDim2.fromOffset(20, 20),
		Image = Theme.Image.woodGrain,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(256, 256),
		ZIndex = 32,
		Parent = frame,
	})
	-- light: darkest at the edges, warmest where the lamp in the window reaches
	layer({
		Name = "Falloff",
		Size = UDim2.fromScale(1, 1),
		Image = Theme.Image.vignette,
		ImageColor3 = Theme.Color.black,
		ImageTransparency = 0.25,
		ZIndex = 32,
		Parent = frame,
	})
	local pool = layer({
		Name = "LampPool",
		Size = UDim2.fromOffset(520, 380),
		Position = UDim2.fromOffset(-60, -90),
		Image = Theme.Image.glow.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.glow.slice,
		ImageColor3 = Theme.Color.amber,
		ImageTransparency = 0.86,
		ZIndex = 32,
		Parent = frame,
	})

	-- the window, sunk into the front with a shadow round it
	local portraitShadow = layer({
		Name = "PortraitShadow",
		Size = UDim2.fromOffset(PORTRAIT.X + 36, PORTRAIT.Y + 36),
		Position = UDim2.fromOffset(RIM - 18, RIM - 14),
		Image = Theme.Image.glow.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.glow.slice,
		ImageColor3 = Theme.Color.black,
		ImageTransparency = 0.2,
		ZIndex = 33,
		Parent = frame,
	})
	local portrait = layer({
		Name = "Portrait",
		Size = UDim2.fromOffset(PORTRAIT.X, PORTRAIT.Y),
		Position = UDim2.fromOffset(RIM, RIM),
		ZIndex = 34,
		Parent = frame,
	})
	-- the hanging lamp inside the booth breathes a little
	local lampGlow = layer({
		Name = "LampGlow",
		Size = UDim2.fromOffset(90, 90),
		Position = UDim2.fromOffset(18, 30),
		Image = Theme.Image.glow.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.glow.slice,
		ImageColor3 = Theme.Color.amber,
		ImageTransparency = 0.7,
		ZIndex = 35,
		Parent = portrait,
	})

	-- the name plate, engraved: dark cut letters with the brass catching the lamp under them
	local plate = layer({
		Name = "NamePlate",
		Size = UDim2.new(1, 0, 0, PLATE_H),
		Image = Theme.Image.plateEngraved.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.plateEngraved.slice,
		SliceScale = 0.42,
		ImageColor3 = Color3.fromRGB(214, 194, 170), -- tarnished: the brightest thing on screen otherwise
		ZIndex = 34,
	})
	local function engraved(offset: number, color: Color3, transparency: number): TextLabel
		local l = Ui.text({
			Font = Theme.Font.display,
			TextSize = 21,
			Color = color,
			Transparency = transparency,
			XAlign = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -60, 1, -2),
			Position = UDim2.fromOffset(30, offset),
		})
		l.ZIndex = 35
		l.Parent = plate
		return l
	end
	local nameLight = engraved(1, Theme.Color.brassLight, 0.25)
	local nameCut = engraved(0, Theme.Color.inkDeep, 0)
	nameCut.ZIndex = 36

	-- the blotter the line is typed onto
	local blotter = layer({
		Name = "Blotter",
		Size = UDim2.new(1, 0, 0, 120),
		Image = Theme.Image.blotter.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.blotter.slice,
		SliceScale = 0.4,
		ZIndex = 34,
	})
	local blotterGlow = layer({
		Name = "Glow",
		Size = UDim2.new(0.9, 0, 1, 40),
		Position = UDim2.fromOffset(-30, -30),
		Image = Theme.Image.glow.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.glow.slice,
		ImageColor3 = Theme.Color.amber,
		ImageTransparency = 0.88,
		ZIndex = 35,
		Parent = blotter,
	})
	local line = Ui.text({
		Name = "Line",
		Font = Theme.Font.type,
		TextSize = TEXT_SIZE,
		Color = Theme.Color.bone,
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -TEXT_PAD.X * 2, 1, -TEXT_PAD.Y * 2),
		Position = UDim2.fromOffset(TEXT_PAD.X, TEXT_PAD.Y),
	})
	line.TextStrokeColor3 = Theme.Color.ember -- lamp glass: a faint warm halo round the type
	line.TextStrokeTransparency = 0.86
	line.LineHeight = 1.12
	line.ZIndex = 36
	line.Parent = blotter

	-- the company's stamp, struck over the corner of the blotter
	local stamp = layer({
		Name = "Stamp",
		Size = UDim2.fromOffset(104, 104),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Image = Theme.Image.stamp,
		ImageColor3 = Theme.Color.signal,
		ImageTransparency = 0.04,
		Rotation = -14,
		ZIndex = 37,
	})

	-- leave: a plain ticket stub; it lifts in the lamp on hover and presses down when clicked
	local tabGlow = layer({
		Name = "TabGlow",
		Size = UDim2.fromOffset(TAB.X + 40, TAB.Y + 40),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 20, 1, 20),
		Image = Theme.Image.glow.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.glow.slice,
		ImageColor3 = Theme.Color.amber,
		ImageTransparency = 1,
		ZIndex = 34,
	})
	local tab = Ui.new("ImageButton", {
		Name = "Leave",
		Size = UDim2.fromOffset(TAB.X, TAB.Y),
		BackgroundColor3 = TAB_CARD,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Image = Theme.Image.card.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.card.slice,
		SliceScale = 0.25,
		AutoButtonColor = false,
		Selectable = true,
		ZIndex = 35,
		Parent = frame,
	}) :: ImageButton
	tab.SelectionImageObject = Ui.new("Frame", { BackgroundTransparency = 1 }) :: Frame -- the glow shows it
	Ui.corner(2).Parent = tab
	local tabText = Ui.text({
		Text = "CLOSE",
		Font = Theme.Font.display,
		TextSize = 19,
		Color = Theme.Color.inkDeep,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
	})
	tabText.ZIndex = 36
	tabText.Parent = tab
	local hot, down = false, false
	local function look()
		Ui.tween(tabGlow, { ImageTransparency = if down then 0.75 elseif hot then 0.45 else 1 })
		tab.ImageColor3 = if down then Color3.fromRGB(190, 175, 160) else Color3.new(1, 1, 1)
		tab.BackgroundColor3 = if down then TAB_CARD:Lerp(Color3.new(), 0.25) else TAB_CARD
		tabText.Position = UDim2.fromOffset(8, if down then 2 else 0)
	end
	local function hover(on: boolean): () -> ()
		return function()
			hot = on
			down = down and on
			look()
		end
	end
	tab.MouseEnter:Connect(hover(true))
	tab.MouseLeave:Connect(hover(false))
	tab.SelectionGained:Connect(hover(true))
	tab.SelectionLost:Connect(hover(false))
	tab.MouseButton1Down:Connect(function()
		down = true
		look()
	end)
	tab.MouseButton1Up:Connect(function()
		down = false
		look()
	end)
	tab.Activated:Connect(function()
		modal:close()
	end)
	modal.focus = tab

	local column = Ui.new("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		ZIndex = 33,
		Parent = frame,
	}) :: Frame
	plate.Parent = column
	blotter.Parent = column
	stamp.Parent = column
	tab.Parent = column
	tabGlow.Parent = column -- a sibling under the tab, so it glows behind it

	-- Lay the window out round the line: the blotter grows with the text, the window with both,
	-- and the portrait grows to the column's height so no wood is left bare beside it.
	local function columnHeight(textHeight: number): (number, number)
		local blotterH = math.max(textHeight + TEXT_PAD.Y * 2 + 6, 92)
		return PLATE_H + 10 + blotterH + 12 + TAB.Y, blotterH
	end
	local function layout(portraitSize: Vector2?, textHeight: number)
		local left = if portraitSize then RIM + portraitSize.X + GAP + 4 else RIM
		local columnH, blotterH = columnHeight(textHeight)
		local inner = math.max(columnH, if portraitSize then portraitSize.Y else 0)
		frame.Size = UDim2.fromOffset(WIDTH, inner + RIM * 2)
		portrait.Visible = portraitSize ~= nil
		portraitShadow.Visible = portraitSize ~= nil
		if portraitSize then
			portrait.Size = UDim2.fromOffset(portraitSize.X, portraitSize.Y)
			portrait.Position = UDim2.fromOffset(RIM, RIM + math.floor((inner - portraitSize.Y) / 2))
			portraitShadow.Size = UDim2.fromOffset(portraitSize.X + 36, portraitSize.Y + 36)
			portraitShadow.Position = portrait.Position - UDim2.fromOffset(18, 14)
		end
		column.Position = UDim2.fromOffset(left, RIM + math.floor((inner - columnH) / 2))
		column.Size = UDim2.fromOffset(WIDTH - left - RIM, columnH)
		blotter.Position = UDim2.fromOffset(0, PLATE_H + 10)
		blotter.Size = UDim2.new(1, 0, 0, blotterH)
		tab.AnchorPoint = Vector2.new(1, 1)
		tab.Position = UDim2.fromScale(1, 1)
		stamp.Position = UDim2.new(1, -TAB.X - 74, 0, PLATE_H + 10 + blotterH + 2)
	end

	-- the lamps flicker, faintly, while the window is open
	local flicker: RBXScriptConnection? = nil
	modal.onOpen = function()
		flicker = RunService.RenderStepped:Connect(function()
			local t = os.clock()
			local n = math.noise(t * 2.3, 0.37) + 0.5 * math.noise(t * 9.1, 4.2)
			lampGlow.ImageTransparency = 0.68 + n * 0.12
			pool.ImageTransparency = 0.86 + n * 0.04
			blotterGlow.ImageTransparency = 0.88 + n * 0.04
		end)
	end
	modal.onClose = function()
		if flicker then
			flicker:Disconnect()
			flicker = nil
		end
	end

	local function measure(text: string, width: number): number
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = Theme.Font.type
		params.Size = TEXT_SIZE
		params.Width = width
		local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
		return if ok then (bounds :: Vector2).Y * line.LineHeight else TEXT_SIZE * 4
	end

	Net.On("Dialogue", function(said: Said)
		if type(said) ~= "table" then
			return
		end
		local picture = Theme.Portrait[said.npc]
		portrait.Image = picture or ""
		local name, role = string.upper(said.name), string.upper(said.role)
		nameCut.Text = `{name}  ·  {role}`
		nameLight.Text = nameCut.Text
		line.Text = `“{said.text}”`
		task.spawn(function()
			local function textWidth(size: Vector2?): number
				local left = if size then RIM + size.X + GAP + 4 else RIM
				return WIDTH - left - RIM - TEXT_PAD.X * 2
			end
			local size: Vector2? = if picture then PORTRAIT else nil
			local textHeight = measure(line.Text, textWidth(size))
			if size then
				-- a long line makes a taller column; the window grows to match it, then re-measure
				local h = math.clamp(columnHeight(textHeight), PORTRAIT.Y, PORTRAIT.Y * 1.35)
				size = Vector2.new(math.floor(h * PORTRAIT.X / PORTRAIT.Y), h)
				textHeight = measure(line.Text, textWidth(size))
			end
			layout(size, textHeight)
			modal:open()
		end)
	end)
end

return Dialogue
