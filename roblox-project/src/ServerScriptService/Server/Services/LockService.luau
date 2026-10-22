--!strict
-- WP-08. Candado láser: duración, cooldown, colisión (el dueño sí puede salir)
-- y el anillo que ven los vecinos.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local LockRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("LockRules"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local Juice = require(Server:WaitForChild("World"):WaitForChild("Juice"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

local LockService = {}

local TURQ = Color3.fromHex("#16D3E8")
local DIM = Color3.fromHex("#3A2A55")
local NEON = Color3.fromHex("#FF4FD8")
local GOLD = Color3.fromHex("#FFC22E")

type Row = { endsAt: number, ownerUserId: number }

local active: { [number]: Row } = {}
local passUntil: { [Player]: number } = {}

local function registerGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("LockLaser")
		PhysicsService:RegisterCollisionGroup("LockOwner")
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("LockLaser", "LockOwner", false)
		PhysicsService:CollisionGroupSetCollidable("LockLaser", "Default", true)
	end)
end

function LockService.isLocked(plotIndex: number): boolean
	local row = active[plotIndex]
	return row ~= nil and os.clock() < row.endsAt
end

local function applyGroups(player: Player)
	local plotIndex = BaseService.plotIndexOf(player.UserId)
	local ownerInside = plotIndex ~= nil and LockService.isLocked(plotIndex)
	local passing = os.clock() < (passUntil[player] or 0)
	local group = if ownerInside or passing then "LockOwner" else "Default"
	local character = player.Character
	if character == nil then
		return
	end
	for _, desc in character:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CollisionGroup = group
		end
	end
end

local function paint(plotIndex: number)
	local world = BaseService.getWorld()
	if world == nil then
		return
	end
	local plot = world.plots[plotIndex]
	if plot == nil then
		return
	end
	local on = LockService.isLocked(plotIndex)
	local remain = 0
	local row = active[plotIndex]
	if on and row ~= nil then
		remain = math.max(0, math.ceil(row.endsAt - os.clock()))
	end
	plot.laser.Transparency = if on then 0.15 else 1
	plot.laserBlock.CanCollide = on
	plot.laserBlock.CollisionGroup = "LockLaser"
	plot.padlock.Material = if on then Enum.Material.Neon else Enum.Material.Metal
	plot.padlock.Color = if on then NEON else GOLD
	plot.ringLabel.Text = if on then tostring(remain) .. "s" else "ABIERTA"
	plot.ringStroke.Transparency = if on then 0 else 0.5
	plot.ringStroke.Color = if on then TURQ else DIM
	plot.model:SetAttribute("LockEndsAt", if on then workspace:GetServerTimeNow() + remain else 0)
	BaseService.setPromptsEnabled(plotIndex, not on)
	if row ~= nil then
		local owner = Players:GetPlayerByUserId(row.ownerUserId)
		if owner ~= nil then
			applyGroups(owner)
		end
	end
end

function LockService.clear(plotIndex: number)
	local row = active[plotIndex]
	active[plotIndex] = nil
	paint(plotIndex)
	if row ~= nil then
		local owner = Players:GetPlayerByUserId(row.ownerUserId)
		if owner ~= nil then
			applyGroups(owner)
		end
	end
end

-- El ladrón que acaba de salir con la piñata puede cruzar el láser unos segundos.
-- Si no, el candado gratis de 20 s lo encierra en la base ajena.
function LockService.letLeave(player: Player, seconds: number)
	passUntil[player] = os.clock() + seconds
	applyGroups(player)
end

function LockService.grant(plotIndex: number, seconds: number, ownerUserId: number)
	local untilClock = os.clock() + seconds
	local row = active[plotIndex]
	if row == nil or row.endsAt < untilClock then
		active[plotIndex] = { endsAt = untilClock, ownerUserId = ownerUserId }
	end
	paint(plotIndex)
end

function LockService.tryActivate(player: Player): (boolean, string)
	local data = Records.get(player)
	local plotIndex = BaseService.plotIndexOf(player.UserId)
	if data == nil or plotIndex == nil then
		return false, "no_plot"
	end
	local world = BaseService.getWorld()
	local plot = if world ~= nil then world.plots[plotIndex] else nil
	if plot == nil then
		return false, "no_plot"
	end
	local allowed = AntiCheatService.authorize(player, "RequestLock", plot.padlock.Position)
	if not allowed then
		return false, "distance"
	end
	if not LockRules.canStart(os.time(), data.LockReadyUnix) then
		return false, "cooldown"
	end
	if LockService.isLocked(plotIndex) then
		return false, "active"
	end
	-- VIP llega con la monetización. El perfil de hoy no tiene ese flag.
	local duration = LockRules.duration(
		Economy.Lock.DurationSec,
		Economy.Lock.VipBonusSec,
		false,
		Economy.Lock.PerReFiestaSec,
		data.ReFiestas,
		Economy.Lock.MaxSec
	)
	data.LockReadyUnix = os.time() + Economy.Lock.CooldownSec
	active[plotIndex] = { endsAt = os.clock() + duration, ownerUserId = player.UserId }
	paint(plotIndex)
	local at = plot.laser.Position
	Juice.sound(at, Tuning.Sfx.Lock)
	Juice.feedback("LOCK", at)
	print(string.format("[Piñata] %s cerró el candado %ds", player.Name, duration))
	return true, "ok"
end

function LockService.init(_services: { [string]: any })
	AntiCheatService.register("RequestLock", function(player, _args)
		LockService.tryActivate(player)
	end)
	registerGroups()
	local world = BaseService.getWorld()
	if world == nil then
		return
	end
	for _, plot in world.plots do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LockPrompt"
		prompt.ActionText = "Candado"
		prompt.ObjectText = "Puerta"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = plot.padlock
		local plotIndex = plot.index
		prompt.Triggered:Connect(function(player)
			if BaseService.plotIndexOf(player.UserId) == plotIndex then
				LockService.tryActivate(player)
			end
		end)
	end
end

function LockService.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				applyGroups(player)
			end)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		passUntil[player] = nil
	end)
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			local expired: { number } = {}
			for index, row in active do
				if os.clock() >= row.endsAt then
					table.insert(expired, index)
				else
					paint(index)
				end
			end
			for _, index in expired do
				LockService.clear(index)
			end
			for _, player in Players:GetPlayers() do
				local untilPass = passUntil[player]
				if untilPass ~= nil and os.clock() >= untilPass then
					passUntil[player] = nil
					applyGroups(player)
				end
			end
		end
	end)
end

return LockService
