--!strict
-- Esquema de jugador y migraciones versionadas (WP-02).
-- No muta la tabla de entrada: si el perfil está corrupto devuelve nil y el servidor no lo pisa.
local Migrations = {}

local VERSION = 4
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
	Buys: number,
	Collects: number,
	FiestaCandy: number,
}

export type PlayerPasses = {
	DoubleCandy: boolean,
	Vip: boolean,
	ExtraPedestals: boolean,
	AutoCollect: boolean,
	BatPack: boolean,
}

export type PlayerSubscription = {
	Active: boolean,
	LastPinataDay: number,
	LastBoxWeek: number,
}

export type PlayerDaily = {
	LastClaimUnix: number,
	LastResetUnix: number,
	Streak: number,
	ClaimedDay: number,
	QuestDay: number,
	QuestClaimedMask: number,
	BaselineBuys: number,
	BaselineBonks: number,
	BaselineSteals: number,
	BaselineCollects: number,
	BaselineFiesta: number,
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
	-- Dulces ya generados que todavía no se reclamaron en la Dulcería.
	VaultCandy: number,
	-- Unix hasta el que el candado manual no se puede volver a prender.
	LockReadyUnix: number,
	-- Unix de los últimos robos sufridos (ventana de 5 min, tope corto).
	RobbedUnix: { number },
	-- La intro de 60 s ya se cumplió (o se saltó). No vuelve a regalar el Michi.
	FtueCompleted: boolean,
	Passes: PlayerPasses,
	Cosmetics: { [string]: boolean },
	Subscription: PlayerSubscription,
	EmergencyCharges: number,
	EmergencyLockUnix: number,
	BatTier: number,
	BatUpgrade: number,
	RewardedBoostUntil: number,
	RewardedDay: number,
	-- Adviento: bit 0 = 11 dic. Las misiones de evento se reinician por día UTC.
	AdventMask: number,
	EventQuestMask: number,
	EventQuestDay: number,
	-- Día UTC del último regalo entre amigos (0 = nunca).
	GiftDay: number,
	-- Los Bastones ya se convirtieron en Dulces después del 7 de enero.
	BastonesSettled: boolean,
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
			Buys = 0,
			Collects = 0,
			FiestaCandy = 0,
		},
		Daily = {
			LastClaimUnix = 0,
			LastResetUnix = 0,
			Streak = 0,
			ClaimedDay = 0,
			QuestDay = 0,
			QuestClaimedMask = 0,
			BaselineBuys = 0,
			BaselineBonks = 0,
			BaselineSteals = 0,
			BaselineCollects = 0,
			BaselineFiesta = 0,
		},
		RookieSeconds = 0,
		VaultCandy = 0,
		LockReadyUnix = 0,
		RobbedUnix = {},
		FtueCompleted = false,
		Passes = {
			DoubleCandy = false,
			Vip = false,
			ExtraPedestals = false,
			AutoCollect = false,
			BatPack = false,
		},
		Cosmetics = {},
		Subscription = {
			Active = false,
			LastPinataDay = 0,
			LastBoxWeek = 0,
		},
		EmergencyCharges = 0,
		EmergencyLockUnix = 0,
		BatTier = 0,
		BatUpgrade = 0,
		RewardedBoostUntil = 0,
		RewardedDay = 0,
		AdventMask = 0,
		EventQuestMask = 0,
		EventQuestDay = 0,
		GiftDay = 0,
		BastonesSettled = false,
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
		Buys = 0,
		Collects = 0,
		FiestaCandy = 0,
	}
	if raw == nil then
		return stats, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_stats"
	end
	local play, playErr = takeInt(raw.PlayTimeSec, 0, maxCurrency)
	local first, firstErr = takeInt(raw.FirstJoinUnix, 0, maxCurrency)
	local lastJoin, joinErr = takeInt(raw.LastJoinUnix, 0, maxCurrency)
	local lastLeave, leaveErr = takeInt(raw.LastLeaveUnix, 0, maxCurrency)
	local steals, stealsErr = takeInt(raw.Steals, 0, maxCurrency)
	local robbed, robbedErr = takeInt(raw.TimesRobbed, 0, maxCurrency)
	local bonks, bonksErr = takeInt(raw.Bonks, 0, maxCurrency)
	local buys, buysErr = takeInt(raw.Buys, 0, maxCurrency)
	local collects, collectsErr = takeInt(raw.Collects, 0, maxCurrency)
	local fiesta, fiestaErr = takeInt(raw.FiestaCandy, 0, maxCurrency)
	if
		play == nil
		or first == nil
		or lastJoin == nil
		or lastLeave == nil
		or steals == nil
		or robbed == nil
		or bonks == nil
		or buys == nil
		or collects == nil
		or fiesta == nil
	then
		return nil,
			playErr
				or firstErr
				or joinErr
				or leaveErr
				or stealsErr
				or robbedErr
				or bonksErr
				or buysErr
				or collectsErr
				or fiestaErr
	end
	stats.PlayTimeSec = play
	stats.FirstJoinUnix = first
	stats.LastJoinUnix = lastJoin
	stats.LastLeaveUnix = lastLeave
	stats.Steals = steals
	stats.TimesRobbed = robbed
	stats.Bonks = bonks
	stats.Buys = buys
	stats.Collects = collects
	stats.FiestaCandy = fiesta
	return stats, nil
