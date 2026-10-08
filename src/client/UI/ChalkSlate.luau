--!strict
--[[
	Chalk slates hung under the crew saloon's nameboards: the crew's notes on the run written on
	the train instead of the screen. Where the train is bound and how bad it is, the stop it is
	standing at, and what is wrong aboard (the firebox out, steam leaks, coal short of the leg).
	Built on this client only, on the static train; nothing here replicates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)
local Theme = require(script.Parent.Theme)

local ChalkSlate = {}

local SLATE = Color3.fromRGB(40, 44, 42)
local WOOD = Color3.fromRGB(96, 62, 38)
local CHALK = Color3.fromRGB(232, 230, 220)
local CHALK_RED = Color3.fromRGB(236, 128, 110)
local SLATE_SIZE = Vector3.new(0.16, 1.3, 3.2)
local HANG = 0.15 -- the gap between the nameboard and the slate, on short chains
local PIXELS = 100 -- SurfaceGui pixels per stud

type Lines = { title: TextLabel, detail: TextLabel, note: TextLabel }

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function chalk(
	gui: SurfaceGui,
	y: number,
	height: number,
	color: Color3,
	transparency: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(18, y)
	label.Size = UDim2.new(1, -36, 0, height)
	label.FontFace = Theme.Font.chalk
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.TextTransparency = transparency
	label.Text = ""
	label.Parent = gui
	return label
end

-- One face of a slate: last stop's half-rubbed-out notes under today's, a chalk rule under the title.
local function face(slate: BasePart, normal: Enum.NormalId): Lines
	local gui = Instance.new("SurfaceGui")
	gui.Face = normal
	gui.CanvasSize = Vector2.new(SLATE_SIZE.Z * PIXELS, SLATE_SIZE.Y * PIXELS)
	gui.LightInfluence = 1
	gui.Parent = slate
	local ghost = chalk(gui, 30, 70, CHALK, 0.95)
	ghost.Text = "coal  coal  COAL"
	ghost.Rotation = -4
	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = CHALK
	rule.BackgroundTransparency = 0.35
	rule.BorderSizePixel = 0
	rule.Position = UDim2.fromOffset(18, 50)
	rule.Size = UDim2.fromOffset(170, 2)
	rule.Rotation = -1
	rule.Parent = gui
	return {
		title = chalk(gui, 8, 40, CHALK, 0.05),
		detail = chalk(gui, 56, 30, CHALK, 0.15),
		note = chalk(gui, 90, 30, CHALK_RED, 0.1),
	}
end

local function marks(tier: number): string
	return string.rep("X ", tier) .. string.rep("_ ", 3 - tier)
end

local function write(all: { Lines })
	local State = Registry.StateController
	local run = State.Get({ "run" }) or {}
	local train = State.Get({ "train" }) or {}
	local phase = run.phase or ""
	local station = run.station
	local destination = run.destination
	local stopCount = run.stopCount or Tuning.Run.StationCount
	local title, detail, note = "", "", ""
	if phase == "Boarding" then
		title, detail = "All aboard", `{stopCount} stops to the Terminus`
	elseif phase == "Terminus" then
		title, detail = "Terminus", "end of the line"
	elseif phase == "Junction" and destination == nil then
		title, detail = "Junction ahead", "vote a line. mind the danger"
	elseif (phase == "Cruise" or phase == "Junction") and destination then
		title = `Next: {destination.name}`
		detail = if destination.terminus
			then "the Terminus. hold on"
			elseif destination.sealed then `{destination.distanceKm} km   danger unknown`
			else `{destination.distanceKm} km   danger {marks(destination.tier)}`
	elseif station then
		title = station.name
		detail = `stop {math.min(run.nextStop or 1, stopCount)}/{stopCount}   danger {marks(station.tier)}`
	end
	local leaks = 0
	for _ in train.breaches or {} do
		leaks += 1
	end
	if train.starving then
		note = "FIRE'S OUT! coal in, now"
	elseif leaks > 0 then
		note = `{leaks} leak{if leaks > 1 then "s" else ""}! patch with parts`
	elseif destination and phase == "Cruise" and train.coal and train.coal < destination.coalCost then
		note = "coal won't last the leg"
	end
	for _, lines in all do
		lines.title.Text = title
		lines.detail.Text = detail
		lines.note.Text = note
	end
end

-- The board's lettering, once it has streamed in with it.
local function boardText(board: BasePart): string?
	local gui = board:WaitForChild("SurfaceGui", 10)
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	return label and label.Text
end

-- Hangs a slate under each of the saloon's nameboards as they stream in, and keeps them
-- written up.
function ChalkSlate.hang(train: Model)
	local folder = Instance.new("Folder")
	folder.Name = "ChalkSlates"
	folder.Parent = Workspace
	local all: { Lines } = {}
	local hung: { [string]: boolean } = {}
	local function consider(board: Instance)
		if not board:IsA("BasePart") or board.Name ~= "Nameboard" then
			return
		end
		task.spawn(function()
			local key = tostring(board.Position)
			if hung[key] or boardText(board) ~= "CREW SALOON" then
				return
			end
			hung[key] = true
			local drop = board.Size.Y / 2 + HANG + SLATE_SIZE.Y / 2
			local cf = board.CFrame * CFrame.new(0, -drop, 0)
			local slate = part("Slate", SLATE_SIZE, cf, SLATE, Enum.Material.Slate, folder)
			-- the wooden frame shows only round the edge: the slate stands proud of it on both sides
			part(
				"SlateFrame",
				Vector3.new(0.1, SLATE_SIZE.Y + 0.12, SLATE_SIZE.Z + 0.12),
				cf,
				WOOD,
				Enum.Material.Wood,
				folder
			)
			for _, z in { -1.3, 1.3 } do
				local chainLength = HANG + 0.12
				part(
					"SlateChain",
					Vector3.new(0.04, chainLength, 0.04),
					board.CFrame * CFrame.new(0, -(board.Size.Y / 2 + chainLength / 2), z),
					Theme.Color.brass,
					Enum.Material.Metal,
					folder
				)
			end
			table.insert(all, face(slate, Enum.NormalId.Right))
			table.insert(all, face(slate, Enum.NormalId.Left))
			write(all)
		end)
	end
	for _, d in train:GetDescendants() do
		consider(d)
	end
	train.DescendantAdded:Connect(consider)
	local State = Registry.StateController
	State.Observe("public", { "run" }, function()
		write(all)
	end)
	State.Observe("public", { "train" }, function()
		write(all)
	end)
end

return ChalkSlate
