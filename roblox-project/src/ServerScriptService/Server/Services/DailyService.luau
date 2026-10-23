--!strict
-- WP-15. Racha diaria y 3 misiones por día UTC. El servidor otorga el premio.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local DailyRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("DailyRules"))
local EventCalendar = require(Shared:WaitForChild("Gameplay"):WaitForChild("EventCalendar"))
local Receipts = require(Shared:WaitForChild("Gameplay"):WaitForChild("Receipts"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local PinataVisual = require(Server:WaitForChild("World"):WaitForChild("PinataVisual"))

local DailyService = {}

local function track(player: Player, name: string, value: number)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value)
	end)
end

local function deny(player: Player, key: string)
	Remotes.get("Feedback"):FireClient(player, "DENIED", { key = key })
end

local function statOf(data: Records.PlayerData, name: string): number
	if name == "Buys" then
		return data.Stats.Buys
	elseif name == "Bonks" then
		return data.Stats.Bonks
	elseif name == "Steals" then
		return data.Stats.Steals
	elseif name == "Collects" then
		return data.Stats.Collects
	elseif name == "FiestaCandy" then
		return data.Stats.FiestaCandy
	end
	return 0
end

local function baselineOf(data: Records.PlayerData, name: string): number
	local daily = data.Daily
	if name == "Buys" then
		return daily.BaselineBuys
	elseif name == "Bonks" then
		return daily.BaselineBonks
	elseif name == "Steals" then
		return daily.BaselineSteals
	elseif name == "Collects" then
		return daily.BaselineCollects
	elseif name == "FiestaCandy" then
		return daily.BaselineFiesta
	end
	return 0
end

local function ensure(data: Records.PlayerData)
	local today = DailyRules.dayIndex(os.time())
	if data.EventQuestDay ~= today then
		data.EventQuestDay = today
		data.EventQuestMask = 0
	end
	if data.Daily.QuestDay == today then
		return
	end
	data.Daily.QuestDay = today
	data.Daily.QuestClaimedMask = 0
	data.Daily.BaselineBuys = data.Stats.Buys
	data.Daily.BaselineBonks = data.Stats.Bonks
	data.Daily.BaselineSteals = data.Stats.Steals
	data.Daily.BaselineCollects = data.Stats.Collects
	data.Daily.BaselineFiesta = data.Stats.FiestaCandy
	if data.Subscription.Active then
		local week = DailyRules.weekIndex(os.time())
		if data.Subscription.LastBoxWeek ~= week then
			local odds = Monetization.SurpriseOdds
			local cosmeticId = Receipts.pickWeighted(odds, math.random())
			if cosmeticId ~= nil then
				data.Cosmetics[cosmeticId] = true
				data.Subscription.LastBoxWeek = week
			end
		end
	end
end

local function givePinata(player: Player, data: Records.PlayerData, pinataId: string): boolean
	if Pinatas[pinataId] == nil or not Records.hasRoom(data) then
		return false
	end
	local granted, instanceId = Records.grantPinata(player, pinataId, "None")
	if not granted or instanceId == nil then
		return false
	end
	local owned = Records.find(data, instanceId)
	if owned == nil then
		return false
	end
	local model = PinataVisual.create(pinataId, nil)
	BaseService.receive(player.UserId, owned, model, true, nil)
	return true
end

function DailyService.snapshot(player: Player): { [string]: any }
	local data = Records.get(player)
	if data == nil then
		return {}
	end
	ensure(data)
	local today = DailyRules.dayIndex(os.time())
	local streak, reason = DailyRules.nextStreak(data.Daily.ClaimedDay, data.Daily.Streak, today)
	local reward =
		DailyRules.rewardForStreak(if reason == "already" or reason == "clock" then data.Daily.Streak else streak)
	local quests = {}
	for index, quest in DailyRules.board(today) do
		local progress = math.max(0, statOf(data, quest.stat) - baselineOf(data, quest.stat))
		local claimed = bit32.band(data.Daily.QuestClaimedMask, bit32.lshift(1, index - 1)) ~= 0
		table.insert(quests, {
			index = tostring(index),
			titleKey = quest.titleKey,
			progress = progress,
			goal = quest.goal,
			candy = quest.candy,
			claimed = claimed,
			ready = progress >= quest.goal and not claimed,
		})
	end
	local eventQuests = {}
	local advent = {
		open = false,
		day = 0,
		claimed = false,
		bastones = 0,
		pinataId = "",
		misses = 0,
		finale = false,
	}
	local phaseOverride = workspace:GetAttribute("ForcePosadasPhase")
	local snap = EventCalendar.snapshot(
		os.time(),
		EventCalendar.isForced(workspace:GetAttribute("ForcePosadas")),
		if type(phaseOverride) == "string" then phaseOverride else nil
	)
	if snap.shop then
		for index, quest in EventCalendar.quests() do
			local progress = math.max(0, statOf(data, quest.stat) - baselineOf(data, quest.stat))
			local claimed = bit32.band(data.EventQuestMask, EventCalendar.questBit(index)) ~= 0
			table.insert(eventQuests, {
				index = quest.id,
				titleKey = quest.titleKey,
				progress = progress,
				goal = quest.goal,
				bastones = quest.bastones,
				claimed = claimed,
				ready = progress >= quest.goal and not claimed,
			})
		end
	end
	if snap.advent then
		local day = EventCalendar.adventDay(os.time(), snap)
		if day ~= nil then
			local bit = EventCalendar.adventBit(day)
			local claimed = bit ~= 0 and bit32.band(data.AdventMask, bit) ~= 0
			local misses = EventCalendar.missesBefore(data.AdventMask, day)
			local prize = EventCalendar.adventReward(day, misses)
			advent = {
				open = true,
				day = day,
				claimed = claimed,
				bastones = prize.bastones,
				pinataId = prize.pinataId or "",
				misses = misses,
				finale = prize.finale,
			}
		end
	end
	return {
		streak = data.Daily.Streak,
		cycleDay = DailyRules.cycleDay(if data.Daily.Streak > 0 then data.Daily.Streak else 1),
		claimed = reason == "already",
		canClaim = reason == "start" or reason == "continue" or reason == "reset",
		rewardCandy = reward.Candy,
		rewardPinata = reward.PinataId or "",
		quests = quests,
		eventQuests = eventQuests,
		advent = advent,
		subscribed = data.Subscription.Active == true,
	}
