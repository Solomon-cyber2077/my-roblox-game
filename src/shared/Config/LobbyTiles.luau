--!strict
--[[
	The depot hall's tiles: the oxblood quarry-tile walk and the green glazed dado on the back and end
	walls. Roblox's CeramicTiles read as a bathroom (a bright, even grout grid), so these surfaces can
	take one of three looks. Only the look changes: sizes, positions, colliders and the LobbySurface
	attributes stay as Builders/LobbyBuilder makes them.

	  "today"    CeramicTiles, as the hall has always been
	  "painted"  the painted MaterialVariants (tools/lobby-tiles/paint.py; src/materials/Lobby*.model.json,
	             BaseMaterial CeramicTiles, so footsteps and physics are unchanged) plus the worn-path
	             overlay on the walk. Needs the maps uploaded: until every variant is `uploaded` and the
	             path has an image, "painted" falls back to "today", so nothing changes.
	  "builtin"  no uploads at all: Slate for the walk, Brick (glazed-brick bond) for the dado

	Each variant's colour map averages `mean`; a part on it is tinted to its old colour / mean
	(Logic/LobbyTiles), so the hall keeps its old average colours and the lighting lock holds.
]]

export type Look = "today" | "painted" | "builtin"

export type Variant = {
	name: string, -- the MaterialVariant's name in MaterialService
	base: string, -- its BaseMaterial (an Enum.Material name)
	studs: number, -- StudsPerTile
	mean: { number }, -- the colour map's average, 0-255 (tools/lobby-tiles/out/means.json)
	builtin: string, -- the "builtin" look's material (an Enum.Material name)
	uploaded: boolean,
}

local LobbyTiles = {
	Look = "builtin" :: Look, -- owner, 2026-11-17: "Use fallback" for the Test Launch
	Variants = {
		quarry = {
			name = "LobbyQuarry",
			base = "CeramicTiles",
			studs = 6, -- 8 x 8 tiles: 9 inch quarries
			mean = { 122, 65, 54 },
			builtin = "Slate",
			uploaded = false,
		} :: Variant,
		dado = {
			name = "LobbyDado",
			base = "CeramicTiles",
			studs = 4, -- 4 x 12 tiles (9 x 3 inch) in running bond
			mean = { 44, 100, 75 },
			builtin = "Brick",
			uploaded = false,
		} :: Variant,
	},
	-- The worn path: a Texture on the walk's top face, its image 16 studs along the walk by the walk's
	-- 8 studs across (tools/lobby-tiles/out/path_color.png). Set `image` to the uploaded id.
	Path = {
		image = nil :: string?,
		along = 16,
		across = 8,
	},
}

return LobbyTiles
