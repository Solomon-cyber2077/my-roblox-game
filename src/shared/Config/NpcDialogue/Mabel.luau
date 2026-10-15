--!strict
--[[
	Mabel "Ticket" Orrin, ticket clerk. Cheerful and plain-spoken: short lines that say what to
	do (the game has no puzzles; talking to her should feel friendly, not like a job).
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
		text = "Evening! I'm Mabel, I keep the tickets. Talk to me between stops if you fancy a job on the way.",
	},
	{
		id = "mabel_smalltalk",
		topic = "SmallTalk",
		text = "Stick together, grab what you can carry, and be back aboard before the whistle. That's the whole trick.",
	},
	{
		id = "mabel_lore",
		topic = "Lore",
		when = { stageMin = 2, seen = "mabel_smalltalk" },
		text = "Funny thing: I punch more tickets than we have passengers. Never mind. Keep your lamp lit.",
	},
	{
		id = "mabel_hint",
		topic = "StopHint",
		text = "Lost things end up at the far end of a platform, where the lamps give out. Look there first.",
	},
	{
		id = "mabel_danger",
		topic = "Danger",
		text = "Last call! Get aboard, now!",
	},
	{
		id = "mabel_offer_luggage",
		topic = "QuestOffer",
		when = { status = "Offered", quest = "MabelLuggage" },
		text = "Someone left a brown leather valise at one of the first three stops. Find it and bring it back to me.",
	},
	{
		id = "mabel_offer_names",
		topic = "QuestOffer",
		when = { status = "Offered", quest = "MabelNames" },
		text = "There's a punched ticket stub somewhere further down the line. Bring it back to me, would you?",
	},
	{
		id = "mabel_offer_manifest",
		topic = "QuestOffer",
		when = { status = "Offered", quest = "MabelManifest" },
		text = "Last job: carry my manifest all the way to the Terminus. Don't lose it!",
	},
	{
		id = "mabel_active",
		topic = "QuestActive",
		when = { status = "Active" },
		text = "Still looking? Try the far end of the platform.",
	},
	{
		id = "mabel_done",
		topic = "QuestDone",
		when = { status = "Done" },
		text = "Lovely, thank you! You'll be paid at the end of the line.",
	},
	{
		id = "mabel_failed",
		topic = "QuestFailed",
		when = { failed = true },
		text = "That one got away last time. Fancy another go?",
	},
	{
		id = "mabel_low",
		topic = "LowSupplies",
		text = "We're low on coal. Bring back anything that burns.",
	},
	{
		id = "mabel_down",
		topic = "CrewDown",
		text = "Someone's down! Go and pull them free.",
	},
	{
		id = "mabel_closecall",
		topic = "CloseCall",
		text = "That was close! Don't cut it so fine next time.",
	},
	{
		id = "mabel_terminus",
		topic = "NearTerminus",
		text = "Nearly at the Terminus. Hold on tight.",
	},
}

return Lines
