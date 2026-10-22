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

return Wallet
