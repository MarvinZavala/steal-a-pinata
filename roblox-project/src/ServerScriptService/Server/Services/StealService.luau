--!strict
-- WP-06. Robar, cargar sobre la cabeza (WalkSpeed 11) y soltar en la base propia.
-- Si el portador suelta o se va, la piñata vuelve. Offline: la base ya no existe,
-- así que no hay nada que robar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local FairPlay = require(Shared:WaitForChild("Config"):WaitForChild("FairPlay"))
local Rarities = require(Shared:WaitForChild("Config"):WaitForChild("Rarities"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local CarryIntegrity = require(Shared:WaitForChild("Gameplay"):WaitForChild("CarryIntegrity"))
local StealRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("StealRules"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local Lifecycle = require(Server:WaitForChild("Adapters"):WaitForChild("Lifecycle"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local Validators = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Validators"))
local Logger = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Logger"))
local Labels = require(Server:WaitForChild("World"):WaitForChild("Labels"))
local PinataVisual = require(Server:WaitForChild("World"):WaitForChild("PinataVisual"))
local Movement = require(Server:WaitForChild("World"):WaitForChild("Movement"))
local Transit = require(Server:WaitForChild("World"):WaitForChild("Transit"))
local Juice = require(Server:WaitForChild("World"):WaitForChild("Juice"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

type OwnedPinata = Records.OwnedPinata

type Carry = {
	uid: string,
	ownerUserId: number,
	pedestal: number,
	model: Model,
	since: number,
	hitsTaken: number,
	hitsRequired: number,
	pinataId: string,
	mutation: string?,
	generation: number,
}

type Loose = {
	uid: string,
	ownerUserId: number,
	pedestal: number,
	model: Model,
	protectedUntil: number,
	alive: boolean,
	owned: OwnedPinata,
	prompt: ProximityPrompt?,
}

local StealService = {}

local carried: { [Player]: Carry } = {}
local lastSteal: { [Player]: number } = {}
local loose: { Loose } = {}
local ledger = CarryIntegrity.empty()

local function hitsRequired(model: Model): number
	local rarity = model:GetAttribute("Rarity")
	if typeof(rarity) ~= "string" then
		return 1
	end
	local needed = Rarities.HitsToDrop[rarity]
	if type(needed) == "number" then
		return needed
	end
	return 1
end

function StealService.isCarrying(player: Player): boolean
	return carried[player] ~= nil
end

function StealService.peek(player: Player): Carry?
	return carried[player]
end

local function findOwned(userId: number, uid: string): OwnedPinata?
	local data = Records.byUserId(userId)
	if data == nil then
		return nil
	end
	return Records.find(data, uid)
end

local function measure(player: Player, position: Vector3): number
	local root = Validators.rootOf(player)
	if root == nil then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

-- authorize() es la distancia (y el slack de ping) del anti-cheat. Si pasa,
-- las reglas de juego ven la distancia recortada al máximo para no pelearse con el slack.
local function approach(player: Player, action: string, position: Vector3, maxDistance: number): (boolean, number)
	local distance = measure(player, position)
	local allowed, why = AntiCheatService.authorize(player, action, position)
	if not allowed then
		if why == "distance" and distance >= 200 then
			Logger.flag(player, action .. ".far", { distance = distance })
		end
		return false, distance
	end
	return true, math.min(distance, maxDistance)
end

local function worldFolder(): Instance
	local current = BaseService.getWorld()
	if current ~= nil then
		return current.folder
	end
	return workspace
end

local function markStolen(model: Model, on: boolean)
	local existing = model:FindFirstChild("StolenMark")
	if on then
		if existing == nil then
			local highlight = Instance.new("Highlight")
			highlight.Name = "StolenMark"
			highlight.FillColor = Color3.fromHex("#FF3E9A")
			highlight.OutlineColor = Color3.fromHex("#FFE14D")
			highlight.FillTransparency = 0.55
			highlight.Parent = model
		end
	elseif existing ~= nil then
		existing:Destroy()
	end
end

local function leagueService(): any
	return require(script.Parent:WaitForChild("LeagueService"))
end

local function outranks(player: Player, victimUserId: number): boolean
	local league = leagueService()
	if type(league) ~= "table" or type(league.outranks) ~= "function" then
		return false
	end
	return league.outranks(player, victimUserId) == true
end

local function beginCarry(
	player: Player,
	model: Model,
	owned: OwnedPinata,
	ownerUserId: number,
	pedestal: number
): boolean
	local root = Validators.rootOf(player)
	if root == nil then
		return false
	end
	if AntiCheatService.carryLocked(player) then
		return false
	end
	local nextLedger, opened, why, generation =
		CarryIntegrity.begin(ledger, owned.InstanceId, ownerUserId, player.UserId)
	if not opened then
		AntiCheatService.reportStrike(player, "carry_dupe")
		warn("[WP-10b] carga rechazada", player.Name, owned.InstanceId, why)
		return false
	end
	ledger = nextLedger
	local oldPrompt = model:FindFirstChild("StealPrompt", true)
	if oldPrompt ~= nil then
		oldPrompt:Destroy()
	end
	PinataVisual.weldOverHead(model, root)
	markStolen(model, true)
	carried[player] = {
		uid = owned.InstanceId,
		ownerUserId = ownerUserId,
		pedestal = pedestal,
		model = model,
		since = os.clock(),
		hitsTaken = 0,
		hitsRequired = hitsRequired(model),
		pinataId = owned.PinataId,
		mutation = Records.mutationOf(owned),
		generation = generation,
	}
	player:SetAttribute("Carrying", true)
	if Movement.mode(player) ~= "stun" then
		Movement.setMode(player, "carry")
	end
	lastSteal[player] = os.clock()
	local victimData = Records.byUserId(ownerUserId)
	if victimData ~= nil then
		Records.noteRobbed(victimData)
	end
	local thiefData = Records.get(player)
	if thiefData ~= nil then
		thiefData.Stats.Steals += 1
	end
	Juice.confetti(root.Position, Tuning.Sfx.Steal)
	Juice.feedback("STEAL", root.Position)
	BaseService.pushState(player)
	local victim = Players:GetPlayerByUserId(ownerUserId)
	if victim ~= nil then
		BaseService.pushState(victim)
	end
	print(string.format("[Piñata] %s carga %s de %d", player.Name, owned.PinataId, ownerUserId))
	return true
end

local function addPrompt(ownerUserId: number, pedestalIndex: number, model: Model)
	local primary = model.PrimaryPart
	if primary == nil then
		return
	end
	if primary:FindFirstChild("StealPrompt") ~= nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	Labels.prompt(prompt, "prompt.steal", "prompt.pinata")
	prompt.HoldDuration = Economy.StealPromptHoldSec
	prompt.MaxActivationDistance = Economy.Steal.MaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = primary
	prompt.Triggered:Connect(function(player)
		StealService.trySteal(player, ownerUserId, pedestalIndex)
	end)
end

local function victimRookie(userId: number): boolean
	local data = Records.byUserId(userId)
	if data == nil then
		return false
	end
	return Records.isRookie(data)
end

local function thiefRookie(player: Player): boolean
	local data = Records.get(player)
	if data == nil then
		return true
	end
	return Records.isRookie(data)
end

local function recentAgainst(userId: number): number
	local data = Records.byUserId(userId)
	if data == nil then
		return 0
	end
	return Records.recentRobbed(data, os.time())
end

function StealService.trySteal(player: Player, ownerUserId: number, pedestalIndex: number)
	if AntiCheatService.carryLocked(player) then
		return
	end
	if type(ownerUserId) ~= "number" or type(pedestalIndex) ~= "number" then
		return
	end
	ownerUserId = math.floor(ownerUserId)
	pedestalIndex = math.floor(pedestalIndex)
	if player.UserId == ownerUserId then
		return
	end
	for _, item in loose do
		if item.alive and item.ownerUserId == ownerUserId and item.pedestal == pedestalIndex then
			StealService.grabLoose(player, item)
			return
		end
	end
	StealService.grabSeated(player, ownerUserId, pedestalIndex)
end

function StealService.grabLoose(player: Player, item: Loose)
	if not item.alive or item.model.Parent == nil then
		return
	end
	local position = item.model:GetPivot().Position
	local near, distance = approach(player, "RequestSteal", position, Economy.Steal.MaxDistance)
	if not near then
		return
	end
	local ok, reason = StealRules.evaluate({
		distance = distance,
		inRange = true,
		locked = false,
		alreadyCarrying = carried[player] ~= nil,
		thiefIsRookie = thiefRookie(player),
		victimIsRookie = victimRookie(item.ownerUserId),
		thiefOutranksVictim = outranks(player, item.ownerUserId),
		cooldownReady = os.clock() - (lastSteal[player] or 0) >= Economy.Steal.CooldownSec,
		recentStealsOnVictim = recentAgainst(item.ownerUserId),
		maxStealsPerWindow = Economy.Steal.MaxPerVictimPer5Min,
		thiefHasRoom = BaseService.hasRoom(player.UserId),
		pinataAvailable = true,
		pinataProtected = os.clock() < item.protectedUntil,
	})
	if not ok then
		if StealRules.shouldLogFar(distance, reason) then
			Logger.flag(player, "RequestSteal.far", { distance = distance, reason = reason })
		end
		return
	end
	item.alive = false
	if item.prompt ~= nil then
		item.prompt:Destroy()
	end
	if not beginCarry(player, item.model, item.owned, item.ownerUserId, item.pedestal) then
		item.alive = true
	end
end

function StealService.grabSeated(player: Player, ownerUserId: number, pedestalIndex: number)
	local position = BaseService.anchorPosition(ownerUserId, pedestalIndex)
	local plotIndex = BaseService.plotIndexOf(ownerUserId)
	if position == nil or plotIndex == nil then
		return
	end
	local lockService = require(script.Parent:WaitForChild("LockService"))
	local near, distance = approach(player, "RequestSteal", position, Economy.Steal.MaxDistance)
	if not near then
		return
	end
	local ok, reason = StealRules.evaluate({
		distance = distance,
		inRange = true,
		locked = lockService.isLocked(plotIndex),
		alreadyCarrying = carried[player] ~= nil,
		thiefIsRookie = thiefRookie(player),
		victimIsRookie = victimRookie(ownerUserId),
		thiefOutranksVictim = outranks(player, ownerUserId),
		cooldownReady = os.clock() - (lastSteal[player] or 0) >= Economy.Steal.CooldownSec,
		recentStealsOnVictim = recentAgainst(ownerUserId),
		maxStealsPerWindow = Economy.Steal.MaxPerVictimPer5Min,
		thiefHasRoom = BaseService.hasRoom(player.UserId),
		pinataAvailable = true,
		pinataProtected = false,
	})
	if not ok then
		if StealRules.shouldLogFar(distance, reason) then
			Logger.flag(player, "RequestSteal.far", { distance = distance, reason = reason, owner = ownerUserId })
		end
		return
	end
	local model, owned = BaseService.detach(ownerUserId, pedestalIndex)
	if model == nil or owned == nil then
		return
	end
	if not beginCarry(player, model, owned, ownerUserId, pedestalIndex) then
		Transit.set(owned.InstanceId, false)
		BaseService.receive(ownerUserId, owned, model, false, pedestalIndex)
		return
	end
	lockService.grant(plotIndex, Economy.Lock.AfterRobbedFreeSec, ownerUserId)
	lockService.letLeave(player, 4)
end

local function removeLoose(item: Loose)
	local keep: { Loose } = {}
	for _, other in loose do
		if other ~= item then
			table.insert(keep, other)
		end
	end
	loose = keep
end

function StealService.deliver(player: Player)
	local carry = carried[player]
	if carry == nil then
		return
	end
	if AntiCheatService.carryLocked(player) then
		StealService.drop(player)
		return
	end
	local root = Validators.rootOf(player)
	local modelPos = carry.model:GetPivot().Position
	local offset = if root ~= nil then (root.Position - modelPos).Magnitude else math.huge
	local crosses = false
	if root ~= nil then
		crosses = AntiCheatService.segmentBlocked(root.Position, modelPos)
	end
	local allowed, why = CarryIntegrity.canDeliver({
		inside = BaseService.inOwnZone(player),
		modelOffset = offset,
		maxOffset = FairPlay.MaxCarrySeparation,
		age = os.clock() - carry.since,
		minAge = Tuning.MinCarrySec,
		crossesSolid = crosses,
	})
	if not allowed then
		if why == "wall" then
			AntiCheatService.reportStrike(player, "carry_wall")
		elseif why == "far" then
			AntiCheatService.reportStrike(player, "carry_far")
		end
		return
	end
	local nextLedger, committed, reason = CarryIntegrity.deliver(ledger, carry.uid, carry.generation, player.UserId)
	if not committed then
		AntiCheatService.reportStrike(player, "carry_dupe")
		warn("[WP-10b] entrega duplicada", player.Name, carry.uid, reason)
		StealService.drop(player)
		return
	end
	ledger = nextLedger
	carried[player] = nil
	player:SetAttribute("Carrying", false)
	if Movement.mode(player) ~= "stun" then
		Movement.setMode(player, "normal")
	end
	local victim = Players:GetPlayerByUserId(carry.ownerUserId)
	local victimData = if victim ~= nil then Records.get(victim) else nil
	local thiefData = Records.get(player)
	PinataVisual.unweld(carry.model)
	markStolen(carry.model, false)
	local function refundToOwner()
		ledger = CarryIntegrity.restore(ledger, carry.uid, carry.ownerUserId)
		local owned = findOwned(carry.ownerUserId, carry.uid)
		if owned ~= nil then
			Transit.set(owned.InstanceId, false)
			BaseService.receive(carry.ownerUserId, owned, carry.model, false, carry.pedestal)
		elseif carry.model.Parent ~= nil then
			Transit.set(carry.uid, false)
			carry.model:Destroy()
		end
	end
	if victim == nil or victimData == nil or thiefData == nil then
		refundToOwner()
		return
	end
	local moved = Records.movePinata(victim, player, carry.uid)
	if not moved then
		refundToOwner()
		return
	end
	Transit.set(carry.uid, false)
	local owned = Records.find(thiefData, carry.uid)
	if owned == nil then
		if carry.model.Parent ~= nil then
			carry.model:Destroy()
		end
		return
	end
	BaseService.receive(player.UserId, owned, carry.model, true, nil)
	local at = if root ~= nil then root.Position else carry.model:GetPivot().Position
	Juice.confetti(at, Tuning.Sfx.Deliver)
	Juice.feedback("DELIVER", at)
	BaseService.pushState(player)
	print(string.format("[Piñata] %s entregó %s en su base", player.Name, carry.pinataId))
end

local function sendHome(item: Loose)
	task.spawn(function()
		local goal = BaseService.anchorPosition(item.ownerUserId, item.pedestal)
		if goal == nil or item.model.Parent == nil then
			item.alive = false
			Transit.set(item.uid, false)
			return
		end
		local primary = item.model.PrimaryPart
		local lift = if primary ~= nil then math.max(primary.Size.Y * 0.5, 1.4) else 1.6
		local startPos = item.model:GetPivot().Position
		local target = goal + Vector3.new(0, lift, 0)
		local dist = (target - startPos).Magnitude
		local dur = math.clamp(dist / Economy.Return.WalkSpeed, 0.6, 10)
		local t0 = os.clock()
		while item.alive and item.model.Parent ~= nil do
			local alpha = math.clamp((os.clock() - t0) / dur, 0, 1)
			local pos = startPos:Lerp(target, alpha)
			local bob = math.sin(alpha * math.pi * 6) * 0.3
			item.model:PivotTo(CFrame.new(pos + Vector3.new(0, bob, 0)))
			if alpha >= 1 then
				break
			end
			task.wait(0.05)
		end
		if not item.alive or item.model.Parent == nil then
			return
		end
		item.alive = false
		if item.prompt ~= nil then
			item.prompt:Destroy()
		end
		removeLoose(item)
		BaseService.receive(item.ownerUserId, item.owned, item.model, false, item.pedestal)
	end)
end

function StealService.drop(player: Player)
	local carry = carried[player]
	if carry == nil then
		return
	end
	local root = Validators.rootOf(player)
	local position = carry.model:GetPivot().Position
	if root ~= nil and AntiCheatService.segmentBlocked(root.Position, position) then
		AntiCheatService.reportStrike(player, "carry_wall")
		local safe = AntiCheatService.lastGoodVector(player)
		if safe ~= nil then
			position = safe
		end
	end
	local nextLedger = CarryIntegrity.abort(ledger, carry.uid, carry.generation)
	ledger = nextLedger
	carried[player] = nil
	player:SetAttribute("Carrying", false)
	if Movement.mode(player) ~= "stun" then
		Movement.setMode(player, "normal")
	end
	carry.model.Parent = worldFolder()
	PinataVisual.unweld(carry.model)
	markStolen(carry.model, false)
	carry.model:PivotTo(CFrame.new(position))
	local owned = findOwned(carry.ownerUserId, carry.uid)
	local home = BaseService.plotOf(carry.ownerUserId)
	if owned == nil or home == nil then
		Transit.set(carry.uid, false)
		if carry.model.Parent ~= nil then
			carry.model:Destroy()
		end
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	Labels.prompt(prompt, "prompt.steal", "prompt.loose")
	prompt.HoldDuration = Economy.StealPromptHoldSec
	prompt.MaxActivationDistance = Economy.Steal.MaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	if carry.model.PrimaryPart ~= nil then
		prompt.Parent = carry.model.PrimaryPart
	end
	local item: Loose = {
		uid = carry.uid,
		ownerUserId = carry.ownerUserId,
		pedestal = carry.pedestal,
		model = carry.model,
		protectedUntil = os.clock() + Economy.Return.ProtectSec,
		alive = true,
		owned = owned,
		prompt = prompt,
	}
	prompt.Triggered:Connect(function(who)
		StealService.grabLoose(who, item)
	end)
	table.insert(loose, item)
	task.delay(Economy.Return.ProtectSec, function()
		if item.alive and item.prompt ~= nil then
			item.prompt.Enabled = true
		end
	end)
	Juice.feedback("DROP", position)
	sendHome(item)
	BaseService.pushState(player)
end

function StealService.init(_services: { [string]: any })
	BaseService.onSeated(addPrompt)
	BaseService.forEachSeated(addPrompt)
	AntiCheatService.register("RequestSteal", function(player, args)
		local ownerUserId = args[1]
		local pedestalIndex = args[2]
		if type(ownerUserId) ~= "number" or type(pedestalIndex) ~= "number" then
			return
		end
		StealService.trySteal(player, ownerUserId, pedestalIndex)
	end)
	Lifecycle.onLeave(20, function(player)
		lastSteal[player] = nil
		StealService.drop(player)
	end)
end

function StealService.start()
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ready: { Player } = {}
			for player, carry in carried do
				local locked = AntiCheatService.carryLocked(player)
				local home = os.clock() - carry.since >= Tuning.MinCarrySec and BaseService.inOwnZone(player)
				if locked or home then
					table.insert(ready, player)
				end
			end
			for _, player in ready do
				if AntiCheatService.carryLocked(player) then
					StealService.drop(player)
				else
					StealService.deliver(player)
				end
			end
		end
	end)
	local function hook(player: Player)
		local returnedLedger, returned = CarryIntegrity.rejoin(ledger, player.UserId)
		ledger = returnedLedger
		if #returned > 0 then
			warn("[WP-10b] rejoin devuelve", player.UserId, table.concat(returned, ","))
		end
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 8)
			if humanoid ~= nil and humanoid:IsA("Humanoid") then
				humanoid.Died:Connect(function()
					StealService.drop(player)
				end)
			end
		end)
		local character = player.Character
		if character ~= nil then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid ~= nil then
				humanoid.Died:Connect(function()
					StealService.drop(player)
				end)
			end
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return StealService
