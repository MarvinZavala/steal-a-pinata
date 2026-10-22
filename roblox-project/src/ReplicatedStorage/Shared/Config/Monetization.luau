--!strict
-- IDs = 0 hasta crear los pases/productos en el Creator Dashboard. Precios en Robux (GDD §9).
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
		SurpriseBox = { Id = 0, Price = 99 }, -- cosmético, mostrar probabilidades
		CandyPackS = { Id = 0, Price = 49, Minutes = 10 },
		CandyPackM = { Id = 0, Price = 149, Minutes = 35 },
		CandyPackL = { Id = 0, Price = 449, Minutes = 120 },
		EmergencyLock = { Id = 0, Price = 25, CooldownSec = 600 },
	},
	PrivateServerPrice = 50,
}
