--!strict
-- Producción de Dulces, tope de la Dulcería y pagos. Puro: sin Roblox.

local CandyMath = {}

export type Entry = { candyPerSec: number, mutation: string? }

function CandyMath.perSecond(entries: { Entry }, multiplier: number, mutationMult: { [string]: number }): number
	local sum = 0
	for _, entry in entries do
		local mult = 1
		if entry.mutation ~= nil then
			local found = mutationMult[entry.mutation]
			if found ~= nil then
				mult = found
			end
		end
		sum += entry.candyPerSec * mult
	end
	return sum * multiplier
end

function CandyMath.cap(perSec: number, capSeconds: number): number
	if perSec <= 0 or capSeconds <= 0 then
		return 0
	end
	return perSec * capSeconds
end

function CandyMath.deposit(vault: number, amount: number, capAmount: number): number
	if amount <= 0 then
		return math.min(vault, capAmount)
	end
	return math.min(capAmount, vault + amount)
end

function CandyMath.accrue(vault: number, perSec: number, dt: number, capAmount: number): number
	return CandyMath.deposit(vault, perSec * dt, capAmount)
end

function CandyMath.trySpend(candy: number, price: number): (boolean, number)
	if price < 0 or price ~= price then
		return false, candy
	end
	if candy < price then
		return false, candy
	end
	return true, candy - price
end

return CandyMath
