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
	local danger = kind == "Pry"
	-- a leak's patch: a riveted iron plate in a polished brass rim with a little pressure gauge
	-- whose needle climbs as you hold
	local steam = kind == "Breach"
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
		BackgroundColor3 = if danger then Theme.Color.signalDark else Theme.Color.steel,
		BackgroundTransparency = 0.06,
		AutoButtonColor = false,
		Text = "",
		Parent = billboard,
	})
	Ui.corner(3).Parent = chip
	if gui:GetAttribute("Compact") == true then
		-- a phone: the prompt is drawn smaller, centred where it was
		chip.AnchorPoint = Vector2.new(0.5, 0.5)
		chip.Position = UDim2.fromScale(0.5, 0.5)
		Ui.new("UIScale", { Scale = 0.72, Parent = chip })
	end
	if steam then
		chip.BackgroundColor3 = Theme.Color.steelLight
		Ui.stroke(Theme.Color.brass, 2, 0.05).Parent = chip
	end
	-- an iron plate in a blackened-brass rim, like every other panel
	Ui.new("ImageLabel", {
		Name = "Plate",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Theme.Image.panel.id,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Theme.Image.panel.slice,
		SliceScale = 0.2,
		ZIndex = 0,
		Parent = chip,
	})
	local key = Ui.new("TextLabel", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Color.brass, -- an enamel keycap
		Text = glyph(prompt, inputType),
		FontFace = Theme.Font.display,
		TextSize = if inputType == Enum.ProximityPromptInputType.Touch then 14 else 22,
		TextColor3 = Theme.Color.ink,
		Parent = chip,
	})
	Ui.corner(3).Parent = key
	Ui.stroke(Theme.Color.brassLight, 1, 0.2).Parent = key
	local textColor = if danger then Theme.Color.white else Theme.Color.brassLight
	local textRight = if steam then 120 else 74 -- the gauge sits at the right end
	local action = Ui.text({
		Text = string.upper(prompt.ActionText),
		Font = Theme.Font.display,
		TextSize = 20,
		Color = textColor,
		Position = UDim2.fromOffset(64, 8),
		Size = UDim2.new(1, -textRight, 0, 24),
	})
	action.Parent = chip
	local object = Ui.text({
		Text = prompt.ObjectText,
		Font = if steam then Theme.Font.bodyBold else Theme.Font.body,
		TextSize = 14,
		Color = if danger then Theme.Color.white elseif steam then Theme.Color.amber else Theme.Color.textDim,
		Position = UDim2.fromOffset(64, 32),
		Size = UDim2.new(1, -textRight, 0, 18),
	})
	object.Parent = chip
	local progress = Ui.new("Frame", {
		Name = "Progress",
		Size = UDim2.fromOffset(0, 4),
		Position = UDim2.new(0, 0, 1, -4),
		BackgroundColor3 = if danger
			then Theme.Color.amber
			elseif steam then Theme.Color.brassLight
			else Theme.Color.ember,
		BorderSizePixel = 0,
		Parent = chip,
	})
	local needle: Frame? = nil
	if steam then
		-- the gauge: an enamel face in a brass bezel, a red needle from 7 to 5 o'clock
		local gauge = Ui.new("Frame", {
			Name = "Gauge",
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.new(1, -12, 0.5, -1),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = Theme.Color.paper,
			BorderSizePixel = 0,
			Parent = chip,
		})
		Ui.corner(20).Parent = gauge
		Ui.stroke(Theme.Color.brass, 3, 0).Parent = gauge
		for step = 0, 8 do
			local tick = Ui.new("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Rotation = -135 + step * 270 / 8,
				Parent = gauge,
			})
			Ui.new("Frame", {
				Size = UDim2.fromOffset(if step % 4 == 0 then 2 else 1, 5),
				Position = UDim2.new(0.5, 0, 0, 3),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = if step == 8 then Theme.Color.signal else Theme.Color.ink,
				BorderSizePixel = 0,
				Parent = tick,
			})
		end
		local spin = Ui.new("Frame", {
			Name = "Needle",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Rotation = -135,
			Parent = gauge,
		})
		Ui.new("Frame", {
			Size = UDim2.fromOffset(2, 15),
			Position = UDim2.new(0.5, 0, 0, 6),
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Theme.Color.signal,
			BorderSizePixel = 0,
			Parent = spin,
		})
		local hub = Ui.new("Frame", {
			Size = UDim2.fromOffset(6, 6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Color.brass,
			BorderSizePixel = 0,
			Parent = gauge,
		})
		Ui.corner(3).Parent = hub
		needle = spin
	end

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
			if needle then
				needle.Rotation = -135
				TweenService:Create(
					needle,
					TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
					{ Rotation = 135 }
				):Play()
			end
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function()
		if holdTween then
			holdTween:Cancel()
		end
		progress.Size = UDim2.fromOffset(0, 4)
		if needle then
			-- the pressure drops back
			Ui.tween(needle, { Rotation = -135 }, TweenInfo.new(0.25, Enum.EasingStyle.Quad))
		end
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
		-- PromptHidden does not reliably fire when the server destroys a prompt (a patched leak's),
		-- which left its chip on screen: it also goes when the prompt leaves the game
		local connections: { RBXScriptConnection } = {}
		local function drop()
			for _, connection in connections do
				connection:Disconnect()
			end
			billboard:Destroy()
		end
		table.insert(connections, prompt.PromptHidden:Connect(drop))
		table.insert(connections, prompt.Destroying:Connect(drop))
		table.insert(
			connections,
			prompt.AncestryChanged:Connect(function()
				if not prompt:IsDescendantOf(game) then
					drop()
				end
			end)
		)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local action = prompt:GetAttribute("Action")
		if action == "Workshop" then
			Registry.UIController.Open("Workshop")
		elseif action == "Outfitter" then
			Registry.UIController.Open("Outfitter")
		elseif action == "Ledger" then
			Registry.UIController.Open("Ledger")
		elseif action == "Chest" then
			Registry.UIController.Open("Chest")
		end
	end)

	-- Gamepad and keyboard users get the default key; touch users tap the chip.
	ProximityPromptService.MaxPromptsVisible = if UserInputService.TouchEnabled then 2 else 3
end

return Prompts
