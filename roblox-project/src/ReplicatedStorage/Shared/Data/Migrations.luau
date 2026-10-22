--!strict
-- Esquema de jugador y migraciones versionadas (WP-02).
-- No muta la tabla de entrada: si el perfil está corrupto devuelve nil y el servidor no lo pisa.
local Migrations = {}

local VERSION = 2
Migrations.VERSION = VERSION

export type OwnedPinata = {
	InstanceId: string,
	PinataId: string,
	Mutation: string,
	ObtainedAt: number,
}

export type PlayerStats = {
	PlayTimeSec: number,
	FirstJoinUnix: number,
	LastJoinUnix: number,
	LastLeaveUnix: number,
	Steals: number,
	TimesRobbed: number,
	Bonks: number,
}

export type PlayerDaily = {
	LastClaimUnix: number,
	LastResetUnix: number,
	Streak: number,
}

export type PlayerData = {
	SchemaVersion: number,
	Dulces: number,
	Bastones: number,
	ReFiestas: number,
	PedestalsOwned: number,
	VaultCapTier: number,
	Inventory: { OwnedPinata },
	Placed: { [string]: string },
	Dex: { [string]: boolean },
	ProcessedPurchases: { [string]: boolean },
	Stats: PlayerStats,
	Daily: PlayerDaily,
	RookieSeconds: number,
}

export type Defaults = {
	pedestalsOwned: number,
	vaultCapTier: number,
	maxVaultTier: number,
	maxPedestalSlots: number,
	maxInventory: number,
	maxCurrency: number,
	maxReFiestas: number,
}

local MUTATIONS: { [string]: boolean } = {
	None = true,
	Golden = true,
	Rainbow = true,
	Christmas = true,
}

local function fail(reason: string): (PlayerData?, string?)
	return nil, reason
end

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function isGoodInt(n: any, max: number): boolean
	if not isFinite(n) or n % 1 ~= 0 or n < 0 or n > max then
		return false
	end
	return true
end

local function takeInt(value: any, fallback: number, max: number): (number?, string?)
	if value == nil then
		return fallback, nil
	end
	if not isGoodInt(value, max) then
		return nil, "bad_number"
	end
	return value, nil
end

local function takeIntMin(value: any, fallback: number, min: number, max: number): (number?, string?)
	local number, reason = takeInt(value, fallback, max)
	if number == nil then
		return nil, reason
	end
	if number < min then
		return nil, "bad_number"
	end
	return number, nil
end

local function isToken(value: any, maxLen: number): boolean
	if type(value) ~= "string" or #value == 0 or #value > maxLen then
		return false
	end
	if string.find(value, "%c") ~= nil then
		return false
	end
	return true
end

local function isPureArray(value: { [any]: any }): boolean
	local count = 0
	for key in value do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
			return false
		end
		count += 1
	end
	return count == #value
end

function Migrations.blank(defaults: Defaults): PlayerData
	return {
		SchemaVersion = VERSION,
		Dulces = 0,
		Bastones = 0,
		ReFiestas = 0,
		PedestalsOwned = defaults.pedestalsOwned,
		VaultCapTier = defaults.vaultCapTier,
		Inventory = {},
		Placed = {},
		Dex = {},
		ProcessedPurchases = {},
		Stats = {
			PlayTimeSec = 0,
			FirstJoinUnix = 0,
			LastJoinUnix = 0,
			LastLeaveUnix = 0,
			Steals = 0,
			TimesRobbed = 0,
			Bonks = 0,
		},
		Daily = {
			LastClaimUnix = 0,
			LastResetUnix = 0,
			Streak = 0,
		},
		RookieSeconds = 0,
	}
end

