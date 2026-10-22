--!strict
-- WP-05. La Pasarela: una piñata cada 4 s, cruza en 40 s, y la compra
-- se valida en el servidor (distancia, Dulces, pedestal libre).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local Rarities = require(Shared:WaitForChild("Config"):WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local SpawnWeights = require(Shared:WaitForChild("Gameplay"):WaitForChild("SpawnWeights"))
local BuyRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("BuyRules"))

local Server = script.Parent.Parent
local Validation = require(Server:WaitForChild("Adapters"):WaitForChild("Validation"))
local ProfileAdapter = require(Server:WaitForChild("Adapters"):WaitForChild("ProfileAdapter"))
local PinataVisual = require(Server:WaitForChild("World"):WaitForChild("PinataVisual"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

local ConveyorService = {}

local BOOST = { Rare = true, Epic = true, Legendary = true, Mythic = true, Secret = true }

type Slot = {
	id: number,
	model: Model,
	pinataId: string,
	mutation: string?,
	price: number?,
	rarity: string,
	born: number,
	sold: boolean,
}

local slots: { Slot } = {}
local nextId = 1
local luckUntil = 0
local rows: { SpawnWeights.RosterRow } = {}

local function luckOn(): boolean
	return os.clock() < luckUntil
end

function ConveyorService.setServerLuck(seconds: number)
	luckUntil = math.max(luckUntil, os.clock() + seconds)
end

local function findSlot(id: number): Slot?
	for _, slot in slots do
		if slot.id == id then
			return slot
		end
	end
	return nil
end

local function removeSlot(slot: Slot)
	local keep: { Slot } = {}
	for _, other in slots do
		if other ~= slot then
			table.insert(keep, other)
		end
	end
	slots = keep
end

local function rollMutation(): string?
	if math.random() < Economy.Mutations.Rainbow.ConveyorChance then
		return "Rainbow"
	end
	if math.random() < Economy.Mutations.Golden.ConveyorChance then
		return "Golden"
	end
	return nil
end

local function rollPinata(): (string?, string)
	local rarity = SpawnWeights.pick(Rarities.SpawnWeight, math.random(), luckOn(), BOOST)
	local ids = SpawnWeights.eligibleIds(rows, rarity)
	local id = SpawnWeights.chooseId(ids, math.random())
	return id, rarity
end

local function spawnSlot(pinataId: string, rarity: string)
	local current = BaseService.getWorld()
	if current == nil then
		return
	end
	local def = Pinatas[pinataId]
	if def == nil then
		return
	end
	local mutation = rollMutation()
	local model = PinataVisual.create(pinataId, mutation)
	local id = nextId
	nextId += 1
	model:SetAttribute("ConveyorId", id)
	model:PivotTo(CFrame.new(current.spawnPos))
	model.Parent = current.folder
	local primary = model.PrimaryPart
	if primary ~= nil then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuyPrompt"
		prompt.ActionText = if def.Price == nil then "¡Tomar!" else "Comprar"
		prompt.ObjectText = def.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Economy.Buy.MaxDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = primary
		prompt.Triggered:Connect(function(player)
			ConveyorService.tryBuy(player, id)
		end)
	end
	table.insert(slots, {
		id = id,
		model = model,
		pinataId = pinataId,
		mutation = mutation,
		price = def.Price,
		rarity = rarity,
		born = os.clock(),
		sold = false,
	})
end

function ConveyorService.tryBuy(player: Player, slotId: number)
	if not Validation.allow(player, "RequestBuy") then
		return
	end
	if not Validation.isFinite(slotId) then
		return
	end
	local slot = findSlot(slotId)
	if slot == nil or slot.sold or slot.model.Parent == nil then
		return
	end
	local position = slot.model:GetPivot().Position
	local distance = Validation.distance(player, position)
	local inRange = Validation.inRange(player, position, Economy.Buy.MaxDistance)
	local data = ProfileAdapter.get(player)
	local candy = if data ~= nil then data.candy else 0
	local ruleDistance = if inRange then math.min(distance, Economy.Buy.MaxDistance) else distance
	local ok, reason = BuyRules.evaluate({
		candy = candy,
		price = slot.price,
		distance = ruleDistance,
		maxDistance = Economy.Buy.MaxDistance,
		hasRoom = BaseService.hasRoom(player.UserId),
	})
	if not ok then
		if distance >= 200 then
			Validation.flag(player, "RequestBuy.far", { distance = distance, reason = reason })
		end
		return
	end
	slot.sold = true
	removeSlot(slot)
	local accepted, why = BaseService.acceptPurchase(player, slot.pinataId, slot.mutation, slot.model)
	if not accepted then
		slot.sold = false
		slot.born = os.clock()
		table.insert(slots, slot)
		-- "funds" / "no_room" son rechazos normales, no un exploit.
		if distance >= 200 then
			Validation.flag(player, "RequestBuy.rejected", { distance = distance, reason = why })
		end
	end
end

local function step()
	local current = BaseService.getWorld()
	if current == nil then
		return
	end
	local cross = Economy.Conveyor.CrossSeconds
	local keep: { Slot } = {}
	for _, slot in slots do
		if slot.sold or slot.model.Parent == nil then
			continue
		end
		local alpha = (os.clock() - slot.born) / cross
		if alpha >= 1 then
			slot.model:Destroy()
		else
			local x = current.spawnPos.X + (current.exitPos.X - current.spawnPos.X) * alpha
			local bob = math.sin(os.clock() * 4 + slot.id) * 0.25
			slot.model:PivotTo(CFrame.new(x, current.height + bob, current.spawnPos.Z))
			table.insert(keep, slot)
		end
	end
	slots = keep
end

function ConveyorService.init(_services: { [string]: any })
	for id, def in Pinatas do
		table.insert(rows, { id = id, rarity = def.Rarity, currency = def.Currency })
	end
end

function ConveyorService.start()
	Remotes.get("RequestBuy").OnServerEvent:Connect(function(player, slotId)
		if type(slotId) ~= "number" then
			return
		end
		ConveyorService.tryBuy(player, slotId)
	end)
	task.spawn(function()
		while true do
			local pinataId, rarity = rollPinata()
			if pinataId ~= nil and SpawnWeights.isHeadline(rarity) then
				local def = Pinatas[pinataId]
				local name = if def then def.Name else pinataId
				Remotes.get("Announce"):FireAllClients(string.format("¡%s en la Pasarela!", name), rarity)
				task.wait(Economy.Conveyor.AnnounceLeadSec)
			end
			if pinataId ~= nil then
				spawnSlot(pinataId, rarity)
			end
			step()
			task.wait(Economy.Conveyor.SpawnEverySec)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			step()
		end
	end)
end

return ConveyorService
