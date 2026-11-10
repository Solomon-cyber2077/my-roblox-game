--!strict
--[[
	The first thing a player sees: a plain dark screen, a moving bar and one tip, in place of Roblox's
	loader, until the state, character, camera and nearby hall are ready. It runs
	before ReplicatedStorage has arrived, so it can't require Theme: the colours and fonts are copied here.
]]

local began = os.clock()
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local MAX_WAIT = 30
local FADE = 0.4
local INK = Color3.fromRGB(16, 13, 10)
local BONE = Color3.fromRGB(232, 211, 168)
local BRASS = Color3.fromRGB(176, 136, 72)
local TIPS = {
	"Stay with your crew. Alone, nobody can pull you free.",
	"The train leaves on time, with or without you.",
	"Keep your lantern lit and watch the edge of the light.",
}

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000

local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = INK
back.BorderSizePixel = 0
back.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.new(0.5, 0, 0.5, -44)
title.Size = UDim2.new(0.9, 0, 0, 44)
title.BackgroundTransparency = 1
title.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
title.Text = "LOADING"
title.TextColor3 = BONE
title.TextSize = 36
title.Parent = back

local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.5)
track.Size = UDim2.fromOffset(240, 6)
track.BackgroundColor3 = BRASS
track.BackgroundTransparency = 0.75
track.BorderSizePixel = 0
track.ClipsDescendants = true
track.Parent = back

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(1, 0)
bar.Position = UDim2.fromScale(0, 0)
bar.Size = UDim2.fromScale(0.35, 1)
bar.BackgroundColor3 = BRASS
bar.BorderSizePixel = 0
bar.Parent = track

local tip = Instance.new("TextLabel")
tip.AnchorPoint = Vector2.new(0.5, 0)
tip.Position = UDim2.new(0.5, 0, 0.5, 26)
tip.Size = UDim2.new(0.8, 0, 0, 52)
tip.BackgroundTransparency = 1
tip.FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular)
tip.Text = TIPS[math.random(#TIPS)]
tip.TextColor3 = BONE
tip.TextSize = 18
tip.TextWrapped = true
tip.TextYAlignment = Enum.TextYAlignment.Top
tip.Parent = back

gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local sweep = TweenService:Create(
	bar,
	TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1),
	{ Position = UDim2.fromScale(1.35, 0) }
)
sweep:Play()

local warned = false
while player:GetAttribute("ClientPlayable") ~= true do
	if not warned and os.clock() - began >= MAX_WAIT then
		warned = true
		warn("[LoadingScreen] playable readiness exceeded 30 s; still waiting")
		tip.Text = "The hall is taking longer to arrive. Still connecting…"
	end
	task.wait(0.1)
end

local fade = TweenInfo.new(FADE)
TweenService:Create(back, fade, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, fade, { TextTransparency = 1 }):Play()
TweenService:Create(tip, fade, { TextTransparency = 1 }):Play()
TweenService:Create(track, fade, { BackgroundTransparency = 1 }):Play()
TweenService:Create(bar, fade, { BackgroundTransparency = 1 }):Play()
task.wait(FADE)
sweep:Cancel()
gui:Destroy()

-- Starts at this script, excluding the launcher and any earlier connection/download time.
print(string.format("[LoadingScreen] playable world %.1f s since ReplicatedFirst", os.clock() - began))
