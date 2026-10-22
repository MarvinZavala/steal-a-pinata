--!strict
-- Puente con el servidor. Hasta el primer StateChanged la UI puede previsualizar
-- el FTUE en Studio; ese presenter se apaga en cuanto el servidor manda estado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Remotes"))
local Locale = require(script.Parent.Locale)
local SoundBus = require(script.Parent.SoundBus)
local UIKit = require(script.Parent.UIKit)
local UIState = require(script.Parent.UIState)

local authoritative = false
local income = true
local folder: Instance? = nil

local UIBridge = {}

local function remote(name: string): RemoteEvent?
	if not folder or not folder.Parent then
		folder = ReplicatedStorage:FindFirstChild("Remotes")
	end
	if not folder then
		return nil
	end
	local inst = folder:FindFirstChild(name)
	if inst and inst:IsA("RemoteEvent") then
		return inst
	end
	return nil
end

local function fire(name: string, ...: any)
	if remote(name) == nil then
		return
	end
	local ok, err = pcall(Remotes.fireServer, name, ...)
	if not ok then
		warn("[UI] " .. tostring(err))
	end
end

local function unit(value: any): number
	if typeof(value) ~= "number" then
		return 0.8
	end
	return math.clamp(value, 0, 1)
end

function UIBridge.isAuthoritative(): boolean
	return authoritative
end

function UIBridge.setOfflineIncome(on: boolean)
	income = on
end

function UIBridge.swing()
	fire("RequestSwing")
end

function UIBridge.lock()
	fire("RequestLock")
end

function UIBridge.collect()
	fire("RequestCollect")
end

function UIBridge.upgrade(id: string)
	fire("RequestUpgrade", id)
end

function UIBridge.fuse(pinataId: string)
	fire("RequestFuse", pinataId)
end

function UIBridge.buy(slotId: number)
	fire("RequestBuy", slotId)
end

function UIBridge.pushSettings()
	local settings = UIState.get().settings
	if typeof(settings) ~= "table" then
		return
	end
	local locale = if typeof(settings.locale) == "string" and settings.locale ~= "" then settings.locale else "auto"
	fire(
		"RequestSettings",
		locale,
		unit(settings.music),
		unit(settings.sfx),
		settings.reduceMotion == true,
		settings.cameraShake ~= false
	)
end

function UIBridge.ftueStep(stepName: string)
	fire("RequestFTUEStep", stepName)
end

function UIBridge.ftueAction(action: string)
	fire("RequestFTUEAction", action)
end

local function applySettingsPatch(patch: any)
	if typeof(patch) ~= "table" or typeof(patch.settings) ~= "table" then
		return
	end
	local settings = patch.settings
	if typeof(settings.locale) == "string" then
		Locale.setLocale(if settings.locale == "auto" then "" else settings.locale)
	end
	if typeof(settings.music) == "number" and typeof(settings.sfx) == "number" then
		SoundBus.setVolumes(settings.music, settings.sfx)
	end
	if typeof(settings.reduceMotion) == "boolean" then
		UIKit.setMotion(if settings.reduceMotion then 0 else 1)
	end
end

function UIBridge.start()
	task.spawn(function()
		local found = ReplicatedStorage:WaitForChild("Remotes", 8)
		if not found then
			UIState.mutate(function() end)
			return
		end
		folder = found
		local function hook(name: string, fn: (...any) -> ())
			local event = found:WaitForChild(name, 4)
			if event and event:IsA("RemoteEvent") then
				event.OnClientEvent:Connect(fn)
			end
		end
		hook("StateChanged", function(patch)
			authoritative = true
			income = false
			UIState.patch(patch)
			applySettingsPatch(patch)
		end)
		hook("Feedback", function(kind, payload)
			if typeof(kind) == "string" then
				UIState.pushFeedback(kind, payload)
			end
		end)
		hook("Announce", function(text, rarity)
			UIState.pushFeedback("ANNOUNCE", {
				text = if typeof(text) == "string" then text else "",
				rarity = rarity,
			})
		end)
		hook("OpenShop", function(kiosk)
			if typeof(kiosk) ~= "string" then
				return
			end
			local shop = require(script.Parent.Parent.Controllers.ShopController) :: any
			shop.open(kiosk)
		end)
		UIState.mutate(function() end)
	end)

	task.spawn(function()
		local Economy =
			require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy")) :: any
		while true do
			task.wait(1)
			if authoritative then
				continue
			end
			local s = UIState.get()
			local shield = if typeof(s.rookieShieldRemaining) == "number" then s.rookieShieldRemaining else 0
			local fiesta = if typeof(s.fiestaRemaining) == "number" then s.fiestaRemaining else -1
			local lockLeft = if typeof(s.myLockRemaining) == "number" then s.myLockRemaining else 0
			local lockCd = if typeof(s.myLockCooldown) == "number" then s.myLockCooldown else 0
			local nextShield = if shield > 0 then shield - 1 else shield
			local nextFiesta = if fiesta > 0 then fiesta - 1 else fiesta
			local nextLock = if lockLeft > 0 then lockLeft - 1 else lockLeft
			local nextCd = if lockLeft <= 0 and lockCd > 0 then lockCd - 1 else lockCd
			local stored = if typeof(s.vaultStored) == "number" then s.vaultStored else 0
			local nextStored = stored
			local fillVault = false
			if income and s.ftueCompleted == true then
				local perSec = if typeof(s.candyPerSec) == "number" then s.candyPerSec else 0
				if perSec > 0 then
					local tiers = Economy.VaultCapSeconds
					local tier = if typeof(s.vaultTier) == "number" then math.clamp(s.vaultTier, 1, #tiers) else 1
					local cap = perSec * tiers[tier]
					if stored < cap then
						nextStored = math.min(cap, stored + perSec)
						fillVault = true
					end
				end
			end
			if
				nextShield == shield
				and nextFiesta == fiesta
				and nextLock == lockLeft
				and nextCd == lockCd
				and not fillVault
			then
				continue
			end
			UIState.mutate(function(st)
				st.rookieShieldRemaining = nextShield
				st.fiestaRemaining = nextFiesta
				st.myLockRemaining = nextLock
				st.myLockCooldown = nextCd
				if fillVault then
					st.vaultStored = nextStored
				end
			end)
		end
	end)
end

return UIBridge
