--!strict
-- Fusión 3 → 1 (GDD §4.7). Secretas y de Evento no se rompen en la Re-Fiesta; la fusión sí puede usarlas
-- si el jugador pide esa especie. La mutación sale Dorada, o Arcoíris con la chance de Economy.

local Fusion = {}

local KEEP: { [string]: boolean } = {
	Secret = true,
	Event = true,
}

function Fusion.keptOnRebirth(rarity: string): boolean
	return KEEP[rarity] == true
end

function Fusion.pickMutation(roll: number, rainbowChance: number): string
	if roll < rainbowChance then
		return "Rainbow"
	end
	return "Golden"
end

local function rankMutation(mutation: string): number
	if mutation == "None" or mutation == "" then
		return 0
	elseif mutation == "Golden" then
		return 1
	elseif mutation == "Christmas" then
		return 2
	end
	return 3
end

-- Tres de la misma especie que no estén en tránsito. Prefiere las sin mutación.
function Fusion.selectThree(inventory: { any }, pinataId: string, busy: { [string]: boolean }?): { string }?
	local rows: { { id: string, rank: number } } = {}
	for _, item in inventory do
		if type(item) == "table" and item.PinataId == pinataId and type(item.InstanceId) == "string" then
			if busy == nil or busy[item.InstanceId] ~= true then
				local mutation = if type(item.Mutation) == "string" then item.Mutation else "None"
				table.insert(rows, { id = item.InstanceId, rank = rankMutation(mutation) })
			end
		end
	end
	if #rows < 3 then
		return nil
	end
	table.sort(rows, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.id < b.id
	end)
	return { rows[1].id, rows[2].id, rows[3].id }
end

function Fusion.removeIds(inventory: { any }, placed: { [string]: string }, ids: { string }): { any }
	local drop: { [string]: boolean } = {}
	for _, id in ids do
		drop[id] = true
	end
	local kept: { any } = {}
	local removed: { any } = {}
	for _, item in inventory do
		if type(item) == "table" and drop[item.InstanceId] == true then
			table.insert(removed, item)
		else
			table.insert(kept, item)
		end
	end
	table.clear(inventory)
	for _, item in kept do
		table.insert(inventory, item)
	end
	local clearKeys: { string } = {}
	for key, value in placed do
		if drop[value] == true then
			table.insert(clearKeys, key)
		end
	end
	for _, key in clearKeys do
		placed[key] = nil
	end
	return removed
end

return Fusion
