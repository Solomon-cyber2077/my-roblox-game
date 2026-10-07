--!strict
--[[
	Musical notes drifting up off the lobby piano while Gnossienne No. 3 plays.
	Each note is a BillboardGui of one glyph on the piano's hidden PianoVoice part
	(Builders/LobbyBuilder, tagged "PianoVoice"): it rises, sways, and fades out
	in gold, cream or amber. All local, nothing uploaded, nothing replicated.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Safe = require(ReplicatedStorage.Shared.Util.Safe)

local TAG = "PianoVoice"
local GLYPHS = { "♪", "♫", "♩", "♬" }
local COLORS = {
	Color3.fromRGB(232, 190, 92), -- gold
	Color3.fromRGB(240, 228, 196), -- cream
	Color3.fromRGB(226, 146, 62), -- amber
}
local INTERVAL = { 0.6, 1.3 } -- seconds between notes
local LIFE = { 3.2, 4.6 } -- seconds a note lives
local RISE = { 4, 6.5 } -- studs it climbs
local SWAY = 1.6 -- studs of drift to either side
local NEAR = 110 -- no notes when the camera is further than this

local PianoNotes = {}

local rng = Random.new()

local function between(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

local function emit(voice: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Note"
	gui.Size = UDim2.fromScale(1.8, 1.8)
	gui.LightInfluence = 0
	gui.MaxDistance = NEAR
	local start = Vector3.new(rng:NextNumber(-2.4, 2.4), 0, rng:NextNumber(-0.4, 0.4))
	gui.StudsOffsetWorldSpace = start
	gui.Adornee = voice

	local glyph = Instance.new("TextLabel")
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Font = Enum.Font.GothamBold
	glyph.TextScaled = true
	glyph.Text = GLYPHS[rng:NextInteger(1, #GLYPHS)]
	glyph.TextColor3 = COLORS[rng:NextInteger(1, #COLORS)]
	glyph.TextTransparency = 1
	glyph.Rotation = rng:NextNumber(-18, 18)
	glyph.Parent = gui
	gui.Parent = voice

	local life = between(LIFE)
	local drift = Vector3.new(rng:NextNumber(-SWAY, SWAY), between(RISE), rng:NextNumber(-SWAY, SWAY) * 0.5)
	TweenService:Create(
		gui,
		TweenInfo.new(life, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = start + drift }
	):Play()
	TweenService:Create(glyph, TweenInfo.new(life * 0.2), { TextTransparency = 0.1 }):Play()
	TweenService:Create(glyph, TweenInfo.new(life, Enum.EasingStyle.Sine), { Rotation = -glyph.Rotation })
		:Play()
	task.delay(life * 0.45, function()
		TweenService
			:Create(glyph, TweenInfo.new(life * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
			})
			:Play()
	end)
	task.delay(life, function()
		gui:Destroy()
	end)
end

local function play(voice: Instance)
	if not voice:IsA("BasePart") then
		return
	end
	task.spawn(function()
		while voice.Parent do
			task.wait(between(INTERVAL))
			Safe.call("PianoNotes", function()
				local camera = Workspace.CurrentCamera
				if voice.Parent and camera and (camera.CFrame.Position - voice.Position).Magnitude < NEAR then
					emit(voice)
				end
			end)
		end
	end)
end

function PianoNotes.Init() end

function PianoNotes.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(play)
	for _, voice in CollectionService:GetTagged(TAG) do
		play(voice)
	end
end

return PianoNotes
