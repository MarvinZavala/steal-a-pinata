--!strict
-- Storybook de Studio. Vive en su propio ScreenGui para no heredar el UIScale del teléfono simulado.
-- Abrilo con el botón, con ReplicatedStorage.UIPreview = true, o escribiendo /ui en el chat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any

local FTUEController = require(script.Parent.FTUEController)
local ShopController = require(script.Parent.ShopController)
local Funnel = require(script.Parent.Parent.UI.Funnel)
local InventoryPanel = require(script.Parent.Parent.UI.InventoryPanel)
local Locale = require(script.Parent.Parent.UI.Locale)
local Menus = require(script.Parent.Parent.UI.Menus)
local Metrics = require(script.Parent.Parent.UI.Metrics)
local SettingsPanel = require(script.Parent.Parent.UI.SettingsPanel)
local Toast = require(script.Parent.Parent.UI.Toast)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local UIState = require(script.Parent.Parent.UI.UIState)

type Insets = { l: number, t: number, r: number, b: number }
type Device = { size: Vector2, insets: Insets }

local DEVICES: { [string]: Device } = {
	phone = { size = Vector2.new(844, 390), insets = { l = 36, t = 6, r = 20, b = 8 } },
	portrait = { size = Vector2.new(390, 844), insets = { l = 0, t = 47, r = 0, b = 34 } },
	tablet = { size = Vector2.new(1024, 768), insets = { l = 0, t = 0, r = 0, b = 0 } },
	desktop = { size = Vector2.new(1280, 720), insets = { l = 0, t = 0, r = 0, b = 0 } },
}

local SCREENS = {
	{ id = "hud", key = "preview.hud" },
	{ id = "carry", key = "preview.carry" },
	{ id = "inventory", key = "preview.inventory" },
	{ id = "dulceria", key = "shop.kiosk_dulceria" },
	{ id = "bates", key = "shop.kiosk_bates" },
	{ id = "cajas", key = "shop.kiosk_cajas" },
	{ id = "vip", key = "shop.kiosk_vip" },
	{ id = "settings", key = "preview.settings" },
	{ id = "toasts", key = "preview.toasts" },
	{ id = "ftue", key = "preview.ftue" },
}

local UIPreviewController = {}

local started = false
local open = false
local card: Frame
local funnelLabel: TextLabel
local lastChat = 0

local function pet(uid: string, pinataId: string, mutation: string, pedestal: number?): { [string]: any }
	return {
		uid = uid,
		pinataId = pinataId,
		mutation = mutation,
		pedestal = pedestal,
	}
end

local function copySettings(): { [string]: any }
	local current = UIState.get().settings
	if typeof(current) ~= "table" then
		return { locale = "", music = 0.8, sfx = 0.8, reduceMotion = false, cameraShake = true }
	end
	return {
		locale = if typeof(current.locale) == "string" then current.locale else "",
		music = if typeof(current.music) == "number" then current.music else 0.8,
		sfx = if typeof(current.sfx) == "number" then current.sfx else 0.8,
		reduceMotion = current.reduceMotion == true,
		cameraShake = current.cameraShake ~= false,
	}
end

local function blank(): { [string]: any }
	return {
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
		paidRandomRestricted = false,
		boxNext = nil,
		settings = copySettings(),
		ftueCompleted = false,
		multiplier = 1,
		batUpgrade = 0,
	}
end

local function album(): { any }
	return {
		pet("a", "michi", "Golden", 1),
		pet("b", "burrito", "None", 2),
		pet("c", "cohetin", "None", 3),
		pet("d", "dragon", "None", 4),
		pet("e", "toro", "Golden", nil),
		pet("f", "sombra", "None", nil),
		pet("g", "renito", "Christmas", nil),
		pet("h", "estrellita", "None", nil),
		pet("i", "burrito", "None", nil),
		pet("j", "burrito", "None", nil),
	}
end

