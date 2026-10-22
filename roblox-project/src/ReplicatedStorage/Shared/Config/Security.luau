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
		Honeypot = { Capacity = 1, LeakPerSec = 0.2 },
		Default = { Capacity = 5, LeakPerSec = 2 },
	},
	Upgrades = { "Pedestal", "VaultCap", "ReFiesta" },
}

return Security
