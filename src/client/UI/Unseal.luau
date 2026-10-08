--!strict
--[[
	The mystery ticket's reveal. While run.destination is sealed (Logic/Mystery.sealed) nothing
	shows here; when the server writes the full destination at Arrival (sealed = false), a ticket
	drops in at the top of the screen: the soot over its "????" wipes away left to right, then the
	station's name and danger are stamped in. It plays once per stop, and only for a client that
	saw the seal (a crewmate joining mid-stop just sees the station).
]]

local Registry = require(script.Parent.Parent.Registry)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Unseal = {}

local HEAD = Font.new("rbxasset://fonts/families/Arvo.json", Enum.FontWeight.Bold)
local SOOT = Color3.fromRGB(58, 52, 48)
local INK_RED = Color3.fromRGB(146, 26, 30)
local W, H = 300, 116
local HOLD_SECONDS = 0.5 -- the sealed ticket sits a moment before the wipe
local WIPE_SECONDS = 0.9
local STAMP_SECONDS = 0.16
local STAMP_FROM = 2.4
local SHOW_SECONDS = 3.2

local function stamped(
	parent: Instance,
	text: string,
	y: number,
	size: number,
	color: Color3
): (TextLabel, UIScale)
	local l = Ui.text({ Text = text, Font = HEAD, TextSize = size, Color = color })
	l.Size = UDim2.new(1, -28, 0, size + 6)
	l.Position = UDim2.fromOffset(14, y)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextTransparency = 1
	l.ZIndex = 3
	l.Parent = parent
	local scale = Ui.new("UIScale", { Scale = STAMP_FROM, Parent = l })
	return l, scale
end

local function play(gui: ScreenGui, destination: any)
	local holder = Ui.new("Frame", {
		Name = "Unseal",
		Size = UDim2.fromOffset(W, H),
		Position = UDim2.new(0.5, 0, 0, -H),
		AnchorPoint = Vector2.new(0.5, 0),
		Rotation = -1.5,
		BackgroundColor3 = Theme.Color.paper,
		BorderSizePixel = 0,
		ZIndex = 30,
		Parent = gui,
	})
	Ui.corner(2).Parent = holder
	Ui.stroke(Theme.Color.inkSoft, 1, 0.5).Parent = holder
	local kind = Ui.text({
		Text = "SEALED LINE · UNSEALED",
		Font = Theme.Font.type,
		TextSize = 12,
		Color = Theme.Color.inkSoft,
	})
	kind.Size = UDim2.new(1, -28, 0, 16)
	kind.Position = UDim2.fromOffset(14, 10)
	kind.TextXAlignment = Enum.TextXAlignment.Center
	kind.ZIndex = 3
	kind.Parent = holder
	local name, nameScale = stamped(holder, string.upper(destination.name or ""), 32, 26, Theme.Color.ink)
	local danger, dangerScale = stamped(holder, `DANGER {destination.tier or 1}`, 76, 16, INK_RED)

	-- the soot, wiped away from the left: a clipping frame that shrinks towards its right edge
	local cover = Ui.new("Frame", {
		Name = "Soot",
		Size = UDim2.new(1, -12, 1, -34),
		Position = UDim2.new(1, -6, 0, 28),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 4,
		Parent = holder,
	})
	local smear = Ui.new("Frame", {
		Size = UDim2.fromOffset(W - 12, H - 34),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = SOOT,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = cover,
	})
	Ui.corner(10).Parent = smear
	local marks = Ui.text({ Text = "????", Font = HEAD, TextSize = 30, Color = Theme.Color.paper })
	marks.Size = UDim2.fromScale(1, 1)
	marks.TextXAlignment = Enum.TextXAlignment.Center
	marks.ZIndex = 5
	marks.Parent = smear

	Ui.tween(holder, { Position = UDim2.new(0.5, 0, 0, 120) }, TweenInfo.new(0.35, Enum.EasingStyle.Back))
	task.delay(HOLD_SECONDS, function()
		local wipe = TweenInfo.new(WIPE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		Ui.tween(cover, { Size = UDim2.new(0, 0, 1, -34) }, wipe)
		task.delay(WIPE_SECONDS, function()
			local slam = TweenInfo.new(STAMP_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Ui.tween(nameScale, { Scale = 1 }, slam)
			Ui.tween(name, { TextTransparency = 0 }, slam)
			if Registry.AudioController then
				Registry.AudioController.Play("TicketPunch")
			end
			task.delay(0.25, function()
				Ui.tween(dangerScale, { Scale = 1 }, slam)
				Ui.tween(danger, { TextTransparency = 0 }, slam)
			end)
			task.delay(SHOW_SECONDS, function()
				Ui.tween(holder, { Position = UDim2.new(0.5, 0, 0, -H - 20) }, TweenInfo.new(0.4))
				task.delay(0.45, function()
					holder:Destroy()
				end)
			end)
		end)
	end)
end

function Unseal.mount(gui: ScreenGui)
	local State = Registry.StateController
	local sealedKey: string? = nil
	local playedKey: string? = nil
	State.Observe("public", { "run", "destination" }, function()
		local destination = State.Get({ "run", "destination" })
		if destination == nil or destination.mystery ~= true then
			return
		end
		local key = `{State.Get({ "run", "runId" })}:{State.Get({ "run", "nextStop" })}`
		if destination.sealed then
			sealedKey = key
		elseif sealedKey == key and playedKey ~= key then
			playedKey = key
			play(gui, destination)
		end
	end)
end

return Unseal
