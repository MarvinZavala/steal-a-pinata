--!strict
-- WP-09. Pedestales, tope, bate, Re-Fiesta y fusión. El servidor gasta y muta el perfil.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local Fusion = require(Shared:WaitForChild("Gameplay"):WaitForChild("Fusion"))
local Progression = require(Shared:WaitForChild("Gameplay"):WaitForChild("Progression"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local Transit = require(Server:WaitForChild("World"):WaitForChild("Transit"))

local EconomyService = {}

local PROMPTS: { [string]: string } = {
	dulceria = "Dulcería",
	bates = "Bates",
	cajas = "Cajas",
	vip = "VIP",
}

local function track(player: Player, name: string, value: number)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value)
	end)
end

local function deny(player: Player, key: string)
	Remotes.get("Feedback"):FireClient(player, "DENIED", { key = key })
end

local function kioskPositions(id: string): { Vector3 }
	local list: { Vector3 } = {}
	local world = workspace:FindFirstChild("World")
	if world == nil then
		return list
	end
	for _, child in world:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("KioskId") == id then
			table.insert(list, child.Position)
		end
	end
	return list
end

local function near(player: Player, action: string, ids: { string }): boolean
	local spots: { Vector3 } = {}
	for _, id in ids do
		for _, position in kioskPositions(id) do
			table.insert(spots, position)
		end
	end
	local plot = BaseService.plotOf(player.UserId)
	if plot ~= nil then
		table.insert(spots, plot.collect.Position)
	end
	for _, position in spots do
		if AntiCheatService.authorize(player, action, position) then
			return true
		end
	end
	return false
end

local function onUpgrade(player: Player, args: { any })
	local id = args[1]
	local data = Records.get(player)
	if type(id) ~= "string" or data == nil then
		return
	end
	local spots = if id == "Bat" then { "bates", "dulceria" } else { "dulceria" }
	if not near(player, "RequestUpgrade", spots) then
		deny(player, "far")
		return
	end
	if id == "Pedestal" then
		local cap = Economy.pedestalCap(data.ReFiestas, data.Passes.ExtraPedestals == true)
		if data.PedestalsOwned >= cap then
			deny(player, "common.max")
			return
		end
		local price = Economy.pedestalPrice(data.PedestalsOwned + 1)
		if not Records.trySpendDulces(player, price) then
			deny(player, "poor")
			return
		end
		data.PedestalsOwned += 1
		BaseService.syncPads(player.UserId)
		track(player, "economy_pedestal", data.PedestalsOwned)
	elseif id == "VaultCap" then
		local price = Economy.vaultCost(data.VaultCapTier + 1)
		if price <= 0 then
			deny(player, "common.max")
			return
		end
		if not Records.trySpendDulces(player, price) then
			deny(player, "poor")
			return
		end
		data.VaultCapTier += 1
		track(player, "economy_vault", data.VaultCapTier)
	elseif id == "Bat" then
		local price = Economy.batUpgradeCost(data.BatUpgrade + 1)
		if price <= 0 then
			deny(player, "common.max")
			return
		end
		if not Records.trySpendDulces(player, price) then
			deny(player, "poor")
			return
		end
		data.BatUpgrade += 1
		track(player, "economy_bat", data.BatUpgrade)
	elseif id == "ReFiesta" then
		local ok, reason = Progression.tryRebirth(data, Pinatas)
		if not ok then
			deny(player, if reason == "pinatas" then "shop.refiesta_need" else "poor")
			return
		end
		BaseService.resync(player)
		track(player, "economy_refiesta", data.ReFiestas)
		Remotes.get("Announce"):FireClient(player, "¡Re-Fiesta!", "Epic")
		return
	else
		return
	end
	BaseService.pushState(player)
end

local function onFuse(player: Player, args: { any })
	local pinataId = args[1]
	local data = Records.get(player)
	if type(pinataId) ~= "string" or data == nil then
		return
	end
	if not near(player, "RequestFuse", { "cajas", "dulceria" }) then
		deny(player, "far")
		return
	end
	local busy: { [string]: boolean } = {}
	for _, item in data.Inventory do
		if Transit.has(item.InstanceId) then
			busy[item.InstanceId] = true
		end
	end
	local ids = Fusion.selectThree(data.Inventory, pinataId, busy)
	if ids == nil then
		deny(player, "shop.fuse_empty")
		return
	end
	Fusion.removeIds(data.Inventory, data.Placed, ids)
	local mutation = Fusion.pickMutation(math.random(), Economy.FusionRainbowChance)
	local granted, instanceId = Records.grantPinata(player, pinataId, mutation)
	if not granted or instanceId == nil then
		deny(player, "poor")
		BaseService.resync(player)
		return
	end
	BaseService.resync(player)
	track(player, "economy_fuse", 1)
	Remotes.get("Feedback"):FireClient(player, "FUSE", { pinataId = pinataId, mutation = mutation })
end

local function bindKiosks()
	local world = workspace:FindFirstChild("World")
	if world == nil then
		return
	end
	for _, child in world:GetChildren() do
		if child:IsA("BasePart") then
			local kioskId = child:GetAttribute("KioskId")
			if type(kioskId) == "string" and child:FindFirstChild("OpenShop") == nil then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "OpenShop"
				prompt.ActionText = "Abrir"
				prompt.ObjectText = PROMPTS[kioskId] or kioskId
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = Economy.Buy.MaxDistance
				prompt.RequiresLineOfSight = false
				prompt.Parent = child
				local shopId = kioskId
				prompt.Triggered:Connect(function(player)
					if AntiCheatService.authorize(player, "RequestUpgrade", child.Position) then
						Remotes.get("OpenShop"):FireClient(player, shopId)
					end
				end)
			end
		end
	end
end

function EconomyService.init(_services: { [string]: any })
	AntiCheatService.register("RequestUpgrade", onUpgrade)
	AntiCheatService.register("RequestFuse", onFuse)
end

function EconomyService.start()
	bindKiosks()
end

return EconomyService
