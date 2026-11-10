--!strict
--[[
	The premise in words (docs/FINAL-DESIGN.md B.3 Narrative, Design step 8; LORE.md section 0). Copy only:
	code keeps its identifiers (run, crew, lobby) and the UI and the world read their names here.

	The Depot is the last lit place. The Company sends its young down the dead line on the last
	train to strip the stations for coal, parts and valuables; the trips delay the end. Those who
	keep to the Company's routes and stick together; those entered in the ledger as left behind are not
	recalled. Nobody is chosen for a fault: they are simply chosen. The Hollows are never explained, and nothing here says anyone comes back from death.
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

	-- the route board in the hall (Builders/LobbyBuilder)
	Board = "THE COMPANY'S LINES",
	BoardLines = table.freeze({
		"Short Line  ·  five stations",
		"Long Line  ·  ten stations",
		"Keep to the route. Keep together.",
	}),

	-- the departure board (UI/Lobby)
	BoardHead = "COLDHARBOUR DEPOT  ·  THE RELIEF",

	-- the run ticket's stamp when the crew is lost (Logic/RunLog.final); was "ENTERED, NOT RECALLED",
	-- shortened on the owner's call (playtest review, 11-09)
	NotRecalled = "CREW LOST",

	-- a brass plaque on a lamp post at every station (Builders/StationDressing)
	Plaque = "KEPT LIT BY THOSE WHO WENT BEFORE",
})
