--!strict
-- Panel de racha y misiones (WP-15). El premio lo da el servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any

local Locale = require(script.Parent.Locale)
local Menus = require(script.Parent.Menus)
local Metrics = require(script.Parent.Metrics)
local UIBridge = require(script.Parent.UIBridge)
local UIKit = require(script.Parent.UIKit)
local UIRoot = require(script.Parent.UIRoot)
local UIState = require(script.Parent.UIState)

local root: Frame
local body: ScrollingFrame

local DailyPanel = {}

local function paint()
	if body == nil then
		return
	end
	for _, child in body:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local m = Metrics.get()
	local daily = UIState.get().daily
	if typeof(daily) ~= "table" then
		return
	end
	local streak = if typeof(daily.streak) == "number" then daily.streak else 0
	local title =
		UIKit.label(body, Locale.t("daily.title", { n = tostring(streak) }), "display", m.body, Theme.color.ink)
	title.Size = UDim2.new(1, 0, 0, m.body + 8)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local reward = if typeof(daily.rewardCandy) == "number" then daily.rewardCandy else 0
	local pinata = if typeof(daily.rewardPinata) == "string" then daily.rewardPinata else ""
	local rewardText = Locale.t("daily.reward", { n = tostring(reward) })
	if pinata ~= "" then
		rewardText ..= " · " .. Locale.pinataName(pinata)
	end
	local rewardLabel = UIKit.label(body, rewardText, "body", m.small, Theme.color.ink_soft)
	rewardLabel.Size = UDim2.new(1, 0, 0, m.small * 2)
	rewardLabel.TextXAlignment = Enum.TextXAlignment.Left
	local claimed = daily.claimed == true
	UIKit.button(body, {
		name = "Claim",
		text = if claimed then Locale.t("daily.claimed") else Locale.t("daily.claim"),
		color = if claimed then Theme.color.cream else Theme.color.lime,
		size = UDim2.new(1, 0, 0, 48),
		onClick = function()
			if not claimed then
				UIBridge.claimDaily()
			end
		end,
	})
	local quests = daily.quests
	if typeof(quests) == "table" then
		for _, quest in quests do
			if typeof(quest) == "table" then
				local progress = if typeof(quest.progress) == "number" then quest.progress else 0
				local goal = if typeof(quest.goal) == "number" then quest.goal else 1
				local key = if typeof(quest.titleKey) == "string" then quest.titleKey else "daily.quest_buy"
				local line = Locale.t(key) .. string.format("  %d/%d", math.min(progress, goal), goal)
				local row = UIKit.label(body, line, "body", m.small, Theme.color.ink)
				row.Size = UDim2.new(1, 0, 0, m.small + 6)
				row.TextXAlignment = Enum.TextXAlignment.Left
				local done = quest.claimed == true
				local ready = quest.ready == true
				local index = if typeof(quest.index) == "string" then quest.index else "1"
				UIKit.button(body, {
					name = "Quest" .. index,
					text = if done then Locale.t("daily.claimed") else Locale.t("daily.claim_quest"),
					color = if ready then Theme.color.turquoise else Theme.color.cream,
					size = UDim2.new(1, 0, 0, 48),
					onClick = function()
						if ready then
							UIBridge.claimQuest(index)
						end
					end,
				})
			end
		end
	end
	local advent = daily.advent
	if typeof(advent) == "table" and advent.open == true then
		local day = if typeof(advent.day) == "number" then advent.day else 0
		local heading =
			UIKit.label(body, Locale.t("event.advent_title", { n = tostring(day) }), "display", m.body, Theme.color.ink)
		heading.Size = UDim2.new(1, 0, 0, m.body + 6)
		heading.TextXAlignment = Enum.TextXAlignment.Left
		local prize = if typeof(advent.bastones) == "number" then advent.bastones else 0
		local bodyKey = if advent.finale == true and advent.pinataId == ""
			then "event.advent_miss"
			else "event.advent_body"
		local misses = if typeof(advent.misses) == "number" then advent.misses else 0
		local detail =
			Locale.t(bodyKey, { n = if bodyKey == "event.advent_miss" then tostring(misses) else tostring(prize) })
		if advent.finale == true and typeof(advent.pinataId) == "string" and advent.pinataId ~= "" then
			detail ..= " · " .. Locale.pinataName(advent.pinataId)
		elseif advent.finale ~= true then
			detail ..= "\n" .. Locale.t("event.advent_renito")
		end
		local adventBody = UIKit.label(body, detail, "body", m.small, Theme.color.ink_soft)
		adventBody.Size = UDim2.new(1, 0, 0, m.small * 3)
		adventBody.TextXAlignment = Enum.TextXAlignment.Left
		adventBody.TextWrapped = true
		local taken = advent.claimed == true
		UIKit.button(body, {
			name = "Advent",
			text = if taken then Locale.t("daily.claimed") else Locale.t("daily.claim"),
			color = if taken then Theme.color.cream else Theme.color.lime,
			size = UDim2.new(1, 0, 0, 48),
			onClick = function()
				if not taken then
					UIBridge.claimAdvent()
				end
			end,
		})
	end
	local eventQuests = daily.eventQuests
	if typeof(eventQuests) == "table" then
		for _, quest in eventQuests do
			if typeof(quest) == "table" then
				local progress = if typeof(quest.progress) == "number" then quest.progress else 0
				local goal = if typeof(quest.goal) == "number" then quest.goal else 1
				local key = if typeof(quest.titleKey) == "string" then quest.titleKey else "event.quest_buy"
				local bastones = if typeof(quest.bastones) == "number" then quest.bastones else 0
				local line = Locale.t(key)
					.. string.format("  %d/%d", math.min(progress, goal), goal)
					.. " · "
					.. Locale.t("event.bastones_n", { n = tostring(bastones) })
				local row = UIKit.label(body, line, "body", m.small, Theme.color.ink)
				row.Size = UDim2.new(1, 0, 0, m.small + 6)
				row.TextXAlignment = Enum.TextXAlignment.Left
				local done = quest.claimed == true
				local ready = quest.ready == true
				local index = if typeof(quest.index) == "string" then quest.index else "e1"
				UIKit.button(body, {
					name = "Event" .. index,
					text = if done then Locale.t("daily.claimed") else Locale.t("daily.claim_quest"),
					color = if ready then Theme.color.turquoise else Theme.color.cream,
					size = UDim2.new(1, 0, 0, 48),
					onClick = function()
						if ready then
							UIBridge.claimQuest(index)
						end
					end,
				})
			end
		end
	end
	local state = UIState.get()
	if state.eventGift == true then
		local giftTitle = UIKit.label(body, Locale.t("event.gift_title"), "display", m.body, Theme.color.ink)
		giftTitle.Size = UDim2.new(1, 0, 0, m.body + 6)
		giftTitle.TextXAlignment = Enum.TextXAlignment.Left
		local note = UIKit.label(body, Locale.t("event.gift_body"), "body", m.small, Theme.color.ink_soft)
		note.Size = UDim2.new(1, 0, 0, m.small * 2)
		note.TextXAlignment = Enum.TextXAlignment.Left
		note.TextWrapped = true
		local pedestal: number? = nil
		local owned = state.owned
		if typeof(owned) == "table" then
			for _, item in owned do
				if typeof(item) == "table" and typeof(item.pedestal) == "number" then
					pedestal = item.pedestal
					break
				end
			end
		end
		local targets = state.giftTargets
		if pedestal == nil then
			local empty = UIKit.label(body, Locale.t("event.gift_need"), "body", m.small, Theme.color.ink)
			empty.Size = UDim2.new(1, 0, 0, m.small * 2)
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.TextWrapped = true
		elseif typeof(targets) ~= "table" or #targets == 0 then
			local empty = UIKit.label(body, Locale.t("event.gift_alone"), "body", m.small, Theme.color.ink)
			empty.Size = UDim2.new(1, 0, 0, m.small * 2)
			empty.TextXAlignment = Enum.TextXAlignment.Left
		else
			for _, target in targets do
				if typeof(target) == "table" and typeof(target.userId) == "number" then
					local userId = target.userId
					local slot = pedestal
					local name = if typeof(target.name) == "string" then target.name else "?"
					UIKit.button(body, {
						name = "Gift" .. tostring(userId),
						text = name,
						color = Theme.color.fiesta_pink,
						size = UDim2.new(1, 0, 0, 48),
						onClick = function()
							UIBridge.gift(userId, slot)
						end,
					})
				end
			end
		end
	end
	local league = state.league
	if typeof(league) == "string" and league ~= "" and Locale.has("league." .. league) then
		local leagueLabel = UIKit.label(body, Locale.t("league." .. league), "body", m.small, Theme.color.ink_soft)
		leagueLabel.Size = UDim2.new(1, 0, 0, m.small + 4)
		leagueLabel.TextXAlignment = Enum.TextXAlignment.Left
	end
