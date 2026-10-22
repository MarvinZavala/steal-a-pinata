--!strict
-- WP-16. Escudo (el reloj sigue en Records), ligas por Poder y servers.
-- TeleportService + MemoryStore. En Studio, o con SkipLeagueTeleport, no se teletransporta.
-- El server privado (dueño ≠ 0) no redirige. El robo entre ligas se frena igual.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local FairPlay = require(Shared:WaitForChild("Config"):WaitForChild("FairPlay"))
local Layout = require(Shared:WaitForChild("Config"):WaitForChild("WorldLayout"))
local LeagueRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("LeagueRules"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))

local LeagueService = {}

local currentLeague = "Mixto"
local lockedMixed = false
local publishedCode: string? = nil
local redirecting: { [Player]: boolean } = {}
local servicesRef: { [string]: any } = {}

local function push(player: Player)
	local base = servicesRef.BaseService
	if type(base) == "table" and type(base.pushState) == "function" then
		base.pushState(player)
	end
end

local function studioSkip(): boolean
	return RunService:IsStudio() or workspace:GetAttribute("SkipLeagueTeleport") == true
end

local function vipServer(): boolean
	return game.PrivateServerOwnerId ~= 0
end

function LeagueService.serverLeague(): string
	if vipServer() then
		return "Privado"
	end
	return currentLeague
end

local function readJoin(player: Player): (string?, string?)
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(join) ~= "table" then
		return nil, nil
	end
	local data = (join :: any).TeleportData
	if type(data) ~= "table" then
		return nil, nil
	end
	local league = if type(data.league) == "string" then data.league else nil
	local code = if type(data.accessCode) == "string" then data.accessCode else nil
	return league, code
end

local function noteJoin(player: Player)
	local league, code = readJoin(player)
	if league == nil then
		return
	end
	if league == "Mixto" then
		currentLeague = "Mixto"
		lockedMixed = true
		if code ~= nil and code ~= "" then
			publishedCode = code
		end
		return
	end
	if LeagueRules.isLeague(league) and currentLeague == "Mixto" and not lockedMixed then
		currentLeague = league
		if code ~= nil and code ~= "" then
			publishedCode = code
		end
	end
end

local function powerOf(player: Player): number
	local data = Records.get(player)
	if data == nil then
		return 0
	end
	return Records.production(data)
end

local function playerLeague(player: Player): string
	return LeagueRules.leagueOf(powerOf(player), FairPlay.Bands)
end

local function stamp(player: Player)
	local league = playerLeague(player)
	player:SetAttribute("League", league)
	player:SetAttribute("LeaguePower", powerOf(player))
	player:SetAttribute("ServerLeague", LeagueService.serverLeague())
	local data = Records.get(player)
	if data ~= nil then
		player:SetAttribute("RookieLeft", Records.rookieLeft(data))
	end
end

function LeagueService.outranks(thief: Player, victimUserId: number): boolean
	local victim = Players:GetPlayerByUserId(victimUserId)
	if victim == nil then
		return false
	end
	return not LeagueRules.canSteal(playerLeague(thief), playerLeague(victim))
end

function LeagueService.decorate(player: Player, payload: { [string]: any })
	stamp(player)
	local league = player:GetAttribute("League")
	local power = player:GetAttribute("LeaguePower")
	local serverLeague = player:GetAttribute("ServerLeague")
	payload.league = if type(league) == "string" then league else "Confeti"
	payload.leaguePower = if type(power) == "number" then power else 0
	payload.serverLeague = if type(serverLeague) == "string" then serverLeague else "Mixto"
	local data = Records.get(player)
	if data ~= nil then
		payload.rookieShieldRemaining = Records.rookieLeft(data)
		payload.rookieLeft = payload.rookieShieldRemaining
		payload.rookie = Records.isRookie(data)
	end
end

local function readDirectory(league: string): { LeagueRules.Listing }
	local list: { LeagueRules.Listing } = {}
	local ok, range = pcall(function()
		local map = MemoryStoreService:GetSortedMap(FairPlay.MemoryStoreName)
		return map:GetRangeAsync(Enum.SortDirection.Ascending, 30, league .. "/", league .. "0")
	end)
	if not ok or type(range) ~= "table" then
		return list
	end
	local rows = range :: { any }
	for _, item in rows do
		if type(item) == "table" and type(item.value) == "table" then
			local value = item.value
			if
				type(value.league) == "string"
				and type(value.jobId) == "string"
				and type(value.accessCode) == "string"
			then
				local players = if type(value.players) == "number" then value.players else 0
				local updated = if type(value.updatedAt) == "number" then value.updatedAt else 0
				table.insert(list, {
					league = value.league,
					jobId = value.jobId,
					players = players,
					accessCode = value.accessCode,
					updatedAt = updated,
				})
			end
		end
	end
	return list