end

local function readDaily(raw: any, maxCurrency: number): (PlayerDaily?, string?)
	local daily: PlayerDaily = {
		LastClaimUnix = 0,
		LastResetUnix = 0,
		Streak = 0,
		ClaimedDay = 0,
		QuestDay = 0,
		QuestClaimedMask = 0,
		BaselineBuys = 0,
		BaselineBonks = 0,
		BaselineSteals = 0,
		BaselineCollects = 0,
		BaselineFiesta = 0,
	}
	if raw == nil then
		return daily, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_daily"
	end
	local claim, claimErr = takeInt(raw.LastClaimUnix, 0, maxCurrency)
	local reset, resetErr = takeInt(raw.LastResetUnix, 0, maxCurrency)
	-- La racha puede pasar de maxReFiestas: es un índice de días, no un nivel.
	local streak, streakErr = takeInt(raw.Streak, 0, maxCurrency)
	local claimedDay, claimedErr = takeInt(raw.ClaimedDay, 0, maxCurrency)
	local questDay, questErr = takeInt(raw.QuestDay, 0, maxCurrency)
	local mask, maskErr = takeInt(raw.QuestClaimedMask, 0, maxCurrency)
	local baseBuys, baseBuysErr = takeInt(raw.BaselineBuys, 0, maxCurrency)
	local baseBonks, baseBonksErr = takeInt(raw.BaselineBonks, 0, maxCurrency)
	local baseSteals, baseStealsErr = takeInt(raw.BaselineSteals, 0, maxCurrency)
	local baseCollects, baseCollectsErr = takeInt(raw.BaselineCollects, 0, maxCurrency)
	local baseFiesta, baseFiestaErr = takeInt(raw.BaselineFiesta, 0, maxCurrency)
	if
		claim == nil
		or reset == nil
		or streak == nil
		or claimedDay == nil
		or questDay == nil
		or mask == nil
		or baseBuys == nil
		or baseBonks == nil
		or baseSteals == nil
		or baseCollects == nil
		or baseFiesta == nil
	then
		return nil,
			claimErr
				or resetErr
				or streakErr
				or claimedErr
				or questErr
				or maskErr
				or baseBuysErr
				or baseBonksErr
				or baseStealsErr
				or baseCollectsErr
				or baseFiestaErr
	end
	daily.LastClaimUnix = claim
	daily.LastResetUnix = reset
	daily.Streak = streak
	daily.ClaimedDay = claimedDay
	daily.QuestDay = questDay
	daily.QuestClaimedMask = mask
	daily.BaselineBuys = baseBuys
	daily.BaselineBonks = baseBonks
	daily.BaselineSteals = baseSteals
	daily.BaselineCollects = baseCollects
	daily.BaselineFiesta = baseFiesta
	return daily, nil
