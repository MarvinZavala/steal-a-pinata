--!strict
-- WP-14. Fiesta alineada a UTC: lluvia y piñata gigante en este server.
-- Un solo loop. Las piñatas están ancladas y solo se golpean en el swing.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local Rarities = require(Shared:WaitForChild("Config"):WaitForChild("Rarities"))
local Events = require(Shared:WaitForChild("Config"):WaitForChild("Events"))
local EventCalendar = require(Shared:WaitForChild("Gameplay"):WaitForChild("EventCalendar"))
local DailyRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("DailyRules"))
local FiestaRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("FiestaRules"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local Security = require(Shared:WaitForChild("Config"):WaitForChild("Security"))
local SpawnWeights = require(Shared:WaitForChild("Gameplay"):WaitForChild("SpawnWeights"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local Transit = require(Server:WaitForChild("World"):WaitForChild("Transit"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local Validators = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Validators"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local Juice = require(Server:WaitForChild("World"):WaitForChild("Juice"))
local PinataVisual = require(Server:WaitForChild("World"):WaitForChild("PinataVisual"))
local PlaceBuilder = require(Server:WaitForChild("World"):WaitForChild("PlaceBuilder"))

local EventService = {}

type Wild = { model: Model, hp: number, rarity: string, pinataId: string }

local wilds: { Wild } = {}
local giant: Wild? = nil
local hits: { [number]: number } = {}
local phaseNow = "idle"
local windowId = -1
local paidWindow = -1
local nextRain = 0
local nextPush = 0
local rows: { SpawnWeights.RosterRow } = {}
local dressedDecor = false
local dressedParade = false
local dressedShop = false
local newYearBurst = false

local function forced(): boolean
	return EventCalendar.isForced(workspace:GetAttribute("ForcePosadas"))
end

local function phaseOverride(): string?
	local phase = workspace:GetAttribute("ForcePosadasPhase")
	if type(phase) == "string" then
		return phase
	end
	return nil
end

local function live()
	return EventCalendar.snapshot(os.time(), forced(), phaseOverride())
end

local function anchor(model: Model)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
		end
	end
end

local function clock(): (string, number, number)
	local now = os.time()
	local into = FiestaRules.into(now, Economy.Fiesta.EverySec)
	local phase = FiestaRules.phase(into, Economy.Fiesta.DurationSec, Economy.Fiesta.GiantSec)
	local window = math.floor(now / Economy.Fiesta.EverySec)
	return phase, window, into
end

local function clearWilds()
	for _, wild in wilds do
		if wild.model.Parent ~= nil then
			wild.model:Destroy()
		end
	end
	table.clear(wilds)
end

local function clearGiant()
	if giant ~= nil and giant.model.Parent ~= nil then
		giant.model:Destroy()
	end
	giant = nil
end

local function plazaPoint(): Vector3
	local angle = math.random() * math.pi * 2
	local radius = 8 + math.random() * 28
	return Vector3.new(math.cos(angle) * radius, 4, math.sin(angle) * radius)
end

local function spawnModel(pinataId: string, rarity: string, at: Vector3, hp: number): Wild
	local model = PinataVisual.create(pinataId, nil)
	anchor(model)
	model:PivotTo(CFrame.new(at))
	local world = workspace:FindFirstChild("World")
	model.Parent = if world ~= nil then world else workspace
	model:SetAttribute("Fiesta", true)
	return { model = model, hp = hp, rarity = rarity, pinataId = pinataId }
end

local function rollWild(): (string?, string)
	local rarity = SpawnWeights.pick(Rarities.SpawnWeight, math.random(), false, nil)
	local ids = SpawnWeights.eligibleIds(rows, rarity)
	return SpawnWeights.chooseId(ids, math.random()), rarity
end

local function payGiant()
	if paidWindow == windowId then
		return
	end
	paidWindow = windowId
	local rowsHit: { FiestaRules.HitRow } = {}
	local totalHits = 0
	for userId, count in hits do
		if count > 0 then
			totalHits += count
			table.insert(rowsHit, { userId = userId, hits = count })
		end
	end
	local pool = Economy.Fiesta.PoolBase + Economy.Fiesta.PoolPerHit * totalHits
	local payouts = FiestaRules.share(rowsHit, pool)
	local snap = live()
	local eventPool = 0
	if snap.fiestaVariant ~= "fiesta" then
		local rules = Events.PosadasPinateras
		eventPool = rules.FiestaBastonesBase + rules.FiestaBastonesPerHit * totalHits
	end
	local bastonPayouts = if eventPool > 0 then FiestaRules.share(rowsHit, eventPool) else {}
	local bastonOf: { [number]: number } = {}
	for _, row in bastonPayouts do
		local amount = row.candy
		if snap.fiestaVariant == "rosca" then
			amount = math.max(amount, Events.PosadasPinateras.RoscaFloor)
		end
		bastonOf[row.userId] = amount
	end
	for _, row in payouts do
		local player = Players:GetPlayerByUserId(row.userId)
		if player ~= nil and row.candy > 0 then
			local data = Records.get(player)
			if data ~= nil and Records.grantDulces(player, row.candy) then
				data.Stats.FiestaCandy += row.candy
				local bastones = bastonOf[row.userId]
				if bastones ~= nil and bastones > 0 then
					Records.grantCurrency(player, "Bastones", bastones)
				end
				pcall(function()
					AnalyticsService:LogCustomEvent(player, "fiesta_payout", row.candy)
				end)
				BaseService.pushState(player)
			end
		end
	end
	table.clear(hits)
	clearGiant()
	local giantKey = if snap.fiestaVariant == "fiesta" then "event.announce_giant" else "event.announce_giant_xmas"
	Remotes.get("Announce"):FireAllClients(giantKey, "Legendary")
end

local function beginRain()
	clearWilds()
	clearGiant()
	table.clear(hits)
	nextRain = os.clock()
	local snap = live()
	local key = "event.announce_fiesta"
	if snap.fiestaVariant == "posada" then
		key = "event.announce_posada"
	elseif snap.fiestaVariant == "newyear" then
		key = "event.announce_newyear"
	elseif snap.fiestaVariant == "rosca" then
		key = "event.announce_rosca"
	end
	Remotes.get("Announce"):FireAllClients(key, "Epic")
end

local function beginGiant()
	clearWilds()
	local count = #Players:GetPlayers()
	local hp = Economy.Fiesta.GiantBaseHp + Economy.Fiesta.GiantHpPerPlayer * count
	local snap = live()
	local pinataId = if snap.fiestaVariant == "fiesta" then "dragon" else Events.PosadasPinateras.GiantId
	if Pinatas[pinataId] == nil then
		pinataId = "pulpo"
	end
	local rarity = if snap.fiestaVariant == "fiesta" then "Epic" else "Event"
	local spawned = spawnModel(pinataId, rarity, Vector3.new(0, 8, 0), hp)
	giant = spawned
	if snap.fiestaVariant ~= "fiesta" then
		pcall(function()
			spawned.model:ScaleTo(2.2)
		end)
	end
end

function EventService.snapshot(player: Player): { [string]: any }
	local phase, _, into = clock()
	local hp = 0
	local maxHp = 0
	if giant ~= nil then
		hp = giant.hp
		maxHp = Economy.Fiesta.GiantBaseHp + Economy.Fiesta.GiantHpPerPlayer * #Players:GetPlayers()
		if hp > maxHp then
			maxHp = hp
		end
	end
	local snap = live()
	local targets = {}
	if snap.gift then
		for _, other in Players:GetPlayers() do
			if other ~= player and #targets < 6 then
				table.insert(targets, { userId = other.UserId, name = other.DisplayName })
			end
		end
	end
	return {
		fiestaRemaining = FiestaRules.hudSeconds(into, Economy.Fiesta.EverySec, Economy.Fiesta.DurationSec),
		fiestaPhase = phase,
		fiestaLeft = FiestaRules.secondsLeft(into, Economy.Fiesta.DurationSec),
		fiestaVariant = snap.fiestaVariant,
		eventActive = snap.active,
		eventShop = snap.shop,
		eventGift = snap.gift,
		giftTargets = targets,
		giantHp = hp,
		giantMax = maxHp,
		myFiestaHits = hits[player.UserId] or 0,
	}
end

local function refreshDress()
	local snap = live()
	if snap.decor == dressedDecor and snap.parade == dressedParade and snap.shop == dressedShop then
		return
	end
	dressedDecor = snap.decor
	dressedParade = snap.parade
	dressedShop = snap.shop
	PlaceBuilder.setEventDress(snap.decor, snap.parade, snap.shop)
end

local function settlePlayers()
	for _, player in Players:GetPlayers() do
		local data = Records.get(player)
		if data ~= nil then
			local changed, gained =
				EventCalendar.applySettle(data, os.time(), forced(), Security.MaxCurrency, phaseOverride())
			if changed then
				BaseService.pushState(player)
				if gained > 0 then
					Remotes.get("Feedback"):FireClient(player, "TOAST", {
						key = "event.settled",
						kind = "good",
						args = { n = tostring(gained) },
					})
				end
			end
		end
	end
end

local function pushSoon()
	local now = os.clock()
	if now < nextPush then
		return
	end
	nextPush = now + if phaseNow == "idle" then 5 else 1
	for _, player in Players:GetPlayers() do
		if Records.get(player) ~= nil then
			Remotes.get("StateChanged"):FireClient(player, EventService.snapshot(player))
		end
	end
end

local function step()
	local phase, window = clock()
	if window ~= windowId or phase ~= phaseNow then
		if phaseNow == "giant" and phase ~= "giant" then
			payGiant()
		end
		windowId = window
		if phase == "rain" and phaseNow ~= "rain" then
			beginRain()
		elseif phase == "giant" and phaseNow ~= "giant" then
			beginGiant()
		elseif phase == "idle" then
			clearWilds()
		end
		phaseNow = phase
	end
	if phaseNow == "rain" and os.clock() >= nextRain and #wilds < Economy.Fiesta.MaxAlive then
		nextRain = os.clock() + Economy.Fiesta.SpawnEverySec
		local pinataId, rarity = rollWild()
		if pinataId ~= nil then
			table.insert(wilds, spawnModel(pinataId, rarity, plazaPoint(), Economy.Fiesta.WildHp))
		end
	end
	refreshDress()
	local nowUnix = os.time()
	local newYear = Events.PosadasPinateras.NewYearUnix
	if not newYearBurst and nowUnix >= newYear and nowUnix < newYear + 90 then
		newYearBurst = true
		Juice.confetti(Vector3.new(0, 8, 0), nil)
		Remotes.get("Announce"):FireAllClients("event.announce_newyear", "Legendary")
	end
	if nowUnix % 30 == 0 then
		settlePlayers()
	end
	pushSoon()
end

local function hurt(player: Player, wild: Wild, origin: Vector3): boolean
	local position = wild.model:GetPivot().Position
	if (position - origin).Magnitude > Economy.Bat.MaxDistance then
		return false
	end
	if not Validators.inFront(player, position, Economy.Bat.MaxAngleDeg) then
		return false
	end
	wild.hp -= 1
	hits[player.UserId] = (hits[player.UserId] or 0) + 1
	local data = Records.get(player)
	local candy = FiestaRules.hitCandy(Economy.Fiesta.HitCandy, wild.rarity)
	if data ~= nil and candy > 0 and Records.grantDulces(player, candy) then
		data.Stats.FiestaCandy += candy
	end
	local snap = live()
	if data ~= nil and snap.fiestaVariant ~= "fiesta" then
		Records.grantCurrency(player, "Bastones", Events.PosadasPinateras.HitBastones)
	end
	return true
end

function EventService.onSwing(player: Player, origin: Vector3)
	if phaseNow == "idle" then
		return
	end
	if phaseNow == "giant" and giant ~= nil and giant.hp > 0 then
		if hurt(player, giant, origin) and giant.hp <= 0 then
			payGiant()
		end
		return
	end
	local best: Wild? = nil
	local bestDistance = math.huge
	for _, wild in wilds do
		if wild.hp > 0 and wild.model.Parent ~= nil then
			local distance = (wild.model:GetPivot().Position - origin).Magnitude
			if distance < bestDistance then
				best = wild
				bestDistance = distance
			end
		end
	end
	if best == nil then
		return
	end
	if not hurt(player, best, origin) then
		return
	end
	if best.hp > 0 then
		return
	end
	local pinataId = best.pinataId
	if best.model.Parent ~= nil then
		best.model:Destroy()
	end
	local keep: { Wild } = {}
	for _, wild in wilds do
		if wild ~= best then
			table.insert(keep, wild)
		end
	end
	wilds = keep
	local data = Records.get(player)
	if data ~= nil and math.random() < Economy.Fiesta.CaptureChance and Records.hasRoom(data) then
		local granted, instanceId = Records.grantPinata(player, pinataId, "None")
		if granted and instanceId ~= nil then
			local owned = Records.find(data, instanceId)
			if owned ~= nil then
				local model = PinataVisual.create(pinataId, nil)
				BaseService.receive(player.UserId, owned, model, true, nil)
			end
		end
	end
end

local function deny(player: Player, key: string)
	Remotes.get("Feedback"):FireClient(player, "DENIED", { key = key })
end

local function givePinata(player: Player, data: Records.PlayerData, pinataId: string, mutation: string?): boolean
	if Pinatas[pinataId] == nil or not Records.hasRoom(data) then
		return false
	end
	local granted, instanceId = Records.grantPinata(player, pinataId, mutation or "None")
	if not granted or instanceId == nil then
		return false
	end
	local owned = Records.find(data, instanceId)
	if owned == nil then
		return false
	end
	local model = PinataVisual.create(pinataId, mutation)
	BaseService.receive(player.UserId, owned, model, true, nil)
	return true
end

local function nearNavidad(player: Player): boolean
	local root = Validators.rootOf(player)
	if root == nil then
		return false
	end
	local world = workspace:FindFirstChild("World")
	if world == nil then
		return false
	end
	for _, child in world:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("KioskId") == "navidad" then
			if (root.Position - child.Position).Magnitude <= Economy.Buy.MaxDistance + 8 then
				return true
			end
		end
	end
	return false
end

local function onAdvent(player: Player)
	local data = Records.get(player)
	if data == nil then
		return
	end
	local snap = live()
	local day = EventCalendar.adventDay(os.time(), snap)
	if day == nil then
		deny(player, "event.advent_closed")
		return
	end
	local bit = EventCalendar.adventBit(day)
	if bit == 0 or bit32.band(data.AdventMask, bit) ~= 0 then
		deny(player, "daily.already")
		return
	end
	local misses = EventCalendar.missesBefore(data.AdventMask, day)
	local prize = EventCalendar.adventReward(day, misses)
	data.AdventMask = bit32.bor(data.AdventMask, bit)
	Records.grantCurrency(player, "Bastones", prize.bastones)
	if prize.pinataId ~= nil and not givePinata(player, data, prize.pinataId, nil) then
		local extra = Events.PosadasPinateras.AdventFinaleBastones - prize.bastones
		if extra > 0 then
			Records.grantCurrency(player, "Bastones", extra)
		end
	end
	BaseService.pushState(player)
	Remotes.get("Feedback"):FireClient(player, "TOAST", {
		key = "event.advent_body",
		kind = "good",
		args = { n = tostring(prize.bastones) },
	})
end

local function skuPrice(sku: string): (string, number)
	local rules = Events.PosadasPinateras
	if sku == rules.HatId then
		return "hat", rules.HatPrice
	end
	if sku == rules.HugId then
		return "hug", rules.HugPrice
	end
	local def = Pinatas[sku]
	if def ~= nil and def.Currency == "Bastones" and def.Price ~= nil then
		for _, id in rules.ShopIds do
			if id == sku then
				return "pinata", def.Price
			end
		end
	end
	return "nope", 0
end

local function onEventBuy(player: Player, args: { any })
	local sku = args[1]
	local data = Records.get(player)
	if data == nil or type(sku) ~= "string" then
		return
	end
	if not live().shop then
		deny(player, "event_off")
		return
	end
	if not nearNavidad(player) then
		deny(player, "far")
		return
	end
	local kind, price = skuPrice(sku)
	if kind == "nope" or price <= 0 then
		return
	end
	if kind ~= "pinata" and data.Cosmetics[sku] == true then
		deny(player, "common.owned")
		return
	end
	if not Records.trySpend(player, "Bastones", price) then
		deny(player, "poor_bastones")
		return
	end
	if kind == "pinata" then
		if not givePinata(player, data, sku, nil) then
			Records.grantCurrency(player, "Bastones", price)
			deny(player, "full")
			return
		end
	else
		data.Cosmetics[sku] = true
	end
	BaseService.pushState(player)
	Remotes.get("Feedback"):FireClient(player, "PURCHASE", {})
end

local function onGift(player: Player, args: { any })
	local data = Records.get(player)
	local targetId = args[1]
	local pedestal = args[2]
	if data == nil or type(targetId) ~= "number" or type(pedestal) ~= "number" then
		return
	end
	if not live().gift then
		deny(player, "event.gift_closed")
		return
	end
	local today = DailyRules.dayIndex(os.time())
	if data.GiftDay == today then
		deny(player, "event.gift_limit")
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if target == nil or target == player then
		deny(player, "event.gift_alone")
		return
	end
	local instanceId = data.Placed[tostring(pedestal)]
	if type(instanceId) ~= "string" then
		deny(player, "event.gift_need")
		return
	end
	if Transit.has(instanceId) then
		deny(player, "busy")
		return
	end
	if not Records.movePinata(player, target, instanceId) then
		deny(player, "full")
		return
	end
	data.GiftDay = today
	BaseService.resync(player)
	BaseService.pushState(target)
	Remotes.get("Feedback"):FireClient(player, "TOAST", { key = "event.gift_sent", kind = "good" })
	Remotes.get("Feedback"):FireClient(target, "TOAST", {
		key = "event.gift_got",
		kind = "good",
		args = { name = player.DisplayName },
	})
end

function EventService.init(_services: { [string]: any })
	for id, def in Pinatas do
		if def.Currency == "Dulces" and def.Price ~= nil then
			table.insert(rows, { id = id, rarity = def.Rarity, currency = def.Currency })
		end
	end
	AntiCheatService.register("RequestClaimAdvent", function(player)
		onAdvent(player)
	end)
	AntiCheatService.register("RequestEventBuy", onEventBuy)
	AntiCheatService.register("RequestGift", onGift)
end

function EventService.start()
	task.spawn(function()
		while true do
			step()
			task.wait(0.25)
		end
	end)
end

return EventService
