--!strict
local H = require("./harness")
local defaults = require("./defaults")
local Migrations = require("../src/ReplicatedStorage/Shared/Data/Migrations")
local Wallet = require("../src/ReplicatedStorage/Shared/Data/Wallet")
local Security = require("../src/ReplicatedStorage/Shared/Config/Security")
local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local Tuning = require("../src/ReplicatedStorage/Shared/Config/Tuning")
local CandyMath = require("../src/ReplicatedStorage/Shared/Gameplay/CandyMath")
local SpawnWeights = require("../src/ReplicatedStorage/Shared/Gameplay/SpawnWeights")
local StealRules = require("../src/ReplicatedStorage/Shared/Gameplay/StealRules")
local BatRules = require("../src/ReplicatedStorage/Shared/Gameplay/BatRules")
local LockRules = require("../src/ReplicatedStorage/Shared/Gameplay/LockRules")
local OfflineEarnings = require("../src/ReplicatedStorage/Shared/Gameplay/OfflineEarnings")
local AssignPlots = require("../src/ReplicatedStorage/Shared/Gameplay/AssignPlots")
local Inventory = require("../src/ReplicatedStorage/Shared/Gameplay/Inventory")
local Aim = require("../src/ReplicatedStorage/Shared/Gameplay/Aim")
local MoveMath = require("../src/ReplicatedStorage/Shared/Gameplay/MoveMath")
local BuyRules = require("../src/ReplicatedStorage/Shared/Gameplay/BuyRules")
local WorldLayout = require("../src/ReplicatedStorage/Shared/Config/WorldLayout")
local SelfTest = require("../src/ReplicatedStorage/Shared/Gameplay/SelfTest")

H.begin()

H.check("reglas de bases, pasarela, robo, bate y candado", function()
	local report = SelfTest.run({
		CandyMath = CandyMath,
		SpawnWeights = SpawnWeights,
		StealRules = StealRules,
		BatRules = BatRules,
		LockRules = LockRules,
		OfflineEarnings = OfflineEarnings,
		AssignPlots = AssignPlots,
		Inventory = Inventory,
		Aim = Aim,
		MoveMath = MoveMath,
		BuyRules = BuyRules,
		WorldLayout = WorldLayout,
		Economy = Economy,
		weights = {
			Common = 62,
			Uncommon = 25,
			Rare = 9,
			Epic = 3,
			Legendary = 0.8,
			Mythic = 0.19,
			Secret = 0.01,
		},
		boosted = { Rare = true, Epic = true, Legendary = true, Mythic = true, Secret = true },
		walkSpeed = Tuning.WalkSpeed,
		carrySpeed = Tuning.CarrySpeed,
		economyWalk = Economy.Walk.Normal,
		economyCarry = Economy.Walk.Carrying,
		gravity = Tuning.Gravity,
		jumpHeight = Tuning.JumpHeight,
		knockH = Tuning.KnockbackHorizontal,
		knockV = Tuning.KnockbackVertical,
	})
	if not report.ok then
		error(table.concat(report.failed, "\n"), 0)
	end
	H.truthy(report.passed >= 70, "pocas pruebas")
	H.truthy(report.worstSpawnDelta <= 0.5, "pesos fuera de banda")
end)

H.check("la dulcería y el candado sobreviven la migración", function()
	local data = Migrations.migrate({
		SchemaVersion = 2,
		Dulces = 10,
		VaultCandy = 40,
		LockReadyUnix = 99,
		RobbedUnix = { 1, 2 },
		Inventory = {
			{ InstanceId = "a", PinataId = "michi", Mutation = "None", ObtainedAt = 1 },
		},
		Placed = { ["2"] = "a" },
	}, defaults()) :: any
	H.eq(data.VaultCandy, 40)
	H.eq(data.LockReadyUnix, 99)
	H.eq(data.RobbedUnix[2], 2)
	H.eq(data.Placed["2"], "a")
	local empty = Migrations.migrate({}, defaults()) :: any
	H.eq(empty.VaultCandy, 0)
	H.eq(#empty.RobbedUnix, 0)
end)

H.check("mover una piñata no la duplica", function()
	local from = Migrations.migrate({}, defaults()) :: any
	local to = Migrations.migrate({}, defaults()) :: any
	H.truthy(Wallet.grantPinata(from, "michi", "Golden", "id-1", 10, Security.MaxInventory, { michi = true }))
	H.truthy(Wallet.place(from, "id-1", 1, Economy.MaxPedestalSlots))
	H.eq(Wallet.slotOf(from, "id-1"), 1)
	H.truthy(Wallet.movePinata(from, to, "id-1", Security.MaxInventory))
	H.eq(#from.Inventory, 0)
	H.eq(Wallet.slotOf(from, "id-1"), nil)
	H.eq(#to.Inventory, 1)
	H.eq(to.Inventory[1].InstanceId, "id-1")
	H.eq(to.Inventory[1].Mutation, "Golden")
	H.eq(to.Dex.michi, true)
	H.eq(Wallet.movePinata(from, to, "id-1", Security.MaxInventory), false)
end)

H.finish()
