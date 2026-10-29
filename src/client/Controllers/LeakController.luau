--!strict
--[[
	The leak alert, with Broken Things Markers on (UI/BrokenThingMarkers.visible): a plate in the
	HUD's leak slot (UI/Hud: it yields to every modal and full-screen UI and never draws over
	anything) naming the nearest leak's car and distance, a small red "!" at every leak (seen
	from anywhere aboard, and from outside the train only when you are near it; the Last
	Light's too), and a low trail of steam drifting along the floor (Logic/LeakRoute): aboard, down the
	aisle car to car to the nearest leak and curving to the wall at it; on the platform while
	the train stands at a station, to the Last Light's door when it is leaking. All come from
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
local LeakRoute = require(Shared.Logic.LeakRoute)
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
local mistFolder: Folder? = nil
type Wisp = {
	part: BasePart,
	gui: BillboardGui,
	puffs: { { frame: Frame, transparency: number } },
	phase: number,
}
local wisps: { Wisp } = {}

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

-- A wisp of the leak's steam drifting low along the floor toward it: a few soft, overlapping
-- puffs facing the camera, pale grey and lit by the car's lamps (never glowing), each wisp
-- breathing and lifting a little on its own rhythm so the trail reads as mist, not markers.
local MIST = Color3.fromRGB(214, 218, 222)
local PUFFS = { -- offset (studs, x up), diameter (studs), opacity
	{ x = 0, y = 0, d = 1.5, a = 0.16 },
	{ x = -0.45, y = 0.1, d = 1.0, a = 0.14 },
	{ x = 0.5, y = 0.15, d = 1.1, a = 0.12 },
	{ x = 0.1, y = 0.35, d = 0.7, a = 0.1 },
}

local function wisp(seed: number): Wisp
	local part = Instance.new("Part")
	part.Name = "LeakMist"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(2.4, 1.4) -- studs
	gui.LightInfluence = 1
	gui.Brightness = 1
	gui.Adornee = part
	gui.Parent = part
	local rng = Random.new(seed)
	local puffs = {}
	for _, spec in PUFFS do
		-- each puff is two rounds, a faint wide one under a denser core, so the edge is soft
		for _, layer in { { scale = 1, a = spec.a * 0.5 }, { scale = 0.6, a = spec.a } } do
			local puff = Instance.new("Frame")
			local d = spec.d * layer.scale * rng:NextNumber(0.85, 1.15)
			puff.AnchorPoint = Vector2.new(0.5, 0.5)
			puff.Position = UDim2.fromScale(0.5 + spec.x / 2.4, 0.62 - spec.y / 1.4)
			puff.Size = UDim2.fromScale(d / 2.4, d / 1.4)
			puff.BackgroundColor3 = MIST
			puff.BorderSizePixel = 0
			puff.Parent = gui
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = puff
			table.insert(puffs, { frame = puff, transparency = 1 - layer.a })
		end
	end
	return { part = part, gui = gui, puffs = puffs, phase = rng:NextNumber(0, math.pi * 2) }
end

local function buildMist()
	local folder = Instance.new("Folder")
	folder.Name = "LeakMist"
	for index = 1, A.Count do
		local made = wisp(index)
		made.part.Parent = folder
		table.insert(wisps, made)
	end
	folder.Parent = nil
	mistFolder = folder
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

-- The path the mist follows now, in train-local studs, and the train's frame; nil for none.
local function route(root: BasePart): ({ LeakRoute.Point }?, CFrame?, Model?)
	local train: Model? = nil
	local origin: CFrame? = nil
	local here: Vector3 = Vector3.zero
	local best: Vector3? = nil
	local cabLeak = false
	for _, anchor in CollectionService:GetTagged(TAG) do
		if anchor:IsA("BasePart") and anchor:IsDescendantOf(Workspace) then
			if origin == nil then
				train = anchor:FindFirstAncestorOfClass("Model")
				local value = train and train:GetAttribute("Origin")
				if typeof(value) ~= "CFrame" then
					return nil
				end
				origin = value
				here = value:PointToObjectSpace(root.Position)
			end
			local at = (origin :: CFrame):PointToObjectSpace(anchor.Position)
			if anchor:GetAttribute("BreachAnchor") == A.CabAnchor then
				cabLeak = true
			elseif best == nil or math.abs(at.X - here.X) < math.abs(best.X - here.X) then
				best = at
			end
		end
	end
	if origin == nil then
		return nil
	end
	local from = { x = here.X, z = here.Z }
	local aboard = Session.status() == "Aboard"
	local phase = Session.phase()
	local docked = phase == "Dwell" or phase == "LastCall"
	-- inside the Last Light itself there is nowhere further to lead
	local inCab = math.abs(here.X - A.CabDoorX) < 7 and math.abs(here.Z) < A.CabDoorZ
	if aboard and best and not inCab then
		return LeakRoute.inside(from, { x = best.X, z = best.Z }), origin, train
	elseif not aboard and docked and cabLeak then
		local dx, dz = here.X - A.CabDoorX, here.Z - A.CabDoorZ
		if math.sqrt(dx * dx + dz * dz) <= A.PlatformReach then
			return LeakRoute.platform(from), origin, train
		end
	end
	return nil
end

local FEET = 3 -- an R6 root stands this far over the floor
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateMist(on: boolean, root: BasePart?)
	local folder = mistFolder
	if folder == nil then
		return
	end
	local path, origin = nil, nil
	if on and root then
		path, origin = route(root)
	end
	if path == nil or origin == nil or root == nil then
		folder.Parent = nil
		return
	end
	local now = os.clock()
	local placed = LeakRoute.place(path, now * A.Scroll)
	rayParams.FilterDescendantsInstances = { folder, root.Parent :: Instance }
	local rootY = origin:PointToObjectSpace(root.Position).Y
	for index = 1, A.Count do
		local spot = placed[index]
		local made = wisps[index]
		made.gui.Enabled = spot ~= nil
		if spot then
			-- hugging whatever floor is under it: carriage boards or the platform
			-- (never on a seat or a crate: anything above your feet is passed under)
			local feet = origin * Vector3.new(spot.x, rootY - FEET, spot.z)
			local hit = Workspace:Raycast(feet + origin.UpVector * 0.5, -origin.UpVector * 6, rayParams)
			local t = now * 1.3 + made.phase
			local lift = 0.35 + 0.12 * math.sin(t)
			made.part.Position = (if hit then hit.Position else feet) + origin.UpVector * lift
			made.gui.Size = UDim2.fromScale(2.4 * (1 + 0.08 * math.sin(t * 0.7)), 1.4)
			-- thin near your feet and far ahead, thickest a few studs on
			local u = (index - 1) / A.Count
			local fade = math.clamp(1 - index / 3, 0, 1) * 0.6 + 0.7 * u
			for _, puff in made.puffs do
				puff.frame.BackgroundTransparency = 1 - (1 - puff.transparency) * (1 - math.min(fade, 1))
			end
		end
	end
	folder.Parent = Workspace.CurrentCamera
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
	-- the marks and mist in the world hide while the train camera looks out
	local inWorld = markersOn and not BrokenThingMarkers.suppressed()
	local view = if show then LeakAlert.view(leaks(), me, markersOn) else nil
	updateMarks(show and inWorld, root)
	if plate and label then
		plate.Visible = view ~= nil
		if view then
			label.Text = view.text
		end
	end
	updateMist(view ~= nil and inWorld, root)
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
	buildMist()
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
