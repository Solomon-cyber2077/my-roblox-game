--!strict
--[[
	The leak alert, with Broken Things Markers on (UI/BrokenThingMarkers.visible): a plate in the
	HUD's leak slot (UI/Hud: it yields to every modal and full-screen UI and never draws over
	anything) naming the nearest leak's car and distance, a small red "!" at every leak (seen
	from anywhere aboard, and from outside the train only when you are near it; the Last
	Light's too). Both come from
	the leak objects (anchors TrainService tags Leak), so the moment the last leak is patched
	they are gone. When the Last Light starts leaking, a line fades in and out at the top of
	the screen.

	With markers off there is neither: the leaks' own steam and hiss carry it, stronger
	(TrainVisualsController), along with the hull's effects (HullController).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local LeakAlert = require(Shared.Logic.LeakAlert)
local Tuning = require(Shared.Config.Tuning)
local Safe = require(Shared.Util.Safe)

local Session = require(script.Parent.Parent.Session)
local BrokenThingMarkers = require(script.Parent.Parent.UI.BrokenThingMarkers)
local Hud = require(script.Parent.Parent.UI.Hud)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)

local LeakController = {}

local TAG = "Leak"
local A = Tuning.LeakArrows
local MARK_NEAR = 20 -- off the train, a leak's "!" shows only this close (studs)

local marks: { [BasePart]: BillboardGui } = {}

local plate: Frame? = nil
local label: TextLabel? = nil
local notice: TextLabel? = nil
local noticeAt = -math.huge -- os.clock() the Last Light notice started

local function buildPlate(slot: Frame)
	local panel = Ui.new("Frame", {
		Name = "LeakAlert",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.leather,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = slot,
	})
	Ui.corner(4).Parent = panel
	Ui.stroke(Theme.Color.signal, 2, 0.05).Parent = panel
	local text = Ui.text({
		Text = "",
		Font = Theme.Font.displayMedium,
		TextSize = 14,
		Color = Theme.Color.white,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
	})
	text.TextScaled = false
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.Parent = panel
	plate = panel
	label = text
end

-- A small red exclamation mark at the leak: a painted "!" with a soot outline, no plate.
local function buildMark(anchor: BasePart): BillboardGui
	local mark = Instance.new("BillboardGui")
	mark.Name = "LeakMark"
	mark.Size = UDim2.fromOffset(24, 44)
	mark.AlwaysOnTop = true
	mark.LightInfluence = 0
	mark.Adornee = anchor
	mark.Enabled = false
	local text = Ui.text({
		Text = "!",
		Font = Theme.Font.display,
		TextSize = 42,
		Color = Theme.Color.dangerText,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
	})
	text.TextStrokeColor3 = Theme.Color.ink
	text.TextStrokeTransparency = 0
	text.Parent = mark
	mark.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	return mark
end

local function updateMarks(show: boolean, root: BasePart?)
	local aboard = Session.status() == "Aboard"
	for anchor, mark in marks do
		if not anchor:HasTag(TAG) or not anchor:IsDescendantOf(Workspace) then
			mark:Destroy()
			marks[anchor] = nil
		end
	end
	for _, anchor in CollectionService:GetTagged(TAG) do
		if anchor:IsA("BasePart") and anchor:IsDescendantOf(Workspace) then
			local mark = marks[anchor] or buildMark(anchor)
			marks[anchor] = mark
			local near = root ~= nil and (root.Position - anchor.Position).Magnitude <= MARK_NEAR
			mark.Enabled = show and (aboard or near)
		end
	end
end

local function leaks(): { LeakAlert.Leak }
	local out: { LeakAlert.Leak } = {}
	for _, part in CollectionService:GetTagged(TAG) do
		if part:IsA("BasePart") and part:IsDescendantOf(Workspace) then
			local p = part.Position
			table.insert(out, {
				id = (part:GetAttribute("LeakId") :: string?) or part.Name,
				anchor = part:GetAttribute("BreachAnchor") :: string?,
				x = p.X,
				y = p.Y,
				z = p.Z,
			})
		end
	end
	return out
end

local function buildNotice(slot: Frame)
	local text = Ui.text({
		Name = "LastLightLeak",
		Text = A.NoticeText,
		Font = Theme.Font.displayMedium,
		TextSize = 24,
		Color = Theme.Color.brassLight,
		Position = UDim2.new(0.5, 0, 0, 58),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(520, 30),
		XAlign = Enum.TextXAlignment.Center,
		Transparency = 1,
	})
	text.TextStrokeColor3 = Theme.Color.ink
	text.TextStrokeTransparency = 1
	text.Visible = false
	text.Parent = slot:FindFirstAncestorOfClass("ScreenGui")
	notice = text
end

-- 0 fully shown, 1 gone
local function noticeFade(): number
	local t = os.clock() - noticeAt
	if t < 0 or t > A.NoticeIn + A.NoticeHold + A.NoticeOut then
		return 1
	elseif t < A.NoticeIn then
		return 1 - t / A.NoticeIn
	elseif t < A.NoticeIn + A.NoticeHold then
		return 0
	end
	return (t - A.NoticeIn - A.NoticeHold) / A.NoticeOut
end

local function updateNotice(on: boolean, slot: Frame?)
	local text = notice
	if text == nil then
		return
	end
	local fade = noticeFade()
	-- it yields like the leak slot: never over a modal or a full-screen screen
	local visible = on and fade < 1 and slot ~= nil and slot.Visible
	text.Visible = visible
	if visible then
		text.TextTransparency = fade
		text.TextStrokeTransparency = 0.3 + 0.7 * fade
	end
end

local function step()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local me = if root then { x = root.Position.X, y = root.Position.Y, z = root.Position.Z } else nil
	local show = Session.isRunActive() and Session.isMember() and Session.isAlive()
	local markersOn = BrokenThingMarkers.visible()
	-- the marks in the world hide while the train camera looks out
	local inWorld = markersOn and not BrokenThingMarkers.suppressed()
	local view = if show then LeakAlert.view(leaks(), me, markersOn) else nil
	updateMarks(show and inWorld, root)
	if plate and label then
		plate.Visible = view ~= nil
		if view then
			label.Text = view.text
		end
	end
	updateNotice(show and markersOn, Hud.leakSlot())
end

function LeakController.Init() end

function LeakController.Start()
	local slot = Hud.leakSlot()
	if slot then
		buildPlate(slot)
		buildNotice(slot)
	else
		warn("LeakController: the HUD has no leak slot")
	end
	RunService.RenderStepped:Connect(function()
		Safe.call("LeakController.step", step)
	end)
	-- the Last Light starts leaking: its notice (step hides it with markers off)
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(anchor)
		if anchor:GetAttribute("BreachAnchor") == A.CabAnchor then
			noticeAt = os.clock()
		end
	end)
	-- the last leak patched: gone this frame, not the next
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function()
		Safe.call("LeakController.step", step)
	end)
end

return LeakController
