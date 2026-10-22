--!strict
-- Números de diseño (GDD §4 y §6). Todo lo que se balancea vive aquí.
local Economy = {
	StartPedestals = 4,
	MaxPedestals = 8, -- piso de abajo. El pase +2 suma sin abrir el 2° piso entero.
	MaxPedestalSlots = 12, -- tope absoluto (2° piso en Re-Fiesta 3)
	ExtraPedestals = 2,
	ReFiestaFloorAt = 3,
	PedestalCostBase = 500,
	PedestalCostGrowth = 2.2,
	VaultCapSeconds = { 300, 600, 1200, 2400 }, -- tope de la Dulcería en segundos de producción
	-- Costo para LLEGAR a ese tier (el 1 es el inicial).
	VaultUpgradeCost = { [2] = 2500, [3] = 15000, [4] = 80000 },
	OfflineRate = 0.5,
	OfflineCapHours = 8,
	ReFiestaMultiplierStep = 0.5,
	-- El GDD pone 500K como ejemplo. En la simulación (semilla 20261022) eso caía ~al minuto 41.
	-- ×11 lleva la primera Re-Fiesta a la hora 2–3 sin tocar precios de Rara/Épica.
	-- Los niveles siguientes van en la misma proporción.
	ReFiestaTiers = {
		{ Candy = 5500000, Rarity = "Epic", Count = 1 },
		{ Candy = 27500000, Rarity = "Legendary", Count = 1 },
		{ Candy = 132000000, Rarity = "Mythic", Count = 1 },
		{ Candy = 440000000, Rarity = "Legendary", Count = 2 },
		{ Candy = 1320000000, Rarity = "Mythic", Count = 1 },
	},
	ReFiestaCandyGrowth = 3.2,
	ReFiestaCandy = 5500000, -- el kiosco viejo lee este número; el nivel 1 coincide
	Walk = { Normal = 16, Carrying = 11 },
	Buy = { MaxDistance = 12 }, -- GDD §3.1, prompt de la Pasarela
	Conveyor = { SpawnEverySec = 4, CrossSeconds = 40, LuckBoostMultiplier = 2, AnnounceLeadSec = 5 },
	Return = { ProtectSec = 3, WalkSpeed = 14 },
	StealPromptHoldSec = 0.6,
	Lock = {
		DurationSec = 30,
		VipBonusSec = 10,
		PerReFiestaSec = 5,
		MaxSec = 60,
		CooldownSec = 60,
		AfterRobbedFreeSec = 20,
	},
	Steal = { MaxDistance = 8, CooldownSec = 1.5, MaxPerVictimPer5Min = 2, WindowSec = 5 * 60 },
	Bat = { CooldownSec = 0.8, MaxDistance = 9, MaxAngleDeg = 70, StunSec = 1.5 },
	-- El bate nuevo de cada Re-Fiesta empuja más. El de Dulces también. Tope para que no sea un cohete.
	BatPushPerReFiesta = 0.06,
	BatPushPerUpgrade = 0.1,
	BatPushCap = 1.6,
	BatUpgradeCost = { 2000, 15000, 80000, 400000 },
	RookieShieldSec = 15 * 60,
	Fiesta = {
		EverySec = 30 * 60,
		DurationSec = 180,
		GiantSec = 40,
		SpawnEverySec = 2.5,
		MaxAlive = 8,
		WildHp = 2,
		CaptureChance = 0.12,
		GiantBaseHp = 48,
		GiantHpPerPlayer = 6,
		PoolBase = 8000,
		PoolPerHit = 35,
		HitCandy = {
			Common = 20,
			Uncommon = 45,
			Rare = 120,
			Epic = 400,
			Legendary = 1200,
			Mythic = 4000,
			Secret = 8000,
			Event = 200,
		},
	},
	FusionRainbowChance = 0.1,
	Mutations = {
		Golden = { Multiplier = 2, ConveyorChance = 0.03 },
		Rainbow = { Multiplier = 5, ConveyorChance = 0.003 },
		Christmas = { Multiplier = 3, ConveyorChance = 0 },
	},
	SetBonus = 0.05,
}

export type ReFiestaOffer = { Candy: number, Rarity: string, Count: number }

local RANK: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
	Event = 4,
}

function Economy.rarityRank(rarity: string): number
	return RANK[rarity] or 0
end

-- Multiplicador aditivo (GDD §6.2). El "2x" suma +1, no duplica.
function Economy.totalMultiplier(reFiestas: number, has2x: boolean, hasVip: boolean, setsDone: number): number
	return 1
		+ Economy.ReFiestaMultiplierStep * reFiestas
		+ (if has2x then 1 else 0)
		+ (if hasVip then 0.5 else 0)
		+ Economy.SetBonus * setsDone
end

-- nextIndex es el pedestal que se está comprando (5 = el primero de pago).
function Economy.pedestalPrice(nextIndex: number): number
	local step = nextIndex - Economy.StartPedestals
	if step < 1 then
		step = 1
	end
	local raw = Economy.PedestalCostBase * (Economy.PedestalCostGrowth ^ (step - 1))
	return math.floor(raw + 0.5)
end

function Economy.vaultCost(tier: number): number
	local cost = Economy.VaultUpgradeCost[tier]
	if type(cost) ~= "number" then
		return 0
	end
	return cost
end

function Economy.batUpgradeCost(nextTier: number): number
	local cost = Economy.BatUpgradeCost[nextTier]
	if type(cost) ~= "number" then
		return 0
	end
	return cost
end

-- El pase suma 2 sin pasar de 12. Re-Fiesta 3 abre el piso (12) y el pase no lo salta antes.
function Economy.pedestalCap(reFiestas: number, extraPass: boolean): number
	local cap = Economy.MaxPedestals
	if extraPass then
		cap += Economy.ExtraPedestals
	end
	if reFiestas >= Economy.ReFiestaFloorAt then
		cap = Economy.MaxPedestalSlots
	end
	if cap > Economy.MaxPedestalSlots then
		cap = Economy.MaxPedestalSlots
	end
	return cap
end

function Economy.refiestaOffer(level: number): ReFiestaOffer
	local safe = if level < 1 then 1 else level
	local row = Economy.ReFiestaTiers[safe]
	if row ~= nil then
		return { Candy = row.Candy, Rarity = row.Rarity, Count = row.Count }
	end
	local last = Economy.ReFiestaTiers[#Economy.ReFiestaTiers]
	local candy = last.Candy
	local extra = safe - #Economy.ReFiestaTiers
	for _ = 1, extra do
		candy = math.floor(candy * Economy.ReFiestaCandyGrowth)
	end
	return { Candy = candy, Rarity = last.Rarity, Count = last.Count }
end

function Economy.pushScale(reFiestas: number, batUpgrade: number): number
	local scale = 1
		+ Economy.BatPushPerReFiesta * math.max(0, reFiestas)
		+ Economy.BatPushPerUpgrade * math.max(0, batUpgrade)
	if scale > Economy.BatPushCap then
		return Economy.BatPushCap
	end
	return scale
end

return Economy
