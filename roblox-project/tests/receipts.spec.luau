--!strict
local H = require("./harness")
local Migrations = require("../src/ReplicatedStorage/Shared/Data/Migrations")
local Receipts = require("../src/ReplicatedStorage/Shared/Gameplay/Receipts")
local PaidRandom = require("../src/ReplicatedStorage/Shared/Gameplay/PaidRandom")
local Security = require("../src/ReplicatedStorage/Shared/Config/Security")
local defaults = require("./defaults")

H.begin()

local function catalog()
	return {
		Products = {
			ServerLuck2x = { Id = 1001, Price = 199, DurationSec = 900 },
			GoldenConveyor = { Id = 1002, Price = 99, Spawns = 5 },
			SurpriseBox = { Id = 1003, Price = 99 },
			CandyPackS = { Id = 1004, Price = 49, Minutes = 10 },
			CandyPackM = { Id = 1005, Price = 149, Minutes = 35 },
			CandyPackL = { Id = 1006, Price = 449, Minutes = 120 },
			EmergencyLock = { Id = 1007, Price = 25, CooldownSec = 600 },
			RewardedBoost = { Id = 1008, Price = 0 },
			CosmeticBat = { Id = 1009, Price = 149, Grant = "bat_oro" },
		},
		SurpriseOdds = {
			{ Id = "trail_confetti", Weight = 50 },
			{ Id = "bat_oro", Weight = 50 },
		},
		Rewarded = { BoostSec = 600, DailyLimit = 1 },
	}
end

local function ctx(now: number, today: number, perSec: number, roll: number)
	return {
		productionPerSec = perSec,
		now = now,
		roll = roll,
		maxCurrency = Security.MaxCurrency,
		today = today,
	}
end

H.check("el mismo PurchaseId no entrega dos veces", function()
	local data = Migrations.migrate({}, defaults()) :: any
	local first = Receipts.commit(data, catalog(), "abc-1", 1004, ctx(1_000, 10, 2, 0.1))
	H.eq(first.status, "granted")
	H.eq(data.Dulces, 2 * 10 * 60)
	local again = Receipts.commit(data, catalog(), "abc-1", 1004, ctx(1_100, 10, 2, 0.1))
	H.eq(again.status, "duplicate")
	H.eq(data.Dulces, 1200)
	H.eq(data.ProcessedPurchases["abc-1"], true)
end)

H.check("otro PurchaseId del mismo producto sí suma, y el id 0 no se marca", function()
	local data = Migrations.migrate({}, defaults()) :: any
	local pack = Receipts.commit(data, catalog(), "one", 1004, ctx(1, 1, 0, 0))
	H.eq(pack.status, "granted")
	-- Sin producción se usa 1 Dulce/s para que el paquete no quede en cero.
	H.eq(data.Dulces, 600)
	local second = Receipts.commit(data, catalog(), "two", 1004, ctx(2, 1, 0, 0))
	H.eq(second.status, "granted")
	H.eq(data.Dulces, 1200)
	local missing = Receipts.commit(data, catalog(), "zero", 0, ctx(3, 1, 1, 0))
	H.eq(missing.status, "unconfigured")
	H.eq(data.ProcessedPurchases.zero, nil)
	H.eq(data.Dulces, 1200)
end)

H.check("suerte, pasarela, caja, candado y cosmético dejan efecto sin duplicar", function()
	local data = Migrations.migrate({}, defaults()) :: any
	local luck = Receipts.commit(data, catalog(), "luck", 1001, ctx(50, 1, 1, 0))
	H.eq(luck.status, "granted")
	H.eq(luck.effects[1].kind, "serverLuck")
	H.eq(luck.effects[1].seconds, 900)
	local gold = Receipts.commit(data, catalog(), "gold", 1002, ctx(50, 1, 1, 0))
	H.eq(gold.effects[1].spawns, 5)
	local box = Receipts.commit(data, catalog(), "box", 1003, ctx(50, 1, 1, 0.1))
	H.eq(box.effects[1].cosmeticId, "trail_confetti")
	H.eq(data.Cosmetics.trail_confetti, true)
	local late = Receipts.commit(data, catalog(), "box", 1003, ctx(50, 1, 1, 0.9))
	H.eq(late.status, "duplicate")
	H.eq(data.Cosmetics.bat_oro, nil)
	local lock = Receipts.commit(data, catalog(), "lock", 1007, ctx(50, 1, 1, 0))
	H.eq(data.EmergencyCharges, 1)
	H.eq(lock.effects[1].kind, "emergency")
	local again = Receipts.commit(data, catalog(), "lock-2", 1007, ctx(50, 1, 1, 0))
	H.eq(again.status, "granted")
	H.eq(data.EmergencyCharges, 2)
	local skin = Receipts.commit(data, catalog(), "skin", 1009, ctx(50, 1, 1, 0))
	H.eq(skin.effects[1].cosmeticId, "bat_oro")
	H.eq(data.Cosmetics.bat_oro, true)
end)

