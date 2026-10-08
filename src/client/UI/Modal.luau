--!strict
--[[
	Centered modal window with a dimmed backdrop. One modal is open at a time;
	opening another closes the current one. Gamepad B, the backdrop or CLOSE
	closes it (Escape is reserved for the Roblox menu).

	It looks like a piece of the train's fittings: a soot-iron plate with a brass
	plate riveted at each corner, an iron header ruled off in brass, the company's
	name in small caps over the window's title.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

export type Modal = {
	frame: Frame,
	body: Frame,
	header: Frame,
	title: TextLabel,
	open: (self: Modal) -> (),
	close: (self: Modal) -> (),
	isOpen: (self: Modal) -> boolean,
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

local Modal = {}

local current: Modal? = nil
local backdrop: Frame? = nil

local function bindClose()
	ContextActionService:BindActionAtPriority("LTO_CloseModal", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and current then
			current:close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 3000, Enum.KeyCode.ButtonB)
end

function Modal.new(gui: ScreenGui, titleText: string, size: Vector2): Modal
	if backdrop == nil then
		backdrop = Ui.new("TextButton", {
			Name = "Backdrop",
			Size = UDim2.new(1, 0, 1, 80),
			Position = UDim2.fromOffset(0, -60),
			BackgroundColor3 = Theme.Color.steel,
			BackgroundTransparency = 0.3,
			Text = "",
			AutoButtonColor = false,
			Visible = false,
			ZIndex = 30,
			Parent = gui,
		});
		(backdrop :: any).Activated:Connect(function()
			if current then
				current:close()
			end
		end)
	end

	local frame = Ui.panel({
		Name = titleText,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 31,
		Parent = gui,
	})
	local header = Ui.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.Color.steelLight,
		BorderSizePixel = 0,
		ZIndex = 32,
		Parent = frame,
	})
	Ui.corner().Parent = header
	Ui.new("Frame", {
		Name = "Rule",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		ZIndex = 33,
		Parent = header,
	})
	local caption = Ui.text({
		Text = "LAST TRAIN OUT",
		Font = Theme.Font.displayMedium,
		TextSize = 12,
		Color = Theme.Color.textDim,
		Position = UDim2.fromOffset(18, 5),
		Size = UDim2.new(1, -140, 0, 14),
	})
	caption.ZIndex = 33
	caption.Parent = header
	local title = Ui.text({
		Text = string.upper(titleText),
		Font = Theme.Font.display,
		TextSize = 25,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(18, 17),
		Size = UDim2.new(1, -140, 0, 30),
	})
	title.ZIndex = 33
	title.Parent = header
	-- a small brass plate riveted at each corner of the window
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local plate = Ui.new("Frame", {
			Name = "Rivet",
			AnchorPoint = corner,
			Position = UDim2.new(
				corner.X,
				if corner.X > 0 then -5 else 5,
				corner.Y,
				if corner.Y > 0 then -5 else 5
			),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Theme.Color.brass,
			BorderSizePixel = 0,
			ZIndex = 35,
			Parent = frame,
		})
		Ui.corner(3).Parent = plate
	end
	local body = Ui.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -32, 1, -76),
		Position = UDim2.fromOffset(16, 64),
		BackgroundTransparency = 1,
		ZIndex = 32,
		Parent = frame,
	})
	local scale = Ui.new("UIScale", { Parent = frame })

	local modal: Modal
	local closeButton = Ui.button("CLOSE", "Secondary", function()
		modal:close()
	end, {
		Size = UDim2.fromOffset(104, 34),
		Position = UDim2.new(1, -14, 0.5, -1),
		AnchorPoint = Vector2.new(1, 0.5),
		TextSize = 16,
	})
	closeButton.ZIndex = 34
	closeButton.Parent = header

	modal = {
		frame = frame,
		body = body,
		header = header,
		title = title,
		onOpen = nil,
		onClose = nil,
		open = function(self: Modal)
			if current and current ~= self then
				current:close()
			end
			current = self
			if backdrop then
				backdrop.Visible = true
			end
			frame.Visible = true
			-- never larger than the screen: on a phone the window shrinks to fit the safe area
			local fit = 1
			local screen = frame.Parent :: GuiBase2d?
			local screenScale = screen and screen:FindFirstChildOfClass("UIScale")
			if screen and screenScale and screenScale.Scale > 0 then
				local room = screen.AbsoluteSize / screenScale.Scale - Vector2.new(16, 16)
				fit = math.min(1, room.X / frame.Size.X.Offset, room.Y / frame.Size.Y.Offset)
			end
			scale.Scale = 0.94 * fit
			Ui.tween(
				scale,
				{ Scale = fit },
				TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			)
			bindClose()
			if self.onOpen then
				self.onOpen()
			end
			GuiService.SelectedObject = closeButton
		end,
		close = function(self: Modal)
			if not frame.Visible then
				return
			end
			frame.Visible = false
			if current == self then
				current = nil
				if backdrop then
					backdrop.Visible = false
				end
				ContextActionService:UnbindAction("LTO_CloseModal")
			end
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(frame) then
				GuiService.SelectedObject = nil
			end
			if self.onClose then
				self.onClose()
			end
		end,
		isOpen = function(_self: Modal)
			return frame.Visible
		end,
	}
	return modal
end

function Modal.closeAll()
	if current then
		current:close()
	end
end

return Modal
