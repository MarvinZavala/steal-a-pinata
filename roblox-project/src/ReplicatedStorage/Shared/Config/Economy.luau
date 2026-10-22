--!strict
-- Números de diseño (GDD §4 y §6). Todo lo que se balancea vive aquí.
local Economy = {
	StartPedestals = 4,
	MaxPedestals = 8, -- +4 con Re-Fiesta 3 (2° piso)
	PedestalCostBase = 500,
	PedestalCostGrowth = 2.2,
	VaultCapSeconds = { 300, 600, 1200, 2400 }, -- tope de la Dulcería en segundos de producción
	OfflineRate = 0.5,
	OfflineCapHours = 8,
	ReFiestaMultiplierStep = 0.5,
	Walk = { Normal = 16, Carrying = 11 },
	Conveyor = { SpawnEverySec = 4, CrossSeconds = 40, LuckBoostMultiplier = 2 },
	Lock = { DurationSec = 30, VipBonusSec = 10, PerReFiestaSec = 5, MaxSec = 60, CooldownSec = 60, AfterRobbedFreeSec = 20 },
	Steal = { MaxDistance = 8, CooldownSec = 1.5, MaxPerVictimPer5Min = 2 },
	Bat = { CooldownSec = 0.8, MaxDistance = 9, MaxAngleDeg = 70, StunSec = 1.5 },
	RookieShieldSec = 15 * 60,
	Fiesta = { EverySec = 30 * 60, DurationSec = 180 },
	Mutations = {
		Golden = { Multiplier = 2, ConveyorChance = 0.03 },
		Rainbow = { Multiplier = 5, ConveyorChance = 0.003 },
		Christmas = { Multiplier = 3, ConveyorChance = 0 },
	},
}

-- Multiplicador aditivo (GDD §6.2)
function Economy.totalMultiplier(reFiestas: number, has2x: boolean, hasVip: boolean, setsDone: number): number
	return 1 + Economy.ReFiestaMultiplierStep * reFiestas + (has2x and 1 or 0) + (hasVip and 0.5 or 0) + 0.05 * setsDone
end

return Economy
