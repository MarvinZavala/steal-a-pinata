--!strict
-- Kioscos Dulcería, Bates, Cajas y VIP. Los Robux solo se piden si el Id del config no es 0.

local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy")) :: any
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local ShopCatalog =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("ShopCatalog")) :: any
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format")) :: any

local Locale = require(script.Parent.Parent.UI.Locale)
local Menus = require(script.Parent.Parent.UI.Menus)
local Metrics = require(script.Parent.Parent.UI.Metrics)
local Toast = require(script.Parent.Parent.UI.Toast)
local UIBridge = require(script.Parent.Parent.UI.UIBridge)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local UIState = require(script.Parent.Parent.UI.UIState)

local root: Frame
local panel: Frame
local header: Frame
local title: TextLabel
local blurb: TextLabel
local list: ScrollingFrame
local kiosk = "picker"
local open = false

local ShopController = {}

local KIOSK_COLOR = {
	dulceria = "sun_yellow",
	bates = "wood",
	cajas = "grape",
	vip = "gold",
}

local function fillFor(name: string): Color3
	local key = KIOSK_COLOR[name]
	if key == "sun_yellow" then
		return Theme.color.sun_yellow
	elseif key == "wood" then
		return Theme.color.wood
	elseif key == "grape" then
		return Theme.color.grape
	elseif key == "gold" then
		return Theme.color.gold
	end
	return Theme.color.fiesta_pink
end

local function clearList()
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function applyLocalUpgrade(st: { [string]: any }, id: string)
	if id == "Pedestal" then
		local count = if typeof(st.pedestalCount) == "number" then st.pedestalCount else 0
		st.pedestalCount = count + 1
	elseif id == "VaultCap" then
		local tier = if typeof(st.vaultTier) == "number" then st.vaultTier else 1
		st.vaultTier = tier + 1
	elseif id == "ReFiesta" then
		st.reFiestas = (if typeof(st.reFiestas) == "number" then st.reFiestas else 0) + 1
		local passes = if typeof(st.passes) == "table" then st.passes else {}
		st.multiplier = Economy.totalMultiplier(st.reFiestas, passes.doubleCandy == true, passes.vip == true, 0)
	end
end

local function spendCandy(cost: number, applyFn: ({ [string]: any }) -> ())
	if UIBridge.isAuthoritative() then
		Toast.push("info", Locale.t("common.sent"))
		return
	end
	if UIState.get().candy < cost then
		Toast.push("bad", Locale.t("deny.poor"))
		return
	end
	UIState.mutate(function(st)
		st.candy -= cost
		applyFn(st)
	end)
	Toast.push("good", Locale.t("toast.purchase"))
end

local function onEntry(entry: any)
	if entry.owned == true then
		Toast.push("info", Locale.t("common.owned"))
		return
	end
	if entry.action == "info" then
		return
	end
	if entry.enabled ~= true then
		if entry.badgeKey == "common.soon" or entry.action == "pass" or entry.action == "product" then
			Toast.push("info", Locale.t("toast.soon"))
		elseif typeof(entry.priceCandy) == "number" and UIState.get().candy < entry.priceCandy then
			Toast.push("bad", Locale.t("deny.poor"))
		end
		return
	end
	if entry.action == "upgrade" then
		local cost = if typeof(entry.priceCandy) == "number" then entry.priceCandy else 0
		spendCandy(cost, function(st)
			applyLocalUpgrade(st, entry.id)
		end)
		UIBridge.upgrade(entry.id)
		ShopController.refresh()
	elseif entry.action == "fuse" then
		local pinataId = string.split(entry.id, ":")[2]
		if not pinataId then
			return
		end
		if not UIBridge.isAuthoritative() then
			UIState.mutate(function(st)
				local kept = {}
				local removed = 0
				local owned = if typeof(st.owned) == "table" then st.owned else {}
				for _, item in owned do
					if typeof(item) == "table" and item.pinataId == pinataId and removed < 3 then
						removed += 1
					else
						table.insert(kept, item)
					end
				end
				table.insert(kept, {
					uid = "fuse-" .. pinataId,
					pinataId = pinataId,
					mutation = "Golden",
					pedestal = nil,
				})
				st.owned = kept
			end)
		end
		UIBridge.fuse(pinataId)
		Toast.push("legend", Locale.t("toast.purchase"))
		ShopController.refresh()
	elseif entry.action == "pass" or entry.action == "product" then
		local productId = ShopCatalog.productId(entry.action, entry.id)
		if typeof(productId) ~= "number" or productId == 0 then
			Toast.push("info", Locale.t("toast.soon"))
			return
		end
		local player = Players.LocalPlayer
		if entry.action == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, productId)
		else
			MarketplaceService:PromptProductPurchase(player, productId)
		end
	end
end

