--!strict
--[[
	Custom ProximityPrompt presentation. Every prompt in the game uses
	Style = Custom; this draws a ticket-styled chip in the world with the input
	glyph, action, object and a hold-progress rule. Touch players tap the chip.
	Prompts tagged with an Action attribute open UI on trigger (workshop, shop).
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Registry = require(script.Parent.Parent.Registry)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Prompts = {}

local function glyph(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return "X"
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	end
	return prompt.KeyboardKeyCode.Name
end

local function build(
	gui: Instance,
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType
): BillboardGui
	local kind = prompt:GetAttribute("Action")
	local danger = kind == "Breach" or kind == "Pry"
	local billboard = Ui.new("BillboardGui", {
		Name = "Prompt",
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(250, 64),
		StudsOffset = Vector3.new(0, 2.6, 0),
		LightInfluence = 0,
		ResetOnSpawn = false,
		Active = true,
		Adornee = prompt.Parent,
		Parent = gui,
	})
	local chip = Ui.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if danger then Theme.Color.signal else Theme.Color.paper,
		AutoButtonColor = false,
		Text = "",
		Parent = billboard,
	})
	Ui.corner(6).Parent = chip
	Ui.stroke(if danger then Theme.Color.signalDark else Theme.Color.brass, 1.5, 0.1).Parent = chip
	local key = Ui.new("TextLabel", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Color.ink,
		Text = glyph(prompt, inputType),
		FontFace = Theme.Font.display,
		TextSize = if inputType == Enum.ProximityPromptInputType.Touch then 14 else 22,
		TextColor3 = Theme.Color.paper,
		Parent = chip,
	})
	Ui.corner(6).Parent = key
	local textColor = if danger then Theme.Color.white else Theme.Color.ink
	local action = Ui.text({
		Text = string.upper(prompt.ActionText),
		Font = Theme.Font.display,
		TextSize = 20,
		Color = textColor,
		Position = UDim2.fromOffset(64, 8),
		Size = UDim2.new(1, -74, 0, 24),
	})
	action.Parent = chip
	local object = Ui.text({
		Text = prompt.ObjectText,
		Font = Theme.Font.body,
		TextSize = 14,
		Color = if danger then Theme.Color.white else Theme.Color.inkSoft,
		Position = UDim2.fromOffset(64, 32),
		Size = UDim2.new(1, -74, 0, 18),
	})
	object.Parent = chip
	local progress = Ui.new("Frame", {
		Name = "Progress",
		Size = UDim2.fromOffset(0, 4),
		Position = UDim2.new(0, 0, 1, -4),
		BackgroundColor3 = if danger then Theme.Color.white else Theme.Color.signal,
		BorderSizePixel = 0,
		Parent = chip,
	})

	local holdTween: Tween? = nil
	prompt.PromptButtonHoldBegan:Connect(function()
		if prompt.HoldDuration > 0 then
			progress.Size = UDim2.fromOffset(0, 4)
			holdTween = TweenService:Create(
				progress,
				TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
				{ Size = UDim2.new(1, 0, 0, 4) }
			);
			(holdTween :: Tween):Play()
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		progress.Size = UDim2.fromOffset(0, 4)
	end)
	if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
		chip.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldBegin()
			end
		end)
		chip.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldEnd()
			end
		end)
	end
	local scale = Ui.new("UIScale", { Scale = 0.8, Parent = chip })
	Ui.tween(scale, { Scale = 1 }, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	return billboard
end

function Prompts.mount(gui: ScreenGui)
	local container = gui.Parent :: Instance
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local billboard = build(container, prompt, inputType)
		local hidden: RBXScriptConnection
		hidden = prompt.PromptHidden:Connect(function()
			hidden:Disconnect()
			billboard:Destroy()
		end)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local action = prompt:GetAttribute("Action")
		if action == "Workshop" then
			Registry.UIController.Open("Workshop")
		elseif action == "Outfitter" then
			Registry.UIController.Open("Outfitter")
		elseif action == "Ledger" then
			Registry.UIController.Open("Ledger")
		end
	end)

	-- Gamepad and keyboard users get the default key; touch users tap the chip.
	ProximityPromptService.MaxPromptsVisible = if UserInputService.TouchEnabled then 2 else 3
end

return Prompts
