--!strict
-- WP-04. Asigna una base, produce Dulces/s, guarda la Dulcería y no deja
-- nada robable cuando el jugador se va (las piñatas quedan en el perfil).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Layout = require(Shared:WaitForChild("Config"):WaitForChild("WorldLayout"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local AssignPlots = require(Shared:WaitForChild("Gameplay"):WaitForChild("AssignPlots"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local Lifecycle = require(Server:WaitForChild("Adapters"):WaitForChild("Lifecycle"))
local Validators = require(Server:WaitForChild("Services"):WaitForChild("AntiCheat"):WaitForChild("Validators"))
local PlaceBuilder = require(Server:WaitForChild("World"):WaitForChild("PlaceBuilder"))
local PinataVisual = require(Server:WaitForChild("World"):WaitForChild("PinataVisual"))
local Movement = require(Server:WaitForChild("World"):WaitForChild("Movement"))
local Transit = require(Server:WaitForChild("World"):WaitForChild("Transit"))
local Juice = require(Server:WaitForChild("World"):WaitForChild("Juice"))

type OwnedPinata = Records.OwnedPinata
type Plot = PlaceBuilder.Plot
type Pedestal = PlaceBuilder.Pedestal
type SeatFn = (userId: number, pedestalIndex: number, model: Model) -> ()

local BaseService = {}

local world: PlaceBuilder.World? = nil
local servicesRef: { [string]: any } = {}
local assignments = AssignPlots.new()
local seatFn: SeatFn? = nil
local lastCollect: { [Player]: number } = {}
local OPEN = Color3.fromHex("#FFE6B8")
local CLOSED = Color3.fromHex("#3A2A55")

local function plotByIndex(index: number): Plot?
	local current = world
	if current == nil then
		return nil
	end
	return current.plots[index]
end

function BaseService.getWorld(): PlaceBuilder.World?
	return world
end

function BaseService.plotOf(userId: number): Plot?
	for index, owner in assignments do
		if owner == userId then
			return plotByIndex(index)
		end
	end
	return nil
end

function BaseService.plotIndexOf(userId: number): number?
	for index, owner in assignments do
		if owner == userId then
			return index
		end
	end
	return nil
end

local function pedestalByIndex(plot: Plot, index: number): Pedestal?
	for _, pedestal in plot.pedestals do
		if pedestal.index == index then
			return pedestal
		end
	end
	return nil
end

local function firstFree(plot: Plot, count: number): Pedestal?
	for _, pedestal in plot.pedestals do
		if pedestal.index <= count and pedestal.uid == nil then
			return pedestal
		end
	end
	return nil
end

function BaseService.anchorPosition(userId: number, index: number): Vector3?
	local plot = BaseService.plotOf(userId)
	if plot == nil then
		return nil
	end
	local pedestal = pedestalByIndex(plot, index)
	if pedestal == nil then
		return nil
	end
	return pedestal.anchor.Position
end

function BaseService.hasRoom(userId: number): boolean
	local data = Records.byUserId(userId)
	if data == nil then
		return false
	end
	return Records.hasRoom(data)
end

function BaseService.contains(userId: number, position: Vector3): boolean
	local plot = BaseService.plotOf(userId)
	if plot == nil then
		return false
	end
	local localPos = plot.cframe:PointToObjectSpace(position)
	return math.abs(localPos.X) <= Layout.FloorX / 2
		and math.abs(localPos.Z) <= Layout.FloorZ / 2
		and localPos.Y > -4
		and localPos.Y < 28
end

function BaseService.inOwnZone(player: Player): boolean
	local root = Validators.rootOf(player)
	if root == nil then
		return false
	end
	return BaseService.contains(player.UserId, root.Position)
end

function BaseService.onSeated(fn: SeatFn)
	seatFn = fn
end

function BaseService.forEachSeated(fn: SeatFn)
	local current = world
	if current == nil then
		return
	end
	for _, plot in current.plots do
		if plot.ownerUserId ~= nil then
			for _, pedestal in plot.pedestals do
				if pedestal.model ~= nil and pedestal.uid ~= nil then
					fn(plot.ownerUserId, pedestal.index, pedestal.model)
				end
			end
		end
	end
end

function BaseService.setPromptsEnabled(plotIndex: number, enabled: boolean)
	local plot = plotByIndex(plotIndex)
	if plot == nil then
		return
	end
	for _, pedestal in plot.pedestals do
		local model = pedestal.model
		if model ~= nil then
			local prompt = model:FindFirstChild("StealPrompt", true)
			if prompt ~= nil and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = enabled
			end
		end
	end
end

local function locked(plot: Plot): boolean
	local lockService = servicesRef.LockService
	if type(lockService) ~= "table" or type(lockService.isLocked) ~= "function" then
		return false
	end
	return lockService.isLocked(plot.index) == true
end

function BaseService.pushState(player: Player)
	local data = Records.get(player)
	if data == nil then
		return
	end
	local perSec = Records.production(data)
	local plot = BaseService.plotOf(player.UserId)
	if plot ~= nil then
		plot.generatorLabel.Text = string.format("DULCERÍA\n%s\n+%s/s", Format(data.VaultCandy), Format(perSec))
	end
	Records.refreshLeaderstats(player)
	local carrying: any = false
	local steal = servicesRef.StealService
	if type(steal) == "table" and type(steal.peek) == "function" then
		local carry = steal.peek(player)
		if type(carry) == "table" then
			local hitsRequired = if type(carry.hitsRequired) == "number" then carry.hitsRequired else 1
			local hitsTaken = if type(carry.hitsTaken) == "number" then carry.hitsTaken else 0
			carrying = {
				pinataId = carry.pinataId,
				mutation = if type(carry.mutation) == "string" then carry.mutation else "None",
				fromUserId = carry.ownerUserId,
				hitsLeft = math.max(0, hitsRequired - hitsTaken),
			}
		end
	end
	local owned = {}
	for _, item in data.Inventory do
		table.insert(owned, {
			uid = item.InstanceId,
			pinataId = item.PinataId,
			mutation = item.Mutation,
			pedestal = Records.slotOf(data, item.InstanceId),
		})
	end
	local lockRemaining = 0
	local lockCooldown = 0
	local plotIndex = BaseService.plotIndexOf(player.UserId)
	local lockService = servicesRef.LockService
	if plotIndex ~= nil and type(lockService) == "table" then
		if type(lockService.remaining) == "function" then
			lockRemaining = lockService.remaining(plotIndex)
		end
		if type(lockService.cooldownLeft) == "function" then
			lockCooldown = lockService.cooldownLeft(player)
		end
	end
	local payload: { [string]: any } = {
		candy = data.Dulces,
		vault = data.VaultCandy,
		vaultStored = data.VaultCandy,
		perSec = perSec,
		candyPerSec = perSec,
		carrying = carrying,
		rookie = Records.isRookie(data),
		rookieLeft = Records.rookieLeft(data),
		rookieShieldRemaining = Records.rookieLeft(data),
		owned = owned,
		pedestalCount = data.PedestalsOwned,
		pedestalCap = Economy.MaxPedestals,
		vaultTier = data.VaultCapTier,
		bastones = data.Bastones,
		reFiestas = data.ReFiestas,
		multiplier = Economy.totalMultiplier(data.ReFiestas, false, false, 0),
		ftueCompleted = data.FtueCompleted == true,
		myLockRemaining = lockRemaining,
		myLockCooldown = lockCooldown,
	}
	local ui = servicesRef.UiIntentService
	if type(ui) == "table" and type(ui.settingsOf) == "function" then
		local settings = ui.settingsOf(player)
		if type(settings) == "table" then
			payload.settings = settings
		end
	end
	Remotes.get("StateChanged"):FireClient(player, payload)
end

local function paintPads(plot: Plot, count: number)
	for _, pedestal in plot.pedestals do
		local open = pedestal.index <= count
		pedestal.pad.Color = if open then OPEN else CLOSED
		pedestal.pad.Transparency = if open then 0 else 0.35
	end
end

function BaseService.syncPads(userId: number)
	local data = Records.byUserId(userId)
	local plot = BaseService.plotOf(userId)
	if data == nil or plot == nil then
		return
	end
	paintPads(plot, data.PedestalsOwned)
end

local function walk(model: Model, feet: Vector3, speed: number)
	local primary = model.PrimaryPart
	if primary == nil then
		return
	end
	local lift = math.max(primary.Size.Y * 0.5, 1.4)
	local goal = feet + Vector3.new(0, lift, 0)
	local startPos = model:GetPivot().Position
	local dist = (goal - startPos).Magnitude
	local dur = math.clamp(dist / math.max(speed, 1), 0.6, 8)
	local t0 = os.clock()
	while model.Parent ~= nil do
		local alpha = math.clamp((os.clock() - t0) / dur, 0, 1)
		local pos = startPos:Lerp(goal, alpha)
		local bob = math.sin(alpha * math.pi * 6) * 0.3
		model:PivotTo(CFrame.new(pos + Vector3.new(0, bob, 0)))
		if alpha >= 1 then
			break
		end
		task.wait(0.05)
	end
end

local function finishSeat(plot: Plot, pedestal: Pedestal, userId: number, owned: OwnedPinata, model: Model)
	if plot.ownerUserId ~= userId or pedestal.uid ~= owned.InstanceId or model.Parent == nil then
		if model.Parent ~= nil then
			model:Destroy()
		end
		return
	end
	PinataVisual.place(model, pedestal.anchor.Position)
	model.Parent = plot.model
	local hook = seatFn
	if hook ~= nil then
		hook(userId, pedestal.index, model)
	end
	if locked(plot) then
		local prompt = model:FindFirstChild("StealPrompt", true)
		if prompt ~= nil and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = false
		end
	end
end

function BaseService.receive(userId: number, owned: OwnedPinata, model: Model, animated: boolean, preferred: number?)
	local data = Records.byUserId(userId)
	local plot = BaseService.plotOf(userId)
	if data == nil or plot == nil then
		if model.Parent ~= nil then
			model:Destroy()
		end
		return
	end
	Transit.set(owned.InstanceId, false)
	local pedestal: Pedestal? = nil
	local wantedIndex = preferred or Records.slotOf(data, owned.InstanceId)
	if wantedIndex ~= nil then
		local wanted = pedestalByIndex(plot, wantedIndex)
		if wanted ~= nil and wanted.uid == nil and wanted.index <= data.PedestalsOwned then
			pedestal = wanted
		end
	end
	if pedestal == nil then
		pedestal = firstFree(plot, data.PedestalsOwned)
	end
	if pedestal == nil then
		Records.unplace(data, owned.InstanceId)
		if model.Parent ~= nil then
			model:Destroy()
		end
		return
	end
	local slot = pedestal
	Records.place(data, owned.InstanceId, slot.index)
	slot.uid = owned.InstanceId
	slot.model = model
	model:SetAttribute("Uid", owned.InstanceId)
	model:SetAttribute("OwnerUserId", userId)
	model.Parent = plot.model
	if animated then
		task.spawn(function()
			walk(model, slot.anchor.Position, Economy.Return.WalkSpeed)
			finishSeat(plot, slot, userId, owned, model)
		end)
	else
		finishSeat(plot, slot, userId, owned, model)
	end
end

function BaseService.acceptPurchase(
	player: Player,
	pinataId: string,
	mutation: string?,
	model: Model,
	price: number?
): (boolean, string)
	local data = Records.get(player)
	local plot = BaseService.plotOf(player.UserId)
	local def = Pinatas[pinataId]
	if data == nil or plot == nil or def == nil then
		return false, "missing"
	end
	if not Records.hasRoom(data) then
		return false, "no_room"
	end
	local slot = firstFree(plot, data.PedestalsOwned)
	if slot == nil then
		return false, "no_room"
	end
	-- nil o <= 0 es gratis (Secretas, y el Michi dorado de la intro). El llamador pasa el precio del slot.
	local charge = if price ~= nil and price > 0 then price else nil
	if charge ~= nil and not Records.trySpendDulces(player, charge) then
		return false, "funds"
	end
	local granted, instanceId = Records.grantPinata(player, pinataId, mutation)
	if not granted or instanceId == nil then
		if charge ~= nil then
			Records.grantDulces(player, charge)
		end
		return false, "funds"
	end
	local owned = Records.find(data, instanceId)
	if owned == nil then
		return false, "missing"
	end
	local buyPrompt = model:FindFirstChild("BuyPrompt", true)
	if buyPrompt ~= nil then
		buyPrompt:Destroy()
	end
	Records.place(data, instanceId, slot.index)
	slot.uid = instanceId
	slot.model = model
	model:SetAttribute("Uid", instanceId)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = plot.model
	Juice.confetti(model:GetPivot().Position, Tuning.Sfx.Buy)
	BaseService.pushState(player)
	task.spawn(function()
		walk(model, slot.anchor.Position, Tuning.WalkSpeed)
		finishSeat(plot, slot, player.UserId, owned, model)
		Juice.confetti(slot.anchor.Position, Tuning.Sfx.Deliver)
		Juice.feedback("DELIVER", slot.anchor.Position)
	end)
	print(string.format("[Piñata] %s compró %s", player.Name, pinataId))
	return true, "ok"
end

function BaseService.detach(ownerUserId: number, pedestalIndex: number): (Model?, OwnedPinata?)
	local data = Records.byUserId(ownerUserId)
	local plot = BaseService.plotOf(ownerUserId)
	if data == nil or plot == nil then
		return nil, nil
	end
	local pedestal = pedestalByIndex(plot, pedestalIndex)
	if pedestal == nil or pedestal.model == nil or pedestal.uid == nil then
		return nil, nil
	end
	local owned = Records.find(data, pedestal.uid)
	if owned == nil then
		return nil, nil
	end
	Records.unplace(data, owned.InstanceId)
	Transit.set(owned.InstanceId, true)
	local model = pedestal.model
	pedestal.model = nil
	pedestal.uid = nil
	return model, owned
end

local function restore(player: Player, plot: Plot)
	local data = Records.get(player)
	if data == nil then
		return
	end
	paintPads(plot, data.PedestalsOwned)
	for _, owned in data.Inventory do
		if not Transit.has(owned.InstanceId) then
			local model = PinataVisual.create(owned.PinataId, Records.mutationOf(owned))
			BaseService.receive(player.UserId, owned, model, false, Records.slotOf(data, owned.InstanceId))
		end
	end
end

local function moveCharacter(player: Player, plot: Plot, character: Model)
	local lifted = plot.spawn.CFrame + Vector3.new(0, 3, 0)
	character:PivotTo(lifted)
	Movement.watch(player, character)
end

local playtestGranted: { [number]: boolean } = {}

local function assign(player: Player)
	local data = Records.wait(player)
	if data == nil then
		warn("[Piñata] el perfil no cargó para", player.Name)
		return
	end
	Records.applyOffline(data)
	if game:GetService("RunService"):IsStudio() and not playtestGranted[player.UserId] then
		playtestGranted[player.UserId] = true
		if data.Dulces == 0 and #data.Inventory == 0 then
			Records.grantDulces(player, Tuning.PlaytestCandy)
		end
	end
	local index = AssignPlots.claim(assignments, Layout.PlotCount, player.UserId)
	if index == nil then
		warn("[Piñata] no quedan bases para", player.Name)
		return
	end
	local plot = plotByIndex(index)
	if plot == nil then
		return
	end
	plot.ownerUserId = player.UserId
	plot.model:SetAttribute("OwnerUserId", player.UserId)
	plot.sign.Text = player.DisplayName
	player.RespawnLocation = plot.spawn
	restore(player, plot)
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if player.Parent ~= nil then
				moveCharacter(player, plot, character)
			end
		end)
	end)
	if player.Character ~= nil then
		local character = player.Character
		task.defer(function()
			if character.Parent ~= nil then
				moveCharacter(player, plot, character)
			end
		end)
	end
	BaseService.pushState(player)
	print(
		string.format(
			"[Piñata] %s → base %d (%d dulces de práctica si el perfil estaba vacío)",
			player.Name,
			index,
			data.Dulces
		)
	)
end

local function release(player: Player)
	lastCollect[player] = nil
	local index = AssignPlots.release(assignments, player.UserId)
	if index == nil then
		return
	end
	local plot = plotByIndex(index)
	if plot == nil then
		return
	end
	for _, pedestal in plot.pedestals do
		if pedestal.model ~= nil then
			pedestal.model:Destroy()
		end
		pedestal.model = nil
		pedestal.uid = nil
	end
	plot.ownerUserId = nil
	plot.model:SetAttribute("OwnerUserId", 0)
	plot.sign.Text = "LIBRE"
	plot.generatorLabel.Text = "DULCERÍA"
	player.RespawnLocation = nil
	local lockService = servicesRef.LockService
	if type(lockService) == "table" and type(lockService.clear) == "function" then
		lockService.clear(index)
	end
end

local function bindCollect(plot: Plot)
	plot.collect.Touched:Connect(function(hit)
		if not hit:IsA("BasePart") then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		if character == nil then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player == nil or plot.ownerUserId ~= player.UserId then
			return
		end
		local now = os.clock()
		if now - (lastCollect[player] or 0) < 0.45 then
			return
		end
		if not BaseService.inOwnZone(player) then
			return
		end
		local data = Records.get(player)
		if data == nil or data.VaultCandy <= 0 then
			return
		end
		lastCollect[player] = now
		local gain = math.floor(data.VaultCandy)
		data.VaultCandy = 0
		if gain > 0 and not Records.grantDulces(player, gain) then
			data.VaultCandy = gain
		end
		Juice.confetti(plot.collect.Position, Tuning.Sfx.Collect)
		Remotes.get("Feedback"):FireClient(player, "COLLECT", {
			amount = gain,
			position = plot.collect.Position,
		})
		BaseService.pushState(player)
	end)
end

function BaseService.init(services: { [string]: any })
	servicesRef = services
	Movement.applyWorld()
	world = PlaceBuilder.build()
	for _, plot in world.plots do
		bindCollect(plot)
	end
	Lifecycle.install()
	Lifecycle.onLeave(40, release)
	Players.PlayerAdded:Connect(assign)
	for _, player in Players:GetPlayers() do
		task.spawn(assign, player)
	end
end

function BaseService.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = Records.get(player)
				if data ~= nil and BaseService.plotOf(player.UserId) ~= nil then
					Records.tickSecond(data)
					BaseService.pushState(player)
				end
			end
		end
	end)
	local SelfCheck = require(script.Parent.Parent:WaitForChild("Tests"):WaitForChild("SelfCheck"))
	SelfCheck.run()
end

return BaseService
