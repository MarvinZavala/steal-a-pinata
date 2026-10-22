--!strict
-- Reglas del bate (GDD §4.4 y §7). inRange / inFront los mide Validation.

local BatRules = {}

export type Input = {
	distance: number,
	maxDistance: number,
	inRange: boolean,
	inFront: boolean,
	cooldownReady: boolean,
}

function BatRules.evaluate(input: Input): (boolean, string)
	if not input.cooldownReady then
		return false, "cooldown"
	end
	if input.distance >= 200 then
		return false, "far"
	end
	if not input.inRange then
		return false, "range"
	end
	if not input.inFront then
		return false, "angle"
	end
	return true, "ok"
end

-- Un whiff a 10 studs es normal. Solo se loguea un alcance imposible.
function BatRules.shouldLog(distance: number, maxDistance: number, reason: string): boolean
	if reason == "cooldown" or reason == "ok" then
		return false
	end
	return distance >= 200 or distance > maxDistance * 2
end

function BatRules.shouldDrop(hitsTaken: number, hitsRequired: number): boolean
	return hitsTaken >= hitsRequired
end

return BatRules
