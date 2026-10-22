--!strict
-- Corre las pruebas puras al arrancar el server (también en un place publicado:
-- si fallan, avisa y el juego sigue). El mismo módulo lo corre `lune tests/run.luau`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SelfTest = require(Shared:WaitForChild("Gameplay"):WaitForChild("SelfTest"))
local CandyMath = require(Shared:WaitForChild("Gameplay"):WaitForChild("CandyMath"))
local SpawnWeights = require(Shared:WaitForChild("Gameplay"):WaitForChild("SpawnWeights"))
local StealRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("StealRules"))
local BatRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("BatRules"))
local LockRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("LockRules"))
local OfflineEarnings = require(Shared:WaitForChild("Gameplay"):WaitForChild("OfflineEarnings"))
local AssignPlots = require(Shared:WaitForChild("Gameplay"):WaitForChild("AssignPlots"))
local Inventory = require(Shared:WaitForChild("Gameplay"):WaitForChild("Inventory"))
local Aim = require(Shared:WaitForChild("Gameplay"):WaitForChild("Aim"))
local MoveMath = require(Shared:WaitForChild("Gameplay"):WaitForChild("MoveMath"))
local BuyRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("BuyRules"))
local WorldLayout = require(Shared:WaitForChild("Config"):WaitForChild("WorldLayout"))
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local Rarities = require(Shared:WaitForChild("Config"):WaitForChild("Rarities"))

local SelfCheck = {}

local GDD_WEIGHTS = {
	Common = 62,
	Uncommon = 25,
	Rare = 9,
	Epic = 3,
	Legendary = 0.8,
	Mythic = 0.19,
	Secret = 0.01,
}

function SelfCheck.run(): boolean
	for rarity, weight in GDD_WEIGHTS do
		if Rarities.SpawnWeight[rarity] ~= weight then
			warn(
				string.format(
					"[SelfCheck] SpawnWeight.%s cambió (%.4f vs %.4f del GDD)",
					rarity,
					Rarities.SpawnWeight[rarity],
					weight
				)
			)
		end
	end
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
		weights = Rarities.SpawnWeight,
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
	if report.ok then
		print(string.format("[SelfCheck] %d pruebas ok", report.passed))
		return true
	end
	for _, line in report.failed do
		warn("[SelfCheck] " .. line)
	end
	return false
end

return SelfCheck
