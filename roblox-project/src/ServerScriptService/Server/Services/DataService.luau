--!strict
-- DataService (WP-02). ProfileStore con session lock, migraciones y mock en Studio.
-- El cliente no puede llamar esto: el ModuleScript no se replica. Toda moneda pasa por Wallet.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Security = require(ReplicatedStorage.Shared.Config.Security)
local Pinatas = require(ReplicatedStorage.Shared.Config.Pinatas)
local DataConfig = require(ReplicatedStorage.Shared.Config.Data)
local Migrations = require(ReplicatedStorage.Shared.Data.Migrations)
local Wallet = require(ReplicatedStorage.Shared.Data.Wallet)
local ProfileStore = require(script.Parent.Parent.Vendor.ProfileStore)

local KICK_LOAD = "No se pudieron cargar tus datos. Volvé a entrar."
local KICK_MIGRATION = "Tus datos no se pudieron migrar. Avisá al equipo y volvé a entrar."
local KICK_STOLEN = "Tu sesión se abrió en otro servidor. Volvé a entrar."

local DataService = {}

local store: any = nil
local useMock = false
local profiles: { [Player]: any } = {}
local ended: { [Player]: boolean } = {}
local loading: { [Player]: boolean } = {}
local pinataAllowed: { [string]: boolean } = {}
local mockBusy = false
local mockWaiters: { thread } = {}

local function makeDefaults(): any
	-- Misma forma que tests/defaults.luau. Los números salen de Economy y Security.
	return {
		pedestalsOwned = Economy.StartPedestals,
		vaultCapTier = 1,
		maxVaultTier = #Economy.VaultCapSeconds,
		maxPedestalSlots = Economy.MaxPedestalSlots,
		maxInventory = Security.MaxInventory,
		maxCurrency = Security.MaxCurrency,
		maxReFiestas = Security.MaxReFiestas,
	}
end

local function activeProfile(player: Player): any?
	local profile = profiles[player]
	if profile == nil or profile:IsActive() ~= true then
		return nil
	end
	return profile
end

local function endProfile(player: Player, profile: any, stampLeave: boolean)
	if ended[player] then
		return
	end
	ended[player] = true
	profiles[player] = nil
	pcall(function()
		if profile == nil or profile:IsActive() ~= true then
			return
		end
		if stampLeave and type(profile.Data) == "table" and type(profile.Data.Stats) == "table" then
			profile.Data.Stats.LastLeaveUnix = os.time()
		end
		profile:EndSession()
	end)
end

local function lockMock()
	if mockBusy then
		table.insert(mockWaiters, coroutine.running())
		coroutine.yield()
		return
	end
	mockBusy = true
end

local function unlockMock()
	local nextWaiter = table.remove(mockWaiters, 1)
	if nextWaiter ~= nil then
		task.spawn(nextWaiter)
	else
		mockBusy = false
	end
end

local function startMock(key: string): any
	lockMock()
	local ok, result = pcall(function()
		return store.Mock:StartSessionAsync(key)
	end)
	unlockMock()
	if not ok then
		error(result, 0)
	end
	return result
end

local function loadPlayer(player: Player)
	local key = tostring(player.UserId)
	local profile: any
	if useMock then
		profile = startMock(key)
	else
		local ok, result = pcall(function()
			return store:StartSessionAsync(key, {
				Cancel = function(): boolean
					return player.Parent ~= Players
				end,
			})
		end)
		if not ok then
			warn("[WP-02] StartSessionAsync falló", player.UserId, result)
			if player.Parent == Players then
				player:Kick(KICK_LOAD)
			end
			return
		end
		profile = result
	end

	if profile == nil then
		if player.Parent == Players then
			player:Kick(KICK_LOAD)
		end
		return
	end

	pcall(function()
		profile:AddUserId(player.UserId)
	end)

	profile.OnSessionEnd:Connect(function()
		local wasEnded = ended[player] == true
		profiles[player] = nil
		ended[player] = nil
		if not wasEnded and player.Parent == Players then
			player:Kick(KICK_STOLEN)
		end
	end)

	if player.Parent ~= Players then
		endProfile(player, profile, false)
		return
	end

	local migrated: any = nil
	local reason = "bad"
	local migrateOk, packed = pcall(function()
		local data, migrateReason = Migrations.migrate(profile.Data, makeDefaults())
		return { data = data, reason = migrateReason }
	end)
	if migrateOk and type(packed) == "table" then
		migrated = packed.data
		reason = packed.reason or "bad"
	else
		reason = "threw"
	end
	if migrated == nil then
		warn("[WP-02] migración rechazada", player.UserId, reason)
		endProfile(player, profile, false)
		if player.Parent == Players then
			player:Kick(KICK_MIGRATION)
		end
		return
	end

	profile.Data = migrated
	pcall(function()
		profile:Reconcile()
	end)

	local now = os.time()
	if type(profile.Data.Stats) == "table" then
		profile.Data.Stats.LastJoinUnix = now
		if profile.Data.Stats.FirstJoinUnix == 0 then
			profile.Data.Stats.FirstJoinUnix = now
		end
	end

	profile.OnAfterSave:Connect(function()
		if player.Parent == Players then
			player:SetAttribute("LastProfileSave", os.time())
		end
	end)

	if player.Parent ~= Players then
		endProfile(player, profile, true)
		return
	end

	profiles[player] = profile
	player:SetAttribute("DataReady", true)
end

local function onPlayer(player: Player)
	if loading[player] or profiles[player] ~= nil then
		return
	end
	loading[player] = true
	task.spawn(function()
		local ok, err = pcall(loadPlayer, player)
		loading[player] = nil
		if not ok then
			warn("[WP-02] error al cargar", player.UserId, err)
			if player.Parent == Players then
				player:Kick(KICK_LOAD)
			end
		end
	end)