local function addOdds(parent: Instance, odds: any)
	if typeof(odds) ~= "table" then
		return
	end
	local block = Instance.new("Frame")
	block.BackgroundTransparency = 1
	block.Size = UDim2.new(1, 0, 0, 8 + #odds * 22)
	block.Parent = parent
	local y = 0
	for _, row in odds do
		if typeof(row) == "table" then
			local line = Instance.new("Frame")
			line.BackgroundTransparency = 1
			line.Position = UDim2.fromOffset(0, y)
			line.Size = UDim2.new(1, 0, 0, 20)
			line.Parent = block
			local track = Instance.new("Frame")
			track.BackgroundColor3 = Theme.color.cream
			track.BorderSizePixel = 0
			track.Size = UDim2.new(0.46, 0, 0, 10)
			track.Position = UDim2.fromOffset(0, 5)
			track.Parent = line
			UIKit.corner(track, 5)
			local bar = Instance.new("Frame")
			bar.BackgroundColor3 =
				fillFor(if row.swatch == "grape" then "cajas" elseif row.swatch == "gold" then "vip" else "dulceria")
			if row.swatch == "lime" then
				bar.BackgroundColor3 = Theme.color.lime
			elseif row.swatch == "fiesta_pink" then
				bar.BackgroundColor3 = Theme.color.fiesta_pink
			elseif row.swatch == "turquoise" then
				bar.BackgroundColor3 = Theme.color.turquoise
			elseif row.swatch == "grape" then
				bar.BackgroundColor3 = Theme.color.grape
			elseif row.swatch == "gold" then
				bar.BackgroundColor3 = Theme.color.gold
			end
			bar.BorderSizePixel = 0
			bar.Size = UDim2.new((row.percent or 0) / 100, 0, 1, 0)
			bar.Parent = track
			UIKit.corner(bar, 5)
			local label = UIKit.label(
				line,
				Locale.t(row.key) .. "  " .. tostring(row.percent) .. "%",
				"body",
				14,
				Theme.color.ink
			)
			label.Position = UDim2.new(0.5, 0, 0, 0)
			label.Size = UDim2.new(0.5, 0, 1, 0)
			label.TextXAlignment = Enum.TextXAlignment.Left
			y += 22
		end
	end
	local note = UIKit.label(block, Locale.t("shop.odds_dupe"), "body", 13, Theme.color.ink_soft)
	note.Position = UDim2.fromOffset(0, y)
	note.Size = UDim2.new(1, 0, 0, 18)
	note.TextXAlignment = Enum.TextXAlignment.Left
	block.Size = UDim2.new(1, 0, 0, y + 20)
end

local function renderPicker()
	title.Text = Locale.t("hud.shop")
	blurb.Text = Locale.t("preview.note")
	header.BackgroundColor3 = Theme.color.fiesta_pink
	local m = Metrics.get()
	for index, name in ShopCatalog.kiosks() do
		local color = fillFor(name)
		local wrap, _hit, caption = UIKit.button(list, {
			name = "Kiosk" .. name,
			text = Locale.t(ShopCatalog.title(name)),
			color = color,
			size = UDim2.new(1, 0, 0, math.max(64, m.button + 8)),
			onClick = function()
				ShopController.open(name)
			end,
		})
		wrap.LayoutOrder = index
		UIKit.fringe(wrap:FindFirstChildWhichIsA("TextButton") :: GuiObject, color, Theme.color.cream)
		if name == "cajas" or name == "vip" then
			caption.TextColor3 = Theme.color.white
			caption.TextStrokeTransparency = 0
			caption.TextStrokeColor3 = Theme.color.ink
		end
	end
end

local function renderKiosk(name: string)
	title.Text = Locale.t(ShopCatalog.title(name))
	blurb.Text = Locale.t(ShopCatalog.blurb(name))
	header.BackgroundColor3 = fillFor(name)
	local m = Metrics.get()
	local state = UIState.get()
	if name == "vip" then
		local mult = if typeof(state.multiplier) == "number" then state.multiplier else 1
		blurb.Text ..= "\n" .. Locale.t("shop.your_mult", { n = string.format("%.1f", mult) })
	end
	local entries = ShopCatalog.entries(name, state)
	for index, entry in entries do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.color.cream
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = index
		row.Parent = list
		UIKit.corner(row, 16)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 10)
		pad.Parent = row
		local stack = Instance.new("UIListLayout")
		stack.Padding = UDim.new(0, 4)
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = row

		local args = entry.titleArgs
		if string.sub(entry.id, 1, 5) == "fuse:" then
			local pinataId = string.split(entry.id, ":")[2]
			if pinataId and pinataId ~= "empty" then
				args = { name = Locale.pinataName(pinataId) }
			end
		end
		local heading = UIKit.label(row, Locale.t(entry.titleKey, args), "display", m.body, Theme.color.ink)
		heading.Size = UDim2.new(1, 0, 0, m.body + 6)
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.LayoutOrder = 1
		local body = UIKit.label(row, Locale.t(entry.bodyKey, entry.bodyArgs), "body", m.small, Theme.color.ink_soft)
		body.Size = UDim2.new(1, 0, 0, m.small * 2 + 4)
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.LayoutOrder = 2
		if entry.odds then
			local oddsHost = Instance.new("Frame")
			oddsHost.BackgroundTransparency = 1
			oddsHost.AutomaticSize = Enum.AutomaticSize.Y
			oddsHost.Size = UDim2.new(1, 0, 0, 0)
			oddsHost.LayoutOrder = 3
			oddsHost.Parent = row
			addOdds(oddsHost, entry.odds)
		end
		local priceText = Locale.t("common.buy")
		local buttonColor = Theme.color.fiesta_pink
		if entry.owned == true then
			priceText = Locale.t("common.owned")
			buttonColor = Theme.color.cream
		elseif typeof(entry.priceRobux) == "number" then
			priceText = Locale.t("shop.robux", { n = tostring(entry.priceRobux) })
			buttonColor = Theme.color.lime
		elseif typeof(entry.priceCandy) == "number" then
			priceText = Format(entry.priceCandy)
			buttonColor = Theme.color.fiesta_pink
		elseif entry.badgeKey then
			priceText = Locale.t(entry.badgeKey)
		end
		if entry.badgeKey == "common.soon" then
			priceText = Locale.t("common.soon")
		end
		local buttonWrap, _hit, caption = UIKit.button(row, {
			name = "Buy" .. entry.id,
			text = priceText,
			color = buttonColor,
			size = UDim2.new(1, 0, 0, math.max(48, m.button - 4)),
			onClick = function()
				onEntry(entry)
			end,
		})
		buttonWrap.LayoutOrder = 4
		caption.TextSize = m.body
	end
