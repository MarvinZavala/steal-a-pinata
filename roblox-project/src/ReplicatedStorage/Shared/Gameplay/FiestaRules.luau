--!strict
-- Reloj de la Fiesta (alineado a UTC para que los servers coincidan) y el reparto de la Gigante.

local FiestaRules = {}

export type HitRow = { userId: number, hits: number }
export type Payout = { userId: number, candy: number, hits: number }

function FiestaRules.into(unix: number, period: number): number
	if period <= 0 then
		return 0
	end
	local wrapped = unix % period
	if wrapped < 0 then
		wrapped += period
	end
	return wrapped
end

-- "idle" fuera de la ventana, "rain" al principio, "giant" en los últimos giantSec.
function FiestaRules.phase(intoPeriod: number, duration: number, giantSec: number): string
	if intoPeriod < 0 or intoPeriod >= duration then
		return "idle"
	end
	local giantAt = duration - math.max(0, giantSec)
	if intoPeriod >= giantAt then
		return "giant"
	end
	return "rain"
end

-- Segundos para el chip del HUD: 0 = está pasando, si no es la espera.
function FiestaRules.hudSeconds(intoPeriod: number, period: number, duration: number): number
	if intoPeriod < duration then
		return 0
	end
	return math.max(0, period - intoPeriod)
end

function FiestaRules.secondsLeft(intoPeriod: number, duration: number): number
	if intoPeriod >= duration then
		return 0
	end
	return duration - intoPeriod
end

-- Cada golpe vale lo mismo. El resto de la división se lo queda quien más pegó.
function FiestaRules.share(rows: { HitRow }, pool: number): { Payout }
	local total = 0
	local bestIndex = 0
	local bestHits = -1
	for index, row in rows do
		if row.hits > 0 then
			total += row.hits
			if row.hits > bestHits then
				bestHits = row.hits
				bestIndex = index
			end
		end
	end
	local out: { Payout } = {}
	if total <= 0 or pool <= 0 then
		return out
	end
	local given = 0
	for _, row in rows do
		if row.hits > 0 then
			local candy = math.floor(pool * row.hits / total)
			given += candy
			table.insert(out, { userId = row.userId, candy = candy, hits = row.hits })
		end
	end
	local rest = math.floor(pool) - given
	if rest > 0 and bestIndex > 0 then
		local bestId = rows[bestIndex].userId
		for _, row in out do
			if row.userId == bestId then
				row.candy += rest
				break
			end
		end
	end
	return out
end

function FiestaRules.hitCandy(tableCandy: { [string]: number }, rarity: string): number
	local amount = tableCandy[rarity]
	if type(amount) ~= "number" then
		return 0
	end
	return amount
end

return FiestaRules
