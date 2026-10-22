--!strict
-- WP-06. Robar, cargar sobre la cabeza (WalkSpeed 11) y soltar en la base propia.
-- Si el portador suelta o se va, la piñata vuelve. Offline: la base ya no existe,
-- así que no hay nada que robar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Rarities = require(Shared:WaitForChild("Config"):WaitForChild("Rarities"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local StealRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("StealRules"))
local Inventory = require(Shared:WaitForChild("Gameplay"):WaitForChild("Inventory"))
local Profile = require(Shared:WaitForChild("Types"):WaitForChild("Profile"))

local Server = script.Parent.Parent
local Validation = require(Server:WaitForChild("Adapters"):WaitForChild("Validation"))
local ProfileAdapter = require(Server:WaitForChild("Adapters"):WaitForChild("ProfileAdapter"))
local Lifecycle = require(Server:WaitForChild("Adapters"):WaitForChild("Lifecycle"))
local PinataVisual = require(Server:WaitForChild("World"):WaitForChild("PinataVisual"))
local Movement = require(Server:WaitForChild("World"):WaitForChild("Movement"))
local Juice = require(Server:WaitForChild("World"):WaitForChild("Juice"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

type OwnedPinata = Profile.OwnedPinata

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
	local data = ProfileAdapter.getByUserId(userId)
	if data == nil then
		return nil
	end
	for _, item in data.pinatas do
		if item.uid == uid then
			return item
		end
	end
	return nil
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

local function beginCarry(
	player: Player,
	model: Model,
	owned: OwnedPinata,
	ownerUserId: number,
	pedestal: number
): boolean
	local root = Validation.root(player)
	if root == nil then
		return false
	end
	local oldPrompt = model:FindFirstChild("StealPrompt", true)
	if oldPrompt ~= nil then
		oldPrompt:Destroy()
	end
	PinataVisual.weldOverHead(model, root)
	markStolen(model, true)
	carried[player] = {
		uid = owned.uid,
		ownerUserId = ownerUserId,
		pedestal = pedestal,
		model = model,
		since = os.clock(),
		hitsTaken = 0,
		hitsRequired = hitsRequired(model),
		pinataId = owned.pinataId,
		mutation = owned.mutation,
	}
	player:SetAttribute("Carrying", true)
	if Movement.mode(player) ~= "stun" then
		Movement.setMode(player, "carry")
	end
	lastSteal[player] = os.clock()
	ProfileAdapter.noteRobbed(ownerUserId)
	Juice.confetti(root.Position, Tuning.Sfx.Steal)
	Juice.feedback("STEAL", root.Position)
	BaseService.pushState(player)
	local victim = Players:GetPlayerByUserId(ownerUserId)
	if victim ~= nil then
		BaseService.pushState(victim)
	end
	print(string.format("[Piñata] %s carga %s de %d", player.Name, owned.pinataId, ownerUserId))
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
	prompt.ActionText = "Robar"
	prompt.ObjectText = "Piñata"
	prompt.HoldDuration = Economy.StealPromptHoldSec
	prompt.MaxActivationDistance = Economy.Steal.MaxDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = primary
	prompt.Triggered:Connect(function(player)
		StealService.trySteal(player, ownerUserId, pedestalIndex)
	end)
end

local function victimRookie(userId: number): boolean
	local player = Players:GetPlayerByUserId(userId)
	if player ~= nil then
		return ProfileAdapter.isRookie(player)
	end
	return ProfileAdapter.isRookieUser(userId, nil)
end

local function recentAgainst(userId: number): number
	local data = ProfileAdapter.getByUserId(userId)
	if data == nil then
		return 0
	end
	return StealRules.countSince(data.robbedAt, os.time(), Economy.Steal.WindowSec)
end

function StealService.trySteal(player: Player, ownerUserId: number, pedestalIndex: number)
	if not Validation.allow(player, "RequestSteal") then
		return
	end
	if not Validation.isFinite(ownerUserId) or not Validation.isFinite(pedestalIndex) then
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
	local distance = Validation.distance(player, position)
	local ok, reason = StealRules.evaluate({
		distance = distance,
		inRange = Validation.inRange(player, position, Economy.Steal.MaxDistance),
		locked = false,
		alreadyCarrying = carried[player] ~= nil,
		thiefIsRookie = ProfileAdapter.isRookie(player),
		victimIsRookie = victimRookie(item.ownerUserId),
		cooldownReady = os.clock() - (lastSteal[player] or 0) >= Economy.Steal.CooldownSec,
		recentStealsOnVictim = recentAgainst(item.ownerUserId),
		maxStealsPerWindow = Economy.Steal.MaxPerVictimPer5Min,
		thiefHasRoom = BaseService.hasRoom(player.UserId),
		pinataAvailable = true,
		pinataProtected = os.clock() < item.protectedUntil,
	})
	if not ok then
		if StealRules.shouldLogFar(distance, reason) then
			Validation.flag(player, "RequestSteal.far", { distance = distance, reason = reason })
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
	local distance = Validation.distance(player, position)
	local ok, reason = StealRules.evaluate({
		distance = distance,
		inRange = Validation.inRange(player, position, Economy.Steal.MaxDistance),
		locked = lockService.isLocked(plotIndex),
		alreadyCarrying = carried[player] ~= nil,
		thiefIsRookie = ProfileAdapter.isRookie(player),
		victimIsRookie = victimRookie(ownerUserId),
		cooldownReady = os.clock() - (lastSteal[player] or 0) >= Economy.Steal.CooldownSec,
		recentStealsOnVictim = recentAgainst(ownerUserId),
		maxStealsPerWindow = Economy.Steal.MaxPerVictimPer5Min,
		thiefHasRoom = BaseService.hasRoom(player.UserId),
		pinataAvailable = true,
		pinataProtected = false,
	})
	if not ok then
		if StealRules.shouldLogFar(distance, reason) then
			Validation.flag(player, "RequestSteal.far", { distance = distance, reason = reason, owner = ownerUserId })
		end
		return
	end
	local model, owned = BaseService.detach(ownerUserId, pedestalIndex)
	if model == nil or owned == nil then
		return
	end
	if not beginCarry(player, model, owned, ownerUserId, pedestalIndex) then
		owned.inTransit = nil
		BaseService.receive(ownerUserId, owned, model, false)
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
	if os.clock() - carry.since < Tuning.MinCarrySec then
		return
	end
	if not BaseService.inOwnZone(player) then
		return
	end
	carried[player] = nil
	player:SetAttribute("Carrying", false)
	if Movement.mode(player) ~= "stun" then
		Movement.setMode(player, "normal")
	end
	local victimData = ProfileAdapter.getByUserId(carry.ownerUserId)
	local thiefData = ProfileAdapter.get(player)
	PinataVisual.unweld(carry.model)
	markStolen(carry.model, false)
	local function refundToOwner()
		local owned = findOwned(carry.ownerUserId, carry.uid)
		if owned ~= nil then
			owned.inTransit = nil
			BaseService.receive(carry.ownerUserId, owned, carry.model, false)
		elseif carry.model.Parent ~= nil then
			carry.model:Destroy()
		end
	end
	if victimData == nil or thiefData == nil then
		refundToOwner()
		return
	end
	local moved = Inventory.move(victimData.pinatas, thiefData.pinatas, carry.uid)
	if not moved then
		refundToOwner()
		return
	end
	local owned = findOwned(player.UserId, carry.uid)
	if owned == nil then
		for _, item in thiefData.pinatas do
			if item.uid == carry.uid then
				item.inTransit = nil
			end
		end
		if carry.model.Parent ~= nil then
			carry.model:Destroy()
		end
		return
	end
	owned.pedestal = nil
	BaseService.receive(player.UserId, owned, carry.model, true)
	local root = Validation.root(player)
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
		BaseService.receive(item.ownerUserId, item.owned, item.model, false)
	end)
end

function StealService.drop(player: Player)
	local carry = carried[player]
	if carry == nil then
		return
	end
	carried[player] = nil
	player:SetAttribute("Carrying", false)
	if Movement.mode(player) ~= "stun" then
		Movement.setMode(player, "normal")
	end
	local position = carry.model:GetPivot().Position
	carry.model.Parent = worldFolder()
	PinataVisual.unweld(carry.model)
	markStolen(carry.model, false)
	carry.model:PivotTo(CFrame.new(position))
	local owned = findOwned(carry.ownerUserId, carry.uid)
	local home = BaseService.plotOf(carry.ownerUserId)
	if owned == nil or home == nil then
		if owned ~= nil then
			owned.inTransit = nil
		end
		if carry.model.Parent ~= nil then
			carry.model:Destroy()
		end
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Robar"
	prompt.ObjectText = "Piñata suelta"
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
	Lifecycle.onLeave(20, function(player)
		lastSteal[player] = nil
		StealService.drop(player)
	end)
end

function StealService.start()
	Remotes.get("RequestSteal").OnServerEvent:Connect(function(player, ownerUserId, pedestalIndex)
		if type(ownerUserId) ~= "number" or type(pedestalIndex) ~= "number" then
			return
		end
		StealService.trySteal(player, ownerUserId, pedestalIndex)
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ready: { Player } = {}
			for player, carry in carried do
				if os.clock() - carry.since >= Tuning.MinCarrySec and BaseService.inOwnZone(player) then
					table.insert(ready, player)
				end
			end
			for _, player in ready do
				StealService.deliver(player)
			end
		end
	end)
	local function hook(player: Player)
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