end

function ShopController.refresh()
	if not open then
		return
	end
	local canvas = list.CanvasPosition
	clearList()
	if kiosk == "picker" then
		renderPicker()
	else
		renderKiosk(kiosk)
	end
	list.CanvasPosition = canvas
end

function ShopController.layout()
	local m = Metrics.get()
	panel.Size = UDim2.fromOffset(
		math.min(if m.portrait then m.w - 16 else 520, m.w - m.margin * 2),
		math.max(240, m.h - m.safeTop - m.safeBottom - m.margin * 2)
	)
end

function ShopController.open(name: string?)
	kiosk = name or "picker"
	if kiosk == "" then
		kiosk = "picker"
	end
	Menus.opening("shop")
	open = true
	root.Visible = true
	ShopController.layout()
	ShopController.refresh()
	local closeHit = panel:FindFirstChild("CloseShop", true)
	if closeHit and closeHit:IsA("GuiObject") then
		GuiService.SelectedObject = closeHit
	end
end

function ShopController.close()
	open = false
	if root then
		root.Visible = false
	end
	Menus.closed("shop")
end

function ShopController.start()
	root = Instance.new("Frame")
	root.Name = "Shop"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 5
	root.Parent = UIRoot.layer("Menus")

	local blocker = Instance.new("TextButton")
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.Modal = true
	blocker.BackgroundColor3 = Theme.color.ink
	blocker.BackgroundTransparency = 0.42
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.Parent = root
	blocker.Activated:Connect(function()
		ShopController.close()
	end)

	panel = Instance.new("Frame")
	panel.Name = "Card"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.BackgroundColor3 = Theme.color.white
	panel.BorderSizePixel = 0
	panel.ZIndex = 2
	panel.ClipsDescendants = true
	panel.Parent = root
	UIKit.corner(panel, 22)
	UIKit.stroke(panel, Theme.color.white, 4)

	header = Instance.new("Frame")
	header.BackgroundColor3 = Theme.color.fiesta_pink
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, 92)
	header.Parent = panel
	title = UIKit.label(header, "", "display", 28, Theme.color.ink)
	title.Size = UDim2.new(1, -200, 0, 36)
	title.Position = UDim2.fromOffset(16, 8)
	title.TextXAlignment = Enum.TextXAlignment.Left
	blurb = UIKit.label(header, "", "body", 15, Theme.color.ink)
	blurb.Size = UDim2.new(1, -24, 0, 40)
	blurb.Position = UDim2.fromOffset(16, 44)
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextYAlignment = Enum.TextYAlignment.Top

	UIKit.button(header, {
		name = "BackShop",
		key = "common.back",
		color = Theme.color.white,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -112, 0, 8),
		size = UDim2.fromOffset(96, 40),
		onClick = function()
			if kiosk == "picker" then
				ShopController.close()
			else
				ShopController.open("picker")
			end
		end,
	})
	UIKit.button(header, {
		name = "CloseShop",
		text = "✕",
		color = Theme.color.cream,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -8, 0, 8),
		size = UDim2.fromOffset(44, 40),
		onClick = function()
			ShopController.close()
		end,
	})

	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, 100)
	list.Size = UDim2.new(1, -24, 1, -112)
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = Theme.color.grape
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	Menus.register("shop", ShopController.close)
	Metrics.onChange(function()
		if open then
			ShopController.layout()
		end
	end)
	Locale.onChange(function()
		if open then
			ShopController.refresh()
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _id, purchased)
		if player == Players.LocalPlayer and purchased then
			Toast.push("good", Locale.t("shop.thanks"))
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _id, purchased)
		if userId == Players.LocalPlayer.UserId and purchased then
			Toast.push("good", Locale.t("shop.thanks"))
		end
	end)
end

return ShopController
