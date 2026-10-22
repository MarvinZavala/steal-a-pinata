--!strict
-- Sorteo de la Pasarela. Las claves se ordenan para que el resultado no dependa del orden del diccionario.

local SpawnWeights = {}

local function ordered(weights: { [string]: number }): { string }
	local keys: { string } = {}
	for key in weights do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

function SpawnWeights.weightOf(key: string, base: number, luck: boolean, boosted: { [string]: boolean }?): number
	if luck and boosted ~= nil and boosted[key] == true then
		return base * 2
	end
	return base
end

function SpawnWeights.total(weights: { [string]: number }, luck: boolean, boosted: { [string]: boolean }?): number
	local sum = 0
	for key, weight in weights do
		sum += SpawnWeights.weightOf(key, weight, luck, boosted)
	end
	return sum
end

function SpawnWeights.pick(
	weights: { [string]: number },
	roll01: number,
	luck: boolean,
	boosted: { [string]: boolean }?
): string
	local keys = ordered(weights)
	local total = SpawnWeights.total(weights, luck, boosted)
	local fallback = keys[1] or "Common"
	if total <= 0 then
		return fallback
	end
	local x = math.clamp(roll01, 0, 0.999999) * total
	local acc = 0
	local last = fallback
	for _, key in keys do
		last = key
		acc += SpawnWeights.weightOf(key, weights[key], luck, boosted)
		if x < acc then
			return key
		end
	end
	return last
end

function SpawnWeights.chooseId(ids: { string }, roll01: number): string?
	if #ids == 0 then
		return nil
	end
	local index = math.clamp(math.floor(math.clamp(roll01, 0, 0.999999) * #ids) + 1, 1, #ids)
	return ids[index]
end

export type RosterRow = { id: string, rarity: string, currency: string }

function SpawnWeights.eligibleIds(rows: { RosterRow }, rarity: string): { string }
	local ids: { string } = {}
	for _, row in rows do
		if row.rarity == rarity and row.currency == "Dulces" then
			table.insert(ids, row.id)
		end
	end
	table.sort(ids)
	return ids
end

function SpawnWeights.isHeadline(rarity: string): boolean
	return rarity == "Legendary" or rarity == "Mythic" or rarity == "Secret"
end

return SpawnWeights