end

local function publish()
	if studioSkip() or vipServer() then
		return
	end
	local kind = LeagueRules.serverKind(game.PrivateServerId, game.PrivateServerOwnerId)
	if not LeagueRules.shouldPublish(kind, publishedCode) then
		return
	end
	if game.JobId == "" then
		return
	end
	local code = publishedCode
	if code == nil then
		return
	end
	pcall(function()
		local map = MemoryStoreService:GetSortedMap(FairPlay.MemoryStoreName)
		map:SetAsync(currentLeague .. "/" .. game.JobId, {
			league = currentLeague,
			jobId = game.JobId,
			players = #Players:GetPlayers(),
			accessCode = code,
			updatedAt = os.time(),
		}, FairPlay.DirectoryTtlSec)
	end)
end

local function teleportTo(player: Player, league: string, accessCode: string)
	local options = Instance.new("TeleportOptions") :: TeleportOptions
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({
		league = league,
		accessCode = accessCode,
	})
	TeleportService:TeleportAsync(game.PlaceId, { player }, options)
end

local function redirect(player: Player, dest: string)
	local placement = LeagueRules.whereTo(
		dest,
		readDirectory(dest),
		readDirectory("Mixto"),
		os.time(),
		FairPlay.DirectoryStaleSec,
		Layout.PlotCount,
		game.JobId,
		FairPlay.PreferMixedWhenEmpty
	)
	local code = placement.accessCode
	if placement.kind == "reserve" or code == nil then
		local ok, reserved = pcall(function()
			return TeleportService:ReserveServer(game.PlaceId)
		end)
		if ok and type(reserved) == "string" and reserved ~= "" then
			code = reserved
		end
	end
	if code == nil then
		warn("[WP-16] sin server para", dest, "— se queda y el robo entre ligas sigue cerrado")
		redirecting[player] = nil
		return
	end
	local league = if placement.kind == "join" and placement.league ~= "" then placement.league else dest
	local ok, err = pcall(teleportTo, player, league, code)
	if not ok then
		warn("[WP-16] teleport", player.UserId, err)
		redirecting[player] = nil
	end
end

local function consider(player: Player)
	if player.Parent == nil or Records.get(player) == nil then
		return
	end
	noteJoin(player)
	stamp(player)
	local decision = LeagueRules.decide({
		studio = studioSkip(),
		vip = vipServer(),
		serverLeague = LeagueService.serverLeague(),
		playerLeague = playerLeague(player),
		openLeagues = FairPlay.OpenLeagues,
		lockedMixed = lockedMixed,
	})
	if decision.action == "claim" then
		currentLeague = decision.league
	end
	stamp(player)
	push(player)
	if decision.action == "redirect" and not redirecting[player] then
		redirecting[player] = true
		task.spawn(redirect, player, decision.league)
	end
end

function LeagueService.init(services: { [string]: any })
	servicesRef = services
	if vipServer() then
		currentLeague = "Privado"
	end
	for _, player in Players:GetPlayers() do
		noteJoin(player)
	end
end

function LeagueService.start()
	local open = table.concat(FairPlay.OpenLeagues, ", ")
	print(`[WP-16] ligas abiertas: {open}. Escudo {Economy.RookieShieldSec}s. Server {LeagueService.serverLeague()}`)
	local function hook(player: Player)
		task.spawn(function()
			local data = Records.wait(player)
			if data == nil or player.Parent == nil then
				return
			end
			consider(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player)
		redirecting[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
	task.spawn(function()
		while true do
			task.wait(FairPlay.DirectoryHeartbeatSec)
			publish()
			if not studioSkip() and not vipServer() then
				for _, player in Players:GetPlayers() do
					if Records.get(player) ~= nil then
						consider(player)
					end
				end
			else
				for _, player in Players:GetPlayers() do
					if Records.get(player) ~= nil then
						stamp(player)
					end
				end
			end
		end
	end)
end

return LeagueService