end

function DataService.usingMock(): boolean
	return useMock
end

function DataService.isLoaded(player: Player): boolean
	return activeProfile(player) ~= nil
end

function DataService.getDulces(player: Player): number?
	local profile = activeProfile(player)
	if profile == nil then
		return nil
	end
	return profile.Data.Dulces
end

function DataService.getBastones(player: Player): number?
	local profile = activeProfile(player)
	if profile == nil then
		return nil
	end
	return profile.Data.Bastones
end

function DataService.inventoryCount(player: Player): number?
	local profile = activeProfile(player)
	if profile == nil or type(profile.Data.Inventory) ~= "table" then
		return nil
	end
	return #profile.Data.Inventory
end

function DataService.grant(player: Player, currency: string, amount: number): boolean
	if not RunService:IsServer() then
		return false
	end
	local profile = activeProfile(player)
	if profile == nil then
		return false
	end
	return Wallet.grant(profile.Data, currency, amount, Security.MaxCurrency)
end

function DataService.trySpend(player: Player, currency: string, amount: number): boolean
	if not RunService:IsServer() then
		return false
	end
	local profile = activeProfile(player)
	if profile == nil then
		return false
	end
	return Wallet.trySpend(profile.Data, currency, amount, Security.MaxCurrency)
end

function DataService.grantPinata(player: Player, pinataId: string, mutation: string?): (boolean, string?)
	if not RunService:IsServer() then
		return false, nil
	end
	local profile = activeProfile(player)
	if profile == nil or pinataAllowed[pinataId] ~= true then
		return false, nil
	end
	local instanceId = HttpService:GenerateGUID(false)
	local granted = Wallet.grantPinata(
		profile.Data,
		pinataId,
		mutation,
		instanceId,
		os.time(),
		Security.MaxInventory,
		pinataAllowed
	)
	if not granted then
		return false, nil
	end
	return true, instanceId
end

function DataService.profile(player: Player): any?
	local profile = activeProfile(player)
	if profile == nil then
		return nil
	end
	return profile.Data
end

function DataService.movePinata(fromPlayer: Player, toPlayer: Player, instanceId: string): boolean
	if not RunService:IsServer() then
		return false
	end
	local fromProfile = activeProfile(fromPlayer)
	local toProfile = activeProfile(toPlayer)
	if fromProfile == nil or toProfile == nil then
		return false
	end
	return Wallet.movePinata(fromProfile.Data, toProfile.Data, instanceId, Security.MaxInventory)
end

function DataService.markPurchase(player: Player, purchaseId: string): boolean
	if not RunService:IsServer() then
		return false
	end
	local profile = activeProfile(player)
	if profile == nil then
		return false
	end
	return Wallet.markPurchase(profile.Data, purchaseId)
end

function DataService.purchaseSaved(player: Player, purchaseId: string): boolean
	local profile = activeProfile(player)
	if profile == nil or type(purchaseId) ~= "string" then
		return false
	end
	local last = profile.LastSavedData
	if type(last) ~= "table" or type(last.ProcessedPurchases) ~= "table" then
		return false
	end
	return last.ProcessedPurchases[purchaseId] == true
end

-- Espera a que el PurchaseId quede en el snapshot guardado. Un autosave viejo no cuenta.
function DataService.persist(player: Player, purchaseId: string): boolean
	if not RunService:IsServer() then
		return false
	end
	local profile = activeProfile(player)
	if profile == nil then
		return false
	end
	if DataService.purchaseSaved(player, purchaseId) then
		return true
	end
	local saved = false
	local conn = profile.OnAfterSave:Connect(function(last: any)
		if
			type(last) == "table"
			and type(last.ProcessedPurchases) == "table"
			and last.ProcessedPurchases[purchaseId] == true
		then
			saved = true
		end
	end)
	pcall(function()
		profile:Save()
	end)
	local deadline = os.clock() + 12
	while not saved and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	conn:Disconnect()
	return saved or DataService.purchaseSaved(player, purchaseId)
end

function DataService.init(_services: { [string]: any })
	for id in Pinatas do
		pinataAllowed[id] = true
	end

	-- Período de autosave de ProfileStore (segundos). El primer guardado espera ~la mitad.
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", DataConfig.AutoSaveSec)

	local template = Migrations.blank(makeDefaults())
	store = ProfileStore.New(DataConfig.StoreName, template)
	useMock = RunService:IsStudio() and workspace:GetAttribute("UseLiveProfiles") ~= true
	if useMock then
		print(
			`[WP-02] ProfileStore.Mock (Studio). Autosave cada {DataConfig.AutoSaveSec}s. Para datos reales: attribute UseLiveProfiles=true en Workspace y API Services.`
		)
	else
		print(`[WP-02] ProfileStore live. Autosave cada {DataConfig.AutoSaveSec}s. EndSession al salir.`)
	end

	ProfileStore.OnError:Connect(function(message: string, storeName: string, profileKey: string)
		warn(`[WP-02] DataStore error ({storeName}/{profileKey}): {message}`)
	end)
	ProfileStore.OnCriticalToggle:Connect(function(isCritical: boolean)
		if isCritical then
			warn("[WP-02] ProfileStore en estado crítico")
		end
	end)
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		player:SetAttribute("DataReady", nil)
		if profile ~= nil then
			endProfile(player, profile, true)
		end
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			local profile = profiles[player]
			if profile ~= nil then
				endProfile(player, profile, true)
			end
		end
	end)
end

return DataService
