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
local FiestaRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("FiestaRules"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local SpawnWeights = require(Shared:WaitForChild("Gameplay"):WaitForChild("SpawnWeights"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local Validators = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Validators"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local PinataVisual = require(Server:WaitForChild("World"):WaitForChild("PinataVisual"))

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
	for _, row in payouts do
		local player = Players:GetPlayerByUserId(row.userId)
		if player ~= nil and row.candy > 0 then
			local data = Records.get(player)
			if data ~= nil and Records.grantDulces(player, row.candy) then
				data.Stats.FiestaCandy += row.candy
				pcall(function()
					AnalyticsService:LogCustomEvent(player, "fiesta_payout", row.candy)
				end)
				BaseService.pushState(player)
			end
		end
	end
	table.clear(hits)
	clearGiant()
	Remotes.get("Announce"):FireAllClients("¡La Piñata Gigante se abrió!", "Legendary")
end

local function beginRain()
	clearWilds()
	clearGiant()
	table.clear(hits)
	nextRain = os.clock()
	Remotes.get("Announce"):FireAllClients("¡FIESTA! Llueven piñatas en la plaza.", "Epic")
end

local function beginGiant()
	clearWilds()
	local count = #Players:GetPlayers()
	local hp = Economy.Fiesta.GiantBaseHp + Economy.Fiesta.GiantHpPerPlayer * count
	local pinataId = "dragon"
	if Pinatas[pinataId] == nil then
		pinataId = "pulpo"
	end
	giant = spawnModel(pinataId, "Epic", Vector3.new(0, 8, 0), hp)
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
	return {
		fiestaRemaining = FiestaRules.hudSeconds(into, Economy.Fiesta.EverySec, Economy.Fiesta.DurationSec),
		fiestaPhase = phase,
		fiestaLeft = FiestaRules.secondsLeft(into, Economy.Fiesta.DurationSec),
		giantHp = hp,
		giantMax = maxHp,
		myFiestaHits = hits[player.UserId] or 0,
	}
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

function EventService.init(_services: { [string]: any })
	for id, def in Pinatas do
		if def.Currency == "Dulces" and def.Price ~= nil then
			table.insert(rows, { id = id, rarity = def.Rarity, currency = def.Currency })
		end
	end
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
