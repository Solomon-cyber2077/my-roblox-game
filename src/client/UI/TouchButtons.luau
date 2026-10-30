--!strict
--[[
	Lays the touch buttons out around Roblox's own jump button (rules in Logic/TouchCluster; checked on real
	screens by `lune run layout`): RUN, LOOK and PING (ContextActionService buttons) at a thumb-sized 60 units,
	and the spot the contextal action button (UI/ActionButton) and the cash-out card (UI/CashOut) read.
	Everything is in screen units (AbsolutePosition), so our UI's scale and the safe area cannot move a
	button onto another.

	  layout()   the cluster's rectangles in AbsolutePosition space
	  apply()    sizes and places RUN, LOOK and PING; Hud calls it whenever the touch controls change
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TouchCluster = require(ReplicatedStorage.Shared.Logic.TouchCluster)

local TouchButtons = {}

local CAS = { run = "LTO_Sprint", look = "LTO_Glance", ping = "LTO_Ping" }

-- Roblox's jump button where it really is, or where its rules put it before it exists.
local function jumpRect(): TouchCluster.Rect
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local touch = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touch and touch:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if jump and jump:IsA("GuiObject") and jump.AbsoluteSize.X > 0 then
		local p, s = jump.AbsolutePosition, jump.AbsoluteSize
		return { x = p.X, y = p.Y, w = s.X, h = s.Y }
	end
	local view = Workspace.CurrentCamera.ViewportSize
	local inset = GuiService:GetGuiInset()
	-- AbsolutePosition space starts below the top inset
	return TouchCluster.jump(view.X, view.Y - inset.Y)
end

function TouchButtons.layout(): TouchCluster.Cluster
	return TouchCluster.place(jumpRect())
end

function TouchButtons.apply()
	local cluster = TouchButtons.layout()
	for key, action in CAS do
		-- not bound yet (the HUD places the watch before PING is bound): asking for its button would warn
		if next(ContextActionService:GetBoundActionInfo(action)) == nil then
			continue
		end
		local button = ContextActionService:GetButton(action)
		local parent = button and button.Parent
		if button and parent and parent:IsA("GuiObject") and parent.AbsoluteSize.X > 0 then
			local r = (cluster :: any)[key] :: TouchCluster.Rect
			button.AnchorPoint = Vector2.zero
			button.Size = UDim2.fromOffset(r.w, r.h)
			button.Position =
				UDim2.fromOffset(r.x - parent.AbsolutePosition.X, r.y - parent.AbsolutePosition.Y)
		end
	end
end

return TouchButtons
