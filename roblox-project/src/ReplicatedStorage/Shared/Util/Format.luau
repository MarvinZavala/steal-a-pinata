--!strict
-- 1234 -> "1.2K", 3_400_000 -> "3.4M"
local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi" }
return function(n: number): string
	local i = 1
	while math.abs(n) >= 1000 and i < #SUFFIX do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return string.format(n < 10 and "%.1f%s" or "%.0f%s", n, SUFFIX[i])
end
