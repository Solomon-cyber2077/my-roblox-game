--!strict
-- Relative luminance of an sRGB colour (0-255 channels): sRGB decoded to linear light, then
-- Rec. 709 / WCAG weights. Used to hold surface treatments and lantern colours above a floor
-- (Config/Surfaces, Config/Cosmetics) so a later art pass cannot quietly darken them.

local Luminance = {}

local function linear(channel: number): number
	local c = channel / 255
	return if c <= 0.04045 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

function Luminance.of(rgb: { number }): number
	return 0.2126 * linear(rgb[1]) + 0.7152 * linear(rgb[2]) + 0.0722 * linear(rgb[3])
end

-- A colour scaled by `factor` (grime darkening it), as Kit.shade does, then measured.
function Luminance.shaded(rgb: { number }, factor: number): number
	return Luminance.of({
		math.clamp(rgb[1] * factor, 0, 255),
		math.clamp(rgb[2] * factor, 0, 255),
		math.clamp(rgb[3] * factor, 0, 255),
	})
end

return Luminance
