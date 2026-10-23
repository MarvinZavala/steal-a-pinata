--!strict
-- Panel de la Fiesta (WP-14). El reloj y el premio los manda el servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any

local Locale = require(script.Parent.Locale)
local Menus = require(script.Parent.Menus)
local UIKit = require(script.Parent.UIKit)
local UIRoot = require(script.Parent.UIRoot)
local UIState = require(script.Parent.UIState)

local root: Frame
local title: TextLabel
local detail: TextLabel
local hits: TextLabel

local FiestaPanel = {}

local function paint()
	if title == nil then
		return
	end
	local state = UIState.get()
	local phase = if typeof(state.fiestaPhase) == "string" then state.fiestaPhase else "idle"
	local variant = if typeof(state.fiestaVariant) == "string" then state.fiestaVariant else "fiesta"
	local left = if typeof(state.fiestaLeft) == "number" then state.fiestaLeft else 0
	local waitSec = if typeof(state.fiestaRemaining) == "number" then state.fiestaRemaining else -1
	local nowKey = "hud.fiesta_now"
	local waitKey = "fiesta.title"
	local rainKey = "fiesta.rain"
	local giantKey = "fiesta.giant"
	if variant == "posada" then
		nowKey = "event.hud_posada"
		waitKey = "event.posada_title"
		rainKey = "event.posada_rain"
		giantKey = "event.posada_giant"
	elseif variant == "newyear" then
		nowKey = "event.hud_newyear"
		waitKey = "event.newyear_title"
		rainKey = "event.newyear_rain"
		giantKey = "event.posada_giant"
	elseif variant == "rosca" then
		nowKey = "event.hud_rosca"
		waitKey = "event.rosca_title"
		rainKey = "event.rosca_rain"
		giantKey = "event.rosca_giant"
	end
	if phase == "giant" then
		title.Text = Locale.t(giantKey)
		local hp = if typeof(state.giantHp) == "number" then state.giantHp else 0
		local maxHp = if typeof(state.giantMax) == "number" then state.giantMax else 0
		detail.Text = Locale.t("fiesta.hp", { hp = tostring(hp), max = tostring(maxHp), time = UIKit.clock(left) })
	elseif phase == "rain" then
		title.Text = Locale.t(nowKey)
		detail.Text = Locale.t(rainKey, { time = UIKit.clock(left) })
	else
		title.Text = Locale.t(waitKey)
		local shown = if waitSec >= 0 then waitSec else 0
		detail.Text = Locale.t("fiesta.wait", { time = UIKit.clock(shown) })
	end
	local mine = if typeof(state.myFiestaHits) == "number" then state.myFiestaHits else 0
	hits.Text = Locale.t("fiesta.hits", { n = tostring(mine) })
end

function FiestaPanel.close()
	if root ~= nil then
		root.Visible = false
	end
	Menus.closed("fiesta")
end

function FiestaPanel.open()
	Menus.opening("fiesta")
	root.Visible = true
	paint()
end

function FiestaPanel.toggle()
	if root ~= nil and root.Visible then
		FiestaPanel.close()
	else
		FiestaPanel.open()
	end
end

function FiestaPanel.start()
	root = Instance.new("Frame")
	root.Name = "Fiesta"
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
		FiestaPanel.close()
	end)

	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.color.white
	card.BorderSizePixel = 0
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(360, 280)
	card.Parent = root
	UIKit.corner(card, 22)
	UIKit.stroke(card, Theme.color.white, 4)

	title = UIKit.label(card, "", "display", 28, Theme.color.fiesta_pink)
	title.Position = UDim2.fromOffset(16, 16)
	title.Size = UDim2.new(1, -120, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextStrokeColor3 = Theme.color.ink
	title.TextStrokeTransparency = 0

	UIKit.button(card, {
		name = "Close",
		key = "common.close",
		color = Theme.color.fiesta_pink,
		size = UDim2.fromOffset(96, 48),
		position = UDim2.new(1, -12, 0, 12),
		anchor = Vector2.new(1, 0),
		onClick = function()
			FiestaPanel.close()
		end,
	})

	detail = UIKit.label(card, "", "body", 18, Theme.color.ink)
	detail.Position = UDim2.fromOffset(16, 80)
	detail.Size = UDim2.new(1, -32, 0, 72)
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextWrapped = true

	hits = UIKit.label(card, "", "display", 22, Theme.color.ink)
	hits.Position = UDim2.fromOffset(16, 160)
	hits.Size = UDim2.new(1, -32, 0, 32)
	hits.TextXAlignment = Enum.TextXAlignment.Left

	local blurb = UIKit.label(card, Locale.t("fiesta.body"), "body", 16, Theme.color.ink_soft)
	blurb.Position = UDim2.fromOffset(16, 200)
	blurb.Size = UDim2.new(1, -32, 0, 60)
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextWrapped = true

	Menus.register("fiesta", FiestaPanel.close)
	UIState.onChange(function()
		if root.Visible then
			paint()
		end
	end)
end

return FiestaPanel
