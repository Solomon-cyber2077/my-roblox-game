-- Minimal Registry surface required by CosmeticService in the isolated place.
return {
	CrewService = {
		IsMember = function()
			return false
		end,
		MemberPlayers = function()
			return {}
		end,
	},
	TrainService = {
		ApplyLivery = function() end,
	},
}
