--!strict
--[[
	Tiny declarative helper for building Roblox UI in code.

	Ui.new("Frame", { Size = ..., [Ui.Children] = { ... }, [Ui.On "Activated"] = fn })
	Properties are assigned in one place; children are parented last so layout
	objects measure once. Shared components (panels, buttons, labels) live here.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Ui = {}

local CHILDREN = newproxy(false)
Ui.Children = CHILDREN

local eventKeys: { [string]: any } = {}
function Ui.On(eventName: string): any
	local key = eventKeys[eventName]
	if key == nil then
		key = newproxy(false)
		eventKeys[eventName] = key
	end
	return key
end

local function eventNameOf(key: any): string?
	for name, value in eventKeys do
		if value == key then
			return name
		end
	end
	return nil
end

function Ui.new(className: string, props: { [any]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local p: { [any]: any } = props or {}
	local kids: { Instance }? = children or p[CHILDREN]
	for key, value in p do
		if key == CHILDREN or key == "Parent" then
			continue
		end
		if type(key) == "userdata" then
			local eventName = eventNameOf(key)
			if eventName then
				(instance :: any)[eventName]:Connect(value)
			end
		else
			(instance :: any)[key] = value
		end
	end
	if kids then
		for _, child in kids do
			child.Parent = instance
		end
	end
	if p.Parent then
		instance.Parent = p.Parent
	end
	return instance
end

function Ui.corner(radius: number?): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Corner) })
end

function Ui.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Ui.new("UIStroke", {
		Color = color or Theme.Color.brass,
		Thickness = thickness or 1,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
	})
end

function Ui.list(
	direction: Enum.FillDirection,
	gap: number,
	align: Enum.HorizontalAlignment?,
	valign: Enum.VerticalAlignment?
): UIListLayout
	return Ui.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, gap),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Ui.tween(instance: Instance, goal: { [string]: any }, info: TweenInfo?): Tween
	local tween = TweenService:Create(instance, info or Theme.Tween, goal)
	tween:Play()
	return tween
end

export type TextProps = {
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Font: Font?,
	TextSize: number?,
	Color: Color3?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	Name: string?,
	LayoutOrder: number?,
	AutoX: boolean?,
	Wrapped: boolean?,
	Rich: boolean?,
	Transparency: number?,
}

function Ui.text(props: TextProps): TextLabel
	return Ui.new("TextLabel", {
		Name = props.Name or "Label",
		BackgroundTransparency = 1,
		Text = props.Text or "",
		Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or 16) + 4),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		FontFace = props.Font or Theme.Font.body,
		TextSize = props.TextSize or 16,
		TextColor3 = props.Color or Theme.Color.white,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Left,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		TextWrapped = props.Wrapped == true,
		RichText = props.Rich == true,
		AutomaticSize = if props.AutoX then Enum.AutomaticSize.X else Enum.AutomaticSize.None,
		LayoutOrder = props.LayoutOrder or 0,
		TextTransparency = props.Transparency or 0,
	})
end

-- Dark steel panel with a brass hairline.
function Ui.panel(props: { [any]: any }): Frame
	local frame = Ui.new("Frame", props)
	frame.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.steel
	frame.BackgroundTransparency = props.BackgroundTransparency or 0.12
	frame.BorderSizePixel = 0
	Ui.corner().Parent = frame
	Ui.stroke(Theme.Color.brass, 1, 0.55).Parent = frame
	return frame
end

-- Cream ticket stock with a perforated edge along one side.
function Ui.ticket(props: { [any]: any }): Frame
	local frame = Ui.new("Frame", props)
	frame.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.paper
	frame.BorderSizePixel = 0
	Ui.corner(4).Parent = frame
	local perforation = Ui.new("Frame", {
		Name = "Perforation",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 4, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		ZIndex = (frame.ZIndex or 1) + 1,
	})
	Ui.list(Enum.FillDirection.Vertical, 5, Enum.HorizontalAlignment.Center).Parent = perforation
	for i = 1, 24 do
		Ui.new("Frame", {
			Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = Theme.Color.paperShade,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = perforation,
		})
	end
	perforation.ClipsDescendants = true
	perforation.Parent = frame
	return frame
end

export type ButtonStyle = "Primary" | "Secondary" | "Danger" | "Paper"

local STYLES: { [string]: { bg: Color3, text: Color3, stroke: Color3 } } = {
	Primary = { bg = Theme.Color.brass, text = Theme.Color.ink, stroke = Theme.Color.brassLight },
	Secondary = { bg = Theme.Color.steelLight, text = Theme.Color.white, stroke = Theme.Color.steelLine },
	Danger = { bg = Theme.Color.signal, text = Theme.Color.white, stroke = Theme.Color.signalDark },
	Paper = { bg = Theme.Color.paper, text = Theme.Color.ink, stroke = Theme.Color.paperShade },
}

function Ui.button(
	text: string,
	style: ButtonStyle?,
	onClick: (() -> ())?,
	props: { [any]: any }?
): TextButton
	local s = STYLES[style or "Primary"]
	local p: { [any]: any } = props or {}
	local button = Ui.new("TextButton", {
		Name = p.Name or "Button",
		Size = p.Size or UDim2.fromOffset(160, 40),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		LayoutOrder = p.LayoutOrder or 0,
		BackgroundColor3 = s.bg,
		AutoButtonColor = false,
		Text = text,
		FontFace = Theme.Font.display,
		TextSize = p.TextSize or 18,
		TextColor3 = s.text,
		BorderSizePixel = 0,
		Selectable = true,
	})
	Ui.corner(5).Parent = button
	local stroke = Ui.stroke(s.stroke, 1, 0.2)
	stroke.Parent = button
	local scale = Ui.new("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		Ui.tween(scale, { Scale = 1.04 })
		Ui.tween(stroke, { Transparency = 0 })
	end)
	button.MouseLeave:Connect(function()
		Ui.tween(scale, { Scale = 1 })
		Ui.tween(stroke, { Transparency = 0.2 })
	end)
	button.MouseButton1Down:Connect(function()
		Ui.tween(scale, { Scale = 0.96 }, TweenInfo.new(0.06))
	end)
	button.MouseButton1Up:Connect(function()
		Ui.tween(scale, { Scale = 1.04 }, TweenInfo.new(0.1))
	end)
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function Ui.setButtonEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	button.BackgroundTransparency = if enabled then 0 else 0.55
	button.TextTransparency = if enabled then 0 else 0.45
end

-- Horizontal meter: returns the frame and a setter(fraction, color?).
function Ui.meter(props: { [any]: any }): (Frame, (number, Color3?, boolean?) -> ())
	local options = table.clone(props)
	local fillColor = options.FillColor
	options.FillColor = nil
	local frame = Ui.new("Frame", options)
	frame.BackgroundColor3 = Theme.Color.black
	frame.BackgroundTransparency = 0.45
	frame.BorderSizePixel = 0
	Ui.corner(3).Parent = frame
	local fill = Ui.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor or Theme.Color.brass,
		BorderSizePixel = 0,
		Parent = frame,
	})
	Ui.corner(3).Parent = fill
	local function set(fraction: number, color: Color3?, instant: boolean?)
		local size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		if instant then
			fill.Size = size
		else
			Ui.tween(fill, { Size = size }, TweenInfo.new(0.25, Enum.EasingStyle.Quad))
		end
		if color then
			fill.BackgroundColor3 = color
		end
	end
	return frame, set
end

return Ui
