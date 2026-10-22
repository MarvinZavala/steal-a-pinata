--!strict
-- Capa anti-cheat (WP-10a). Cada remote de cliente pasa por acá antes de tocar el juego.
-- Moneda e inventario no se leen del payload: DataService es el único que los cambia.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Security = require(ReplicatedStorage.Shared.Config.Security)
local Pinatas = require(ReplicatedStorage.Shared.Config.Pinatas)
local Payload = require(ReplicatedStorage.Shared.Net.Payload)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Logger = require(script.Parent.AntiCheat.Logger)
local RateLimiter = require(script.Parent.AntiCheat.RateLimiter)
local Validators = require(script.Parent.AntiCheat.Validators)

local AntiCheatService = {}

local limiters: { [string]: any } = {}
local handlers: { [string]: (Player, { any }) -> () } = {}
local speedState: { [Player]: { x: number, y: number, z: number, t: number } } = {}

local function rateFor(name: string, honeypot: boolean): any
	if honeypot then
		return Security.Rates.Honeypot
	end
	local rate = (Security.Rates :: any)[name]
	if rate == nil then
		return Security.Rates.Default
	end
	return rate
end

function AntiCheatService.authorize(player: Player, action: string, target: Vector3?): (boolean, string?)
	local root = Validators.rootOf(player)
	if root == nil then
		return false, "no_root"
	end
	local position = root.Position
	if not Validators.positionSane(position.X, position.Y, position.Z, Security.MapHalfExtent) then
		return false, "position"
	end
	if target == nil then
		return true, nil
	end
	if not Validators.positionSane(target.X, target.Y, target.Z, Security.MapHalfExtent) then
		return false, "target"
	end

	local maxDist: number? = nil
	local maxAngle: number? = nil
	if action == "RequestBuy" or action == "RequestLock" or action == "RequestUpgrade" or action == "RequestFuse" then
		maxDist = Economy.Buy.MaxDistance
	elseif action == "RequestSteal" then
		maxDist = Economy.Steal.MaxDistance
	elseif action == "RequestSwing" then
		maxDist = Economy.Bat.MaxDistance
		maxAngle = Economy.Bat.MaxAngleDeg
	end

	local ping = 0
	local okPing, value = pcall(function()
		return player:GetNetworkPing()
	end)
	if okPing and type(value) == "number" then
		ping = value
	end
	local slack = Validators.pingSlack(ping, Economy.Walk.Normal)
	if
		maxDist ~= nil
		and not Validators.withinPoints(
			position.X,
			position.Y,
			position.Z,
			target.X,
			target.Y,
			target.Z,
			maxDist,
			slack
		)
	then
		return false, "distance"
	end
	if maxAngle ~= nil then
		local look = root.CFrame.LookVector
		if
			not Validators.inFrontPoints(
				look.X,
				look.Y,
				look.Z,
				position.X,
				position.Y,
				position.Z,
				target.X,
				target.Y,
				target.Z,
				maxAngle
			)
		then
			return false, "angle"
		end
	end
	return true, nil
end

function AntiCheatService.register(name: string, handler: (Player, { any }) -> ())
	local spec = Payload.spec(name)
	if spec == nil or spec.Direction ~= "C2S" or spec.Honeypot then
		error("[WP-10a] no se puede registrar " .. name, 2)
	end
	handlers[name] = handler
end

local function handle(player: Player, name: string, args: { any })
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local limiter = limiters[name]
	if limiter ~= nil and not limiter:allow(player, name) then
		Logger.flag(player, "rate:" .. name)
		return
	end
	local spec = Payload.spec(name)
	if spec ~= nil and spec.Honeypot then
		Logger.flag(player, "honeypot:" .. name)
		return
	end
	if Logger.levelFor(Logger.count(player.UserId), Security.FlagRestrictAt) == "restrict" then
		return
	end
	local ok, reason = Payload.validateSafe(name, args, Security, Pinatas)
	if not ok then
		Logger.flag(player, "payload:" .. name .. ":" .. tostring(reason))
		return
	end
	local allowed, why = AntiCheatService.authorize(player, name, nil)
	if not allowed then
		if why ~= "no_root" then
			Logger.flag(player, "position:" .. tostring(why))
		end
		return
	end
	local handler = handlers[name]
	if handler == nil then
		-- Semana 1: la intención es válida y no cambia moneda ni inventario.
		return
	end
	local ran, err = pcall(handler, player, args)
	if not ran then
		Logger.flag(player, "handler:" .. name)
		warn("[WP-10a] handler", name, err)
	end
end

function AntiCheatService.init(_services: { [string]: any })
	local connected = 0
	for _, name in Payload.names() do
		local spec = Payload.spec(name)
		if spec ~= nil and spec.Direction == "C2S" then
			local rate = rateFor(name, spec.Honeypot)
			limiters[name] = RateLimiter.new(rate.Capacity, rate.LeakPerSec)
			local remote = Remotes.get(name)
			remote.OnServerEvent:Connect(function(player: Player, ...)
				local args = { ... }
				local ok, err = pcall(handle, player, name, args)
				if not ok then
					warn("[WP-10a] guard", name, err)
				end
			end)
			connected += 1
		end
	end
	print(`[WP-10a] anti-cheat escuchando {connected} remotes`)
end

function AntiCheatService.start()
	Players.PlayerRemoving:Connect(function(player)
		speedState[player] = nil
		Logger.clear(player.UserId)
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local root = Validators.rootOf(player)
			if root == nil then
				speedState[player] = nil
			else
				local position = root.Position
				local previous = speedState[player]
				if previous == nil then
					speedState[player] = { x = position.X, y = position.Y, z = position.Z, t = now }
				else
					local dt = now - previous.t
					if dt >= Security.SpeedSampleSec then
						local distance = Validators.distanceBetween(
							previous.x,
							previous.y,
							previous.z,
							position.X,
							position.Y,
							position.Z
						)
						local maxSpeed = Economy.Walk.Normal * Security.SpeedMultiplier
						if not Validators.speedSane(distance, dt, maxSpeed, Security.TeleportSlackStuds) then
							Logger.flag(player, "speed", { distance = distance, dt = dt }, false)
						end
						if not Validators.positionSane(position.X, position.Y, position.Z, Security.MapHalfExtent) then
							Logger.flag(player, "position:bounds", nil, false)
						end
						speedState[player] = { x = position.X, y = position.Y, z = position.Z, t = now }
					end
				end
			end
		end
	end)
end

return AntiCheatService