end

local function readPasses(raw: any): (PlayerPasses?, string?)
	local passes: PlayerPasses = {
		DoubleCandy = false,
		Vip = false,
		ExtraPedestals = false,
		AutoCollect = false,
		BatPack = false,
	}
	if raw == nil then
		return passes, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_passes"
	end
	local function flag(value: any): (boolean?, string?)
		if value == nil then
			return false, nil
		end
		if type(value) ~= "boolean" then
			return nil, "bad_passes"
		end
		return value, nil
	end
	local doubleCandy, doubleErr = flag(raw.DoubleCandy)
	local vip, vipErr = flag(raw.Vip)
	local extra, extraErr = flag(raw.ExtraPedestals)
	local auto, autoErr = flag(raw.AutoCollect)
	local bat, batErr = flag(raw.BatPack)
	if doubleCandy == nil or vip == nil or extra == nil or auto == nil or bat == nil then
		return nil, doubleErr or vipErr or extraErr or autoErr or batErr
	end
	passes.DoubleCandy = doubleCandy
	passes.Vip = vip
	passes.ExtraPedestals = extra
	passes.AutoCollect = auto
	passes.BatPack = bat
	return passes, nil
end

local function readCosmetics(raw: any): ({ [string]: boolean }?, string?)
	if raw == nil then
		return {}, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_cosmetics"
	end
	local cosmetics: { [string]: boolean } = {}
	for key, value in raw do
		if type(key) ~= "string" or not isToken(key, 32) then
			return nil, "bad_cosmetics"
		end
		if type(value) ~= "boolean" then
			return nil, "bad_cosmetics"
		end
		if value == true then
			cosmetics[key] = true
		end
	end
	return cosmetics, nil
end

local function readSubscription(raw: any, maxCurrency: number): (PlayerSubscription?, string?)
	local sub: PlayerSubscription = {
		Active = false,
		LastPinataDay = 0,
		LastBoxWeek = 0,
	}
	if raw == nil then
		return sub, nil
	end
	if type(raw) ~= "table" then
		return nil, "bad_subscription"
	end
	if raw.Active ~= nil and type(raw.Active) ~= "boolean" then
		return nil, "bad_subscription"
	end
	local pinataDay, pinataErr = takeInt(raw.LastPinataDay, 0, maxCurrency)
	local boxWeek, boxErr = takeInt(raw.LastBoxWeek, 0, maxCurrency)
	if pinataDay == nil or boxWeek == nil then
		return nil, pinataErr or boxErr
	end
	sub.Active = raw.Active == true
	sub.LastPinataDay = pinataDay
	sub.LastBoxWeek = boxWeek
	return sub, nil
end

