--!strict
-- Espejo de solo lectura del estado que pinta la UI.
-- Se escribe con patch (servidor) o mutate (preview / presenter offline).

local state: { [string]: any } = {
	candy = 0,
	candyPerSec = 0,
	bastones = 0,
	owned = {},
	pedestalCount = 4,
	pedestalCap = 8,
	vaultTier = 1,
	vaultStored = 0,
	carrying = nil,
	rookieShieldRemaining = 0,
	myLockRemaining = 0,
	myLockCooldown = 0,
	nearbyLocks = {},
	fiestaRemaining = -1,
	reFiestas = 0,
	passes = {
		doubleCandy = false,
		vip = false,
		extraPedestals = false,
		autoCollect = false,
		batPack = false,
	},
	batSkin = "wood",
	settings = {
		locale = "",
		music = 0.8,
		sfx = 0.8,
		reduceMotion = false,
		cameraShake = true,
	},
	ftueCompleted = false,
	multiplier = 1,
	batUpgrade = 0,
	fiestaPhase = "idle",
	fiestaLeft = 0,
	giantHp = 0,
	giantMax = 0,
	myFiestaHits = 0,
	daily = {
		streak = 0,
		cycleDay = 1,
		claimed = false,
		canClaim = false,
		rewardCandy = 0,
		rewardPinata = "",
		quests = {},
		subscribed = false,
	},
}

local listeners: { ({ [string]: any }) -> () } = {}
local feedbackListeners: { (string, { [string]: any }) -> () } = {}

local UIState = {}

local NUMBER_KEYS = {
	"candy",
	"candyPerSec",
	"bastones",
	"pedestalCount",
	"pedestalCap",
	"vaultTier",
	"vaultStored",
	"rookieShieldRemaining",
	"myLockRemaining",
	"myLockCooldown",
	"fiestaRemaining",
	"reFiestas",
	"multiplier",
	"batUpgrade",
	"fiestaLeft",
	"giantHp",
	"giantMax",
	"myFiestaHits",
}

local function emit()
	for _, fn in listeners do
		local ok, err = pcall(fn, state)
		if not ok then
			warn("[UI] " .. tostring(err))
		end
	end
end

local function readOwned(list: any): { any }
	local out = {}
	if typeof(list) ~= "table" then
		return out
	end
	for _, item in list do
		if typeof(item) == "table" and typeof(item.pinataId) == "string" then
			local pedestal = nil
			if typeof(item.pedestal) == "number" then
				pedestal = item.pedestal
			end
			table.insert(out, {
				uid = if typeof(item.uid) == "string" then item.uid else item.pinataId,
				pinataId = item.pinataId,
				mutation = if typeof(item.mutation) == "string" then item.mutation else "None",
				pedestal = pedestal,
			})
		end
	end
	return out
end

local function readCarry(item: any): { [string]: any }?
	if typeof(item) ~= "table" or typeof(item.pinataId) ~= "string" then
		return nil
	end
	return {
		pinataId = item.pinataId,
		mutation = if typeof(item.mutation) == "string" then item.mutation else "None",
		fromUserId = if typeof(item.fromUserId) == "number" then item.fromUserId else 0,
		hitsLeft = if typeof(item.hitsLeft) == "number" then item.hitsLeft else 1,
	}
end

local function readLocks(list: any): { any }
	local out = {}
	if typeof(list) ~= "table" then
		return out
	end
	for _, item in list do
		if typeof(item) == "table" then
			table.insert(out, {
				userId = if typeof(item.userId) == "number" then item.userId else 0,
				name = if typeof(item.name) == "string" then string.sub(item.name, 1, 24) else "?",
				remaining = if typeof(item.remaining) == "number" then item.remaining else 0,
				cooldown = if typeof(item.cooldown) == "number" then item.cooldown else 0,
			})
		end
	end
	return out
end

local function mergePasses(from: any)
	if typeof(from) ~= "table" then
		return
	end
	local passes = state.passes
	for _, key in { "doubleCandy", "vip", "extraPedestals", "autoCollect", "batPack" } do
		if typeof(from[key]) == "boolean" then
			passes[key] = from[key]
		end
	end
end

local function mergeSettings(from: any)
	if typeof(from) ~= "table" then
		return
	end
	local settings = state.settings
	if typeof(from.locale) == "string" then
		settings.locale = from.locale
	end
	if typeof(from.music) == "number" then
		settings.music = math.clamp(from.music, 0, 1)
	end
	if typeof(from.sfx) == "number" then
		settings.sfx = math.clamp(from.sfx, 0, 1)
	end
	if typeof(from.reduceMotion) == "boolean" then
		settings.reduceMotion = from.reduceMotion
	end
	if typeof(from.cameraShake) == "boolean" then
		settings.cameraShake = from.cameraShake
	end
end

function UIState.get(): { [string]: any }
	return state
end

function UIState.patch(partial: any)
	if typeof(partial) ~= "table" then
		return
	end
	for _, key in NUMBER_KEYS do
		if typeof(partial[key]) == "number" then
			state[key] = partial[key]
		end
	end
	if typeof(partial.owned) == "table" then
		state.owned = readOwned(partial.owned)
	end
	if partial.carrying == false or partial.clearCarrying == true then
		state.carrying = nil
	elseif typeof(partial.carrying) == "table" then
		state.carrying = readCarry(partial.carrying)
	end
	if typeof(partial.nearbyLocks) == "table" then
		state.nearbyLocks = readLocks(partial.nearbyLocks)
	end
	if typeof(partial.passes) == "table" then
		mergePasses(partial.passes)
	end
	if typeof(partial.settings) == "table" then
		mergeSettings(partial.settings)
	end
	if typeof(partial.batSkin) == "string" then
		state.batSkin = partial.batSkin
	end
	if typeof(partial.fiestaPhase) == "string" then
		state.fiestaPhase = partial.fiestaPhase
	end
	if typeof(partial.daily) == "table" then
		state.daily = partial.daily
	end
	if typeof(partial.ftueCompleted) == "boolean" then
		state.ftueCompleted = partial.ftueCompleted
	end
	emit()
end

function UIState.mutate(fn: ({ [string]: any }) -> ())
	fn(state)
	emit()
end

function UIState.replace(nextState: { [string]: any })
	state = nextState
	emit()
end

function UIState.onChange(fn: ({ [string]: any }) -> ())
	table.insert(listeners, fn)
end

function UIState.pushFeedback(kind: string, payload: any)
	local data = if typeof(payload) == "table" then payload else {}
	for _, fn in feedbackListeners do
		local ok, err = pcall(fn, kind, data)
		if not ok then
			warn("[UI] " .. tostring(err))
		end
	end
end

function UIState.onFeedback(fn: (string, { [string]: any }) -> ())
	table.insert(feedbackListeners, fn)
end

return UIState
