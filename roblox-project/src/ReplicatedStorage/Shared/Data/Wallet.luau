--!strict
-- Mutaciones de moneda e inventario. No conoce al cliente: el servidor pasa números que él mismo calculó.
-- Un monto que no sea un entero positivo, o una moneda desconocida, no cambia nada.
local Wallet = {}

local CURRENCIES: { [string]: boolean } = {
	Dulces = true,
	Bastones = true,
}

local MUTATIONS: { [string]: boolean } = {
	None = true,
	Golden = true,
	Rainbow = true,
	Christmas = true,
}

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function isAmount(n: any, maxCurrency: number): boolean
	if not isFinite(n) then
		return false
	end
	if n % 1 ~= 0 or n <= 0 or n > maxCurrency then
		return false
	end
	return true
end

function Wallet.trySpend(data: any, currency: any, amount: any, maxCurrency: number): boolean
	if type(data) ~= "table" or CURRENCIES[currency] ~= true then
		return false
	end
	if not isAmount(amount, maxCurrency) then
		return false
	end
	local balance = data[currency]
	if type(balance) ~= "number" or balance < amount then
		return false
	end
	data[currency] = balance - amount
	return true
end

function Wallet.grant(data: any, currency: any, amount: any, maxCurrency: number): boolean
	if type(data) ~= "table" or CURRENCIES[currency] ~= true then
		return false
	end
	if not isAmount(amount, maxCurrency) then
		return false
	end
	local balance = data[currency]
	if type(balance) ~= "number" then
		return false
	end
	if balance + amount > maxCurrency then
		return false
	end
	data[currency] = balance + amount
	return true
end

function Wallet.grantPinata(
	data: any,
	pinataId: any,
	mutation: any,
	instanceId: any,
	now: any,
	maxInventory: number,
	allowed: { [string]: boolean }?
): boolean
	if type(data) ~= "table" or type(data.Inventory) ~= "table" or type(data.Dex) ~= "table" then
		return false
	end
	if type(pinataId) ~= "string" or pinataId == "" or #pinataId > 32 then
		return false
	end
	if allowed ~= nil and allowed[pinataId] ~= true then
		return false
	end
	local mut = if mutation == nil then "None" else mutation
	if type(mut) ~= "string" or MUTATIONS[mut] ~= true then
		return false
	end
	if type(instanceId) ~= "string" or instanceId == "" or #instanceId > 64 then
		return false
	end
	if string.find(instanceId, "%c") ~= nil then
		return false
	end
	if not isFinite(now) or now < 0 then
		return false
	end
	if #data.Inventory >= maxInventory then
		return false
	end
	for _, item in data.Inventory do
		if type(item) == "table" and item.InstanceId == instanceId then
			return false
		end
	end
	table.insert(data.Inventory, {
		InstanceId = instanceId,
		PinataId = pinataId,
		Mutation = mut,
		ObtainedAt = now,
	})
	data.Dex[pinataId] = true
	return true
end

-- true solo la primera vez que se ve ese PurchaseId (ProcessReceipt idempotente, WP-11).
function Wallet.markPurchase(data: any, purchaseId: any): boolean
	if type(data) ~= "table" or type(data.ProcessedPurchases) ~= "table" then
		return false
	end
	if type(purchaseId) ~= "string" or purchaseId == "" or #purchaseId > 80 then
		return false
	end
	if string.find(purchaseId, "%c") ~= nil then
		return false
	end
	if data.ProcessedPurchases[purchaseId] == true then
		return false
	end
	data.ProcessedPurchases[purchaseId] = true
	return true
end

local function findItem(data: any, instanceId: string): any?
	if type(data) ~= "table" or type(data.Inventory) ~= "table" then
		return nil
	end
	for _, item in data.Inventory do
		if type(item) == "table" and item.InstanceId == instanceId then
			return item
		end
	end
	return nil
end

function Wallet.slotOf(data: any, instanceId: string): number?
	if type(data) ~= "table" or type(data.Placed) ~= "table" then
		return nil
	end
	for key, value in data.Placed do
		if value == instanceId then
			local slot = tonumber(key)
			if slot ~= nil then
				return slot
			end
		end
	end
	return nil
end

function Wallet.unplace(data: any, instanceId: string)
	if type(data) ~= "table" or type(data.Placed) ~= "table" then
		return
	end
	local drop: { string } = {}
	for key, value in data.Placed do
		if value == instanceId and type(key) == "string" then
			table.insert(drop, key)
		end
	end
	for _, key in drop do
		data.Placed[key] = nil
	end
end

function Wallet.place(data: any, instanceId: any, slot: any, maxSlots: number): boolean
	if type(data) ~= "table" or type(instanceId) ~= "string" then
		return false
	end
	if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > maxSlots then
		return false
	end
	if type(data.Placed) ~= "table" or findItem(data, instanceId) == nil then
		return false
	end
	Wallet.unplace(data, instanceId)
	local key = tostring(slot)
	local previous = data.Placed[key]
	if type(previous) == "string" and previous ~= instanceId then
		data.Placed[key] = nil
	end
	data.Placed[key] = instanceId
	return true
end

-- Saca la piñata del inventario de origen (y de sus pedestales) y la deja en el destino.
-- El InstanceId no cambia: no hay copia.
function Wallet.movePinata(fromData: any, toData: any, instanceId: any, maxInventory: number): boolean
	if type(fromData) ~= "table" or type(toData) ~= "table" or fromData == toData then
		return false
	end
	if type(instanceId) ~= "string" or type(fromData.Inventory) ~= "table" or type(toData.Inventory) ~= "table" then
		return false
	end
	if type(toData.Dex) ~= "table" then
		return false
	end
	if #toData.Inventory >= maxInventory then
		return false
	end
	if findItem(toData, instanceId) ~= nil then
		return false
	end
	local item = findItem(fromData, instanceId)
	if item == nil then
		return false
	end
	local keep: { any } = {}
	for _, other in fromData.Inventory do
		if other ~= item then
			table.insert(keep, other)
		end
	end
	table.clear(fromData.Inventory)
	for _, other in keep do
		table.insert(fromData.Inventory, other)
	end
	Wallet.unplace(fromData, instanceId)
	Wallet.unplace(toData, instanceId)
	table.insert(toData.Inventory, item)
	if type(item.PinataId) == "string" then
		toData.Dex[item.PinataId] = true
	end
	return true
end

return Wallet
