--!strict
--[[
	The leak alert, with Broken Things Markers on (UI/BrokenThingMarkers.visible): a plate in the
	HUD's leak slot (UI/Hud: it yields to every modal and full-screen UI and never draws over
	anything) naming the nearest leak's car and distance, a world arrow over your head
	pointing to it with the distance, and a small red "!" at every leak (seen from anywhere
	aboard, and from outside the train only when you are near it; the Last Light's too). All come
	from the leak objects (anchors TrainService tags Leak) through Logic/LeakAlert, so the
	moment the last leak is patched they are gone.

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
local Safe = require(Shared.Util.Safe)

local Session = require(script.Parent.Parent.Session)
local BrokenThingMarkers = require(script.Parent.Parent.UI.BrokenThingMarkers)
local Hud = require(script.Parent.Parent.UI.Hud)
local Theme = require(script.Parent.Parent.UI.Theme)
local Ui = require(script.Parent.Parent.UI.Ui)

local LeakController = {}

local TAG = "Leak"
local ARROW_HEIGHT = 4.2 -- studs over your root
local ARROW_NEAR = 7 -- closer than this to the leak, the arrow is not needed
local MARK_NEAR = 20 -- off the train, a leak's "!" shows only this close (studs)

local marks: { [BasePart]: BillboardGui } = {}

local plate: Frame? = nil
local label: TextLabel? = nil
local arrow: Model? = nil
local arrowText: TextLabel? = nil

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

local function piece(model: Model, size: Vector3, offset: CFrame): BasePart
	local part = Instance.new("Part")
	part.Size = size
	part.Color = Theme.Color.caution
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part:SetAttribute("Offset", offset)
	part.Parent = model
	return part
end

-- A chevron arrow (pointing along its -Z) with a distance tag, local to this client.
local function buildArrow()
	local model = Instance.new("Model")
	model.Name = "LeakArrow"
	piece(model, Vector3.new(0.3, 0.3, 1.8), CFrame.new(0, 0, 0.5))
	piece(model, Vector3.new(0.3, 0.3, 1.1), CFrame.new(0.32, 0, -0.55) * CFrame.Angles(0, math.rad(-40), 0))
	piece(model, Vector3.new(0.3, 0.3, 1.1), CFrame.new(-0.32, 0, -0.55) * CFrame.Angles(0, math.rad(40), 0))
	local anchor = piece(model, Vector3.new(0.1, 0.1, 0.1), CFrame.new())
	anchor.Transparency = 1
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(70, 22)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 0.9, 0)
	tag.AlwaysOnTop = true
	tag.Adornee = anchor
	tag.Parent = model
	local text = Ui.text({
		Text = "",
		Font = Theme.Font.displayMedium,
		TextSize = 14,
		Color = Theme.Color.caution,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
	})
	text.TextStrokeTransparency = 0.4
	text.Parent = tag
	model.Parent = nil
	arrow = model
	arrowText = text
end

local function placeArrow(model: Model, at: Vector3, toward: Vector3)
	local flat = Vector3.new(toward.X - at.X, 0, toward.Z - at.Z)
	local look = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	local base = CFrame.lookAt(at, at + look)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.CFrame = base * ((part:GetAttribute("Offset") :: CFrame?) or CFrame.new())
		end
	end
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

local function step()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local me = if root then { x = root.Position.X, y = root.Position.Y, z = root.Position.Z } else nil
	local show = Session.isRunActive() and Session.isMember() and Session.isAlive()
	local markersOn = BrokenThingMarkers.visible()
	local view = if show then LeakAlert.view(leaks(), me, markersOn) else nil
	updateMarks(show and markersOn, root)
	if plate and label then
		plate.Visible = view ~= nil
		if view then
			label.Text = view.text
		end
	end
	local model = arrow
	if model then
		if view and root and view.distance > ARROW_NEAR then
			local target = Vector3.new(view.nearest.x, view.nearest.y, view.nearest.z)
			placeArrow(model, root.Position + Vector3.yAxis * ARROW_HEIGHT, target)
			if arrowText then
				arrowText.Text = `{view.metres} m`
			end
			model.Parent = Workspace.CurrentCamera
		else
			model.Parent = nil
		end
	end
end

function LeakController.Init() end

function LeakController.Start()
	local slot = Hud.leakSlot()
	if slot then
		buildPlate(slot)
	else
		warn("LeakController: the HUD has no leak slot")
	end
	buildArrow()
	RunService.RenderStepped:Connect(function()
		Safe.call("LeakController.step", step)
	end)
	-- the last leak patched: gone this frame, not the next
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function()
		Safe.call("LeakController.step", step)
	end)
end

return LeakController
