--!strict
-- Vista del perfil real. No copia los datos: DataService.profile es la tabla
-- que ProfileStore guarda. Moneda e inventario pasan por DataService y Wallet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local Migrations = require(Shared:WaitForChild("Data"):WaitForChild("Migrations"))
local Wallet = require(Shared:WaitForChild("Data"):WaitForChild("Wallet"))
local CandyMath = require(Shared:WaitForChild("Gameplay"):WaitForChild("CandyMath"))
local OfflineEarnings = require(Shared:WaitForChild("Gameplay"):WaitForChild("OfflineEarnings"))
local StealRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("StealRules"))

local Server = script.Parent.Parent
local DataService = require(Server:WaitForChild("Services"):WaitForChild("DataService"))
local Transit = require(Server:WaitForChild("World"):WaitForChild("Transit"))

export type PlayerData = Migrations.PlayerData
export type OwnedPinata = Migrations.OwnedPinata

local Records = {}

local function mutationTable(): { [string]: number }
	return {
		Golden = Economy.Mutations.Golden.Multiplier,
		Rainbow = Economy.Mutations.Rainbow.Multiplier,
		Christmas = Economy.Mutations.Christmas.Multiplier,
	}
end

function Records.get(player: Player): PlayerData?
	local raw = DataService.profile(player)
	if type(raw) ~= "table" then
		return nil
	end
	return raw :: PlayerData
end

function Records.byUserId(userId: number): PlayerData?
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return nil
	end
	return Records.get(player)
end

function Records.wait(player: Player): PlayerData?
	local deadline = os.clock() + 20
	while player.Parent ~= nil and os.clock() < deadline do
		local data = Records.get(player)
		if data ~= nil then
			return data
		end
		task.wait(0.1)
	end
	return nil
end

function Records.find(data: PlayerData, instanceId: string): OwnedPinata?
	for _, item in data.Inventory do
		if item.InstanceId == instanceId then
			return item
		end
	end
	return nil
end

function Records.mutationOf(item: OwnedPinata): string?
	if item.Mutation == "None" or item.Mutation == "" then
		return nil
	end
	return item.Mutation
end

function Records.production(data: PlayerData): number
	local entries: { CandyMath.Entry } = {}
	for _, owned in data.Inventory do
		if not Transit.has(owned.InstanceId) then
			local def = Pinatas[owned.PinataId]
			if def then
				table.insert(entries, {
					candyPerSec = def.CandyPerSec,
					mutation = Records.mutationOf(owned),
				})
			end
		end
	end
	-- 2x, VIP y sets entran con WP-11. Hoy el perfil solo tiene Re-Fiestas.
	local mult = Economy.totalMultiplier(data.ReFiestas, false, false, 0)
	return CandyMath.perSecond(entries, mult, mutationTable())
end

function Records.capAmount(data: PlayerData): number
	local tiers = Economy.VaultCapSeconds
	local seconds = tiers[data.VaultCapTier] or tiers[1]
	return CandyMath.cap(Records.production(data), seconds)
end

function Records.hasRoom(data: PlayerData): boolean
	return #data.Inventory < data.PedestalsOwned
end

function Records.isRookie(data: PlayerData): boolean
	return data.RookieSeconds < Economy.RookieShieldSec
end

function Records.rookieLeft(data: PlayerData): number
	return math.max(0, Economy.RookieShieldSec - data.RookieSeconds)
end

function Records.tickSecond(data: PlayerData)
	data.Stats.PlayTimeSec += 1
	data.RookieSeconds += 1
	local cap = Records.capAmount(data)
	local nextVault = CandyMath.accrue(data.VaultCandy, Records.production(data), 1, cap)
	data.VaultCandy = math.floor(nextVault)
end

function Records.applyOffline(data: PlayerData)
	local leftAt = data.Stats.LastLeaveUnix
	if leftAt <= 0 then
		return
	end
	local elapsed = os.time() - leftAt
	local gain = OfflineEarnings.earned(Records.production(data), elapsed, Economy.OfflineRate, Economy.OfflineCapHours)
	local cap = Records.capAmount(data)
	data.VaultCandy = math.floor(CandyMath.deposit(data.VaultCandy, gain, cap))
	data.Stats.LastLeaveUnix = 0
end

function Records.trySpendDulces(player: Player, amount: number): boolean
	if amount ~= math.floor(amount) or amount <= 0 then
		return false
	end
	return DataService.trySpend(player, "Dulces", amount)
end

function Records.grantDulces(player: Player, amount: number): boolean
	local whole = math.floor(amount)
	if whole <= 0 then
		return false
	end
	return DataService.grant(player, "Dulces", whole)
end

function Records.grantPinata(player: Player, pinataId: string, mutation: string?): (boolean, string?)
	local stored = if mutation == nil or mutation == "" then "None" else mutation
	return DataService.grantPinata(player, pinataId, stored)
end

function Records.movePinata(fromPlayer: Player, toPlayer: Player, instanceId: string): boolean
	return DataService.movePinata(fromPlayer, toPlayer, instanceId)
end

function Records.place(data: PlayerData, instanceId: string, slot: number): boolean
	return Wallet.place(data, instanceId, slot, Economy.MaxPedestalSlots)
end

function Records.unplace(data: PlayerData, instanceId: string)
	Wallet.unplace(data, instanceId)
end

function Records.slotOf(data: PlayerData, instanceId: string): number?
	return Wallet.slotOf(data, instanceId)
end

function Records.noteRobbed(data: PlayerData)
	table.insert(data.RobbedUnix, os.time())
	while #data.RobbedUnix > 8 do
		table.remove(data.RobbedUnix, 1)
	end
	data.Stats.TimesRobbed += 1
end

function Records.recentRobbed(data: PlayerData, now: number): number
	return StealRules.countSince(data.RobbedUnix, now, Economy.Steal.WindowSec)
end

function Records.refreshLeaderstats(player: Player)
	local data = Records.get(player)
	if data == nil then
		return
	end
	local folder = player:FindFirstChild("leaderstats")
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = "leaderstats"
		created.Parent = player
		folder = created
	end
	local stats = folder :: Instance
	local function stat(name: string, value: number)
		local valueObject = stats:FindFirstChild(name)
		if valueObject == nil or not valueObject:IsA("IntValue") then
			local created = Instance.new("IntValue")
			created.Name = name
			created.Parent = stats
			valueObject = created
		end
		if valueObject:IsA("IntValue") then
			valueObject.Value = math.floor(value + 0.5)
		end
	end
	stat("Dulces", data.Dulces)
	stat("Dulcera", data.VaultCandy)
end

return Records
