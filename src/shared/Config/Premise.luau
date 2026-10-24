--!strict
--[[
	The premise in words (docs/FINAL-DESIGN.md B.3 Narrative, Prompt 8; LORE.md section 0). Copy only:
	code keeps its identifiers (run, crew, lobby) and the UI and the world read their names here.

	The Depot is the last lit place. The Company sends its young down the dead line on the last
	train to strip the stations for coal, parts and valuables; the trips delay the end. Those who
	come back from the Terminus go on the Roll; those entered in the ledger as left behind are not
	recalled. The Hollows are never explained, and nothing here says anyone comes back from death.
]]

return table.freeze({
	Title = "LAST TRAIN OUT", -- the game's title stays
	Depot = "COLDHARBOUR DEPOT", -- the lobby
	Hand = "HAND", -- a player (the Company's Hands)
	Hands = "HANDS",
	Relief = "RELIEF", -- a run

	-- the hall's notice (UI/PosterArt's coal bill)
	Notice = table.freeze({
		Wanted = "H A N D S",
		For = "for the Relief",
		Body = "RELIEF DEPARTS AT DUSK.\nHANDS REPORT TO THE CLERK.",
		Motto = "THE DEPOT STANDS WHILE THE LINE RUNS.",
		Apply = "Coldharbour Depot · Apply to the Clerk.",
	}),

	-- the honours board in the hall (Builders/LobbyBuilder) and the Ledger
	Roll = "ROLL OF THE TERMINUS",
	RollLines = table.freeze({
		"Hands who came back from the Terminus",
		"Their names, titles and liveries",
		"Open the Ledger to see your record",
	}),

	-- the departure board (UI/Lobby)
	BoardHead = "COLDHARBOUR DEPOT  ·  THE RELIEF",

	-- the run ticket's stamp when the crew is lost (Logic/RunLog.final)
	NotRecalled = "ENTERED, NOT RECALLED",

	-- a brass plaque on a lamp post at every station (Builders/StationDressing)
	Plaque = "KEPT LIT BY THOSE WHO WENT BEFORE",
})