local function showcase(kind: string): { [string]: any }
	local state = blank()
	state.candy = 1284
	state.candyPerSec = 12
	state.vaultStored = 80
	state.rookieShieldRemaining = 14 * 60 + 12
	state.fiestaRemaining = 4 * 60 + 59
	state.ftueCompleted = true
	state.owned = {
		pet("a", "michi", "Golden", 1),
		pet("b", "burrito", "None", 2),
	}
	state.nearbyLocks = {
		{ userId = 2, name = "Nube", remaining = 12, cooldown = 0 },
		{ userId = 3, name = "Sol", remaining = 0, cooldown = 40 },
	}
	if kind == "inventory" or kind == "cajas" or kind == "vip" then
		state.owned = album()
	end
	if kind == "carry" then
		state.carrying = { pinataId = "toro", mutation = "Golden", fromUserId = 1, hitsLeft = 2 }
	end
	if kind == "vip" then
		state.passes.doubleCandy = true
		state.multiplier = 2
	end
	return state
end

local function paintFunnel()
	if not funnelLabel then
		return
	end
	local lines = Funnel.history()
	if #lines == 0 then
		funnelLabel.Text = Locale.t("preview.analytics")
		return
	end
	funnelLabel.Text = table.concat(lines, "\n")
end

local function applyDevice(id: string)
	local device = DEVICES[id]
	if device == nil then
		UIRoot.setDevice(nil)
		Metrics.setOverride(nil, nil)
		return
	end
	UIRoot.setDevice(device.size)
	Metrics.setOverride(device.size, device.insets)
end

local function show(id: string)
	if id ~= "ftue" then
		FTUEController.stop()
	end
	Menus.closeAll()
	if id == "ftue" then
		UIState.replace(blank())
		FTUEController.play({ preview = true })
		return
	end
	UIState.replace(showcase(id))
	if id == "inventory" then
		InventoryPanel.open()
	elseif id == "settings" then
		SettingsPanel.open()
	elseif id == "dulceria" or id == "bates" or id == "cajas" or id == "vip" then
		ShopController.open(id)
	elseif id == "toasts" then
		Toast.push("good", Locale.t("toast.purchase"))
		Toast.push("bad", Locale.t("toast.robbed"))
		Toast.push("legend", Locale.t("toast.bonk"))
		Toast.push("announce", Locale.t("hud.fiesta_now"))
	end
end

local function chip(parent: Instance, text: string, color: Color3, order: number, onClick: () -> ())
	local wrap, _hit, caption = UIKit.button(parent, {
		name = "Chip" .. tostring(order),
		text = text,
		color = color,
		size = UDim2.new(1, 0, 0, 44),
		onClick = onClick,
	})
	wrap.LayoutOrder = order
	caption.TextSize = 16
end

local function setOpen(on: boolean)
	open = on
	card.Visible = on
end

local function onChat(text: string)
	if string.lower(text) ~= "/ui" then
		return
	end
	local now = os.clock()
	if now - lastChat < 0.4 then
		return
	end
	lastChat = now
	setOpen(not open)
end

