--!strict
-- Artículos pagos con azar (política de Roblox): las probabilidades que la tienda muestra antes de comprar
-- (Caja Sorpresa, Suerte de Server, Pasarela Dorada) y la alternativa sin azar para quien tiene
-- ArePaidRandomItemsRestricted: la caja entrega una secuencia conocida y anunciada.

local SpawnWeights = if typeof(script) == "Instance"
	then require(script.Parent.SpawnWeights)
	else require("./SpawnWeights")

local PaidRandom = {}

export type Weighted = { Id: string, Weight: number }
export type RarityOdds = { rarity: string, percent: number }

-- Siguiente premio de la secuencia conocida: el primero de la lista que todavía no tiene. nil = los tiene todos.
function PaidRandom.nextInSequence(odds: { Weighted }, owned: { [string]: any }?): string?
	for _, row in odds do
		if owned == nil or owned[row.Id] ~= true then
			return row.Id
		end
	end
	return nil
end

-- Porcentaje legible: un decimal desde 10 %, dos debajo (la Secreta queda en 0.01 %).
function PaidRandom.round(percent: number): number
	if percent >= 10 then
		return math.floor(percent * 10 + 0.5) / 10
	end
	return math.floor(percent * 100 + 0.5) / 100
end

-- Probabilidad (0..100) de cada rareza al salir una piñata en la Pasarela.
-- luck: Suerte de Server (SpawnWeights dobla las de `boosted`). liftTo: Pasarela Dorada, lo que está antes de
-- liftTo en `order` sale como liftTo (igual que ConveyorService.rollPinata).
function PaidRandom.rarityOdds(
	weights: { [string]: number },
	order: { string },
	luck: boolean,
	boosted: { [string]: boolean },
	liftTo: string?
): { RarityOdds }
	local share: { [string]: number } = {}
	local total = 0
	local lifting = liftTo ~= nil
	for _, rarity in order do
		local base = weights[rarity]
		if base ~= nil then
			local weight = SpawnWeights.weightOf(rarity, base, luck, boosted)
			total += weight
			local target = rarity
			if lifting and liftTo ~= nil then
				if rarity == liftTo then
					lifting = false
				else
					target = liftTo
				end
			end
			share[target] = (share[target] or 0) + weight
		end
	end
	local rows: { RarityOdds } = {}
	if total <= 0 then
		return rows
	end
	for _, rarity in order do
		local weight = share[rarity]
		if weight ~= nil then
			table.insert(rows, { rarity = rarity, percent = PaidRandom.round(weight / total * 100) })
		end
	end
	return rows
end

return PaidRandom