local function readInventory(raw: any, maxInventory: number): ({ OwnedPinata }?, string?)
	if raw == nil then
		return {}, nil
	end
	if type(raw) ~= "table" or not isPureArray(raw) then
		return nil, "bad_inventory"
	end
	if #raw > maxInventory then
		return nil, "bad_inventory"
	end
	local inventory: { OwnedPinata } = {}
	local seen: { [string]: boolean } = {}
	for _, entry in raw do
		if type(entry) ~= "table" then
			return nil, "bad_inventory"
		end
		if not isToken(entry.InstanceId, 64) or not isToken(entry.PinataId, 32) then
			return nil, "bad_inventory"
		end
		local instanceId = entry.InstanceId :: string
		if seen[instanceId] then
			return nil, "duplicate_instance"
		end
		seen[instanceId] = true
		local mutation = entry.Mutation
		if mutation == nil then
			mutation = "None"
		end
		if type(mutation) ~= "string" or MUTATIONS[mutation] ~= true then
			return nil, "bad_mutation"
		end
		local obtained = entry.ObtainedAt
		if obtained == nil then
			obtained = 0
		end
		if not isGoodInt(obtained, 1e15) then
			return nil, "bad_inventory"
		end
		table.insert(inventory, {
			InstanceId = instanceId,
			PinataId = entry.PinataId :: string,
			Mutation = mutation,
			ObtainedAt = obtained,
		})
	end
	return inventory, nil
end

local function readPlaced(raw: any, inventory: { OwnedPinata }, maxSlots: number): ({ [string]: string }?, string?)
	if raw == nil then
		return {}, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_placed"
	end
	local owned: { [string]: boolean } = {}
	for _, item in inventory do
		owned[item.InstanceId] = true
	end
	local placed: { [string]: string } = {}
	for key, value in raw do
		local slotKey: string?
		if type(key) == "string" and string.match(key, "^%d+$") ~= nil then
			slotKey = key
		elseif type(key) == "number" and key % 1 == 0 then
			slotKey = tostring(key)
		end
		if slotKey == nil or type(value) ~= "string" then
			return nil, "bad_placed"
		end
		local slot = tonumber(slotKey)
		if slot == nil or slot < 1 or slot > maxSlots then
			return nil, "bad_placed"
		end
		-- Un enlace a una instancia que ya no existe se tira; no se borra el perfil.
		if owned[value] == true then
			placed[tostring(slot)] = value
		end
	end
	return placed, nil
end

local function readDex(raw: any): ({ [string]: boolean }?, string?)
	if raw == nil then
		return {}, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_dex"
	end
	local dex: { [string]: boolean } = {}
	for key, value in raw do
		if type(key) ~= "string" or not isToken(key, 32) then
			return nil, "bad_dex"
		end
		if type(value) ~= "boolean" then
			return nil, "bad_dex"
		end
		if value == true then
			dex[key] = true
		end
	end
	return dex, nil
end

local function readPurchases(raw: any): ({ [string]: boolean }?, string?)
	if raw == nil then
		return {}, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_purchases"
	end
	local purchases: { [string]: boolean } = {}
	for key, value in raw do
		if not isToken(key, 80) or type(value) ~= "boolean" then
			return nil, "bad_purchases"
		end
		if value == true then
			purchases[key] = true
		end
	end
	return purchases, nil
end

local function readStats(raw: any, maxCurrency: number): (PlayerStats?, string?)
	local stats: PlayerStats = {
		PlayTimeSec = 0,
		FirstJoinUnix = 0,
		LastJoinUnix = 0,
		LastLeaveUnix = 0,
		Steals = 0,
		TimesRobbed = 0,
		Bonks = 0,
	}
	if raw == nil then
		return stats, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_stats"
	end
	local fields = { "PlayTimeSec", "FirstJoinUnix", "LastJoinUnix", "LastLeaveUnix", "Steals", "TimesRobbed", "Bonks" }
	for _, field in fields do
		local number, reason = takeInt(raw[field], 0, maxCurrency)
		if number == nil then
			return nil, reason
		end
		-- Asignación campo por campo: el tipo de PlayerStats no acepta indexar con string suelto.
		if field == "PlayTimeSec" then
			stats.PlayTimeSec = number
		elseif field == "FirstJoinUnix" then
			stats.FirstJoinUnix = number
		elseif field == "LastJoinUnix" then
			stats.LastJoinUnix = number
		elseif field == "LastLeaveUnix" then
			stats.LastLeaveUnix = number
		elseif field == "Steals" then
			stats.Steals = number
		elseif field == "TimesRobbed" then
			stats.TimesRobbed = number
		else
			stats.Bonks = number
		end
	end
	return stats, nil
end