end

local function onClaim(player: Player)
	local data = Records.get(player)
	if data == nil then
		return
	end
	ensure(data)
	local today = DailyRules.dayIndex(os.time())
	local streak, reason = DailyRules.nextStreak(data.Daily.ClaimedDay, data.Daily.Streak, today)
	if reason == "already" or reason == "clock" then
		deny(player, "daily.already")
		return
	end
	data.Daily.Streak = streak
	data.Daily.ClaimedDay = today
	data.Daily.LastClaimUnix = os.time()
	local reward = DailyRules.rewardForStreak(streak)
	Records.grantDulces(player, reward.Candy)
	if reward.PinataId ~= nil then
		givePinata(player, data, reward.PinataId)
	end
	if data.Subscription.Active and data.Subscription.LastPinataDay ~= today then
		if not givePinata(player, data, "estrellita") then
			Records.grantDulces(player, 800)
		end
		data.Subscription.LastPinataDay = today
	end
	track(player, "daily_claim", streak)
	BaseService.pushState(player)
end

local function onEventQuest(player: Player, data: Records.PlayerData, id: string)
	local phaseOverride = workspace:GetAttribute("ForcePosadasPhase")
	local snap = EventCalendar.snapshot(
		os.time(),
		EventCalendar.isForced(workspace:GetAttribute("ForcePosadas")),
		if type(phaseOverride) == "string" then phaseOverride else nil
	)
	if not snap.shop then
		deny(player, "event_off")
		return
	end
	ensure(data)
	local quest = EventCalendar.questById(id)
	if quest == nil then
		return
	end
	local index = 0
	for slot, row in EventCalendar.quests() do
		if row.id == id then
			index = slot
		end
	end
	local bit = EventCalendar.questBit(index)
	if bit == 0 or bit32.band(data.EventQuestMask, bit) ~= 0 then
		deny(player, "daily.already")
		return
	end
	local progress = statOf(data, quest.stat) - baselineOf(data, quest.stat)
	if progress < quest.goal then
		deny(player, "common.need")
		return
	end
	data.EventQuestMask = bit32.bor(data.EventQuestMask, bit)
	Records.grantCurrency(player, "Bastones", quest.bastones)
	track(player, "event_quest", quest.bastones)
	BaseService.pushState(player)
end

local function onQuest(player: Player, args: { any })
	local data = Records.get(player)
	local indexText = args[1]
	if data == nil or type(indexText) ~= "string" then
		return
	end
	if string.sub(indexText, 1, 1) == "e" then
		onEventQuest(player, data, indexText)
		return
	end
	ensure(data)
	local index = tonumber(indexText)
	if index == nil then
		return
	end
	local today = DailyRules.dayIndex(os.time())
	local quest = DailyRules.questByIndex(today, index)
	if quest == nil then
		return
	end
	local bit = bit32.lshift(1, index - 1)
	if bit32.band(data.Daily.QuestClaimedMask, bit) ~= 0 then
		deny(player, "daily.already")
		return
	end
	local progress = statOf(data, quest.stat) - baselineOf(data, quest.stat)
	if progress < quest.goal then
		deny(player, "common.need")
		return
	end
	data.Daily.QuestClaimedMask = bit32.bor(data.Daily.QuestClaimedMask, bit)
	Records.grantDulces(player, quest.candy)
	track(player, "daily_quest", quest.candy)
	BaseService.pushState(player)
end

function DailyService.init(_services: { [string]: any })
	AntiCheatService.register("RequestClaimDaily", function(player)
		onClaim(player)
	end)
	AntiCheatService.register("RequestClaimQuest", onQuest)
end

function DailyService.start() end

return DailyService
