--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local Locale = require(script.Parent.Locale)
local Menus = require(script.Parent.Menus)
local Metrics = require(script.Parent.Metrics)
local SoundBus = require(script.Parent.SoundBus)
local Toast = require(script.Parent.Toast)
local UIBridge = require(script.Parent.UIBridge)
local UIKit = require(script.Parent.UIKit)
local UIRoot = require(script.Parent.UIRoot)
local UIState = require(script.Parent.UIState)

local root: Frame
local panel: Frame
local rows: Frame
local lastToast = 0

local SettingsPanel = {}

local function settings(): { [string]: any }
	local s = UIState.get().settings
	if typeof(s) == "table" then
		return s
	end
	return {}
end

local function apply(nextSettings: { [string]: any })
	UIState.mutate(function(s)
		s.settings = nextSettings
	end)
	if typeof(nextSettings.locale) == "string" then
		Locale.setLocale(nextSettings.locale)
	end
	local music = if typeof(nextSettings.music) == "number" then nextSettings.music else 0.8
	local sfx = if typeof(nextSettings.sfx) == "number" then nextSettings.sfx else 0.8
	SoundBus.setVolumes(music, sfx)
	UIKit.setMotion(if nextSettings.reduceMotion == true then 0 else 1)
	UIBridge.pushSettings()
	local now = os.clock()
	if now - lastToast > 1.1 then
		lastToast = now
		Toast.push("info", Locale.t("toast.saved"))
	end
end

local function copy(): { [string]: any }
	local current = settings()
	return {
		locale = if typeof(current.locale) == "string" then current.locale else "",
		music = if typeof(current.music) == "number" then current.music else 0.8,
		sfx = if typeof(current.sfx) == "number" then current.sfx else 0.8,
		reduceMotion = current.reduceMotion == true,
		cameraShake = current.cameraShake ~= false,
	}
end

local function stepVolume(field: string, delta: number)
	local nextSettings = copy()
	local value = if typeof(nextSettings[field]) == "number" then nextSettings[field] else 0.8
	nextSettings[field] = math.clamp(math.floor((value + delta) * 4 + 0.5) / 4, 0, 1)
	apply(nextSettings)
	SettingsPanel.refresh()
end

