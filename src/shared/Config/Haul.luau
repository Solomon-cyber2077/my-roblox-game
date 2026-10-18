--!strict
-- Physical recovery feeds existing Crew Rank XP, never a spendable balance.
return {
	DoubleFraction = 0.6,
	DuoPenalty = 0.15,
	SoloPenalty = 0.35,
	LampBonus = 0.5,
	PromptReach = 9,
	PickupReach = 3,
	MovementSlack = 4,
	CarrierSeparation = 10,
	DeliveryReach = 4,
	DroppedBrightness = 0.15,
	Tick = 0.1,
	CrateValuables = {
		"Sovereign",
		"Sovereign",
		"SilverWatch",
		"ShareCertificate",
		"ShareCertificate",
		"Sovereign",
	},
	LooseValuables = { "Sovereign", "SilverWatch", "ShareCertificate" },
	Supplies = { "Scrap", "Tonic" },
	Trophy = "Burnt railway ticket",
	Xp = { Sovereign = 12, SilverWatch = 18, ShareCertificate = 24 },
}
