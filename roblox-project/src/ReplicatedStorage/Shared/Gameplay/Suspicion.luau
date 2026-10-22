--!strict
-- WP-10b. Puntaje de la sesión y la escalera log → rubber-band → candado de carga → kick.
-- El kick cierra la sesión. No escribe un ban. El puntaje no se guarda en el perfil.

local Suspicion = {}

export type Response = "log" | "rubberband" | "carry_lock" | "kick"

export type Thresholds = {
	RubberBandAt: number,
	CarryLockAt: number,
	KickAt: number,
	DecayPerSec: number,
}

export type Memory = {
	value: number,
	lastAt: number,
	response: Response,
	lastReason: string,
}

function Suspicion.blank(): Memory
	return { value = 0, lastAt = 0, response = "log", lastReason = "" }
end

function Suspicion.responseFor(value: number, thresholds: Thresholds): Response
	if value >= thresholds.KickAt then
		return "kick"
	end
	if value >= thresholds.CarryLockAt then
		return "carry_lock"
	end
	if value >= thresholds.RubberBandAt then
		return "rubberband"
	end
	return "log"
end

function Suspicion.decayed(value: number, lastAt: number, now: number, decayPerSec: number): number
	if lastAt <= 0 or now <= lastAt or decayPerSec <= 0 then
		return math.max(0, value)
	end
	return math.max(0, value - decayPerSec * (now - lastAt))
end

function Suspicion.strike(memory: Memory, now: number, kind: string, weight: number, thresholds: Thresholds): Memory
	local value = Suspicion.decayed(memory.value, memory.lastAt, now, thresholds.DecayPerSec) + weight
	return {
		value = value,
		lastAt = now,
		response = Suspicion.responseFor(value, thresholds),
		lastReason = kind,
	}
end

-- El teleport, el noclip y el vuelo se corrigen en el acto: si no, el exploit rinde.
-- La velocidad rara solo se corrige cuando el puntaje ya pidió rubber-band.
function Suspicion.shouldCorrect(kind: string, response: Response): boolean
	if kind == "teleport" or kind == "noclip" or kind == "fly" or kind == "carry_wall" then
		return true
	end
	return response == "rubberband" or response == "carry_lock" or response == "kick"
end

return Suspicion
