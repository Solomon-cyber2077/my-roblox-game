--!strict
--[[
	The stop-five cash-out (Logic/CashOut, launch hardening step 4): a paper card under the junction
	ballot for each crew member the server offered it to. CASH OUT takes what is earned and steps off
	at the Depot Hall; RIDE ON (or no answer before the junction ends) stays aboard for the Terminus.
	A brass bar along the foot runs down with the offer. The pay packet (Theme.Image.payPacket) sits
	on the left once uploaded.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Types = require(Shared.Types)
local TouchCluster = require(Shared.Logic.TouchCluster)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local TouchButtons = require(script.Parent.TouchButtons)
local Ui = require(script.Parent.Ui)

local CashOut = {}

local WIDTH, HEIGHT = 470, 190
local ICON = 104
-- On a phone the card is laid out in screen units (against our UIScale), so its buttons stay thumb-sized
-- (Logic/TouchCluster.Size) and it sits bottom-left, clear of the touch buttons and under the route
-- ballot; `lune run layout` checks it on real screens.
local COMPACT = { maxWidth = 400, height = 120, pad = 10, margin = 8, title = 15, body = 12 }
local COMPACT_TITLE = `STOP {Tuning.Run.CashOutStop} - CASH OUT OR RIDE ON?`
local COMPACT_BODY =
	`Cash out: keep what you earned. Ride on: +{Tuning.Economy.BrassVictoryAlive} Brass at the Terminus.`

function CashOut.mount(gui: ScreenGui)
	local State = Registry.StateController
	local dismissed: { [number]: boolean } = {} -- offers this player answered RIDE ON to, by endsAt

	local card = Ui.ticket({
		Name = "CashOut",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = UDim2.new(0.5, 0, 1, -170),
		AnchorPoint = Vector2.new(0.5, 1),
		Visible = false,
		Parent = gui,
	})
	local art = Theme.Image.payPacket
	local textLeft = if art ~= "" then ICON + 34 else 20
	local inset: Frame? = nil
	if art ~= "" then
		-- a dark inset, so the manila packet does not sink into the card
		inset = Ui.new("Frame", {
			Name = "Inset",
			Size = UDim2.fromOffset(ICON + 12, ICON + 12),
			Position = UDim2.fromOffset(10, 12),
			BackgroundColor3 = Theme.Color.ink,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Parent = card,
		})
		Ui.corner(4).Parent = inset :: Frame
		Ui.new("ImageLabel", {
			Name = "PayPacket",
			Image = art,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(ICON, ICON),
			Position = UDim2.fromOffset(6, 6),
			Parent = inset,
		})
	end

	local title = Ui.text({
		Text = `STOP {Tuning.Run.CashOutStop} - YOUR FARE IS EARNED`,
		Font = Theme.Font.display,
		TextSize = 21,
		Color = Theme.Color.ink,
		Size = UDim2.new(1, -textLeft - 16, 0, 26),
		Position = UDim2.fromOffset(textLeft, 12),
	})
	title.Parent = card
	local body = Ui.text({
		Text = `Cash out: keep what you have earned and step off at the Depot. The next run here leaves once this crew is done.\nRide on: the Terminus pays {Tuning.Economy.BrassVictoryAlive} Brass more.`,
		TextSize = 13,
		Color = Theme.Color.ink,
		Wrapped = true,
		YAlign = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -textLeft - 16, 0, 72),
		Position = UDim2.fromOffset(textLeft, 42),
	})
	body.Parent = card

	local function offer(): Types.CashOutOffer?
		return State.Get({ "run", "cashOut" }) :: Types.CashOutOffer?
	end

	local cashOut = Ui.button("CASH OUT", "Secondary", function()
		Net.Fire("CashOut")
	end, {
		Name = "CashOutButton",
		Size = UDim2.fromOffset(150, 56),
		Position = UDim2.new(1, -332, 1, -70),
	})
	cashOut.Parent = card
	local rideOn = Ui.button("RIDE ON", "Primary", function()
		local current = offer()
		if current then
			dismissed[current.endsAt] = true
		end
		card.Visible = false
	end, {
		Name = "RideOnButton",
		Size = UDim2.fromOffset(150, 56),
		Position = UDim2.new(1, -168, 1, -70),
	})
	rideOn.Parent = card

	-- the offer's time, a brass bar along the foot of the card
	local track = Ui.new("Frame", {
		Name = "Time",
		Size = UDim2.new(1, -28, 0, 3),
		Position = UDim2.new(0, 14, 1, -8),
		BackgroundColor3 = Theme.Color.ink,
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
		Parent = card,
	})
	local fill = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.brass,
		BorderSizePixel = 0,
		Parent = track,
	})
	local total = 1

	-- the desktop card as built above, or the phone card in screen units
	local uiScale = gui:FindFirstChildOfClass("UIScale")
	local function layout()
		if gui:GetAttribute("Compact") ~= true then
			card.AnchorPoint = Vector2.new(0.5, 1)
			card.Position = UDim2.new(0.5, 0, 1, -170)
			card.Size = UDim2.fromOffset(WIDTH, HEIGHT)
			if UserInputService.TouchEnabled then
				-- a tablet: slide left until the card clears the touch buttons by a gap
				local s = if uiScale and uiScale.Scale > 0 then uiScale.Scale else 1
				local origin, area = gui.AbsolutePosition, gui.AbsoluteSize
				local half = WIDTH * s / 2
				local maxRight = TouchButtons.layout().action.x - TouchCluster.Gap
				local center = origin.X + area.X / 2
				if center + half > maxRight then
					card.Position = UDim2.new(0, (maxRight - half - origin.X) / s, 1, -170)
				end
			end
			title.Text = `STOP {Tuning.Run.CashOutStop} - YOUR FARE IS EARNED`
			title.TextSize, body.TextSize = 21, 13
			title.Position, title.Size = UDim2.fromOffset(textLeft, 12), UDim2.new(1, -textLeft - 16, 0, 26)
			body.Text =
				`Cash out: keep what you have earned and step off at the Depot. The next run here leaves once this crew is done.\nRide on: the Terminus pays {Tuning.Economy.BrassVictoryAlive} Brass more.`
			body.Position, body.Size = UDim2.fromOffset(textLeft, 42), UDim2.new(1, -textLeft - 16, 0, 72)
			-- 56 tall: ~9.3 mm on an iPad at our UI scale (the thumb minimum), roomy with a mouse
			cashOut.Size, cashOut.Position = UDim2.fromOffset(150, 56), UDim2.new(1, -332, 1, -70)
			rideOn.Size, rideOn.Position = UDim2.fromOffset(150, 56), UDim2.new(1, -168, 1, -70)
			if inset then
				inset.Visible = true
			end
			return
		end
		local s = if uiScale and uiScale.Scale > 0 then uiScale.Scale else 1
		local function u(v: number): number
			return v / s
		end
		local C = COMPACT
		local origin, area = gui.AbsolutePosition, gui.AbsoluteSize
		local left = origin.X + C.margin
		-- clear of every touch button, the phone tool belt and bag too (Logic/TouchCluster.left)
		local w = math.min(C.maxWidth, TouchCluster.left(TouchButtons.layout()) - C.margin * 1.5 - left)
		local bottom = origin.Y + area.Y - C.margin
		card.AnchorPoint = Vector2.new(0, 1)
		card.Position = UDim2.fromOffset(u(left - origin.X), u(bottom - origin.Y))
		card.Size = UDim2.fromOffset(u(w), u(C.height))
		title.Text, body.Text = COMPACT_TITLE, COMPACT_BODY
		title.TextSize, body.TextSize = u(C.title), u(C.body)
		title.Position, title.Size =
			UDim2.fromOffset(u(C.pad), u(6)), UDim2.fromOffset(u(w - 2 * C.pad), u(20))
		body.Position, body.Size =
			UDim2.fromOffset(u(C.pad), u(27)), UDim2.fromOffset(u(w - 2 * C.pad), u(16))
		local bw = (w - 3 * C.pad) / 2
		local bh = TouchCluster.Size
		local by = C.height - bh - 12
		cashOut.Size, cashOut.Position = UDim2.fromOffset(u(bw), u(bh)), UDim2.fromOffset(u(C.pad), u(by))
		rideOn.Size, rideOn.Position =
			UDim2.fromOffset(u(bw), u(bh)), UDim2.fromOffset(u(2 * C.pad + bw), u(by))
		if inset then
			inset.Visible = false
		end
	end

	local function render()
		local current = offer()
		local shown = current ~= nil
			and Session.phase() == "Junction"
			and Session.isAlive()
			and current.eligible[Session.userKey] == true
			and not current.taken[Session.userKey]
			and not dismissed[current.endsAt]
		if shown and not card.Visible and current then
			total = math.max(current.endsAt - Session.now(), 1)
			layout()
		end
		card.Visible = shown
	end

	State.Observe("public", { "run", "cashOut" }, render)
	State.Observe("public", { "run", "phase" }, render)
	State.Observe("public", { "crew", Session.userKey }, render)

	RunService.RenderStepped:Connect(function()
		if not card.Visible then
			return
		end
		local current = offer()
		if current == nil then
			return
		end
		local left = math.max(current.endsAt - Session.now(), 0)
		fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
		if left <= 0 then
			card.Visible = false
		end
	end)
end

return CashOut
