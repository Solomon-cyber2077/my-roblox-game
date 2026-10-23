--!strict
--[[
	The interior lighting lock (docs/FINAL-DESIGN.md Prompt 6, B.3): one warm amber estate recipe
	for the Depot Hall and the train's interior. Local fixtures only (colour, brightness, range,
	shadows); global Lighting, ambient and exposure stay with Scenery/Sky (LOBBY) and
	AtmosphereController, and stations never read this.

	Character FIXED, values PROVISIONAL: low warm ambient, bright 2600 K amber fixtures (Amber), deep
	shadow between lamps, glints from brass and glass, bloom kept to flames. Builders/LobbyBuilder
	and Builders/TrainInterior read every fixture here by name; docs/direction/reference holds the
	locked reference shots and their luminance bands (tools/shot.ps1, tools/refbands).
]]

export type Fixture = { color: { number }, brightness: number, range: number, shadows: boolean? }

local AMBER = { 255, 190, 120 } -- 2600 K: the recipe's fixture colour
local GAS = { 255, 178, 98 } -- gas behind tinted glass: the hall's globes and the piano's pool
local FIRE = { 255, 150, 80 }
local FLAME = { 255, 147, 60 }
local COALS = { 255, 120, 40 }

local function fixture(color: { number }, brightness: number, range: number, shadows: boolean?): Fixture
	return table.freeze({ color = color, brightness = brightness, range = range, shadows = shadows })
end

return table.freeze({
	Amber = AMBER,
	-- the recipe's target for a main fixture (most keep their tuned values below until the owner's look pass)
	Recipe = table.freeze({ brightness = 1.2, range = { 20, 24 } }),

	Hall = table.freeze({
		Globe = fixture(GAS, 1, 38), -- the platform's hanging globes (some cast shadows: LobbyBuilder picks)
		Kiosk = fixture(AMBER, 0.75, 22), -- the Outfitter's lamp
		Bulb = fixture(AMBER, 0.55, 14),
		Stove = fixture(FIRE, 0.9, 18),
		TableLamp = fixture(AMBER, 0.55, 16), -- the side table's green-shaded lamp
		Pendant = fixture(AMBER, 0.65, 20),
		PianoFlame = fixture(FLAME, 0.55, 8), -- kept to the piano itself, never on the board above
		PianoPool = fixture(GAS, 0.6, 22),
		Lantern = fixture(AMBER, 0.75, 22),
		Gooseneck = fixture(AMBER, 1.1, 31.5), -- the two lamps leaning over the departure board
	}),

	Train = table.freeze({
		Bulb = fixture(AMBER, 0.6, 11),
		BoardLantern = fixture(AMBER, 0.4, 12), -- over the route board's tickets
		Firebox = fixture(COALS, 1.0, 13),
		Banker = fixture(AMBER, 0.55, 9),
		Flame = fixture(AMBER, 0.7, 14),
		BenchLamp = fixture(AMBER, 0.8, 13),
		Stove = fixture(COALS, 2.2, 16, true),
		GaugeLamp = fixture(AMBER, 0.45, 7),
		-- the saloon ceiling's square lanterns: the hall's back-wall lamp light (Hall.Gooseneck's gas
		-- colour and strength), reach cut to a car's width
		Lantern = fixture(GAS, 1.1, 20, true),
	}),
})
