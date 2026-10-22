--!strict
-- Capa anti-cheat (WP-10a + WP-10b). Cada remote de cliente pasa por acá antes de tocar el juego.
-- Moneda e inventario no se leen del payload: DataService es el único que los cambia.
-- WP-10b: movimiento, carga y puntaje. El puntaje no se manda al cliente ni se guarda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local FairPlay = require(Shared:WaitForChild("Config"):WaitForChild("FairPlay"))
local Security = require(Shared:WaitForChild("Config"):WaitForChild("Security"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local Layout = require(Shared:WaitForChild("Config"):WaitForChild("WorldLayout"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local DebugReport = require(Shared:WaitForChild("Gameplay"):WaitForChild("DebugReport"))
local MovementSanity = require(Shared:WaitForChild("Gameplay"):WaitForChild("MovementSanity"))
local PlotSolids = require(Shared:WaitForChild("Gameplay"):WaitForChild("PlotSolids"))
local Suspicion = require(Shared:WaitForChild("Gameplay"):WaitForChild("Suspicion"))
local Payload = require(Shared:WaitForChild("Net"):WaitForChild("Payload"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local Server = script.Parent.Parent
local Logger = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Logger"))
local RateLimiter = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("RateLimiter"))
local Validators = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Validators"))
local DebugView = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("DebugView"))
local Movement = require(Server:WaitForChild("World"):WaitForChild("Movement"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))

local AntiCheatService = {}

local limiters: { [string]: any } = {}
local handlers: { [string]: (Player, { any }) -> () } = {}
local speedState: { [Player]: { x: number, y: number, z: number, t: number } } = {}
local lastGood: { [Player]: { x: number, y: number, z: number } } = {}
local memories: { [Player]: Suspicion.Memory } = {}
local carryLockUntil: { [Player]: number } = {}
local lastStrikeAt: { [Player]: { [string]: number } } = {}
local kicked: { [Player]: boolean } = {}

local moveCfg = MovementSanity.fromTuning(Tuning, Security, FairPlay)

local function thresholds(): Suspicion.Thresholds
	return {
		RubberBandAt = FairPlay.RubberBandAt,
		CarryLockAt = FairPlay.CarryLockAt,
		KickAt = FairPlay.KickAt,
		DecayPerSec = FairPlay.DecayPerSec,
	}
end

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

local function plotNoclip(x1: number, y1: number, z1: number, x2: number, y2: number, z2: number): boolean
	local world = BaseService.getWorld()
	if world == nil then
		return false
	end
	for _, plot in world.plots do
		local origin = plot.cframe.Position
		local faceX = if plot.cframe.LookVector.X >= 0 then 1 else -1
		if
			PlotSolids.noclip(Layout, origin.X, origin.Y, origin.Z, faceX, x1, y1, z1, x2, y2, z2, FairPlay.NoclipSkin)
		then
			return true
		end
	end
	return false
end

local function rubberband(player: Player): boolean
	local good = lastGood[player]
	local root = Validators.rootOf(player)
	if good == nil or root == nil then
		return false
	end
	root.CFrame = CFrame.new(good.x, good.y, good.z)
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
	return true
end

local function publishReport()
	DebugView.write(AntiCheatService.report())
end

function AntiCheatService.carryLockLeft(player: Player): number
	local untilAt = carryLockUntil[player]
	if untilAt == nil then
		return 0
	end
	return math.max(0, untilAt - os.clock())
end

function AntiCheatService.carryLocked(player: Player): boolean
	return AntiCheatService.carryLockLeft(player) > 0
end

function AntiCheatService.rows(): { DebugReport.Row }
	local list: { DebugReport.Row } = {}
	for _, player in Players:GetPlayers() do
		local memory = memories[player] or Suspicion.blank()
		local leagueAttr = player:GetAttribute("League")
		local powerAttr = player:GetAttribute("LeaguePower")
		table.insert(list, {
			userId = player.UserId,
			name = player.Name,
			score = memory.value,
			response = memory.response,
			league = if type(leagueAttr) == "string" then leagueAttr else "?",
			power = if type(powerAttr) == "number" then powerAttr else 0,
			carryLocked = AntiCheatService.carryLocked(player),
			lastReason = memory.lastReason,
		})
	end
	return list
end

function AntiCheatService.report(): string
	local recent: { DebugReport.Recent } = {}
	for _, flag in Logger.recent() do
		table.insert(recent, {
			userId = flag.userId,
			playerName = flag.playerName,
			reason = flag.reason,
			count = flag.count,
		})
	end
	return DebugReport.format(AntiCheatService.rows(), recent)
end

function AntiCheatService.segmentBlocked(fromPos: Vector3, toPos: Vector3): boolean
	return plotNoclip(fromPos.X, fromPos.Y, fromPos.Z, toPos.X, toPos.Y, toPos.Z)
end

function AntiCheatService.lastGoodVector(player: Player): Vector3?
	local good = lastGood[player]
	if good == nil then
		return nil
	end
	return Vector3.new(good.x, good.y, good.z)
end

function AntiCheatService.decorate(player: Player, payload: { [string]: any })
	payload.carryLocked = AntiCheatService.carryLocked(player)
	payload.carryLockLeft = AntiCheatService.carryLockLeft(player)
end

-- Devuelve true si corrigió la posición. El sample siguiente tiene que arrancar de lastGood.
function AntiCheatService.reportStrike(player: Player, kind: string): boolean
	if player.Parent == nil then
		return false
	end
	local now = os.clock()
	local repeatWindow = if kind == "bat_spam" then FairPlay.Bat.FlagCooldownSec else FairPlay.RepeatStrikeSec
	local cooledKind = kind == "bat_spam" or kind == "carry_far" or kind == "carry_wall" or kind == "carry_dupe"
	if cooledKind then
		local byKind = lastStrikeAt[player]
		if byKind == nil then
			byKind = {}
			lastStrikeAt[player] = byKind
		end
		local previous = byKind[kind]
		if previous ~= nil and now - previous < repeatWindow then
			return false
		end
		byKind[kind] = now
	end
	local raw = (FairPlay.Weights :: any)[kind]
	local weight = 1
	if type(raw) == "number" then
		weight = raw
	end
	local memory = Suspicion.strike(memories[player] or Suspicion.blank(), now, kind, weight, thresholds())
	memories[player] = memory
	Logger.flag(player, kind, { score = memory.value, response = memory.response })
	local response = memory.response
	if response == "kick" and not DebugView.kickEnabled() then
		response = "carry_lock"
	end
	local corrected = false
	if Suspicion.shouldCorrect(kind, response) then
		corrected = rubberband(player)
	end
	if (response == "carry_lock" or response == "kick") and not AntiCheatService.carryLocked(player) then
		carryLockUntil[player] = now + FairPlay.CarryLockSec
	end
	if memory.response == "kick" and DebugView.kickEnabled() and kicked[player] ~= true then
		kicked[player] = true
		pcall(function()
			player:Kick("Cerramos esta sesión por actividad imposible. Podés volver a entrar.")
		end)
	end
	publishReport()
	return corrected
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

local function pingOf(player: Player): number
	local ok, value = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and type(value) == "number" then
		return value
	end
	return 0
end

local function samplePlayer(player: Player, now: number)
	local root = Validators.rootOf(player)
	if root == nil then
		speedState[player] = nil
		return
	end
	local position = root.Position
	local previous = speedState[player]
	if previous == nil then
		speedState[player] = { x = position.X, y = position.Y, z = position.Z, t = now }
		lastGood[player] = { x = position.X, y = position.Y, z = position.Z }
		return
	end
	local dt = now - previous.t
	if dt < Security.SpeedSampleSec then
		return
	end
	if not Validators.positionSane(position.X, position.Y, position.Z, Security.MapHalfExtent) then
		AntiCheatService.reportStrike(player, "teleport")
		local good = lastGood[player]
		if good ~= nil then
			speedState[player] = { x = good.x, y = good.y, z = good.z, t = now }
		end
		return
	end
	local distance = Validators.distanceBetween(previous.x, previous.y, previous.z, position.X, position.Y, position.Z)
	local mode = Movement.mode(player)
	local knockAge = Movement.impulseAge(player, now)
	local blocked = plotNoclip(previous.x, previous.y, previous.z, position.X, position.Y, position.Z)
	local verdict = MovementSanity.classify(moveCfg, distance, dt, mode, pingOf(player), knockAge, position.Y)
	local kind: string? = nil
	if blocked then
		kind = "noclip"
	elseif verdict ~= "ok" then
		kind = verdict
	end
	local corrected = false
	if kind ~= nil then
		corrected = AntiCheatService.reportStrike(player, kind)
	else
		lastGood[player] = { x = position.X, y = position.Y, z = position.Z }
	end
	if corrected then
		local good = lastGood[player]
		if good ~= nil then
			speedState[player] = { x = good.x, y = good.y, z = good.z, t = now }
			return
		end
	end
	speedState[player] = { x = position.X, y = position.Y, z = position.Z, t = now }
end

function AntiCheatService.start()
	DebugView.install()
	publishReport()
	print("[WP-10b] movimiento, carga y puntaje. Vista: ServerStorage.FairPlayDebug")
	Players.PlayerRemoving:Connect(function(player)
		speedState[player] = nil
		lastGood[player] = nil
		memories[player] = nil
		carryLockUntil[player] = nil
		lastStrikeAt[player] = nil
		kicked[player] = nil
		Logger.clear(player.UserId)
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			samplePlayer(player, now)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			publishReport()
		end
	end)
end

return AntiCheatService
