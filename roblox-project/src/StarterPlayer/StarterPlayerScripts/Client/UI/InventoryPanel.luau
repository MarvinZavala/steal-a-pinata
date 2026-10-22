--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pinatas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Pinatas")) :: any
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local Locale = require(script.Parent.Locale)
local Menus = require(script.Parent.Menus)
local Metrics = require(script.Parent.Metrics)
local UIKit = require(script.Parent.UIKit)
local UIRoot = require(script.Parent.UIRoot)
local UIState = require(script.Parent.UIState)

local root: Frame
local panel: Frame
local scroll: ScrollingFrame
local content: Frame
local title: TextLabel
local countLabel: TextLabel
local emptyLabel: TextLabel

local InventoryPanel = {}

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function addCard(item: any?, emptyIndex: number?)
	local m = Metrics.get()
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.color.cream
	card.BorderSizePixel = 0
	card.LayoutOrder = if emptyIndex then emptyIndex else 100
	card.Parent = content
	UIKit.corner(card, m.radius)
	local rarity = "Common"
	if item and typeof(item.pinataId) == "string" then
		local def = Pinatas[item.pinataId]
		if typeof(def) == "table" and typeof(def.Rarity) == "string" then
			rarity = def.Rarity
		end
		local style = Theme.rarity(rarity)
		card.BackgroundColor3 = if rarity == "Secret" then Theme.color.ink else Theme.color.cream
		UIKit.stroke(
			card,
			style.color,
			if style.frame == "double" or style.frame == "pulse" then m.stroke + 2 else m.stroke
		)
		local face = UIKit.pinataFace(
			card,
			item.pinataId,
			if typeof(item.mutation) == "string" then item.mutation else "None",
			m.button
		)
		face.AnchorPoint = Vector2.new(0.5, 0)
		face.Position = UDim2.new(0.5, 0, 0, 6)
		local name = UIKit.label(
			card,
			Locale.pinataName(item.pinataId),
			"body",
			m.small,
			if rarity == "Secret" then Theme.color.white else Theme.color.ink
		)
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -28)
		name.Size = UDim2.new(1, -8, 0, m.small + 2)
		name.TextWrapped = false
		local chip = UIKit.rarityChip(card, rarity, math.max(18, m.small + 4))
		chip.AnchorPoint = Vector2.new(0.5, 1)
		chip.Position = UDim2.new(0.5, 0, 1, -6)
		local mutation = if typeof(item.mutation) == "string" then item.mutation else "None"
		if mutation ~= "None" then
			local ribbon = UIKit.label(card, Locale.mutationName(mutation), "body", m.small - 1, Theme.color.gold_deep)
			ribbon.Position = UDim2.fromOffset(4, 4)
			ribbon.Size = UDim2.new(1, -8, 0, m.small)
			ribbon.TextXAlignment = Enum.TextXAlignment.Left
		end
		local base = if typeof(def) == "table" and typeof(def.CandyPerSec) == "number" then def.CandyPerSec else 0
		name.Text = Locale.pinataName(item.pinataId)
		local rate = UIKit.label(
			card,
			Locale.t("hud.per_sec", { n = tostring(base) }),
			"body",
			m.small - 1,
			Theme.color.ink_soft
		)
		rate.AnchorPoint = Vector2.new(1, 0)
		rate.Position = UDim2.new(1, -4, 0, 2)
		rate.Size = UDim2.fromOffset(64, m.small + 2)
		rate.TextXAlignment = Enum.TextXAlignment.Right
	else
		UIKit.stroke(card, Theme.color.ink_soft, 2)
		local label = UIKit.label(card, Locale.t("hud.empty"), "body", m.small, Theme.color.ink_soft)
		label.Text = if emptyIndex then Locale.t("hud.empty") else ""
	end
end

local function rebuild()
	local s = UIState.get()
	local m = Metrics.get()
	local columns = if m.w < 520 then 2 else 3
	local grid = content:FindFirstChildOfClass("UIGridLayout")
	if grid then
		local cell = math.clamp(math.floor((scroll.AbsoluteSize.X - 16) / columns) - 8, 108, 150)
		grid.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.18))
		grid.CellPadding = UDim2.fromOffset(8, 8)
	end
	clear(content)
	local pedestalCount = if typeof(s.pedestalCount) == "number" then s.pedestalCount else 0
	local owned = if typeof(s.owned) == "table" then s.owned else {}
	local slots: { any } = {}
	for index = 1, pedestalCount do
		slots[index] = false
	end
	local bag = {}
	local ownedCount = 0
	for _, item in owned do
		if typeof(item) == "table" then
			ownedCount += 1
			local pedestal = item.pedestal
			if
				typeof(pedestal) == "number"
				and pedestal >= 1
				and pedestal <= pedestalCount
				and slots[pedestal] == false
			then
				slots[pedestal] = item
			else
				table.insert(bag, item)
			end
		end
	end
	for index = 1, pedestalCount do
		local item = slots[index]
		if item == false then
			addCard(nil, index)
		else
			addCard(item, nil)
		end
	end
	for _, item in bag do
		addCard(item, nil)
	end
	countLabel.Text = Locale.t("inv.count", { n = tostring(ownedCount), max = tostring(pedestalCount) })
	emptyLabel.Visible = ownedCount == 0
	emptyLabel.Text = Locale.t("inv.empty")
	title.Text = Locale.t("inv.title")
