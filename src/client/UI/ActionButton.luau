--!strict
--[[
	The touch action button (launch hardening step 5; rules in Logic/TouchAction). One fixed button
	left of RUN, labelled for the one prompt in range ("SEARCH CRATE", "OPEN DOOR"); hidden when
	nothing is. A tap triggers it; a prompt whose server rule needs a hold fills a brass bar while the
	thumb stays down, and the hold ends if the prompt goes or another takes its place. It drives the
	same ProximityPrompt as E and gamepad X (InputHoldBegin/End), so the server's checks are the same.
	Roblox's own touch camera and jump button are left alone; no swipe is bound anywhere.

	The plate is the rendered brass push-plate (Theme.Image.actionPlate, up and pressed) once
	uploaded, otherwise the enamel Primary button.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local TouchAction = require(Shared.Logic.TouchAction)

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local ActionButton = {}

local SIZE = Vector2.new(168, 58)
-- left of RUN (MovementController puts it at 1,-170 / 1,-150), clear of the jump button
local POSITION = UDim2.new(1, -262, 1, -96)
local COMPACT_SCALE = 0.86

function ActionButton.mount(gui: ScreenGui)
	local state = TouchAction.new()
	local prompts: { [ProximityPrompt]: boolean } = {}

	local art = Theme.Image.actionPlate
	local button: GuiButton
	local label: TextLabel
	if art.up ~= "" then
		local plate = Ui.new("ImageButton", {
			Name = "ActionButton",
			Image = art.up,
			PressedImage = art.down,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = art.slice,
			SliceScale = art.scale,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Parent = gui,
		})
		label = Ui.text({
			Text = "",
			Font = Theme.Font.display,
			TextSize = 20,
			Color = Theme.Color.brassLight,
			XAlign = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -24, 1, -10),
			Position = UDim2.fromOffset(12, 3),
		})
		label.TextScaled = true
		Ui.new("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 11, Parent = label })
		label.Parent = plate
		button = plate
	else
		local enamel = Ui.button("", "Primary")
		enamel.Name = "ActionButton"
		enamel.Parent = gui
		enamel.TextScaled = true
		Ui.new("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 11, Parent = enamel })
		button = enamel
		label = enamel :: any
	end
	button.Size = UDim2.fromOffset(SIZE.X, SIZE.Y)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = POSITION
	button.Visible = false
	button.Selectable = false -- gamepad uses X on the prompt itself
	local scale = Ui.new("UIScale", { Parent = button })
	local function fit()
		scale.Scale = if gui:GetAttribute("Compact") then COMPACT_SCALE else 1
	end
	fit()
	gui:GetAttributeChangedSignal("Compact"):Connect(fit)

	local bar = Ui.new("Frame", {
		Name = "Hold",
		Size = UDim2.fromOffset(0, 4),
		Position = UDim2.new(0, 10, 1, -9),
		BackgroundColor3 = Theme.Color.brassLight,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = button,
	})

	local function endHold(id: any?)
		if id ~= nil then
			(id :: ProximityPrompt):InputHoldEnd()
		end
		bar.Size = UDim2.fromOffset(0, 4)
	end

	local function refresh()
		local target = TouchAction.target(state)
		button.Visible = target ~= nil
		if target then
			label.Text = TouchAction.label(target.action, target.object)
		end
	end

	local function remove(prompt: ProximityPrompt)
		if prompts[prompt] then
			prompts[prompt] = nil
			endHold(TouchAction.hide(state, prompt))
			refresh()
		end
	end

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if
			inputType ~= Enum.ProximityPromptInputType.Touch
			or prompt.Style ~= Enum.ProximityPromptStyle.Custom
		then
			return
		end
		prompts[prompt] = true
		endHold(TouchAction.show(state, {
			id = prompt,
			action = prompt.ActionText,
			object = prompt.ObjectText,
			hold = prompt.HoldDuration,
		}))
		refresh()
		local hidden: RBXScriptConnection? = nil
		local gone: RBXScriptConnection? = nil
		local function drop()
			if hidden then
				hidden:Disconnect()
			end
			if gone then
				gone:Disconnect()
			end
			remove(prompt)
		end
		hidden = prompt.PromptHidden:Connect(drop)
		gone = prompt.Destroying:Connect(drop)
	end)

	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local id = TouchAction.press(state, os.clock())
		if id ~= nil then
			(id :: ProximityPrompt):InputHoldBegin()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		endHold(TouchAction.release(state))
	end)

	RunService.RenderStepped:Connect(function()
		if not button.Visible then
			return
		end
		local p = TouchAction.progress(state, os.clock())
		bar.Size = UDim2.new(p, -20 * p, 0, 4)
	end)
end

return ActionButton
