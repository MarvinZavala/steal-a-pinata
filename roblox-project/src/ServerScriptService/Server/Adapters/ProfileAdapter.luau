--!strict
-- Adaptador de datos en memoria. El gameplay SOLO habla con este módulo.
-- Si DataService (WP-02) expone loadProfile / commit / releaseProfile, se usan.
-- Si no, la sesión vive en RAM y sobrevive a salir y volver en el MISMO server.
-- Reemplazable: ver INTEGRATION.md. No editar DataService desde aquí.

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local Profile = require(Shared:WaitForChild("Types"):WaitForChild("Profile"))
local CandyMath = require(Shared:WaitForChild("Gameplay"):WaitForChild("CandyMath"))
local OfflineEarnings = require(Shared:WaitForChild("Gameplay"):WaitForChild("OfflineEarnings"))

type OwnedPinata = Profile.OwnedPinata
type ProfileData = Profile.ProfileData

type Session = {
	player: Player,
	data: ProfileData,
	sessionStart: number,
}

type DataPort = {
	loadProfile: ((Player) -> any)?,
	commit: ((Player, ProfileData) -> ())?,
	releaseProfile: ((Player) -> ())?,
}

local ProfileAdapter = {}

local port: DataPort? = nil
local byPlayer: { [Player]: Session } = {}
local byUserId: { [number]: ProfileData } = {}
local playtestGranted: { [number]: boolean } = {}
local uidSeq = 0

local function mutationTable(): { [string]: number }
	return {
		Golden = Economy.Mutations.Golden.Multiplier,
		Rainbow = Economy.Mutations.Rainbow.Multiplier,
		Christmas = Economy.Mutations.Christmas.Multiplier,
	}
end

local function capSeconds(data: ProfileData): number
	local tiers = Economy.VaultCapSeconds
	return tiers[data.vaultTier] or tiers[1]
end

function ProfileAdapter.production(data: ProfileData): number
	local entries: { CandyMath.Entry } = {}
	for _, owned in data.pinatas do
		if owned.inTransit ~= true then
			local def = Pinatas[owned.pinataId]
			if def then
				table.insert(entries, { candyPerSec = def.CandyPerSec, mutation = owned.mutation })
			end
		end
	end
	local mult = Economy.totalMultiplier(data.reFiestas, data.has2x, data.hasVip, data.setsDone)
	return CandyMath.perSecond(entries, mult, mutationTable())
end

local function applyOffline(data: ProfileData)
	local leftAt = data.lastLogoutUnix
	if leftAt == nil then
		return
	end
	local elapsed = os.time() - leftAt
	local perSec = ProfileAdapter.production(data)
	local gain = OfflineEarnings.earned(perSec, elapsed, Economy.OfflineRate, Economy.OfflineCapHours)
	local cap = CandyMath.cap(perSec, capSeconds(data))
	data.vaultCandy = CandyMath.deposit(data.vaultCandy, gain, cap)
	data.lastLogoutUnix = nil
end

local function commit(player: Player, data: ProfileData)
	local current = port
	if current == nil or current.commit == nil then
		return
	end
	local fn = current.commit
	local ok, err = pcall(fn, player, data)
	if not ok then
		warn("[ProfileAdapter] commit falló:", err)
	end
end

function ProfileAdapter.bind(dataService: any)
	if type(dataService) ~= "table" then
		return
	end
	if type(dataService.loadProfile) ~= "function" then
		return
	end
	port = dataService :: DataPort
	print("[ProfileAdapter] DataService.loadProfile detectado: el puerto WP-02 queda conectado")
end

function ProfileAdapter.newUid(userId: number): string
	uidSeq += 1
	return string.format("%d_%d_%d", userId, os.time(), uidSeq)
end

