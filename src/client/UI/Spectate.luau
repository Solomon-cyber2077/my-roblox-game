--!strict
--[[
	Elimination card and spectator bar. The card names the cause in large type,
	says whether a flare can still bring you back, then shrinks into a bar that
	shows who you are watching (Q/E, shoulder buttons or the arrows to switch).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Spectate = {}

local CAUSES: { [string]: { title: string, line: string } } = {
	LeftBehind = { title = "LEFT BEHIND", line = "The train pulled out without you." },
	Taken = { title = "TAKEN", line = "A Hollow caught you in the open." },
	Smothered = { title = "LOST IN THE FOG", line = "You stayed too long past the fog line." },
	Fell = { title = "FELL", line = "The ground gave way beneath you." },
	Disconnected = { title = "DISCONNECTED", line = "" },
}

local card: Frame
local cardTitle: TextLabel
local cardLine: TextLabel
local cardHope: TextLabel
local bar: ImageLabel
local barLabel: TextLabel
local targetIndex = 1

local function aliveOthers(): { Player }
	local crew = Registry.StateController.Get({ "crew" }) or {}
	local out: { Player } = {}
	for _, player in Players:GetPlayers() do
		local entry = crew[tostring(player.UserId)]
		if player ~= Players.LocalPlayer and entry and entry.status ~= "Eliminated" then
			table.insert(out, player)
		end
	end
	table.sort(out, function(a, b)
		return a.UserId < b.UserId
	end)
	return out
end

local function refreshTarget()
	local others = aliveOthers()
	if #others == 0 then
		barLabel.Text = "NO ONE LEFT TO WATCH"
		Registry.CameraController.SetSpectateTarget(nil)
		return
	end
	targetIndex = (targetIndex - 1) % #others + 1
	local target = others[targetIndex]
	barLabel.Text = `WATCHING {string.upper(target.DisplayName)}  ·  Q / E TO SWITCH`
	Registry.CameraController.SetSpectateTarget(target)
end

function Spectate.mount(gui: ScreenGui)
	card = Ui.new("Frame", {
		Name = "Eliminated",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.black,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 25,
		Parent = gui,
	})
	cardTitle = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 72,
		Color = Theme.Color.signal,
		Size = UDim2.new(1, 0, 0, 84),
		Position = UDim2.fromScale(0.5, 0.38),
		AnchorPoint = Vector2.new(0.5, 0.5),
		XAlign = Enum.TextXAlignment.Center,
	})
	cardTitle.ZIndex = 26
	cardTitle.TextStrokeTransparency = 0.5
	cardTitle.Parent = card
	cardLine = Ui.text({
		Text = "",
		Font = Theme.Font.body,
		TextSize = 20,
		Color = Theme.Color.white,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0.5, 0, 0.38, 56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		XAlign = Enum.TextXAlignment.Center,
	})
	cardLine.ZIndex = 26
	cardLine.Parent = card
	cardHope = Ui.text({
		Text = "",
		Font = Theme.Font.type,
		TextSize = 18,
		Color = Theme.Color.sky,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0.5, 0, 0.38, 92),
		AnchorPoint = Vector2.new(0.5, 0.5),
		XAlign = Enum.TextXAlignment.Center,
	})
	cardHope.ZIndex = 26
	cardHope.Parent = card

	bar = Ui.panel({
		Name = "SpectateBar",
		Size = UDim2.fromOffset(460, 44),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = gui,
	})
	barLabel = Ui.text({
		Text = "",
		Font = Theme.Font.display,
		TextSize = 17,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
	})
	barLabel.Parent = bar

	ContextActionService:BindAction(
		"LTO_SpectateCycle",
		function(_, inputState, input)
			if inputState ~= Enum.UserInputState.Begin or not bar.Visible then
				return Enum.ContextActionResult.Pass
			end
			local forward = input.KeyCode == Enum.KeyCode.E
				or input.KeyCode == Enum.KeyCode.ButtonR1
				or input.KeyCode == Enum.KeyCode.Right
			targetIndex += if forward then 1 else -1
			refreshTarget()
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.Q,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonL1,
		Enum.KeyCode.ButtonR1,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right
	)

	Registry.StateController.Observe("public", { "crew" }, function()
		local status = Session.status()
		local spectating = status == "Eliminated" and Session.isRunActive()
		bar.Visible = spectating and not card.Visible
		if spectating then
			refreshTarget()
		else
			Registry.CameraController.SetSpectateTarget(nil)
		end
	end)
end

function Spectate.showElimination(cause: string, canRescue: boolean)
	local info = CAUSES[cause] or CAUSES.Taken
	cardTitle.Text = info.title
	cardLine.Text = info.line
	cardHope.Text = if canRescue
		then "A crewmate can still bring you back with a Signal Flare."
		else "This was your second chance. Watch your crew bring it home."
	card.Visible = true
	card.BackgroundTransparency = 1
	Ui.tween(card, { BackgroundTransparency = 0.35 }, TweenInfo.new(0.6))
	cardTitle.TextTransparency = 1
	Ui.tween(cardTitle, { TextTransparency = 0 }, TweenInfo.new(0.4))
	task.delay(3.5, function()
		Ui.tween(card, { BackgroundTransparency = 1 }, TweenInfo.new(0.6))
		Ui.tween(cardTitle, { TextTransparency = 1 }, TweenInfo.new(0.6))
		task.wait(0.6)
		card.Visible = false
		if Session.status() == "Eliminated" then
			bar.Visible = true
			refreshTarget()
		end
	end)
end

function Spectate.hide()
	card.Visible = false
	bar.Visible = false
	Registry.CameraController.SetSpectateTarget(nil)
end

return Spectate
