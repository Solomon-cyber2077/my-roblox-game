--[[
	Touch layout dump, for `lune run layout --dump=<file>`: run in Studio's command bar on the CLIENT while
	playing in the Device Emulator (one device at a time, landscape). It prints one JSON line with the real
	rectangles (AbsolutePosition / AbsoluteSize) of Roblox's jump button, our RUN / LOOK / PING buttons, the
	action button, and the screen facts the layout check assumes (viewport, top inset, UI scale, Compact).
	Save the line to a file named after the device id in .lune/lib/TouchLayout (e.g. iPhoneSE.json).
	Walk up to a crate first so the action button is showing.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local function rect(obj: Instance?): { number }?
	if obj and obj:IsA("GuiObject") and obj.AbsoluteSize.X > 0 then
		local p, s = obj.AbsolutePosition, obj.AbsoluteSize
		return { p.X, p.Y, s.X, s.Y }
	end
	return nil
end

local touch = playerGui:FindFirstChild("TouchGui")
local frame = touch and touch:FindFirstChild("TouchControlFrame")
local ours = playerGui:FindFirstChild("LastTrainOut") :: ScreenGui?
local scale = ours and ours:FindFirstChildOfClass("UIScale")
local view = workspace.CurrentCamera.ViewportSize
local inset = GuiService:GetGuiInset()

local out = {
	viewport = { view.X, view.Y },
	inset = { inset.X, inset.Y },
	uiScale = if scale then scale.Scale else nil,
	compact = if ours then ours:GetAttribute("Compact") else nil,
	guiOrigin = if ours then { ours.AbsolutePosition.X, ours.AbsolutePosition.Y } else nil,
	jump = rect(frame and frame:FindFirstChild("JumpButton")),
	run = rect(ContextActionService:GetButton("LTO_Sprint")),
	look = rect(ContextActionService:GetButton("LTO_Glance")),
	ping = rect(ContextActionService:GetButton("LTO_Ping")),
	action = rect(ours and ours:FindFirstChild("ActionButton")),
}
print(HttpService:JSONEncode(out))
