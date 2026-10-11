--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.Settings)
local LogicSettings = require(Shared.Logic.Settings)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local Markers = {}
local player = Players.LocalPlayer
local root: Instance? = nil
local markerByPrompt: { [ProximityPrompt]: BillboardGui? } = {}
local watchers: { [ProximityPrompt]: { RBXScriptConnection } } = {}
local mounted = false

local function destroyMarker(prompt: ProximityPrompt)
	local marker = markerByPrompt[prompt]
	if marker then
		marker:Destroy()
		markerByPrompt[prompt] = nil
	end
end

local function visible(): boolean
	if player:GetAttribute("SettingsReady") ~= true then
		return false
	end
	return LogicSettings.markersVisible(
		player:GetAttribute("BrokenThingMarkers"),
		player:GetAttribute("RunsStarted")
	)
end

local function target(prompt: ProximityPrompt): boolean
	local action = prompt:GetAttribute("Action")
	return action == "Breach" or action == "Power"
end

local function remove(prompt: ProximityPrompt)
	destroyMarker(prompt)
	local connections = watchers[prompt]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		watchers[prompt] = nil
	end
end

local function refresh(prompt: ProximityPrompt)
	if
		not target(prompt)
		or not prompt.Enabled
		or prompt.Parent == nil
		or not prompt:IsDescendantOf(Workspace)
		or not visible()
	then
		destroyMarker(prompt)
		return
	end
	local parent = prompt.Parent
	local adornee = if parent:IsA("BasePart") or parent:IsA("Attachment") then parent else nil
	if adornee == nil then
		destroyMarker(prompt)
		return
	end
	local marker = markerByPrompt[prompt]
	if marker then
		marker.Adornee = adornee
		local plate = marker:FindFirstChildOfClass("Frame")
		local label = plate and plate:FindFirstChildOfClass("TextLabel")
		if label then
			label.Text = if prompt:GetAttribute("Action") == "Power" then "POWER" else "LEAK"
		end
		marker.Enabled = visible()
		return
	end
	local created = Instance.new("BillboardGui")
	created.Name = "BrokenThingMarker"
	created.Size = UDim2.fromOffset(Config.MarkerWidth, Config.MarkerHeight)
	created.MaxDistance = Config.MarkerMaxDistance
	created.StudsOffsetWorldSpace = Vector3.new(0, Config.MarkerOffset, 0)
	created.AlwaysOnTop = true
	created.Adornee = adornee
	created.Parent = root
	local plate = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.leather,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = created,
	})
	Ui.corner(2).Parent = plate
	Ui.stroke(Theme.Color.brass, 1, 0.1).Parent = plate
	local label = Ui.text({
		Text = if prompt:GetAttribute("Action") == "Power" then "POWER" else "LEAK",
		Font = Theme.Font.displayMedium,
		TextSize = 13,
		Color = Theme.Color.brassLight,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
	})
	label.ZIndex = 3
	label.Parent = plate
	markerByPrompt[prompt] = created
end

local function watch(prompt: ProximityPrompt)
	if watchers[prompt] then
		refresh(prompt)
		return
	end
	watchers[prompt] = {
		prompt:GetAttributeChangedSignal("Action"):Connect(function()
			refresh(prompt)
		end),
		prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			refresh(prompt)
		end),
		prompt.AncestryChanged:Connect(function()
			if not prompt:IsDescendantOf(Workspace) then
				remove(prompt)
			else
				refresh(prompt)
			end
		end),
	}
	refresh(prompt)
end

function Markers.mount(gui: ScreenGui)
	if mounted then
		return
	end
	mounted = true
	root = gui.Parent
	if root == nil then
		return
	end
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			watch(descendant)
		end
	end
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			watch(descendant)
		end
	end)
	for _, attribute in { "BrokenThingMarkers", "RunsStarted" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			for prompt in watchers do
				refresh(prompt)
			end
		end)
	end
end

return Markers
