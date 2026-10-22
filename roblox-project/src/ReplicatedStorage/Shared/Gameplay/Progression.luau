--!strict
-- Compras de Dulcería y Re-Fiesta. Puro: el servicio gasta con Wallet y después llama acá,
-- o usa tryRebirth que sí muta el perfil (Dulces a 0, no solo el precio).

local Economy = if typeof(script) == "Instance"
	then require(script.Parent.Parent.Config.Economy)
	else require("../Config/Economy")
local Fusion = if typeof(script) == "Instance" then require(script.Parent.Fusion) else require("./Fusion")

local Progression = {}

function Progression.countAtLeast(inventory: { any }, pinatas: { [string]: any }, rarity: string): number
	local need = Economy.rarityRank(rarity)
	local total = 0
	for _, item in inventory do
		if type(item) == "table" and type(item.PinataId) == "string" then
			local def = pinatas[item.PinataId]
			local rank = 0
			if type(def) == "table" and type(def.Rarity) == "string" then
				rank = Economy.rarityRank(def.Rarity)
			end
			if rank >= need and need > 0 then
				total += 1
			end
		end
	end
	return total
end

-- Reinicia Dulces, bóveda, piñatas normales y pedestales comprados.
-- Secretas y de Evento se quedan, con su pedestal si lo tenían.
function Progression.tryRebirth(data: any, pinatas: { [string]: any }): (boolean, string)
	if type(data) ~= "table" or type(data.Inventory) ~= "table" or type(data.Placed) ~= "table" then
		return false, "data"
	end
	local nextLevel = (if type(data.ReFiestas) == "number" then data.ReFiestas else 0) + 1
	local offer = Economy.refiestaOffer(nextLevel)
	local candy = if type(data.Dulces) == "number" then data.Dulces else 0
	if candy < offer.Candy then
		return false, "poor"
	end
	if Progression.countAtLeast(data.Inventory, pinatas, offer.Rarity) < offer.Count then
		return false, "pinatas"
	end
	local keep: { any } = {}
	for _, item in data.Inventory do
		local rarity = "Common"
		if type(item) == "table" and type(item.PinataId) == "string" then
			local def = pinatas[item.PinataId]
			if type(def) == "table" and type(def.Rarity) == "string" then
				rarity = def.Rarity
			end
		end
		if Fusion.keptOnRebirth(rarity) then
			table.insert(keep, item)
		end
	end
	local alive: { [string]: boolean } = {}
	for _, item in keep do
		if type(item.InstanceId) == "string" then
			alive[item.InstanceId] = true
		end
	end
	local placed: { [string]: string } = {}
	for key, value in data.Placed do
		if type(key) == "string" and type(value) == "string" and alive[value] == true then
			placed[key] = value
		end
	end
	table.clear(data.Inventory)
	for _, item in keep do
		table.insert(data.Inventory, item)
	end
	table.clear(data.Placed)
	for key, value in placed do
		data.Placed[key] = value
	end
	data.Dulces = 0
	data.VaultCandy = 0
	data.PedestalsOwned = Economy.StartPedestals
	data.ReFiestas = nextLevel
	local bat = if type(data.BatTier) == "number" then data.BatTier else 0
	data.BatTier = bat + 1
	return true, "ok"
end

return Progression
