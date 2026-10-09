--!strict
--[[
	Mabel "Ticket" Orrin, ticket clerk. Cheerful, over-organised, rules are sacred.
	Fifteen lines, picked by Logic/NpcDialogue. `when` narrows a line:
	  status    the run's errand for her: "Offered" | "Active" | "Done"
	  quest     the run's errand is this quest
	  stage     the player's saved stage must equal this; stageMin at least this
	  seen      the player must already have heard that line (in any run)
	  failed    her last errand ran out on the player (said once, then cleared)

	The ending is undecided: hint, contradict, never explain (HANDOFF.md "Mystery clues").
]]

local Lines = {
	{
		id = "mabel_greeting",
		topic = "Greeting",
		text = "Ticket, please! Oh, you're crew. Crew don't need tickets. I'll punch you one anyway; it keeps the count honest. Mabel Orrin, route board and manifests.",
	},
	{
		id = "mabel_smalltalk",
		topic = "SmallTalk",
		text = "Rule nine: nobody is left on a platform without being written down. Nobody remembers rules one to eight. I wrote those too, but they're less important.",
	},
	{
		id = "mabel_lore",
		topic = "Lore",
		when = { stageMin = 2, seen = "mabel_smalltalk" },
		text = "I punched forty-one tickets this month for seats nobody sat in. The punch has never once been wrong. So it's the seats, isn't it? It has to be the seats.",
	},
	{
		id = "mabel_hint",
		topic = "StopHint",
		text = "Lost property ends up at the far end of a platform, where the lamps give out. Nobody likes walking down there. That's exactly why things get left.",
	},
	{
		id = "mabel_danger",
		topic = "Danger",
		text = "Last call means LAST call! Get aboard! I am not writing your name down. Don't make me write your name down.",
	},
	{
		id = "mabel_offer_luggage",
		topic = "QuestOffer",
		when = { status = "Offered", quest = "MabelLuggage" },
		text = "A valise was checked through at one of the first three stops and never claimed. Brown leather, initials rubbed off. Bring it back before I have to fill in the form. I hate that form.",
	},
	{
		id = "mabel_offer_names",
		topic = "QuestOffer",
		when = { status = "Offered", quest = "MabelNames" },
		text = "That valise you brought me had a ticket stub sewn into the lining. Punched, with a name on it, and the name was already on my list. I never told anyone about my list. Further down the line there'll be another. Find it?",
	},
	{
		id = "mabel_offer_manifest",
		topic = "QuestOffer",
		when = { status = "Offered", quest = "MabelManifest" },
		text = "The stubs you found match my list exactly. So I've written the final manifest: everyone who ought to be aboard. It has to reach the Terminus, and I have to be holding it when it does. Please don't ask me why. I've asked myself.",
	},
	{
		id = "mabel_active",
		topic = "QuestActive",
		when = { status = "Active" },
		text = "Still on it? Good. Things never really go missing on this line. They just wait where nobody thinks to look.",
	},
	{
		id = "mabel_done",
		topic = "QuestDone",
		when = { status = "Done" },
		text = "Received, stamped and filed! That entry has been open longer than I've been aboard, and I've been aboard forever. Errands are paid at the end of the line, as per the rules.",
	},
	{
		id = "mabel_failed",
		topic = "QuestFailed",
		when = { failed = true },
		text = "Last trip's entry is still open, then. I don't cross things out. I just copy them into the next book, a little smaller each time.",
	},
	{
		id = "mabel_low",
		topic = "LowSupplies",
		text = "The coal ledger's running thin. I've started rationing my ink, out of sympathy. Bring back anything that burns.",
	},
	{
		id = "mabel_down",
		topic = "CrewDown",
		text = "I heard. I've put a mark by their name. Only in pencil! Pencil rubs out. Go and get them so I can rub it out.",
	},
	{
		id = "mabel_closecall",
		topic = "CloseCall",
		text = "You were half a step from being a line in my book. I'd already licked the pencil. Don't ever do that to me again.",
	},
	{
		id = "mabel_terminus",
		topic = "NearTerminus",
		text = "The Terminus is on the board. It's always been on the board. I just can't find a single ticket in my files punched for the journey back.",
	},
}

return Lines