function ProfileAdapter.load(player: Player): ProfileData
	local existing = byPlayer[player]
	if existing then
		return existing.data
	end
	local userId = player.UserId
	local data = byUserId[userId]
	local cold = data == nil
	if data == nil then
		local raw = nil
		local current = port
		if current ~= nil and current.loadProfile ~= nil then
			local fn = current.loadProfile
			local ok, result = pcall(fn, player)
			if ok then
				raw = result
			else
				warn("[ProfileAdapter] loadProfile falló, sigo en memoria:", result)
			end
		end
		data = Profile.hydrate(raw, Economy.StartPedestals)
		-- Un server nuevo no tiene al ladrón en memoria: la piñata vuelve a su dueño.
		for _, owned in data.pinatas do
			owned.inTransit = nil
		end
		byUserId[userId] = data
	end
	applyOffline(data)
	if cold and RunService:IsStudio() and not playtestGranted[userId] then
		playtestGranted[userId] = true
		if data.candy == 0 and #data.pinatas == 0 then
			data.candy += Tuning.PlaytestCandy
		end
	end
	byPlayer[player] = { player = player, data = data, sessionStart = os.clock() }
	ProfileAdapter.refreshLeaderstats(player)
	return data
end

function ProfileAdapter.get(player: Player): ProfileData?
	local session = byPlayer[player]
	if session == nil then
		return nil
	end
	return session.data
end

function ProfileAdapter.getByUserId(userId: number): ProfileData?
	return byUserId[userId]
end

function ProfileAdapter.playedSeconds(player: Player): number
	local session = byPlayer[player]
	if session == nil then
		return 0
	end
	return session.data.totalPlaySeconds + (os.clock() - session.sessionStart)
end

function ProfileAdapter.isRookie(player: Player): boolean
	return ProfileAdapter.playedSeconds(player) < Economy.RookieShieldSec
end

function ProfileAdapter.isRookieUser(userId: number, onlinePlayer: Player?): boolean
	if onlinePlayer ~= nil and onlinePlayer.UserId == userId then
		return ProfileAdapter.isRookie(onlinePlayer)
	end
	local data = byUserId[userId]
	if data == nil then
		return false
	end
	return data.totalPlaySeconds < Economy.RookieShieldSec
end

function ProfileAdapter.trySpend(player: Player, price: number): boolean
	local data = ProfileAdapter.get(player)
	if data == nil then
		return false
	end
	local ok, left = CandyMath.trySpend(data.candy, price)
	if not ok then
		return false
	end
	data.candy = left
	ProfileAdapter.refreshLeaderstats(player)
	return true
end

function ProfileAdapter.addCandy(player: Player, amount: number)
	local data = ProfileAdapter.get(player)
	if data == nil or amount <= 0 then
		return
	end
	data.candy += amount
	ProfileAdapter.refreshLeaderstats(player)
end

function ProfileAdapter.noteRobbed(userId: number)
	local data = byUserId[userId]
	if data == nil then
		return
	end
	table.insert(data.robbedAt, os.time())
end

function ProfileAdapter.refreshLeaderstats(player: Player)
	local data = ProfileAdapter.get(player)
	if data == nil then
		return
	end
	local folder = player:FindFirstChild("leaderstats")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
	end
	local function stat(name: string, value: number)
		local valueObject = folder:FindFirstChild(name)
		if valueObject == nil then
			local created = Instance.new("IntValue")
			created.Name = name
			created.Parent = folder
			valueObject = created
		end
		if valueObject ~= nil and valueObject:IsA("IntValue") then
			valueObject.Value = math.floor(value + 0.5)
		end
	end
	stat("Dulces", data.candy)
	stat("Dulcera", data.vaultCandy)
end

function ProfileAdapter.commitPlayer(player: Player)
	local data = ProfileAdapter.get(player)
	if data ~= nil then
		commit(player, data)
	end
end

function ProfileAdapter.release(player: Player)
	local session = byPlayer[player]
	if session == nil then
		return
	end
	session.data.totalPlaySeconds += os.clock() - session.sessionStart
	session.data.lastLogoutUnix = os.time()
	commit(player, session.data)
	local current = port
	if current ~= nil and current.releaseProfile ~= nil then
		local fn = current.releaseProfile
		local ok, err = pcall(fn, player)
		if not ok then
			warn("[ProfileAdapter] releaseProfile falló:", err)
		end
	end
	byPlayer[player] = nil
end

function ProfileAdapter.startAutosave()
	task.spawn(function()
		while true do
			task.wait(30)
			for player in byPlayer do
				ProfileAdapter.commitPlayer(player)
			end
		end
	end)
end

return ProfileAdapter