function UIPreviewController.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "FiestaPreview"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 80
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggleWrap = UIKit.button(gui, {
		name = "PreviewToggle",
		key = "preview.title",
		color = Theme.color.grape,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -8, 0, 8),
		size = UDim2.fromOffset(120, 44),
		z = 5,
		onClick = function()
			setOpen(not open)
		end,
	})
	local toggleCaption = toggleWrap:FindFirstChild("Caption", true)
	if toggleCaption and toggleCaption:IsA("TextLabel") then
		toggleCaption.TextColor3 = Theme.color.white
		toggleCaption.TextStrokeColor3 = Theme.color.ink
		toggleCaption.TextStrokeTransparency = 0
	end

	card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -8, 0, 58)
	card.Size = UDim2.fromOffset(268, 560)
	card.BackgroundColor3 = Theme.color.white
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = gui
	UIKit.corner(card, 20)
	UIKit.stroke(card, Theme.color.white, 4)

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Theme.color.grape
	scroll.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local note = UIKit.label(scroll, Locale.t("preview.note"), "body", 13, Theme.color.ink_soft)
	note.LayoutOrder = 0
	note.Size = UDim2.new(1, 0, 0, 36)
	note.TextXAlignment = Enum.TextXAlignment.Left

	local deviceLabel = UIKit.label(scroll, Locale.t("preview.device"), "body", 14, Theme.color.ink)
	deviceLabel.LayoutOrder = 1
	deviceLabel.Size = UDim2.new(1, 0, 0, 18)
	deviceLabel.TextXAlignment = Enum.TextXAlignment.Left
	local deviceRow = Instance.new("Frame")
	deviceRow.BackgroundTransparency = 1
	deviceRow.Size = UDim2.new(1, 0, 0, 44)
	deviceRow.LayoutOrder = 2
	deviceRow.Parent = scroll
	local devices = {
		{ id = "auto", text = "Auto" },
		{ id = "phone", text = "Tel" },
		{ id = "portrait", text = "Vert" },
		{ id = "tablet", text = "Tab" },
		{ id = "desktop", text = "PC" },
	}
	for index, device in devices do
		local _wrap, _hit, caption = UIKit.button(deviceRow, {
			name = "Dev" .. device.id,
			text = device.text,
			color = Theme.color.cream,
			size = UDim2.fromOffset(44, 44),
			position = UDim2.fromOffset((index - 1) * 48, 0),
			onClick = function()
				applyDevice(device.id)
			end,
		})
		caption.TextSize = 13
	end

	local langRow = Instance.new("Frame")
	langRow.BackgroundTransparency = 1
	langRow.Size = UDim2.new(1, 0, 0, 44)
	langRow.LayoutOrder = 3
	langRow.Parent = scroll
	local langs = {
		{ id = "", label = "Auto" },
		{ id = "es", label = "ES" },
		{ id = "en", label = "EN" },
		{ id = "pt", label = "PT" },
	}
	for index, lang in langs do
		UIKit.button(langRow, {
			name = "Loc" .. lang.label,
			text = lang.label,
			color = Theme.color.sun_yellow,
			size = UDim2.fromOffset(48, 44),
			position = UDim2.fromOffset((index - 1) * 52, 0),
			onClick = function()
				UIState.mutate(function(s)
					local settings = copySettings()
					settings.locale = lang.id
					s.settings = settings
				end)
				Locale.setLocale(lang.id)
				SettingsPanel.refresh()
			end,
		})
	end

	for index, screen in SCREENS do
		chip(scroll, Locale.t(screen.key), Theme.color.fiesta_pink, 20 + index, function()
			show(screen.id)
		end)
	end
	chip(scroll, Locale.t("preview.stop"), Theme.color.cream, 30, function()
		FTUEController.stop()
		Menus.closeAll()
	end)

	funnelLabel = UIKit.label(scroll, Locale.t("preview.analytics"), "body", 13, Theme.color.ink)
	funnelLabel.LayoutOrder = 40
	funnelLabel.Size = UDim2.new(1, 0, 0, 120)
	funnelLabel.TextXAlignment = Enum.TextXAlignment.Left
	funnelLabel.TextYAlignment = Enum.TextYAlignment.Top
	Funnel.onLogged(function()
		paintFunnel()
	end)
	Locale.onChange(function()
		note.Text = Locale.t("preview.note")
		paintFunnel()
	end)

	player.Chatted:Connect(onChat)
	local ok, err = pcall(function()
		TextChatService.MessageReceived:Connect(function(message)
			local source = message.TextSource
			if source and source.UserId == player.UserId then
				onChat(message.Text)
			end
		end)
	end)
	if not ok then
		warn("[UI] chat preview " .. tostring(err))
	end
end

return UIPreviewController
