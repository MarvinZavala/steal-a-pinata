--!strict
local H = require("./harness")
local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local Pinatas = require("../src/ReplicatedStorage/Shared/Config/Pinatas")
local Migrations = require("../src/ReplicatedStorage/Shared/Data/Migrations")
local Fusion = require("../src/ReplicatedStorage/Shared/Gameplay/Fusion")
local Progression = require("../src/ReplicatedStorage/Shared/Gameplay/Progression")
local FiestaRules = require("../src/ReplicatedStorage/Shared/Gameplay/FiestaRules")
local SetBonus = require("../src/ReplicatedStorage/Shared/Gameplay/SetBonus")
local defaults = require("./defaults")

H.begin()

H.check("el multiplicador es aditivo y el 2x suma 1", function()
	H.eq(Economy.totalMultiplier(0, false, false, 0), 1)
	H.eq(Economy.totalMultiplier(2, true, true, 1), 1 + 1 + 1 + 0.5 + 0.05)
	H.eq(Economy.totalMultiplier(1, false, false, 0), 1.5)
end)

H.check("los pedestales crecen ×2.2 y el tope respeta la Re-Fiesta", function()
	H.eq(Economy.pedestalPrice(5), 500)
	H.eq(Economy.pedestalPrice(6), math.floor(500 * 2.2 + 0.5))
	H.eq(Economy.pedestalCap(0, false), 8)
	H.eq(Economy.pedestalCap(0, true), 10)
	H.eq(Economy.pedestalCap(3, false), 12)
	H.eq(Economy.pedestalCap(3, true), 12)
	H.eq(Economy.vaultCost(2), 2500)
	H.eq(Economy.vaultCost(4), 80000)
	H.eq(Economy.refiestaOffer(1).Candy, 5500000)
	H.eq(Economy.refiestaOffer(1).Rarity, "Epic")
	H.truthy(Economy.refiestaOffer(6).Candy > Economy.refiestaOffer(5).Candy)
end)

H.check("la Re-Fiesta se lleva los Dulces y deja Secretas y de Evento", function()
	local data = Migrations.migrate({
		SchemaVersion = 2,
		Dulces = 5500000,
		PedestalsOwned = 8,
		VaultCandy = 40,
		Inventory = {
			{ InstanceId = "c", PinataId = "burrito", Mutation = "None", ObtainedAt = 1 },
			{ InstanceId = "e", PinataId = "pulpo", Mutation = "Golden", ObtainedAt = 2 },
			{ InstanceId = "s", PinataId = "sombra", Mutation = "None", ObtainedAt = 3 },
			{ InstanceId = "n", PinataId = "renito", Mutation = "None", ObtainedAt = 4 },
		},
		Placed = { ["1"] = "c", ["2"] = "s", ["3"] = "n" },
	}, defaults()) :: any
	H.eq(Progression.tryRebirth(data, Pinatas), true)
	H.eq(data.Dulces, 0)
	H.eq(data.VaultCandy, 0)
	H.eq(data.PedestalsOwned, 4)
	H.eq(data.ReFiestas, 1)
	H.eq(data.BatTier, 1)
	H.eq(#data.Inventory, 2)
	local ids: { [string]: boolean } = {}
	for _, item in data.Inventory do
		ids[item.InstanceId] = true
	end
	H.eq(ids.c, nil)
	H.eq(ids.e, nil)
	H.eq(ids.s, true)
	H.eq(ids.n, true)
	H.eq(data.Placed["1"], nil)
	H.eq(data.Placed["2"], "s")
	H.eq(data.Placed["3"], "n")
	H.eq(Progression.tryRebirth(data, Pinatas), false)
end)

H.check("sin la Épica o sin los Dulces la Re-Fiesta no toca el perfil", function()
	local data = Migrations.migrate({
		SchemaVersion = 2,
		Dulces = 500000,
		Inventory = {
			{ InstanceId = "c", PinataId = "burrito", Mutation = "None", ObtainedAt = 1 },
		},
	}, defaults()) :: any
	H.eq(Progression.tryRebirth(data, Pinatas), false)
	H.eq(data.Dulces, 500000)
	H.eq(#data.Inventory, 1)
end)

H.check("la fusión elige 3 y prefiere las sin mutación", function()
	local inventory = {
		{ InstanceId = "a", PinataId = "michi", Mutation = "Rainbow" },
		{ InstanceId = "b", PinataId = "michi", Mutation = "None" },
		{ InstanceId = "c", PinataId = "michi", Mutation = "Golden" },
		{ InstanceId = "d", PinataId = "michi", Mutation = "None" },
		{ InstanceId = "e", PinataId = "burrito", Mutation = "None" },
	}
	local picked = Fusion.selectThree(inventory, "michi", { c = true })
	H.truthy(picked)
	local row = picked :: { string }
	H.eq(#row, 3)
	H.eq(row[1], "b")
	H.eq(row[2], "d")
	H.eq(Fusion.pickMutation(0.05, 0.1), "Rainbow")
	H.eq(Fusion.pickMutation(0.2, 0.1), "Golden")
	H.eq(Fusion.keptOnRebirth("Secret"), true)
	H.eq(Fusion.keptOnRebirth("Epic"), false)
end)

H.check("la gigante reparte según los golpes y no deja resto", function()
	local rows = {
		{ userId = 1, hits = 1 },
		{ userId = 2, hits = 3 },
		{ userId = 3, hits = 0 },
	}
	local payout = FiestaRules.share(rows, 100)
	H.eq(#payout, 2)
	local sum = 0
	for _, row in payout do
		sum += row.candy
	end
	H.eq(sum, 100)
	H.eq(FiestaRules.phase(10, 180, 40), "rain")
	H.eq(FiestaRules.phase(150, 180, 40), "giant")
	H.eq(FiestaRules.phase(180, 180, 40), "idle")
	H.eq(FiestaRules.hudSeconds(0, 1800, 180), 0)
	H.eq(FiestaRules.hudSeconds(180, 1800, 180), 1620)
end)

H.check("un set completo cuenta y uno a medias no", function()
	local dex: { [string]: boolean } = {}
	for id, def in Pinatas do
		if def.Set == "Classics" then
			dex[id] = true
		end
	end
	H.eq(SetBonus.count(dex, Pinatas), 1)
	dex.estrellita = nil
	H.eq(SetBonus.count(dex, Pinatas), 0)
end)

H.finish()