end

function InventoryPanel.mount()
	local layer = UIRoot.layer("Menus")
	root = Instance.new("Frame")
	root.Name = "Inventory"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 3
	root.Parent = layer

	local blocker = Instance.new("TextButton")
	blocker.Name = "Blocker"
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.BackgroundColor3 = Theme.color.ink
	blocker.BackgroundTransparency = 0.4
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.Modal = true
	blocker.ZIndex = 1
	blocker.Parent = root
	blocker.Activated:Connect(function()
		InventoryPanel.close()
	end)

	panel = Instance.new("Frame")
	panel.Name = "Sheet"
	panel.BackgroundColor3 = Theme.color.white
	panel.BorderSizePixel = 0
	panel.ZIndex = 2
	panel.Parent = root
	UIKit.corner(panel, 22)
	UIKit.stroke(panel, Theme.color.white, 4)
	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = Theme.color.ink
	shadow.BackgroundTransparency = 0.75
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Position = UDim2.fromOffset(0, 5)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Parent = panel
	UIKit.corner(shadow, 22)

	title = UIKit.label(panel, "", "display", 28, Theme.color.ink)
	title.Name = "Title"
	title.Size = UDim2.new(1, -120, 0, 36)
	title.Position = UDim2.fromOffset(16, 10)
	title.TextXAlignment = Enum.TextXAlignment.Left
	countLabel = UIKit.label(panel, "", "body", 16, Theme.color.ink_soft)
	countLabel.Size = UDim2.fromOffset(80, 28)
	countLabel.Position = UDim2.new(1, -150, 0, 14)
	local _closeWrap, closeHit = UIKit.button(panel, {
		name = "CloseInventory",
		key = "common.close",
		color = Theme.color.cream,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -10, 0, 10),
		size = UDim2.fromOffset(96, 44),
		onClick = function()
			InventoryPanel.close()
		end,
	})

	scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grid"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(12, 62)
	scroll.Size = UDim2.new(1, -24, 1, -74)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Theme.color.grape
	scroll.ZIndex = 3
	scroll.Parent = panel

	content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Parent = scroll
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content

	emptyLabel = UIKit.label(panel, "", "body", 18, Theme.color.ink_soft)
	emptyLabel.Position = UDim2.fromOffset(16, 64)
	emptyLabel.Size = UDim2.new(1, -32, 0, 28)
	emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
	emptyLabel.ZIndex = 4

	Menus.register("inventory", InventoryPanel.close)
	Metrics.onChange(function()
		InventoryPanel.layout()
		if root.Visible then
			rebuild()
		end
	end)
	Locale.onChange(function()
		if root.Visible then
			rebuild()
		end
	end)
	UIState.onChange(function()
		if root.Visible then
			rebuild()
		end
	end)
	closeHit.Selectable = true
end

function InventoryPanel.layout()
	local m = Metrics.get()
	local width = if m.w < 700 then m.w - m.margin * 2 else math.min(480, math.floor(m.w * 0.46))
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, m.safeLeft + m.margin, 0.5, 0)
	panel.Size = UDim2.fromOffset(width, math.max(220, m.h - m.safeTop - m.safeBottom - m.margin * 2))
	title.TextSize = m.title
end

function InventoryPanel.open()
	Menus.opening("inventory")
	root.Visible = true
	InventoryPanel.layout()
	rebuild()
	local closeHit = panel:FindFirstChild("CloseInventoryWrap", true)
	if closeHit and closeHit:IsA("GuiObject") then
		local hit = closeHit:FindFirstChild("CloseInventory")
		if hit and hit:IsA("GuiObject") then
			GuiService.SelectedObject = hit
		end
	end
end

function InventoryPanel.close()
	if not root.Visible then
		Menus.closed("inventory")
		return
	end
	root.Visible = false
	Menus.closed("inventory")
end

function InventoryPanel.toggle()
	if root.Visible then
		InventoryPanel.close()
	else
		InventoryPanel.open()
	end
end

return InventoryPanel