local function readUnixList(raw: any, maxCount: number, maxValue: number): ({ number }?, string?)
	if raw == nil then
		return {}, nil
	end
	if type(raw) ~= "table" or not isPureArray(raw) or #raw > maxCount then
		return nil, "bad_robbed"
	end
	local list: { number } = {}
	for _, value in raw do
		if not isGoodInt(value, maxValue) then
			return nil, "bad_robbed"
		end
		table.insert(list, value)
	end
	return list, nil
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
	local vaultCandy, vaultCandyErr = takeInt(raw.VaultCandy, 0, defaults.maxCurrency)
	if vaultCandy == nil then
		return fail(vaultCandyErr or "bad_number")
	end
	local lockReady, lockReadyErr = takeInt(raw.LockReadyUnix, 0, defaults.maxCurrency)
	if lockReady == nil then
		return fail(lockReadyErr or "bad_number")
	end
	local robbedUnix, robbedErr = readUnixList(raw.RobbedUnix, 8, defaults.maxCurrency)
	if robbedUnix == nil then
		return fail(robbedErr or "bad_robbed")
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
	local daily, dailyErr = readDaily(raw.Daily, defaults.maxCurrency)
	if daily == nil then
		return fail(dailyErr or "bad_daily")
	end
	local passes, passesErr = readPasses(raw.Passes)
	if passes == nil then
		return fail(passesErr or "bad_passes")
	end
	local cosmetics, cosmeticsErr = readCosmetics(raw.Cosmetics)
	if cosmetics == nil then
		return fail(cosmeticsErr or "bad_cosmetics")
	end
	local subscription, subErr = readSubscription(raw.Subscription, defaults.maxCurrency)
	if subscription == nil then
		return fail(subErr or "bad_subscription")
	end
	local charges, chargesErr = takeInt(raw.EmergencyCharges, 0, defaults.maxCurrency)
	if charges == nil then
		return fail(chargesErr or "bad_number")
	end
	local emergencyAt, emergencyErr = takeInt(raw.EmergencyLockUnix, 0, defaults.maxCurrency)
	if emergencyAt == nil then
		return fail(emergencyErr or "bad_number")
	end
	local batTier, batTierErr = takeInt(raw.BatTier, 0, defaults.maxReFiestas)
	if batTier == nil then
		return fail(batTierErr or "bad_number")
	end
	local batUpgrade, batUpgradeErr = takeInt(raw.BatUpgrade, 0, 8)
	if batUpgrade == nil then
		return fail(batUpgradeErr or "bad_number")
	end
	local boostUntil, boostErr = takeInt(raw.RewardedBoostUntil, 0, defaults.maxCurrency)
	if boostUntil == nil then
		return fail(boostErr or "bad_number")
	end
	local rewardedDay, rewardedErr = takeInt(raw.RewardedDay, 0, defaults.maxCurrency)
	if rewardedDay == nil then
		return fail(rewardedErr or "bad_number")
	end
	local adventMask, adventErr = takeInt(raw.AdventMask, 0, defaults.maxCurrency)
	if adventMask == nil then
		return fail(adventErr or "bad_number")
	end
	local eventQuestMask, eventQuestErr = takeInt(raw.EventQuestMask, 0, defaults.maxCurrency)
	if eventQuestMask == nil then
		return fail(eventQuestErr or "bad_number")
	end
	local eventQuestDay, eventQuestDayErr = takeInt(raw.EventQuestDay, 0, defaults.maxCurrency)
	if eventQuestDay == nil then
		return fail(eventQuestDayErr or "bad_number")
	end
	local giftDay, giftDayErr = takeInt(raw.GiftDay, 0, defaults.maxCurrency)
	if giftDay == nil then
		return fail(giftDayErr or "bad_number")
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
	data.VaultCandy = vaultCandy
	data.LockReadyUnix = lockReady
	data.RobbedUnix = robbedUnix
	-- Un valor que no es true (ausente, string, número) queda en false. No rechaza el perfil.
	data.FtueCompleted = raw.FtueCompleted == true
	data.Inventory = inventory
	data.Placed = placed
	data.Dex = dex
	data.ProcessedPurchases = purchases
	data.Stats = stats
	data.Daily = daily
	data.Passes = passes
	data.Cosmetics = cosmetics
	data.Subscription = subscription
	data.EmergencyCharges = charges
	data.EmergencyLockUnix = emergencyAt
	data.BatTier = batTier
	data.BatUpgrade = batUpgrade
	data.RewardedBoostUntil = boostUntil
	data.RewardedDay = rewardedDay
	data.AdventMask = adventMask
	data.EventQuestMask = eventQuestMask
	data.EventQuestDay = eventQuestDay
	data.GiftDay = giftDay
	-- Ausente o cualquier cosa que no sea true queda en false. No rechaza el perfil.
	data.BastonesSettled = raw.BastonesSettled == true
	return data, nil
end

return Migrations
