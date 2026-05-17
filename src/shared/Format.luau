--!strict

local Format = {}

-- Formats a size number into a human-readable string per PRD §9.2.
-- Examples: 42 → "42", 1234 → "1.2K", 12345 → "12K", 1500000 → "1.5M"
function Format.number(n: number): string
	n = math.floor(n)
	if n < 1_000 then
		return tostring(n)
	elseif n < 10_000 then
		return string.format("%.1fK", n / 1_000)
	elseif n < 1_000_000 then
		return string.format("%dK", math.floor(n / 1_000))
	elseif n < 10_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n < 1_000_000_000 then
		return string.format("%dM", math.floor(n / 1_000_000))
	elseif n < 10_000_000_000 then
		return string.format("%.1fB", n / 1_000_000_000)
	elseif n < 1_000_000_000_000 then
		return string.format("%dB", math.floor(n / 1_000_000_000))
	else
		return string.format("%.1fT", n / 1_000_000_000_000)
	end
end

return Format
