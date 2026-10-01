--!strict
--[[
	Centered modal window with a dimmed backdrop. One modal is open at a time;
	opening another closes the current one. Gamepad B, the backdrop or CLOSE
	closes it (Escape is reserved for the Roblox menu).
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
			BackgroundColor3 = Theme.Color.black,
			BackgroundTransparency = 0.45,
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
		BackgroundColor3 = Theme.Color.paper,
		BorderSizePixel = 0,
		ZIndex = 32,
		Parent = frame,
	})
	Ui.corner().Parent = header
	local title = Ui.text({
		Text = string.upper(titleText),
		Font = Theme.Font.display,
		TextSize = 26,
		Color = Theme.Color.ink,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -140, 1, 0),
	})
	title.ZIndex = 33
	title.Parent = header
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
		Size = UDim2.fromOffset(96, 34),
		Position = UDim2.new(1, -10, 0.5, 0),
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
			scale.Scale = 0.94
			Ui.tween(
				scale,
				{ Scale = 1 },
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
