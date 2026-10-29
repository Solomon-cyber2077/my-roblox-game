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

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Types = require(Shared.Types)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local CashOut = {}

local WIDTH, HEIGHT = 470, 178
local ICON = 104
local COMPACT_SCALE = 0.82 -- on a phone, so it clears the touch buttons

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
	local scale = Ui.new("UIScale", { Parent = card })
	local function fit()
		scale.Scale = if gui:GetAttribute("Compact") then COMPACT_SCALE else 1
	end
	fit()
	gui:GetAttributeChangedSignal("Compact"):Connect(fit)

	local art = Theme.Image.payPacket
	local textLeft = if art ~= "" then ICON + 34 else 20
	if art ~= "" then
		-- a dark inset, so the manila packet does not sink into the card
		local inset = Ui.new("Frame", {
			Name = "Inset",
			Size = UDim2.fromOffset(ICON + 12, ICON + 12),
			Position = UDim2.fromOffset(10, 12),
			BackgroundColor3 = Theme.Color.ink,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Parent = card,
		})
		Ui.corner(4).Parent = inset
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
		Size = UDim2.fromOffset(150, 44),
		Position = UDim2.new(1, -332, 1, -58),
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
		Size = UDim2.fromOffset(150, 44),
		Position = UDim2.new(1, -168, 1, -58),
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
