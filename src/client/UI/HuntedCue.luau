--!strict
--[[
	The hunted cue (Tuning.HuntedCue, rules in Logic/HuntedCue). When a Hollow is hunting this player
	(State "Hunt", Target = our user id) from off-screen, a pair of pale eyes glints at the edge of the
	screen toward it, brighter as it closes in, with a slow pulse; it goes the moment the Hollow comes on
	screen or gives up. Phones only (the Compact layout): a small screen shows less around you, and that
	is where the bot playtests lost chases (`lune run phone-report`).

	The eyes are the rendered glint (Theme.Image.huntedEyes) once uploaded; until then two small pale
	lights stand in.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local HuntedCue = require(Shared.Logic.HuntedCue)

local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Cue = {}

local C = Tuning.HuntedCue
local PULSE_RATE = 1.6 -- glints a second at full strength, slower further off
local MIN_SHOW = 0.25 -- weakest visible strength (transparency 0.75)

function Cue.mount(gui: ScreenGui)
	if not C.Enabled then
		return
	end
	local me = Players.LocalPlayer.UserId

	local mark = Ui.new("Frame", {
		Name = "HuntedCue",
		Size = UDim2.fromOffset(C.Size, C.Size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	local glints: { GuiObject } = {}
	if Theme.Image.huntedEyes ~= "" then
		table.insert(
			glints,
			Ui.new("ImageLabel", {
				Name = "Eyes",
				Image = Theme.Image.huntedEyes,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 20,
				Parent = mark,
			})
		)
	else
		for _, x in { 0.36, 0.64 } do
			local eye = Ui.new("Frame", {
				Size = UDim2.fromOffset(9, 5),
				Position = UDim2.fromScale(x, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(220, 232, 245),
				BorderSizePixel = 0,
				ZIndex = 20,
				Parent = mark,
			})
			Ui.corner(3).Parent = eye
			table.insert(glints, eye)
		end
	end

	local function setAlpha(alpha: number)
		for _, g in glints do
			if g:IsA("ImageLabel") then
				g.ImageTransparency = 1 - alpha
			else
				g.BackgroundTransparency = 1 - alpha
			end
		end
	end

	local uiScale = gui:FindFirstChildOfClass("UIScale")
	local folder: Instance? = nil
	task.spawn(function()
		folder = Workspace:WaitForChild("Hollows", 60)
	end)

	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		local hollows = folder
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hollows == nil or root == nil or (C.CompactOnly and gui:GetAttribute("Compact") ~= true) then
			mark.Visible = false
			return
		end
		-- the nearest Hollow hunting us
		local best: BasePart? = nil
		local bestDistance = math.huge
		for _, model in hollows:GetChildren() do
			if model:GetAttribute("State") == "Hunt" and model:GetAttribute("Target") == me then
				local part = (model :: Model).PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
				if part then
					local d = (part.Position - root.Position).Magnitude
					if d < bestDistance then
						best, bestDistance = part, d
					end
				end
			end
		end
		local strength = if best then HuntedCue.strength(bestDistance) else 0
		if best == nil or strength <= 0 then
			mark.Visible = false
			return
		end
		local camera = Workspace.CurrentCamera
		local view = camera.ViewportSize
		local point, _ = camera:WorldToViewportPoint(best.Position)
		local placed = HuntedCue.place(point.X, point.Y, point.Z > 0, view.X, view.Y)
		if placed == nil then
			mark.Visible = false -- on screen: the player can see it
			return
		end
		mark.Visible = true
		-- the camera's viewport point into our gui's canvas: below the top inset, past the gui's own
		-- safe-area origin, and against our UIScale, so the eyes land on the screen's edge at full size
		local s = if uiScale and uiScale.Scale > 0 then uiScale.Scale else 1
		local inset = GuiService:GetGuiInset()
		local origin = gui.AbsolutePosition
		mark.Position =
			UDim2.fromOffset((placed.x - inset.X - origin.X) / s, (placed.y - inset.Y - origin.Y) / s)
		mark.Size = UDim2.fromOffset(C.Size / s, C.Size / s)
		local pulse = 0.75 + 0.25 * math.sin(clock * math.pi * 2 * PULSE_RATE * (0.5 + strength * 0.5))
		setAlpha(math.max(strength, MIN_SHOW) * pulse)
	end)
end

return Cue
