--!strict
-- Text formatting used by HUD, summary cards and the shop.

local Format = {}

-- 65.2 -> "1:05". Rounds up so a countdown never shows 0:00 while time remains.
function Format.clock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

-- 1250 -> "1,250"
function Format.thousands(n: number): string
	local negative = n < 0
	local digits = tostring(math.floor(math.abs(n) + 0.5))
	local out = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return if negative then "-" .. out else out
end

-- 8 -> "+8", -3 -> "-3"
function Format.signed(n: number): string
	return if n >= 0 then "+" .. Format.thousands(n) else Format.thousands(n)
end

function Format.plural(n: number, singular: string, pluralForm: string?): string
	return `{Format.thousands(n)} {if n == 1 then singular else (pluralForm or singular .. "s")}`
end

function Format.percent(fraction: number): string
	return `{math.floor(fraction * 100 + 0.5)}%`
end

return table.freeze(Format)
