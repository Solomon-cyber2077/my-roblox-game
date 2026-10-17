"""
Every threshold and every Roblox approximation the dim-screen harness uses, in one place.
Lighting numbers are NOT here: they come from the game (.lune/visibility.luau exports
Tuning, Config/Cosmetics, Scenery/Sky and UI/Overlay), so previews cannot drift from it.

Sources (see tools/visibility/README.md for the full list):
  WCAG 2.1 SC 1.4.11 Non-text Contrast: 3:1 for graphical objects needed to understand
    content; contrast ratio (L1 + F) / (L2 + F) on relative luminance (sRGB -> linear,
    Y = 0.2126 R + 0.7152 G + 0.0722 B).
  IEC 61966-2-1 (sRGB): reference viewing environment 64 lux, viewer flare 1.0%;
    typical office 5.0%. WCAG's 0.05 is the office figure.
  Android Pie brightness blog (2018): sliders are perceptual (log-like), so a slider at
    45% gives less than 45% of peak luminance; dimming a panel scales emitted light.
"""

# --- the dim device -------------------------------------------------------------------
# A phone's brightness control scales the light the panel emits: every pixel's LINEAR
# luminance is multiplied, the image's gamma is untouched. So 45% = linear * 0.45, then
# sRGB-encode for the picture. (Scaling sRGB code values instead would be 0.45^2.2 = 0.17
# linear: a far darker screen than "45%".) A perceptual slider at 45% sits lower still,
# which is what the report-only 25% stress pass stands in for.
DIM_DEFAULT = 0.45
DIM_STRESS = 0.25

# Viewer flare, as a share of the panel's FULL white: light the room puts on the glass.
# It does not dim with the panel, which is why a dim screen loses contrast. The game's
# target is a dim phone in a dark room, so the gate uses the sRGB reference (dim)
# environment's 1%; WCAG's office 5% is reported alongside for information.
FLARE = 0.01
FLARE_OFFICE = 0.05

# --- gate 1: must-see -------------------------------------------------------------------
# Platform edges and anything a player can run into, at the floor distance and just
# inside it. WCAG 1.4.11's 3:1 for objects a user must perceive to operate.
MUST_SEE_CONTRAST = 3.0
BAND_AT = (0.95, 1.05)  # "at the floor": share of the floor radius, horizontal from the player
BAND_INSIDE = (0.75, 0.95)  # "just inside"
MIN_PIXELS = 10  # an object needs this many pixels in the band (at 0.5 scale) to be judged
RING = 3  # pixels of surround compared against an object
# obstacles: collidable parts whose top is above a step and whose bottom is below the head
STEP = 0.6  # studs: lower than this is walked over
HEAD = 5.0  # studs: an R6 character's height (legs 2, torso 2, head 1)

# --- the slider's minimum: reaction distance (not contrast) ------------------------------
# Contrast at the floor's own distance gets easier as the floor shrinks, so it cannot set
# the minimum. The floor must instead cover what a sprinting player crosses before they can
# react and stop: Tuning.Crew.SprintSpeed x (perception-response + stopping) + margin.
# Perception-response: Green (2000), "How long does it take to stop?", Transportation Human
# Factors 2(3): ~0.75 s when the hazard is expected (a player in a horror game expects one;
# 1.25 s for ordinary, 1.5 s for surprise). Stopping: a Roblox Humanoid has no deceleration
# in MovementController, it stops within a physics step or two (approximation, ~0.1 s).
# Margin: phone input + frame + network latency, ~0.15 s.
REACTION_S = 0.75
STOP_S = 0.10
LATENCY_S = 0.15

# --- gate 2: crew -----------------------------------------------------------------------
# A teammate's lantern (glass + glow) must read at 3:1 beyond the floor; their silhouette
# is reported. Crewmates stand between these distances from you.
CREW_CONTRAST = 3.0
CREW_DISTANCES = (26, 40, 60)  # studs: past the floor, the rim range and the chase radius

# --- gate 3: mood ceiling ("Walmart" limit) ---------------------------------------------
# Average picture level (mean linear luminance at full brightness) and the share of the
# frame lit above mid-grey. Anchored by tools/visibility/refs.py on store screenshots of
# Outlast, Darkwood and Alan Wake (a station frame may be no brighter than the brightest
# horror reference frame's quartile) and the lobby capture called "like a Walmart"
# (docs/compare/before_lobby_hall.jpg): the ceilings sit well under it.
LIT_LEVEL = 0.214  # linear luminance of sRGB 128 (mid-grey)
APL_CEILING = None  # filled from refs.json by refs.py; see REFS below
LIT_CEILING = None
REFS = "refs.json"

# --- Roblox approximations (the Blender scene is NOT the engine) ------------------------
# 1. PointLight/SpotLight falloff: Roblox does not document its curve. We window each light
#    by (1 - d/Range)^2 (zero at Range), the pessimistic of the two common game curves
#    ((1-(d/R)^2)^2 is brighter everywhere inside Range). Brightness 1 at d -> 0 lights a
#    white, facing surface to white.
FALLOFF = "(1-d/R)^2"
# 2. Lighting.Ambient lights every surface (added as albedo * Ambient), OutdoorAmbient comes
#    from the sky dome minus Ambient (ray-traced sky occlusion), so open ground gets
#    OutdoorAmbient and fully covered ground gets Ambient, as Roblox documents them.
# 3. The moon: one directional light at Lighting.Brightness * MOON_SHARE (night) in
#    ColorShift_Top, from the hour; full Brightness by day. Roblox's moon intensity is not
#    documented.
MOON_SHARE = 0.25
# 4. Atmosphere: a depth haze toward Atmosphere.Color, 1 - exp(-Density * d / HAZE_STUDS);
#    Roblox's scattering model is not documented. Negligible inside the floor.
HAZE_STUDS = 250
# 5. Post: exposure 2^ExposureCompensation, Roblox ColorCorrection (brightness add, contrast
#    about mid-grey, saturation, tint multiply) in display space, no tone curve (a clamp;
#    Roblox's Future tonemapper shoulder only affects highlights), no bloom (bloom only
#    brightens glows: conservative for the crew gate).
# 6. Highlights (rim): a 2-pixel outline in Rim.Color at 1 - Rim.Outline opacity and the
#    Rim.Fill wash, unlit, on the Rim.Max nearest rim targets, as VisibilityController picks.
RIM_PIXELS = 2
# 7. Characters: blocky R6 (legs 1x2x1, torso 2x2x1, arms 1x2x1, head 1.2x1x1) in a dark
#    coat; real avatars vary. Lantern lens 1.6 studs up at the right hip.
COAT = (58, 54, 50)
SKIN = (204, 160, 128)
LENS_HEIGHT = 1.6
# 8. The camera: Roblox's classic third person, StartZoom behind a focus 1.5 studs above
#    the root, pitched down CAMERA_PITCH degrees, vertical FOV from the export.
FOCUS = 1.5
CAMERA_PITCH = 12
# 9. Kit meshes come from assets/stationkit/StationKit.blend (vertex colours); everything
#    else is the exported primitives. The landscape round the station is not built.

# --- render ---------------------------------------------------------------------------
WIDTH, HEIGHT = 480, 270  # the 0.5-scale frame of a 960x540 phone view
SAMPLES = 32
