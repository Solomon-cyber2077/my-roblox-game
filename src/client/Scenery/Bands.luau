--!strict
--[[
	Heights and reaches the landscape layers (Land) and the set pieces (Features)
	share.

	Every slab sits wholly inside its own height band, so no two layers ever share
	a plane, and anything standing on a layer has its base buried in that layer's
	slab (lune run audit checks both):

	  near overlays   -14.0 .. -13.9   patches and field strips on the near ground
	  near ground     -14.4 .. -14.0
	  near sea        -15.1 .. -14.8
	  mid overlays    -14.5 .. -14.1   patches on the mid ground, raised further
	                                   because they are seen from further away
	  mid ground      -15.5 .. -14.5
	  mid sea         -15.5 .. -15.2
	  horizon ground  -16.0 .. -15.0   out past the mid field
	                  -16.0 .. -15.5   and in under it, right beneath the mid slabs:
	                                   the mid layer stops short of the horizon's
	                                   reach ahead, and past it this is the ground
	  far sea         -15.9 .. -15.6   out past the mid field and in under it
	  ridges stand at -15.7, inside every horizon slab and the far sea

	Set pieces that meet the ground (canyon walls, sinkhole cliffs) keep their tops
	inside the slab of the layer they meet, a little under its surface.
]]

return {
	Ground = -14, -- near ground top
	NearThickness = 0.4,
	Overlay = 0.1,
	MidOverlay = 0.4,
	MidTop = -14.5,
	MidThickness = 1.0,
	HorizonTop = -15.0,
	HorizonThickness = 1.0,
	HorizonInnerTop = -15.5,
	HorizonInnerThickness = 0.5,
	RidgeBase = -15.7,
	SeaNear = -14.8,
	SeaMid = -15.2,
	SeaHorizon = -15.6,
	SeaThickness = 0.3,

	Formation = -6.85, -- top of the formation under the ballast

	NearZ = 420, -- the near ground reaches this far from the track
	MidZ = 1600, -- then the mid ground
	FarZ = 10000, -- then the horizon, past the furthest reach of the far range
}
