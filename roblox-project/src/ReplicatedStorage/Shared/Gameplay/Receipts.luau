--!strict
-- ProcessReceipt puro. El PurchaseId se marca en el mismo perfil que el premio.
-- Un reintento del mismo id no vuelve a dar nada. Si el premio no entra, se desmarca
-- para que Roblox pueda reintentar. Un id 0 (placeholder) no se puede mapear.

local Wallet = if typeof(script) == "Instance"
	then require(script.Parent.Parent.Data.Wallet)
	else require("../Data/Wallet")
local PaidRandom = if typeof(script) == "Instance" then require(script.Parent.PaidRandom) else require("./PaidRandom")

local Receipts = {}

export type ProductDef = {
	Id: number,
	Price: number?,
	Minutes: number?,
	DurationSec: number?,
	Spawns: number?,
	CooldownSec: number?,
}

export type Catalog = {
	Products: { [string]: ProductDef },
	SurpriseOdds: { { Id: string, Weight: number } }?,
	-- Minutos de producción que paga un repetido de la Caja Sorpresa ("Si ya lo tenés, te damos Dulces").
	SurpriseDupeMinutes: number?,
	Rewarded: { BoostSec: number?, DailyLimit: number? }?,
}

export type Context = {
	productionPerSec: number,
	now: number,
	roll: number,
	maxCurrency: number,
	today: number,
	-- ArePaidRandomItemsRestricted: la caja da la secuencia conocida (PaidRandom) en vez de sortear.
	sequence: boolean?,
}

export type Effect = {
	kind: string,
	seconds: number?,
	spawns: number?,
	cosmeticId: string?,
	amount: number?,
}

export type Result = {
	status: string,
	key: string?,
	effects: { Effect },
}

local function empty(status: string, key: string?): Result
	return { status = status, key = key, effects = {} }
end

function Receipts.findKey(catalog: Catalog, productId: number): string?
	if type(productId) ~= "number" or productId == 0 or productId ~= productId then
		return nil
	end
	local found: string? = nil
	for key, def in catalog.Products do
		if type(def) == "table" and def.Id == productId then
			if found ~= nil then
				return nil
			end
			found = key
		end
	end
	return found
end

function Receipts.pickWeighted(odds: { { Id: string, Weight: number } }, roll: number): string?
	local total = 0
	for _, row in odds do
		if row.Weight > 0 then
			total += row.Weight
		end
	end
	if total <= 0 then
		return nil
	end
	local x = math.clamp(roll, 0, 0.999999) * total
	local acc = 0
	local last: string? = nil
	for _, row in odds do
		if row.Weight > 0 then
			last = row.Id
			acc += row.Weight
			if x < acc then
				return row.Id
			end
		end
	end
	return last
end

local function ensureCosmetics(data: any)
	if type(data.Cosmetics) ~= "table" then
		data.Cosmetics = {}
	end
end

local function grantCandy(data: any, amount: number, maxCurrency: number): boolean
	local whole = math.floor(amount)
	if whole <= 0 then
		return false
	end
	return Wallet.grant(data, "Dulces", whole, maxCurrency)
end

local function applyKey(data: any, key: string, def: ProductDef, ctx: Context, catalog: Catalog): (boolean, { Effect })
	local effects: { Effect } = {}
	if key == "ServerLuck2x" then
		local seconds = def.DurationSec or (15 * 60)
		table.insert(effects, { kind = "serverLuck", seconds = seconds })
		return true, effects
	elseif key == "GoldenConveyor" then
		local spawns = def.Spawns or 5
		table.insert(effects, { kind = "goldenConveyor", spawns = spawns })
		return true, effects
	elseif key == "SurpriseBox" then
		local odds = catalog.SurpriseOdds
		if odds == nil then
			return false, effects
		end
		ensureCosmetics(data)
		local cosmeticId = if ctx.sequence
			then PaidRandom.nextInSequence(odds, data.Cosmetics)
			else Receipts.pickWeighted(odds, ctx.roll)
		if cosmeticId == nil or data.Cosmetics[cosmeticId] == true then
			-- Repetido (o la secuencia ya completa): paga Dulces, como dice la tienda.
			local perSec = math.max(ctx.productionPerSec, 1)
			local amount = math.floor(perSec * (catalog.SurpriseDupeMinutes or 10) * 60)
			if not grantCandy(data, amount, ctx.maxCurrency) then
				return false, effects
			end
			table.insert(effects, { kind = "candy", amount = amount })
			return true, effects
		end
		data.Cosmetics[cosmeticId] = true
		table.insert(effects, { kind = "cosmetic", cosmeticId = cosmeticId })
		return true, effects
	elseif key == "CandyPackS" or key == "CandyPackM" or key == "CandyPackL" then
		local minutes = def.Minutes or 0
		local perSec = ctx.productionPerSec
		if perSec < 1 then
			perSec = 1
		end
		local amount = math.floor(perSec * minutes * 60)
		if not grantCandy(data, amount, ctx.maxCurrency) then
			return false, effects
		end
		table.insert(effects, { kind = "candy", amount = amount })
		return true, effects
	elseif key == "EmergencyLock" then
		local charges = if type(data.EmergencyCharges) == "number" then data.EmergencyCharges else 0
		data.EmergencyCharges = charges + 1
		table.insert(effects, { kind = "emergency" })
		return true, effects
	elseif key == "RewardedBoost" then
		local limit = 1
		if catalog.Rewarded ~= nil and type(catalog.Rewarded.DailyLimit) == "number" then
			limit = catalog.Rewarded.DailyLimit
		end
		local used = if type(data.RewardedDay) == "number" and data.RewardedDay == ctx.today then 1 else 0
		if used >= limit then
			table.insert(effects, { kind = "noop" })
			return true, effects
		end
		local seconds = 10 * 60
		if catalog.Rewarded ~= nil and type(catalog.Rewarded.BoostSec) == "number" then
			seconds = catalog.Rewarded.BoostSec
		end
		local untilUnix = ctx.now + seconds
		local current = if type(data.RewardedBoostUntil) == "number" then data.RewardedBoostUntil else 0
		if current > untilUnix then
			untilUnix = current
		end
		data.RewardedBoostUntil = untilUnix
		data.RewardedDay = ctx.today
		table.insert(effects, { kind = "boost", seconds = seconds })
		return true, effects
	end
	local cosmeticId = (def :: any).Grant
	if type(cosmeticId) == "string" and cosmeticId ~= "" then
		ensureCosmetics(data)
		data.Cosmetics[cosmeticId] = true
		table.insert(effects, { kind = "cosmetic", cosmeticId = cosmeticId })
		return true, effects
	end
	return false, effects
end

-- status: granted | duplicate | retry | unconfigured
function Receipts.commit(data: any, catalog: Catalog, purchaseId: string, productId: number, ctx: Context): Result
	if type(data) ~= "table" or type(data.ProcessedPurchases) ~= "table" then
		return empty("retry", nil)
	end
	if type(purchaseId) ~= "string" or purchaseId == "" then
		return empty("retry", nil)
	end
	if data.ProcessedPurchases[purchaseId] == true then
		return empty("duplicate", nil)
	end
	local key = Receipts.findKey(catalog, productId)
	if key == nil then
		return empty("unconfigured", nil)
	end
	local def = catalog.Products[key]
	if not Wallet.markPurchase(data, purchaseId) then
		return empty("duplicate", nil)
	end
	local ok, effects = applyKey(data, key, def, ctx, catalog)
	if not ok then
		data.ProcessedPurchases[purchaseId] = nil
		return empty("retry", key)
	end
	return { status = "granted", key = key, effects = effects }
end

return Receipts
