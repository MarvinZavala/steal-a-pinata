--!strict
-- Límites técnicos de la capa anti-cheat (GDD §7).
-- Distancias, cooldowns y velocidades de juego viven en Config/Economy.luau.
local Security = {
	MapHalfExtent = 10000,
	-- Por encima de Walk.Normal * este factor (más TeleportSlackStuds) se loguea. No banea.
	SpeedMultiplier = 2,
	TeleportSlackStuds = 12,
	SpeedSampleSec = 0.3,
	MaxCurrency = 1e15,
	MaxInventory = 400,
	MaxReFiestas = 500,
	-- A partir de esta cantidad de flags en la sesión se ignoran las intenciones (no hay ban automático).
	FlagRestrictAt = 15,
	Bounds = {
		Slot = { Min = 1, Max = 100000 },
		-- Los jugadores de prueba de Studio usan UserId negativo. 0 no es un id.
		UserId = { Min = -1000000000, Max = 10000000000 },
		Pedestal = { Min = 1, Max = 12 },
		String = { MaxLen = 32 },
	},
	-- Leaky bucket. La capacidad tiene que quedar muy por debajo de 100 req/s (criterio WP-10a).
	Rates = {
		RequestBuy = { Capacity = 5, LeakPerSec = 2 },
		RequestSteal = { Capacity = 3, LeakPerSec = 1 },
		RequestSwing = { Capacity = 4, LeakPerSec = 2 },
		RequestLock = { Capacity = 2, LeakPerSec = 1 },
		RequestUpgrade = { Capacity = 3, LeakPerSec = 1 },
		RequestFuse = { Capacity = 2, LeakPerSec = 1 },
		RequestCollect = { Capacity = 3, LeakPerSec = 1 },
		RequestSettings = { Capacity = 2, LeakPerSec = 1 },
		RequestFTUEStep = { Capacity = 4, LeakPerSec = 1 },
		RequestFTUEAction = { Capacity = 4, LeakPerSec = 1 },
		RequestClaimDaily = { Capacity = 2, LeakPerSec = 0.2 },
		RequestClaimQuest = { Capacity = 3, LeakPerSec = 1 },
		RequestClaimAdvent = { Capacity = 2, LeakPerSec = 0.2 },
		RequestEventBuy = { Capacity = 3, LeakPerSec = 1 },
		RequestGift = { Capacity = 2, LeakPerSec = 0.2 },
		RequestRewarded = { Capacity = 2, LeakPerSec = 0.2 },
		Honeypot = { Capacity = 1, LeakPerSec = 0.2 },
		Default = { Capacity = 5, LeakPerSec = 2 },
	},
	Upgrades = { "Pedestal", "VaultCap", "ReFiesta", "Bat" },
	Quests = { "1", "2", "3", "e1", "e2", "e3" },
	EventSkus = { "tamalito", "jengibrin", "gorro_navidad", "abrazo" },
	-- Pasos del embudo §10.1 y acciones que la UI pide. El servidor no vuelve a loguear el funnel.
	FtueSteps = {
		"1_spawn",
		"2_arrow_followed",
		"3_first_claim",
		"4_thief_seen",
		"5_first_bonk",
		"6_first_income",
		"7_first_collect",
		"8_first_purchase",
	},
	FtueActions = { "claim", "bonk", "collect", "buy", "complete", "skip" },
	Locales = { "auto", "es", "en", "pt" },
}

return Security
