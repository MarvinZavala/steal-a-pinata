--!strict
-- Reglas de robo (GDD §4.3 y §7). El servidor llena los booleanos con
-- AntiCheatService.authorize (distancia y slack de ping). Esto solo decide sí o no.

local StealRules = {}

export type Input = {
	distance: number,
	inRange: boolean,
	locked: boolean,
	alreadyCarrying: boolean,
	thiefIsRookie: boolean,
	victimIsRookie: boolean,
	cooldownReady: boolean,
	recentStealsOnVictim: number,
	maxStealsPerWindow: number,
	thiefHasRoom: boolean,
	pinataAvailable: boolean,
	pinataProtected: boolean,
}

function StealRules.evaluate(input: Input): (boolean, string)
	if input.distance >= 200 then
		return false, "far"
	end
	if not input.pinataAvailable then
		return false, "missing"
	end
	if input.pinataProtected then
		return false, "protected"
	end
	if input.locked then
		return false, "locked"
	end
	if input.thiefIsRookie or input.victimIsRookie then
		return false, "rookie"
	end
	if input.alreadyCarrying then
		return false, "carrying"
	end
	if not input.thiefHasRoom then
		return false, "no_room"
	end
	if not input.cooldownReady then
		return false, "cooldown"
	end
	if input.recentStealsOnVictim >= input.maxStealsPerWindow then
		return false, "cap"
	end
	if not input.inRange then
		return false, "distance"
	end
	return true, "ok"
end

function StealRules.shouldLogFar(distance: number, reason: string): boolean
	return reason == "far" or distance >= 200
end

function StealRules.countSince(times: { number }, now: number, windowSec: number): number
	local n = 0
	for _, at in times do
		if now - at < windowSec then
			n += 1
		end
	end
	return n
end

function StealRules.countRecent(
	stamps: { { victim: number, at: number } },
	victim: number,
	now: number,
	windowSec: number
): number
	local n = 0
	for _, stamp in stamps do
		if stamp.victim == victim and now - stamp.at < windowSec then
			n += 1
		end
	end
	return n
end

return StealRules
