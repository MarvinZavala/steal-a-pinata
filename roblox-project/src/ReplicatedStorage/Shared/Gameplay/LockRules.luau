--!strict
-- Duración y cooldown del candado (GDD §4.5). El VIP y la Re-Fiesta suman, con tope.

local LockRules = {}

function LockRules.duration(
	baseSec: number,
	vipBonus: number,
	hasVip: boolean,
	perReFiesta: number,
	reFiestas: number,
	maxSec: number
): number
	local bonus = if hasVip then vipBonus else 0
	local total = baseSec + bonus + perReFiesta * math.max(0, reFiestas)
	return math.min(maxSec, math.max(0, total))
end

function LockRules.canStart(now: number, cooldownEndsAt: number): boolean
	return now >= cooldownEndsAt
end

function LockRules.remaining(now: number, endsAt: number): number
	return math.max(0, endsAt - now)
end

return LockRules
