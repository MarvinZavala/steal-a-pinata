--!strict
-- WP-11. Pases, productos y ProcessReceipt idempotente.
-- El PurchaseId se marca en el mismo paso que el premio. No se concede dos veces.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))
local Security = require(Shared:WaitForChild("Config"):WaitForChild("Security"))
local DailyRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("DailyRules"))
local Receipts = require(Shared:WaitForChild("Gameplay"):WaitForChild("Receipts"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local ConveyorService = require(script.Parent:WaitForChild("ConveyorService"))
local LockService = require(script.Parent:WaitForChild("LockService"))

local MonetizationService = {}

local PASS_FIELD: { [string]: string } = {
	DoubleCandy = "DoubleCandy",
	VipFiesta = "Vip",
	ExtraPedestals = "ExtraPedestals",
	AutoCollect = "AutoCollect",
	BatSkinPack = "BatPack",
}

local function catalog(): Receipts.Catalog
	return Monetization :: any
end

local function applyEffects(player: Player, effects: { Receipts.Effect })
	local data = Records.get(player)
	for _, effect in effects do
		if effect.kind == "serverLuck" and type(effect.seconds) == "number" then
			ConveyorService.setServerLuck(effect.seconds)
			Remotes.get("Announce"):FireAllClients("¡Suerte de server x2! Gracias, " .. player.Name, "Rare")
		elseif effect.kind == "goldenConveyor" and type(effect.spawns) == "number" then
			ConveyorService.queueGolden(effect.spawns)
			Remotes.get("Announce"):FireAllClients("¡Pasarela dorada! Gracias, " .. player.Name, "Epic")
		elseif effect.kind == "emergency" and data ~= nil then
			local product = Monetization.Products.EmergencyLock
			local cooldown = if type(product.CooldownSec) == "number" then product.CooldownSec else 600
			if data.EmergencyCharges > 0 and os.time() >= data.EmergencyLockUnix then
				local plotIndex = BaseService.plotIndexOf(player.UserId)
				if plotIndex ~= nil then
					data.EmergencyCharges -= 1
					data.EmergencyLockUnix = os.time() + cooldown
					LockService.grant(plotIndex, 30, player.UserId)
				end
			end
		end
	end
end

local function finish(player: Player, purchaseId: string, decisionName: string): Enum.ProductPurchaseDecision
	if decisionName == "granted" then
		local saved = DataService.persist(player, purchaseId)
		if not saved then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		BaseService.pushState(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	if type(receipt) ~= "table" or type(receipt.PlayerId) ~= "number" or type(receipt.PurchaseId) ~= "string" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Records.get(player)
	if data == nil or type(receipt.ProductId) ~= "number" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if DataService.purchaseSaved(player, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local result = Receipts.commit(data, catalog(), receipt.PurchaseId, receipt.ProductId, {
		productionPerSec = Records.production(data),
		now = os.time(),
		roll = math.random(),
		maxCurrency = Security.MaxCurrency,
		today = DailyRules.dayIndex(os.time()),
	})
	if result.status == "granted" then
		applyEffects(player, result.effects)
		return finish(player, receipt.PurchaseId, "granted")
	end
	if result.status == "duplicate" then
		return finish(player, receipt.PurchaseId, "granted")
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function refreshPasses(player: Player)
	local data = Records.get(player)
	if data == nil then
		return
	end
	for key, def in Monetization.GamePasses do
		local field = PASS_FIELD[key]
		if field ~= nil and type(def.Id) == "number" and def.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.Id)
			end)
			if ok and type(owns) == "boolean" then
				if field == "DoubleCandy" then
					data.Passes.DoubleCandy = owns
				elseif field == "Vip" then
					data.Passes.Vip = owns
				elseif field == "ExtraPedestals" then
					data.Passes.ExtraPedestals = owns
				elseif field == "AutoCollect" then
					data.Passes.AutoCollect = owns
				elseif field == "BatPack" then
					data.Passes.BatPack = owns
				end
			end
		end
	end
	local subId = Monetization.Subscription.Id
	local lookup = (MarketplaceService :: any).GetUserSubscriptionStatusAsync
	if subId ~= "" and type(lookup) == "function" then
		local ok, status = pcall(function()
			return lookup(MarketplaceService, player, subId)
		end)
		if ok and type(status) == "table" then
			data.Subscription.Active = status.IsSubscribed == true or status.SubscriptionState == "Subscribed"
		end
	end
	player:SetAttribute("Vip", data.Passes.Vip == true)
	BaseService.pushState(player)
end

local function onRewarded(player: Player)
	local productId = Monetization.Rewarded.ProductId
	local ads = (MarketplaceService :: any).CreateAdRewardFromDevProductId
	if productId == 0 or type(ads) ~= "function" then
		Remotes.get("Feedback"):FireClient(player, "DENIED", { key = "common.soon" })
		return
	end
	local ok, reward = pcall(function()
		return ads(MarketplaceService, productId)
	end)
	if not ok or reward == nil then
		Remotes.get("Feedback"):FireClient(player, "DENIED", { key = "common.soon" })
		return
	end
	local show = (reward :: any).Show
	if type(show) ~= "function" then
		Remotes.get("Feedback"):FireClient(player, "DENIED", { key = "common.soon" })
		return
	end
	pcall(function()
		show(reward, player)
	end)
end

local function autoCollect()
	for _, player in Players:GetPlayers() do
		local data = Records.get(player)
		if data ~= nil and data.Passes.AutoCollect == true and data.VaultCandy > 0 then
			local gain = math.floor(data.VaultCandy)
			data.VaultCandy = 0
			if gain > 0 and Records.grantDulces(player, gain) then
				data.Stats.Collects += 1
				BaseService.pushState(player)
			elseif gain > 0 then
				data.VaultCandy = gain
			end
		end
	end
end

function MonetizationService.debugGrant(player: Player, productKey: string, purchaseId: string): boolean
	if not RunService:IsStudio() then
		return false
	end
	local data = Records.get(player)
	local source = Monetization.Products[productKey]
	if data == nil or type(source) ~= "table" or type(purchaseId) ~= "string" or purchaseId == "" then
		return false
	end
	local products: { [string]: any } = {}
	for key, def in Monetization.Products do
		local copy = table.clone(def :: any)
		if key == productKey then
			copy.Id = 91001
		end
		products[key] = copy
	end
	local patched = {
		Products = products,
		SurpriseOdds = Monetization.SurpriseOdds,
		Rewarded = Monetization.Rewarded,
	}
	local result = Receipts.commit(data, patched, purchaseId, 91001, {
		productionPerSec = Records.production(data),
		now = os.time(),
		roll = math.random(),
		maxCurrency = Security.MaxCurrency,
		today = DailyRules.dayIndex(os.time()),
	})
	if result.status ~= "granted" and result.status ~= "duplicate" then
		return false
	end
	if result.status == "granted" then
		applyEffects(player, result.effects)
	end
	DataService.persist(player, purchaseId)
	BaseService.pushState(player)
	return true
end

function MonetizationService.debugOwnPass(player: Player, field: string, owned: boolean): boolean
	if not RunService:IsStudio() then
		return false
	end
	local data = Records.get(player)
	if data == nil then
		return false
	end
	if field == "DoubleCandy" then
		data.Passes.DoubleCandy = owned
	elseif field == "Vip" then
		data.Passes.Vip = owned
	elseif field == "ExtraPedestals" then
		data.Passes.ExtraPedestals = owned
	elseif field == "AutoCollect" then
		data.Passes.AutoCollect = owned
	elseif field == "BatPack" then
		data.Passes.BatPack = owned
	else
		return false
	end
	player:SetAttribute("Vip", data.Passes.Vip == true)
	BaseService.pushState(player)
	return true
end

function MonetizationService.init(_services: { [string]: any })
	MarketplaceService.ProcessReceipt = processReceipt
	AntiCheatService.register("RequestRewarded", function(player)
		onRewarded(player)
	end)
end

function MonetizationService.start()
	local function hook(player: Player)
		task.spawn(function()
			if Records.wait(player) == nil then
				return
			end
			refreshPasses(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, purchased)
		if purchased == true then
			task.spawn(refreshPasses, player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			autoCollect()
		end
	end)
end

return MonetizationService
