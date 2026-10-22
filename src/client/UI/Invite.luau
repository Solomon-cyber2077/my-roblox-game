--!strict
--[[
	INVITE (Prompt 10): Roblox's game-invite prompt for the Depot panel (UI/Lobby) and the run card
	(UI/RunCard). The button shows only when SocialService:CanSendGameInviteAsync says this player
	may invite (privacy settings, account limits); a press opens the prompt and tells the server,
	which logs invite_prompted. A friend who accepts lands in the hall, or aboard through
	join-in-progress.
]]

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Net = require(script.Parent.Parent.Net)

local Invite = {}

local allowed = false
local checked = false
local waiting: { (boolean) -> () } = {}

local function check()
	local ok, result = pcall(function()
		return SocialService:CanSendGameInviteAsync(Players.LocalPlayer)
	end)
	allowed = ok and result == true
	checked = true
	for _, callback in waiting do
		task.spawn(callback, allowed)
	end
	table.clear(waiting)
end

-- `callback(allowed)` once the check has run (at once if it has).
function Invite.whenChecked(callback: (boolean) -> ())
	if checked then
		task.spawn(callback, allowed)
	else
		table.insert(waiting, callback)
	end
end

function Invite.prompt(source: string)
	if not allowed then
		return
	end
	local ok = pcall(function()
		SocialService:PromptGameInvite(Players.LocalPlayer)
	end)
	if ok then
		Net.Fire("Invited", source)
	end
end

task.spawn(check)

return Invite
