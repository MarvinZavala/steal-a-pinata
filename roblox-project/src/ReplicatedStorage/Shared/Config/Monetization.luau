--!strict
-- IDs = 0 hasta crear los pases/productos en el Creator Dashboard. Precios en Robux (GDD §9).
-- Un id 0 no se puede entregar: ProcessReceipt lo deja en NotProcessedYet.
return {
	GamePasses = {
		DoubleCandy = { Id = 0, Price = 249 },
		VipFiesta = { Id = 0, Price = 399 },
		ExtraPedestals = { Id = 0, Price = 199 },
		AutoCollect = { Id = 0, Price = 149 },
		BatSkinPack = { Id = 0, Price = 299 },
	},
	Products = {
		ServerLuck2x = { Id = 0, Price = 199, DurationSec = 15 * 60 },
		GoldenConveyor = { Id = 0, Price = 99, Spawns = 5 },
		SurpriseBox = { Id = 0, Price = 99 },
		CandyPackS = { Id = 0, Price = 49, Minutes = 10 },
		CandyPackM = { Id = 0, Price = 149, Minutes = 35 },
		CandyPackL = { Id = 0, Price = 449, Minutes = 120 },
		EmergencyLock = { Id = 0, Price = 25, CooldownSec = 600 },
		RewardedBoost = { Id = 0, Price = 0 },
		CosmeticTrail = { Id = 0, Price = 149, Grant = "trail_confetti" },
		CosmeticRibbon = { Id = 0, Price = 99, Grant = "trail_serpentina" },
		CosmeticDecor = { Id = 0, Price = 79, Grant = "base_banderin" },
		CosmeticPedestal = { Id = 0, Price = 199, Grant = "pedestal_oro" },
		CosmeticBat = { Id = 0, Price = 249, Grant = "bat_oro" },
	},
	-- Mismas probabilidades que muestra la Caja Sorpresa.
	SurpriseOdds = {
		{ Id = "trail_confetti", Weight = 50 },
		{ Id = "trail_serpentina", Weight = 25 },
		{ Id = "base_banderin", Weight = 15 },
		{ Id = "pedestal_oro", Weight = 8 },
		{ Id = "bat_oro", Weight = 2 },
	},
	-- Un repetido de la Caja Sorpresa paga estos minutos de producción en Dulces (lo dice la tienda).
	SurpriseDupeMinutes = 10,
	Rewarded = { ProductId = 0, BoostSec = 10 * 60, DailyLimit = 1 },
	-- Id vacío: la suscripción se crea en el dashboard. El servidor no cobra solo.
	Subscription = { Id = "", Price = 49, Name = "Pase Fiesta" },
	-- Se configura en la página de la experiencia, no se vende dentro del juego.
	PrivateServerPrice = 50,
}