end

function DailyPanel.close()
	if root ~= nil then
		root.Visible = false
	end
	Menus.closed("daily")
end

function DailyPanel.open()
	Menus.opening("daily")
	root.Visible = true
	paint()
end

function DailyPanel.toggle()
	if root ~= nil and root.Visible then
		DailyPanel.close()
	else
		DailyPanel.open()
	end
end

function DailyPanel.start()
	root = Instance.new("Frame")
	root.Name = "Daily"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 4
	root.Parent = UIRoot.layer("Menus")

	local blocker = Instance.new("TextButton")
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.BackgroundColor3 = Theme.color.ink
	blocker.BackgroundTransparency = 0.4
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.Parent = root
	blocker.Activated:Connect(function()
		DailyPanel.close()
	end)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = Theme.color.white
	card.BorderSizePixel = 0
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(360, 560)
	card.Parent = root
	UIKit.corner(card, 22)
	UIKit.stroke(card, Theme.color.white, 4)
	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = Theme.color.ink
	shadow.BackgroundTransparency = 0.75
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(6, 8)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = 0
	shadow.Parent = card
	UIKit.corner(shadow, 22)

	UIKit.button(card, {
		name = "Close",
		key = "common.close",
		color = Theme.color.fiesta_pink,
		size = UDim2.fromOffset(96, 48),
		position = UDim2.new(1, -12, 0, 12),
		anchor = Vector2.new(1, 0),
		onClick = function()
			DailyPanel.close()
		end,
	})

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Body"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Position = UDim2.fromOffset(16, 72)
	scroller.Size = UDim2.new(1, -32, 1, -88)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 6
	scroller.Parent = card
	body = scroller
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	Menus.register("daily", DailyPanel.close)
	UIState.onChange(function()
		if root.Visible then
			paint()
		end
	end)
end

return DailyPanel
