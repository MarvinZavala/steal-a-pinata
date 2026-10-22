--!strict
-- Intenciones de la UI que el gameplay no cubre: mejoras de kiosco, ajustes
-- y la intro. El pad amarillo junta los dulces; RequestCollect no se registra
-- (un payload válido se acepta y no cambia el perfil). El bate es RequestSwing
-- y el candado es RequestLock. El embudo de analytics lo manda solo el cliente.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local ShopCatalog = require(Shared:WaitForChild("UI"):WaitForChild("ShopCatalog"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local Juice = require(Server:WaitForChild("World"):WaitForChild("Juice"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local ConveyorService = require(script.Parent:WaitForChild("ConveyorService"))

local UiIntentService = {}

type Settings = {
	locale: string,
	music: number,
	sfx: number,
	reduceMotion: boolean,
	cameraShake: boolean,
}

local settingsOf: { [Player]: Settings } = {}
local offered: { [Player]: { [string]: boolean } } = {}
local bots: { [Player]: BasePart } = {}

function UiIntentService.settingsOf(player: Player): Settings?
	return settingsOf[player]
end

local function deny(player: Player, key: string)
	Remotes.get("Feedback"):FireClient(player, "DENIED", { key = key })
end

local function hasEpic(data: Records.PlayerData): boolean
	for _, item in data.Inventory do
		local def = Pinatas[item.PinataId]
		if def ~= nil and def.Rarity == "Epic" then
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
	if id == "Pedestal" then
		if data.PedestalsOwned >= Economy.MaxPedestals then
			deny(player, "common.max")
			return
		end
		local price = ShopCatalog.pedestalPrice(data.PedestalsOwned + 1)
		if not Records.trySpendDulces(player, price) then
			deny(player, "poor")
			return
		end
		data.PedestalsOwned += 1
		BaseService.syncPads(player.UserId)
	elseif id == "VaultCap" then
		local tiers = Economy.VaultCapSeconds
		if data.VaultCapTier >= #tiers then
			deny(player, "common.max")
			return
		end
		local price = ShopCatalog.vaultCost(data.VaultCapTier + 1)
		if price <= 0 or not Records.trySpendDulces(player, price) then
			deny(player, "poor")
			return
		end
		data.VaultCapTier += 1
	elseif id == "ReFiesta" then
		if not hasEpic(data) then
			deny(player, "poor")
			return
		end
		local price = ShopCatalog.refiestaCandy()
		if price <= 0 or not Records.trySpendDulces(player, price) then
			deny(player, "poor")
			return
		end
		data.ReFiestas += 1
	else
		return
	end
	BaseService.pushState(player)
end

local function onSettings(player: Player, args: { any })
	local locale = args[1]
	local music = args[2]
	local sfx = args[3]
	if type(locale) ~= "string" or type(music) ~= "number" or type(sfx) ~= "number" then
		return
	end
	settingsOf[player] = {
		locale = locale,
		music = math.clamp(music, 0, 1),
		sfx = math.clamp(sfx, 0, 1),
		reduceMotion = args[4] == true,
		cameraShake = args[5] ~= false,
	}
	BaseService.pushState(player)
end

local function clearBot(player: Player)
	local part = bots[player]
	bots[player] = nil
	if part ~= nil then
		part:Destroy()
	end
end

local function spawnBot(player: Player)
	clearBot(player)
	local plot = BaseService.plotOf(player.UserId)
	if plot == nil then
		return
	end
	local goal = BaseService.anchorPosition(player.UserId, 1)
	if goal == nil then
		goal = plot.spawn.Position
	end
	local startPos = plot.spawn.Position + Vector3.new(0, 4, 16)
	local part = Instance.new("Part")
	part.Name = "Ladronzuelo"
	part.Size = Vector3.new(2.2, 4.2, 2.2)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Color = Color3.fromHex("#1B1430")
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(startPos)
	part:SetAttribute("FTUEBot", true)
	part.Parent = plot.model
	CollectionService:AddTag(part, "FTUEThief")
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 36)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "Ladronzuelo"
	label.TextColor3 = Color3.fromHex("#FFE14D")
	label.TextStrokeColor3 = Color3.fromHex("#1B1430")
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	bots[player] = part
	local target = goal + Vector3.new(0, 2, 0)
	task.spawn(function()
		local t0 = os.clock()
		local dur = 5.5
		while part.Parent ~= nil and os.clock() - t0 < dur do
			local alpha = math.clamp((os.clock() - t0) / dur, 0, 1)
			part.CFrame = CFrame.new(startPos:Lerp(target, alpha))
			task.wait(0.05)
		end
	end)
end

local function claimOffer(player: Player, key: string): boolean
	local row = offered[player]
	if row == nil then
		row = {}
		offered[player] = row
	end
	if row[key] == true then
		return false
	end
	row[key] = true
	return true
end

local function releaseOffer(player: Player, key: string)
	local row = offered[player]
	if row ~= nil then
		row[key] = nil
	end
end

local function announce(player: Player, pinataId: string)
	local def = Pinatas[pinataId]
	local name = if def ~= nil then def.Name else pinataId
	local rarity = if def ~= nil then def.Rarity else "Common"
	Remotes.get("Announce"):FireClient(player, string.format("¡%s en la Pasarela!", name), rarity)
end

local function offerOnce(player: Player, key: string, pinataId: string, mutation: string?, free: boolean)
	if not claimOffer(player, key) then
		return
	end
	local slotId = ConveyorService.offer(pinataId, mutation, free)
	if slotId == nil then
		releaseOffer(player, key)
		return
	end
	announce(player, pinataId)
end

local function introOpen(player: Player): Records.PlayerData?
	if ReplicatedStorage:GetAttribute("SkipFTUE") == true then
		return nil
	end
	local data = Records.get(player)
	if data == nil or data.FtueCompleted == true then
		return nil
	end
	return data
end

local function onStep(player: Player, args: { any })
	local step = args[1]
	local data = introOpen(player)
	if type(step) ~= "string" or data == nil then
		return
	end
	if step == "2_arrow_followed" or step == "3_first_claim" then
		offerOnce(player, "michi", "michi", "Golden", true)
	elseif step == "4_thief_seen" then
		spawnBot(player)
	elseif step == "7_first_collect" then
		if data.VaultCandy < 250 then
			data.VaultCandy = 250
		end
		BaseService.pushState(player)
	elseif step == "8_first_purchase" then
		offerOnce(player, "burrito", "burrito", nil, false)
	end
end

local function markDone(player: Player)
	task.spawn(function()
		local data = Records.wait(player)
		if data == nil then
			return
		end
		data.FtueCompleted = true
		clearBot(player)
		if player.Parent ~= nil then
			BaseService.pushState(player)
		end
	end)
end

local function onAction(player: Player, args: { any })
	local action = args[1]
	if action == "bonk" then
		local part = bots[player]
		local position = if part ~= nil then part.Position else nil
		clearBot(player)
		if position ~= nil then
			Juice.bonkSign(position)
			Juice.feedbackOne(player, "BONK", position)
		end
		return
	end
	if action == "complete" or action == "skip" then
		markDone(player)
	end
	-- claim, collect y buy los resuelve la Pasarela o el pad. No se otorgan otra vez.
end

function UiIntentService.init(_services: { [string]: any })
	AntiCheatService.register("RequestUpgrade", onUpgrade)
	AntiCheatService.register("RequestSettings", onSettings)
	AntiCheatService.register("RequestFTUEStep", onStep)
	AntiCheatService.register("RequestFTUEAction", onAction)
end

function UiIntentService.start()
	local function honor(player: Player)
		if ReplicatedStorage:GetAttribute("SkipFTUE") == true then
			markDone(player)
		end
	end
	Players.PlayerAdded:Connect(honor)
	for _, player in Players:GetPlayers() do
		honor(player)
	end
	ReplicatedStorage:GetAttributeChangedSignal("SkipFTUE"):Connect(function()
		if ReplicatedStorage:GetAttribute("SkipFTUE") ~= true then
			return
		end
		for _, player in Players:GetPlayers() do
			honor(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		settingsOf[player] = nil
		offered[player] = nil
		clearBot(player)
	end)
end

return UiIntentService