H.check("el video del mismo día no apila el boost y el día siguiente sí", function()
	local data = Migrations.migrate({}, defaults()) :: any
	local first = Receipts.commit(data, catalog(), "ad-1", 1008, ctx(1_000, 4, 1, 0))
	H.eq(first.status, "granted")
	H.eq(first.effects[1].kind, "boost")
	H.eq(data.RewardedBoostUntil, 1600)
	local second = Receipts.commit(data, catalog(), "ad-2", 1008, ctx(1_100, 4, 1, 0))
	H.eq(second.status, "granted")
	H.eq(second.effects[1].kind, "noop")
	H.eq(data.RewardedBoostUntil, 1600)
	local nextDay = Receipts.commit(data, catalog(), "ad-3", 1008, ctx(90_000, 5, 1, 0))
	H.eq(nextDay.effects[1].kind, "boost")
	H.eq(data.RewardedBoostUntil, 90600)
end)

H.check("ids repetidos en el catálogo no se pueden cobrar", function()
	local data = Migrations.migrate({}, defaults()) :: any
	local ambiguous = {
		Products = {
			A = { Id = 5, Minutes = 10 },
			B = { Id = 5, Minutes = 10 },
		},
	}
	local result = Receipts.commit(data, ambiguous, "x", 5, ctx(1, 1, 1, 0))
	H.eq(result.status, "unconfigured")
	H.eq(data.ProcessedPurchases.x, nil)
	H.eq(data.Dulces, 0)
end)

H.check("Caja Sorpresa: un repetido paga Dulces (lo dice la tienda)", function()
	local data = Migrations.migrate({}, defaults()) :: any
	-- roll 0.1 cae en trail_confetti (primer 50%)
	local first = Receipts.commit(data, catalog(), "box-1", 1003, ctx(1, 1, 3, 0.1))
	H.eq(first.status, "granted")
	H.eq(data.Cosmetics.trail_confetti, true)
	H.eq(data.Dulces, 0)
	local dupe = Receipts.commit(data, catalog(), "box-2", 1003, ctx(2, 1, 3, 0.1))
	H.eq(dupe.status, "granted")
	-- SurpriseDupeMinutes por defecto = 10 minutos de producción
	H.eq(data.Dulces, 3 * 10 * 60)
end)

H.check("Caja Sorpresa con ArePaidRandomItemsRestricted: secuencia conocida, sin azar", function()
	local data = Migrations.migrate({}, defaults()) :: any
	local seq = ctx(1, 1, 2, 0.99)
	seq.sequence = true
	-- roll 0.99 sortearía bat_oro; la secuencia da el primero que no tiene
	H.eq(Receipts.commit(data, catalog(), "s-1", 1003, seq).status, "granted")
	H.eq(data.Cosmetics.trail_confetti, true)
	H.eq(data.Cosmetics.bat_oro, nil)
	H.eq(Receipts.commit(data, catalog(), "s-2", 1003, seq).status, "granted")
	H.eq(data.Cosmetics.bat_oro, true)
	-- Secuencia completa: paga Dulces en vez de nada
	H.eq(Receipts.commit(data, catalog(), "s-3", 1003, seq).status, "granted")
	H.eq(data.Dulces, 2 * 10 * 60)
end)

H.check("PaidRandom: probabilidades de la Pasarela con Suerte y Pasarela Dorada", function()
	local weights = { Common = 62, Uncommon = 25, Rare = 9, Epic = 3, Legendary = 0.8, Mythic = 0.19, Secret = 0.01 }
	local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Event" }
	local boosted = { Rare = true, Epic = true, Legendary = true, Mythic = true, Secret = true }
	local function byRarity(rows)
		local map = {}
		local total = 0
		for _, row in rows do
			map[row.rarity] = row.percent
			total += row.percent
		end
		return map, total
	end
	local plain, plainTotal = byRarity(PaidRandom.rarityOdds(weights, order, false, boosted, nil))
	H.eq(plain.Common, 62)
	H.eq(plain.Secret, 0.01)
	H.truthy(math.abs(plainTotal - 100) < 0.2, "suma 100")
	local luck = byRarity(PaidRandom.rarityOdds(weights, order, true, boosted, nil))
	-- Rara+ se dobla: 9*2 / (62+25+26) = 15.9 %
	H.eq(luck.Rare, 15.9)
	H.truthy(luck.Common < plain.Common, "la suerte baja las comunes")
	local golden = byRarity(PaidRandom.rarityOdds(weights, order, false, boosted, "Rare"))
	H.eq(golden.Common, nil)
	H.eq(golden.Uncommon, nil)
	H.eq(golden.Rare, 96)
	H.eq(PaidRandom.nextInSequence({ { Id = "a", Weight = 1 }, { Id = "b", Weight = 1 } }, { a = true }), "b")
	H.eq(PaidRandom.nextInSequence({ { Id = "a", Weight = 1 } }, { a = true }), nil)
end)

H.finish()
