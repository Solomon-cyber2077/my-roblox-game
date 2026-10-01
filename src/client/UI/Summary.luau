--!strict
-- End-of-run receipt: outcome, payout lines in ledger type, XP, rank-ups and milestones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)

local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Summary = {}

local modal: Modal.Modal

local TITLES: { [string]: { text: string, color: Color3, line: string } } = {
	Victory = { text = "END OF THE LINE", color = Theme.Color.go, line = "The train reached the Terminus." },
	Wiped = { text = "NO ONE MADE IT", color = Theme.Color.signal, line = "The whole crew was lost." },
	Derailed = { text = "BROKEN DOWN", color = Theme.Color.caution, line = "The train failed on the line." },
}

function Summary.mount(gui: ScreenGui)
	modal = Modal.new(gui, "Run receipt", Vector2.new(520, 580))
end

function Summary.show(data: { [string]: any })
	local body = modal.body
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	local title = TITLES[data.outcome] or TITLES.Wiped
	local receipt = Ui.ticket({ Size = UDim2.fromScale(1, 1), ZIndex = 32, Parent = body })
	local content = Ui.new("Frame", {
		Size = UDim2.new(1, -44, 1, -20),
		Position = UDim2.fromOffset(30, 10),
		BackgroundTransparency = 1,
		ZIndex = 33,
		Parent = receipt,
	})
	Ui.list(Enum.FillDirection.Vertical, 6).Parent = content

	local order = 0
	local function rule()
		order += 1
		Ui.new("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Theme.Color.inkSoft,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 34,
			Parent = content,
		})
	end
	local function line(text: string, font: Font, size: number, color: Color3)
		order += 1
		local label = Ui.text({
			Text = text,
			Font = font,
			TextSize = size,
			Color = color,
			LayoutOrder = order,
			Wrapped = true,
		})
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.ZIndex = 34
		label.Parent = content
	end

	line(title.text, Theme.Font.display, 34, title.color)
	line(title.line, Theme.Font.body, 16, Theme.Color.inkSoft)
	line(`Stations cleared: {data.stations or 0}`, Theme.Font.displayMedium, 18, Theme.Color.ink)
	rule()
	for _, entry in data.lines or {} do
		local label = tostring(entry.label)
		local amount = Format.signed(entry.amount)
		line(
			`{label} {string.rep(".", math.max(2, 34 - #label - #amount))} {amount}`,
			Theme.Font.type,
			16,
			if entry.amount < 0 then Theme.Color.signal else Theme.Color.ink
		)
	end
	rule()
	line(`BRASS EARNED   {Format.thousands(data.brass or 0)}`, Theme.Font.display, 26, Theme.Color.ink)
	line(`XP EARNED   {Format.thousands(data.xp or 0)}`, Theme.Font.displayMedium, 18, Theme.Color.inkSoft)
	if data.rankAfter and data.rankBefore and data.rankAfter > data.rankBefore then
		line(`PROMOTED TO CREW RANK {data.rankAfter}`, Theme.Font.display, 20, Theme.Color.go)
	end
	for _, name in data.milestones or {} do
		line(`LINE MASTERY: {string.upper(name)}`, Theme.Font.display, 18, Theme.Color.signal)
	end
	if data.saved == false then
		line(
			"Progress is not saved in this session (DataStores unavailable).",
			Theme.Font.body,
			13,
			Theme.Color.signal
		)
	end
	modal:open()
end

return Summary
