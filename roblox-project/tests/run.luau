--!strict
-- Runner de las pruebas puras. Desde roblox-project/:
--   /tmp/lune-bin/lune tests/run.luau

local process = require("@lune/process")

-- Lune resuelve require por ruta de archivo, relativa a este archivo.
local src = "../src/ReplicatedStorage/Shared"
local CandyMath = require(src .. "/Gameplay/CandyMath")
local SpawnWeights = require(src .. "/Gameplay/SpawnWeights")
local StealRules = require(src .. "/Gameplay/StealRules")
local BatRules = require(src .. "/Gameplay/BatRules")
local LockRules = require(src .. "/Gameplay/LockRules")
local OfflineEarnings = require(src .. "/Gameplay/OfflineEarnings")
local AssignPlots = require(src .. "/Gameplay/AssignPlots")
local Inventory = require(src .. "/Gameplay/Inventory")
local Aim = require(src .. "/Gameplay/Aim")
local MoveMath = require(src .. "/Gameplay/MoveMath")
local BuyRules = require(src .. "/Gameplay/BuyRules")
local WorldLayout = require(src .. "/Config/WorldLayout")
local Economy = require(src .. "/Config/Economy")
local Tuning = require(src .. "/Config/Tuning")
local SelfTest = require(src .. "/Gameplay/SelfTest")

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

if report.ok then
	print(string.format("[tests] %d checks ok (peor delta de spawn %.3f pp)", report.passed, report.worstSpawnDelta))
	process.exit(0)
end

for _, line in report.failed do
	print("[fail] " .. line)
end
print(string.format("[tests] %d failed, %d passed", #report.failed, report.passed))
process.exit(1)