local function readDaily(raw: any, maxCurrency: number, maxReFiestas: number): (PlayerDaily?, string?)
	local daily: PlayerDaily = {
		LastClaimUnix = 0,
		LastResetUnix = 0,
		Streak = 0,
	}
	if raw == nil then
		return daily, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_daily"
	end
	local claim, claimErr = takeInt(raw.LastClaimUnix, 0, maxCurrency)
	if claim == nil then
		return nil, claimErr
	end
	local reset, resetErr = takeInt(raw.LastResetUnix, 0, maxCurrency)
	if reset == nil then
		return nil, resetErr
	end
	local streak, streakErr = takeInt(raw.Streak, 0, maxReFiestas)
	if streak == nil then
		return nil, streakErr
	end
	daily.LastClaimUnix = claim
	daily.LastResetUnix = reset
	daily.Streak = streak
	return daily, nil
end

function Migrations.migrate(raw: any, defaults: Defaults): (PlayerData?, string?)
	if type(raw) ~= "table" or type(defaults) ~= "table" then
		return fail("not_table")
	end
	local version = raw.SchemaVersion
	if version == nil then
		version = 0
	end
	if not isGoodInt(version, 1000) then
		return fail("bad_version")
	end
	if version > VERSION then
		return fail("future_version")
	end

	local dulces, dulcesErr = takeInt(raw.Dulces, 0, defaults.maxCurrency)
	if dulces == nil then
		return fail(dulcesErr or "bad_number")
	end
	local bastones, bastonesErr = takeInt(raw.Bastones, 0, defaults.maxCurrency)
	if bastones == nil then
		return fail(bastonesErr or "bad_number")
	end
	local reFiestas, reFiestasErr = takeInt(raw.ReFiestas, 0, defaults.maxReFiestas)
	if reFiestas == nil then
		return fail(reFiestasErr or "bad_number")
	end
	local pedestals, pedestalsErr =
		takeIntMin(raw.PedestalsOwned, defaults.pedestalsOwned, 1, defaults.maxPedestalSlots)
	if pedestals == nil then
		return fail(pedestalsErr or "bad_number")
	end
	local vault, vaultErr = takeIntMin(raw.VaultCapTier, defaults.vaultCapTier, 1, defaults.maxVaultTier)
	if vault == nil then
		return fail(vaultErr or "bad_number")
	end
	local rookie, rookieErr = takeInt(raw.RookieSeconds, 0, defaults.maxCurrency)
	if rookie == nil then
		return fail(rookieErr or "bad_number")
	end

	local inventory, inventoryErr = readInventory(raw.Inventory, defaults.maxInventory)
	if inventory == nil then
		return fail(inventoryErr or "bad_inventory")
	end
	local placed, placedErr = readPlaced(raw.Placed, inventory, defaults.maxPedestalSlots)
	if placed == nil then
		return fail(placedErr or "bad_placed")
	end
	local dex, dexErr = readDex(raw.Dex)
	if dex == nil then
		return fail(dexErr or "bad_dex")
	end
	local stats, statsErr = readStats(raw.Stats, defaults.maxCurrency)
	if stats == nil then
		return fail(statsErr or "bad_stats")
	end
	local daily, dailyErr = readDaily(raw.Daily, defaults.maxCurrency, defaults.maxReFiestas)
	if daily == nil then
		return fail(dailyErr or "bad_daily")
	end

	-- v1 no tenía compras ni Bonks ni LastResetUnix: readStats/readDaily ya rellenan 0 si faltan.
	-- Esas claves solo se aceptan como fuente si el perfil ya declara v2 (o si venían en v1 y son válidas).
	local purchases: { [string]: boolean } = {}
	if version >= 1 then
		local read, purchaseErr = readPurchases(raw.ProcessedPurchases)
		if read == nil then
			return fail(purchaseErr or "bad_purchases")
		end
		purchases = read
	end

	local data = Migrations.blank(defaults)
	data.SchemaVersion = VERSION
	data.Dulces = dulces
	data.Bastones = bastones
	data.ReFiestas = reFiestas
	data.PedestalsOwned = pedestals
	data.VaultCapTier = vault
	data.RookieSeconds = rookie
	data.Inventory = inventory
	data.Placed = placed
	data.Dex = dex
	data.ProcessedPurchases = purchases
	data.Stats = stats
	data.Daily = daily
	return data, nil
end

return Migrations
