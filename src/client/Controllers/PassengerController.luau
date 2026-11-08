--!strict
--[[
	The Depot's passive people on this client (Services/PassengerService builds and moves them;
	CharacterAnimator plays their bodies):

	  * what they say: when a rig's SayAt changes and your character is within Bubble.hear, a
	    small card of smoked paper floats over its head for Bubble.seconds
	  * the Performance setting: the ones not marked PerformanceKeep are hidden on this client and
	    stop colliding with your character, so a phone draws and steps half as many
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Passengers = require(ReplicatedStorage.Shared.Config.Passengers)
local Theme = require(script.Parent.Parent.UI.Theme)

local PassengerController = {}

local TAG = "Passenger"
local SETTING = "GraphicsQuality"
local B = Passengers.Bubble

local collide: { [BasePart]: boolean } = {} -- each part's own CanCollide, kept while hidden

local function hidden(rig: Model): boolean
	return Players.LocalPlayer:GetAttribute(SETTING) == "Performance"
		and rig:GetAttribute("PerformanceKeep") ~= true
end

local function applyTier(rig: Model)
	local hide = hidden(rig)
	for _, part in rig:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = if hide then 1 else 0
			if collide[part] == nil then
				collide[part] = part.CanCollide
			end
			part.CanCollide = (collide[part] :: boolean) and not hide
		end
	end
end

local function bubble(rig: Model)
	local text = rig:GetAttribute("Say") :: string?
	local head = rig:FindFirstChild("Head") :: BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if text == nil or head == nil or root == nil or hidden(rig) then
		return
	end
	if (root.Position - head.Position).Magnitude > B.hear then
		return
	end
	local old = head:FindFirstChild("SpeechBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpeechBubble"
	gui.Size = UDim2.fromOffset(250, 84)
	gui.StudsOffset = Vector3.new(0, 3.1, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = B.hear + 6
	gui.Adornee = head
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.fromScale(0.5, 1)
	card.Size = UDim2.fromScale(1, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Theme.Color.paper
	card.BorderSizePixel = 0
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = card
	local rim = Instance.new("UIStroke")
	rim.Color = Theme.Color.paperShade
	rim.Thickness = 1.5
	rim.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 7)
	pad.PaddingLeft = UDim.new(0, 9)
	pad.PaddingRight = UDim.new(0, 9)
	pad.Parent = card
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.FontFace = Theme.Font.body
	label.TextSize = 15
	label.TextWrapped = true
	label.TextColor3 = Theme.Color.ink
	label.Text = text
	label.Parent = card
	gui.Parent = head
	task.delay(B.seconds, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function watch(rig: Instance)
	if not rig:IsA("Model") then
		return
	end
	applyTier(rig)
	rig.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			applyTier(rig)
		end
	end)
	rig:GetAttributeChangedSignal("SayAt"):Connect(function()
		bubble(rig)
	end)
end

function PassengerController.Init() end

function PassengerController.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
	for _, rig in CollectionService:GetTagged(TAG) do
		watch(rig)
	end
	Players.LocalPlayer:GetAttributeChangedSignal(SETTING):Connect(function()
		for _, rig in CollectionService:GetTagged(TAG) do
			if rig:IsA("Model") then
				applyTier(rig)
			end
		end
	end)
end

return PassengerController