local function addRow(order: number, text: string): Frame
	local m = Metrics.get()
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, m.button + 8)
	row.LayoutOrder = order
	row.Parent = rows
	local label = UIKit.label(row, text, "body", m.body, Theme.color.ink)
	label.Size = UDim2.new(0.42, 0, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	return row
end

function SettingsPanel.refresh()
	if not rows then
		return
	end
	for _, child in rows:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local m = Metrics.get()
	local current = copy()
	local lang = addRow(1, Locale.t("settings.language"))
	local options = {
		{ id = "", label = Locale.t("settings.auto") },
		{ id = "es", label = "ES" },
		{ id = "en", label = "EN" },
		{ id = "pt", label = "PT" },
	}
	local slot = 48
	local gap = 6
	local count = #options
	local langLabel = lang:FindFirstChildWhichIsA("TextLabel")
	if langLabel then
		langLabel.Size = UDim2.new(1, -(count * (slot + gap) + 4), 1, 0)
	end
	for index, option in options do
		local selected = current.locale == option.id
		local _wrap, _hit, caption = UIKit.button(lang, {
			name = "Lang" .. option.id,
			text = option.label,
			color = if selected then Theme.color.fiesta_pink else Theme.color.cream,
			size = UDim2.fromOffset(slot, m.button - 4),
			position = UDim2.new(1, -((count - index) * (slot + gap) + slot), 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			onClick = function()
				local nextSettings = copy()
				nextSettings.locale = option.id
				apply(nextSettings)
				SettingsPanel.refresh()
			end,
		})
		caption.TextSize = m.small
	end

	local function volumeRow(order: number, key: string, field: string)
		local row = addRow(order, Locale.t(key))
		local value = if typeof(current[field]) == "number" then current[field] else 0
		UIKit.button(row, {
			name = field .. "Minus",
			text = "−",
			color = Theme.color.cream,
			size = UDim2.fromOffset(m.button, m.button - 4),
			position = UDim2.new(0.46, 0, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			onClick = function()
				stepVolume(field, -0.25)
			end,
		})
		local readout = UIKit.label(row, tostring(math.floor(value * 100)) .. "%", "number", m.body, Theme.color.ink)
		readout.Position = UDim2.new(0.46, m.button + 4, 0, 0)
		readout.Size = UDim2.fromOffset(64, m.button)
		UIKit.button(row, {
			name = field .. "Plus",
			text = "+",
			color = Theme.color.lime,
			size = UDim2.fromOffset(m.button, m.button - 4),
			position = UDim2.new(0.46, m.button + 72, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			onClick = function()
				stepVolume(field, 0.25)
			end,
		})
	end
	volumeRow(2, "settings.music", "music")
	volumeRow(3, "settings.sfx", "sfx")

	local function toggleRow(order: number, key: string, field: string)
		local row = addRow(order, Locale.t(key))
		local on = current[field] == true
		UIKit.button(row, {
			name = field,
			text = if on then Locale.t("settings.on") else Locale.t("settings.off"),
			color = if on then Theme.color.turquoise else Theme.color.cream,
			size = UDim2.fromOffset(m.button * 1.4, m.button - 4),
			position = UDim2.new(1, 0, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			onClick = function()
				local nextSettings = copy()
				nextSettings[field] = not on
				apply(nextSettings)
				SettingsPanel.refresh()
			end,
		})
	end
	toggleRow(4, "settings.motion", "reduceMotion")
	toggleRow(5, "settings.shake", "cameraShake")

	local hints = UIKit.label(rows, Locale.t("settings.hints"), "body", m.small, Theme.color.ink_soft)
	hints.LayoutOrder = 6
	hints.Size = UDim2.new(1, 0, 0, m.body * 2 + 8)
	hints.TextXAlignment = Enum.TextXAlignment.Left
	local pad = UIKit.label(rows, Locale.t("settings.pad"), "body", m.small, Theme.color.ink_soft)
	pad.LayoutOrder = 7
	pad.Size = UDim2.new(1, 0, 0, m.body * 2 + 8)
	pad.TextXAlignment = Enum.TextXAlignment.Left
end

function SettingsPanel.mount()
	root = Instance.new("Frame")
	root.Name = "Settings"
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
	blocker.Modal = true
	blocker.Parent = root
	blocker.Activated:Connect(function()
		SettingsPanel.close()
	end)

	panel = Instance.new("Frame")
	panel.Name = "Card"
	panel.BackgroundColor3 = Theme.color.white
	panel.BorderSizePixel = 0
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.ZIndex = 2
	panel.Parent = root
	UIKit.corner(panel, 22)
	UIKit.stroke(panel, Theme.color.white, 4)

	local title = UIKit.label(panel, "", "display", 28, Theme.color.ink)
	title.Name = "Title"
	title.Size = UDim2.new(1, -130, 0, 40)
	title.Position = UDim2.fromOffset(16, 8)
	title.TextXAlignment = Enum.TextXAlignment.Left
	Locale.bind(title, "settings.title")
	UIKit.button(panel, {
		name = "CloseSettings",
		key = "common.close",
		color = Theme.color.cream,
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, -10, 0, 10),
		size = UDim2.fromOffset(96, 44),
		onClick = function()
			SettingsPanel.close()
		end,
	})

	rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Position = UDim2.fromOffset(16, 60)
	rows.Size = UDim2.new(1, -32, 1, -72)
	rows.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rows

	Menus.register("settings", SettingsPanel.close)
	Metrics.onChange(function(m)
		panel.Size = UDim2.fromOffset(math.min(560, m.w - m.margin * 2), math.min(520, m.h - m.margin * 2))
		if root.Visible then
			SettingsPanel.refresh()
		end
	end)
end

function SettingsPanel.open()
	Menus.opening("settings")
	root.Visible = true
	SettingsPanel.refresh()
	local closeHit = panel:FindFirstChild("CloseSettings", true)
	if closeHit and closeHit:IsA("GuiObject") then
		GuiService.SelectedObject = closeHit
	end
end

function SettingsPanel.close()
	if root and root.Visible then
		root.Visible = false
	end
	Menus.closed("settings")
end

function SettingsPanel.toggle()
	if root.Visible then
		SettingsPanel.close()
	else
		SettingsPanel.open()
	end
end

return SettingsPanel
