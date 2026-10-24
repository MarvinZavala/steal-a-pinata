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
local EventCalendar = require(Shared:WaitForChild("Gameplay"):WaitForChild("EventCalendar"))
local Events = require(Shared:WaitForChild("Config"):WaitForChild("Events"))
local Layout = require(Shared:WaitForChild("Config"):WaitForChild("WorldLayout"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local Validators = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Validators"))
local Logger = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Logger"))
local Labels = require(Server:WaitForChild("World"):WaitForChild("Labels"))
local PinataVisual = require(Server:WaitForChild("World"):WaitForChild("PinataVisual"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

local ConveyorService = {}

type Slot = {
	id: number,
	model: Model,
	pinataId: string,
	mutation: string?,
	price: number?,
	currency: string,
	rarity: string,
	born: number,
	sold: boolean,
	shown: boolean,
	onShown: (() -> ())?,
}

-- Las piñatas miran a -Z del modelo; la plaza queda del lado opuesto a la Pasarela.
local FACING = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -math.sign(Layout.PasarelaZ)))

local slots: { Slot } = {}
local nextId = 1
local luckUntil = 0
local goldenLeft = 0
local rows: { SpawnWeights.RosterRow } = {}

local function luckOn(): boolean
	return os.clock() < luckUntil
end

function ConveyorService.setServerLuck(seconds: number)
	luckUntil = math.max(luckUntil, os.clock() + seconds)
end

function ConveyorService.queueGolden(spawns: number)
	if spawns ~= spawns or spawns <= 0 then
		return
	end
	goldenLeft += math.floor(spawns)
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

local function eventNow()
	local attribute = workspace:GetAttribute("ForcePosadas")
	local phase = workspace:GetAttribute("ForcePosadasPhase")
	return EventCalendar.snapshot(
		os.time(),
		EventCalendar.isForced(attribute),
		if type(phase) == "string" then phase else nil
	)
end

local function rollMutation(): string?
	if EventCalendar.mutationHit(eventNow(), math.random()) then
		return "Christmas"
	end
	if math.random() < Economy.Mutations.Rainbow.ConveyorChance then
		return "Rainbow"
	end
	if math.random() < Economy.Mutations.Golden.ConveyorChance then
		return "Golden"
	end
	return nil
end

local function rollPinata(): (string?, string)
	local snap = eventNow()
	if EventCalendar.runwayHit(snap, math.random()) then
		local runwayId = Events.PosadasPinateras.RunwayId
		local runway = Pinatas[runwayId]
		if runway ~= nil then
			return runwayId, runway.Rarity
		end
	end
	local rarity = SpawnWeights.pick(Rarities.SpawnWeight, math.random(), luckOn(), Rarities.LuckBoosted)
	if goldenLeft > 0 then
		goldenLeft -= 1
		local lifted = rarity == "Rare"
			or rarity == "Epic"
			or rarity == "Legendary"
			or rarity == "Mythic"
			or rarity == "Secret"
		if not lifted then
			rarity = "Rare"
		end
	end
	local ids = SpawnWeights.eligibleIds(rows, rarity)
	local id = SpawnWeights.chooseId(ids, math.random())
	return id, rarity
end

-- Una piñata nueva entra al menos MinGapSec después de la última; si tiene que esperar, queda oculta.
local function nextBorn(): number
	local newest = -math.huge
	for _, slot in slots do
		newest = math.max(newest, slot.born)
	end
	return math.max(os.clock(), newest + Economy.Conveyor.MinGapSec)
end

local function pending(): boolean
	for _, slot in slots do
		if not slot.shown then
			return true
		end
	end
	return false
end

local function reveal(slot: Slot)
	slot.shown = true
	local fn = slot.onShown
	slot.onShown = nil
	if fn ~= nil then
		task.spawn(fn)
	end
end

local function insertSlot(
	pinataId: string,
	rarity: string,
	mutation: string?,
	price: number?,
	currency: string,
	onShown: (() -> ())?
): number?
	local current = BaseService.getWorld()
	if current == nil then
		return nil
	end
	local def = Pinatas[pinataId]
	if def == nil then
		return nil
	end
	local model = PinataVisual.create(pinataId, mutation)
	local id = nextId
	nextId += 1
	local born = nextBorn()
	local shown = born <= os.clock()
	model:SetAttribute("ConveyorId", id)
	model:PivotTo(CFrame.new(current.spawnPos) * FACING)
	if shown then
		model.Parent = current.folder
	end
	local primary = model.PrimaryPart
	if primary ~= nil then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuyPrompt"
		local actionKey = if price == nil then "prompt.take" else "prompt.buy"
		Labels.prompt(prompt, actionKey, "pinata." .. pinataId)
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
		price = price,
		currency = currency,
		rarity = rarity,
		born = born,
		sold = false,
		shown = false,
		onShown = onShown,
	})
	if shown then
		reveal(slots[#slots])
	end
	return id
end

local function spawnSlot(pinataId: string, rarity: string)
	local def = Pinatas[pinataId]
	local price = if def ~= nil then def.Price else nil
	local currency = if def ~= nil and def.Currency == "Bastones" then "Bastones" else "Dulces"
	insertSlot(pinataId, rarity, rollMutation(), price, currency)
end

-- La intro pone un slot concreto. free = true no cobra aunque el roster tenga precio.
-- onShown corre cuando la piñata aparece de verdad (puede esperar MinGapSec detrás de otra).
function ConveyorService.offer(pinataId: string, mutation: string?, free: boolean, onShown: (() -> ())?): number?
	local def = Pinatas[pinataId]
	if def == nil then
		return nil
	end
	local price = if free then nil else def.Price
	local currency = if def.Currency == "Bastones" then "Bastones" else "Dulces"
	return insertSlot(pinataId, def.Rarity, mutation, price, currency, onShown)
end

function ConveyorService.tryBuy(player: Player, slotId: number)
	if type(slotId) ~= "number" then
		return
	end
	local slot = findSlot(slotId)
	if slot == nil or slot.sold or slot.model.Parent == nil then
		return
	end
	local position = slot.model:GetPivot().Position
	local root = Validators.rootOf(player)
	local distance = if root ~= nil then (root.Position - position).Magnitude else math.huge
	local allowed, why = AntiCheatService.authorize(player, "RequestBuy", position)
	if not allowed then
		if why == "distance" and distance >= 200 then
			Logger.flag(player, "RequestBuy.far", { distance = distance })
		end
		return
	end
	local data = Records.get(player)
	local candy = if data ~= nil then data.Dulces else 0
	local balance = candy
	if slot.currency == "Bastones" then
		balance = if data ~= nil then data.Bastones else 0
	end
	local ok, reason = BuyRules.evaluate({
		candy = candy,
		balance = balance,
		price = slot.price,
		distance = math.min(distance, Economy.Buy.MaxDistance),
		maxDistance = Economy.Buy.MaxDistance,
		hasRoom = BaseService.hasRoom(player.UserId),
	})
	if not ok then
		if reason == "distance" and distance >= 200 then
			Logger.flag(player, "RequestBuy.far", { distance = distance, reason = reason })
		end
		return
	end
	slot.sold = true
	removeSlot(slot)
	local accepted, reject =
		BaseService.acceptPurchase(player, slot.pinataId, slot.mutation, slot.model, slot.price, slot.currency)
	if not accepted then
		-- Sigue donde iba: volver a born = ahora la mandaba al inicio, encima de otra, y se podía retener.
		slot.sold = false
		table.insert(slots, slot)
		-- "funds" / "no_room" son rechazos normales, no un exploit.
		if distance >= 200 then
			Logger.flag(player, "RequestBuy.rejected", { distance = distance, reason = reject })
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
		if slot.sold then
			continue
		end
		local alpha = (os.clock() - slot.born) / cross
		if alpha < 0 then
			table.insert(keep, slot)
			continue
		end
		if slot.model.Parent == nil then
			if slot.shown then
				continue
			end
			slot.model.Parent = current.folder
			reveal(slot)
		end
		if alpha >= 1 then
			slot.model:Destroy()
		else
			local x = current.spawnPos.X + (current.exitPos.X - current.spawnPos.X) * alpha
			local bob = math.sin(os.clock() * 4 + slot.id) * 0.25
			slot.model:PivotTo(CFrame.new(x, current.height + bob, current.spawnPos.Z) * FACING)
			table.insert(keep, slot)
		end
	end
	slots = keep
end

function ConveyorService.init(_services: { [string]: any })
	for id, def in Pinatas do
		table.insert(rows, { id = id, rarity = def.Rarity, currency = def.Currency })
	end
	AntiCheatService.register("RequestBuy", function(player, args)
		local slotId = args[1]
		if type(slotId) ~= "number" then
			return
		end
		ConveyorService.tryBuy(player, slotId)
	end)
end

function ConveyorService.start()
	task.spawn(function()
		while true do
			-- Con una piñata de la intro esperando su turno no se sortea otra: la cola no crece.
			if pending() then
				step()
				task.wait(Economy.Conveyor.SpawnEverySec)
				continue
			end
			local pinataId, rarity = rollPinata()
			local headline = SpawnWeights.isHeadline(rarity) or pinataId == Events.PosadasPinateras.RunwayId
			if pinataId ~= nil and headline then
				Remotes.get("Announce"):FireAllClients("announce.runway:" .. pinataId, rarity)
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
