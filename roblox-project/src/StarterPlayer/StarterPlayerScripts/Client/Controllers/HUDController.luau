--!strict
-- HUD móvil: Dulces con salto, Piñatitos, robo, candados cercanos, bate y candado.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy")) :: any
local Pinatas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Pinatas")) :: any
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format")) :: any

local Intent = require(script.Parent.Parent.UI.Intent)
local InventoryPanel = require(script.Parent.Parent.UI.InventoryPanel)
local Locale = require(script.Parent.Parent.UI.Locale)
local Menus = require(script.Parent.Parent.UI.Menus)
local Metrics = require(script.Parent.Parent.UI.Metrics)
local SettingsPanel = require(script.Parent.Parent.UI.SettingsPanel)
local SoundBus = require(script.Parent.Parent.UI.SoundBus)
local UIBridge = require(script.Parent.Parent.UI.UIBridge)
local UIGuide = require(script.Parent.Parent.UI.UIGuide)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local UIState = require(script.Parent.Parent.UI.UIState)

local ShopController = require(script.Parent.ShopController) :: any

local actionsVisible = true
local candyTarget = 0
local rateTarget = -1
local batReadyAt = 0
local candyValue: NumberValue
local numberLabel: TextLabel
local rateLabel: TextLabel
local rateScale: UIScale
local numberScale: UIScale
local candyWrap: Frame
local vaultFill: Frame
local fiestaLabel: TextLabel
local shieldLabel: TextLabel
local fiestaWrap: Frame
local shieldWrap: Frame
local badge: TextLabel
local carryWrap: Frame
local carryLabel: TextLabel
local collectWrap: Frame
local collectLabel: TextLabel
local batWrap: Frame
local lockWrap: Frame
local lockOverlay: Frame
local invWrap: Frame
local shopWrap: Frame
local settingsWrap: Frame
local multLabel: TextLabel
local lockList: Frame
local lockSig = ""

local HUDController = {}

local function num(value: any, fallback: number): number
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function floater(text: string)
	local label = UIKit.label(candyWrap, text, "number", Metrics.get().body, Theme.color.lime)
	Theme.outlineNumber(label)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.75, 0, 0.2, 0)
	label.Size = UDim2.fromOffset(140, 28)
	label.ZIndex = 8
	UIKit.tween(label, 0.65, { Position = UDim2.new(0.75, 0, 0, -24), TextTransparency = 1 })
	task.delay(0.7, function()
		label:Destroy()
	end)
end

local function pulse(scale: UIScale)
	if UIKit.motion() <= 0 then
		scale.Scale = 1
		return
	end
	local up = UIKit.tween(scale, 0.12, { Scale = 1.25 }, Enum.EasingStyle.Back)
	if up then
		up.Completed:Connect(function()
			UIKit.tween(scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Quad)
		end)
	end
end

local function swing()
	if Intent.try("bat") then
		return
	end
	if os.clock() < batReadyAt then
		return
	end
	batReadyAt = os.clock() + Economy.Bat.CooldownSec
	UIBridge.swing()
	SoundBus.play("bonk")
	pulse(numberScale)
end

local function lockDoor()
	local s = UIState.get()
	if not UIBridge.isAuthoritative() then
		if num(s.myLockRemaining, 0) > 0 then
			return
		end
		if num(s.myLockCooldown, 0) > 0 then
			UIState.pushFeedback("DENIED", { key = "cooldown" })
			return
		end
		local bonus = 0
		if typeof(s.passes) == "table" and s.passes.vip == true then
			bonus = Economy.Lock.VipBonusSec
		end
		UIState.mutate(function(st)
			st.myLockRemaining = Economy.Lock.DurationSec + bonus
			st.myLockCooldown = Economy.Lock.CooldownSec
		end)
	end
	UIBridge.lock()
	SoundBus.play("pop")
end

local function collect()
	if Intent.try("collect") then
		return
	end
	local stored = num(UIState.get().vaultStored, 0)
	UIBridge.collect()
	if not UIBridge.isAuthoritative() and stored > 0 then
		UIState.mutate(function(st)
			st.candy = num(st.candy, 0) + stored
			st.vaultStored = 0
		end)
		UIState.pushFeedback("COLLECT", { amount = stored })
		SoundBus.play("candy")
	end
end

local function layout(m: any)
	local left = m.safeLeft + m.margin
	local right = m.safeRight + m.margin
	local top = m.safeTop + m.margin
	local bottom = m.safeBottom + m.margin
	local candyWidth = if m.compact then m.w - left - right - m.button - 10 else math.min(320, math.floor(m.w * 0.36))

	candyWrap.Position = UDim2.fromOffset(left, top)
	candyWrap.Size = UDim2.fromOffset(math.max(160, candyWidth), m.candyH)
	numberLabel.TextSize = m.num
	rateLabel.TextSize = m.small

	settingsWrap.AnchorPoint = Vector2.new(1, 0)
	settingsWrap.Position = UDim2.new(1, -right, 0, top)
	settingsWrap.Size = UDim2.fromOffset(m.button, m.button)

	local chipW = if m.compact then 158 else 176
	if m.compact then
		fiestaWrap.AnchorPoint = Vector2.zero
		fiestaWrap.Position = UDim2.fromOffset(left, top + m.candyH + 6)
		shieldWrap.AnchorPoint = Vector2.zero
		shieldWrap.Position = UDim2.fromOffset(left + chipW + 8, top + m.candyH + 6)
	else
		fiestaWrap.AnchorPoint = Vector2.new(1, 0)
		fiestaWrap.Position = UDim2.new(1, -(right + m.button + 8), 0, top)
		shieldWrap.AnchorPoint = Vector2.new(1, 0)
		shieldWrap.Position = UDim2.new(1, -(right + m.button + chipW + 16), 0, top)
	end
	fiestaWrap.Size = UDim2.fromOffset(chipW, m.chip)
	shieldWrap.Size = UDim2.fromOffset(chipW, m.chip)
	fiestaLabel.TextSize = m.small
	shieldLabel.TextSize = m.small

	badge.Position = UDim2.fromOffset(left, top + m.candyH - 4)
	badge.TextSize = m.small

	local bat = math.floor(m.button * 1.22)
	batWrap.AnchorPoint = Vector2.new(1, 1)
	batWrap.Position = UDim2.new(1, -right, 1, -bottom)
	batWrap.Size = UDim2.fromOffset(bat, bat)
	lockWrap.AnchorPoint = Vector2.new(1, 1)
	lockWrap.Position = UDim2.new(1, -right, 1, -(bottom + bat + 8))
	lockWrap.Size = UDim2.fromOffset(m.button, m.button)

	local sideW = math.max(108, m.button + 36)
	invWrap.AnchorPoint = Vector2.new(0, 1)
	invWrap.Position = UDim2.new(0, left, 1, -bottom)
	invWrap.Size = UDim2.fromOffset(sideW, m.button)
	shopWrap.AnchorPoint = Vector2.new(0, 1)
	shopWrap.Position = UDim2.new(0, left + sideW + 8, 1, -bottom)
	shopWrap.Size = UDim2.fromOffset(sideW, m.button)

	collectWrap.AnchorPoint = Vector2.new(0, 1)
	collectWrap.Position = UDim2.new(0, left, 1, -(bottom + m.button + 8))
	collectWrap.Size = UDim2.fromOffset(sideW * 2 + 8, m.button)

	carryWrap.AnchorPoint = Vector2.new(0.5, 1)
	carryWrap.Position = UDim2.new(0.5, 0, 1, -(bottom + bat + 12))
	local carryW = m.w - left - right - sideW * 2 - bat - 36
	if carryW < 180 then
		local chipBottom = if m.compact then top + m.candyH + m.chip + 12 else top + m.candyH + 8
		carryWrap.AnchorPoint = Vector2.new(0, 0)
		carryWrap.Position = UDim2.fromOffset(left, chipBottom)
		carryWrap.Size = UDim2.fromOffset(m.w - left - right, m.chip + 6)
	else
		carryWrap.Size = UDim2.fromOffset(carryW, m.chip + 8)
	end

	lockList.Position = UDim2.fromOffset(left, if m.compact then top + m.candyH + m.chip + 8 else top + m.candyH + 8)
	lockList.Size = UDim2.fromOffset(180, m.chip * 3)

	batWrap.Visible = actionsVisible
	lockWrap.Visible = actionsVisible
	invWrap.Visible = actionsVisible
	shopWrap.Visible = actionsVisible
end

local function paintLocks(s: { [string]: any })
	local locks = if typeof(s.nearbyLocks) == "table" then s.nearbyLocks else {}
	local parts = {}
	for _, item in locks do
		if typeof(item) == "table" then
			table.insert(parts, tostring(item.userId) .. ":" .. tostring(item.remaining))
		end
	end
	local sig = table.concat(parts, "|")
	if sig == lockSig then
		return
	end
	lockSig = sig
	for _, child in lockList:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local shown = 0
	for _, item in locks do
		if typeof(item) == "table" and shown < 3 then
			shown += 1
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 28)
			row.Parent = lockList
			local ring = Instance.new("Frame")
			ring.Size = UDim2.fromOffset(22, 22)
			ring.Position = UDim2.fromOffset(0, 3)
			ring.BackgroundTransparency = 1
			ring.Parent = row
			UIKit.corner(ring, nil)
			local active = num(item.remaining, 0) > 0
			UIKit.stroke(ring, if active then Theme.color.turquoise else Theme.color.ink_soft, 3)
			local label = UIKit.label(row, "", "body", 14, Theme.color.ink)
			label.Position = UDim2.fromOffset(28, 0)
			label.Size = UDim2.new(1, -28, 1, 0)
			label.TextXAlignment = Enum.TextXAlignment.Left
			local timeText = if active then UIKit.clock(num(item.remaining, 0)) else UIKit.clock(num(item.cooldown, 0))
			label.Text = tostring(item.name) .. " " .. timeText
		end
	end
	lockList.Visible = shown > 0 and not carryWrap.Visible
end

local function refresh()
	local s = UIState.get()
	local candy = num(s.candy, 0)
	if candy ~= candyTarget then
		local delta = candy - candyTarget
		candyTarget = candy
		UIKit.tween(candyValue, 0.35, { Value = candy }, Enum.EasingStyle.Quad)
		if delta > 0.5 then
			floater("+" .. Format(delta))
			pulse(numberScale)
			SoundBus.play("candy")
		end
	end
	local rate = num(s.candyPerSec, 0)
	rateLabel.Text = Locale.t("hud.per_sec", { n = Format(rate) })
	if rate ~= rateTarget then
		rateTarget = rate
		pulse(rateScale)
	end
	local mult = num(s.multiplier, 1)
	multLabel.Visible = mult > 1.01
	multLabel.Text = Locale.t("hud.multiplier", { n = string.format("%.1f", mult) })

	local tiers = Economy.VaultCapSeconds
	local tier = math.clamp(num(s.vaultTier, 1), 1, #tiers)
	local cap = math.max(1, rate * tiers[tier])
	local stored = num(s.vaultStored, 0)
	vaultFill.Size = UDim2.new(math.clamp(stored / cap, 0, 1), 0, 1, 0)
	-- En la plaza el pad amarillo es el único cobro. El botón queda para el teatro offline.
	collectWrap.Visible = stored >= 1 and not UIBridge.isAuthoritative()
	collectLabel.Text = Locale.t("hud.collect") .. " " .. Format(stored)

	local fiesta = num(s.fiestaRemaining, -1)
	fiestaWrap.Visible = fiesta >= 0
	fiestaLabel.Text = if fiesta <= 0
		then Locale.t("hud.fiesta_now")
		else Locale.t("hud.fiesta_in", { time = UIKit.clock(fiesta) })
	local shield = num(s.rookieShieldRemaining, 0)
	shieldWrap.Visible = shield > 0
	shieldLabel.Text = Locale.t("hud.shield", { time = UIKit.clock(shield) })
	badge.Visible = RunService:IsStudio() and not UIBridge.isAuthoritative()
	badge.Text = Locale.t("hud.local_badge")

	local carry = s.carrying
	carryWrap.Visible = typeof(carry) == "table"
	if typeof(carry) == "table" and typeof(carry.pinataId) == "string" then
		local mutation = Locale.mutationName(if typeof(carry.mutation) == "string" then carry.mutation else "None")
		local name = Locale.pinataName(carry.pinataId)
		if mutation ~= "" then
			name ..= " " .. mutation
		end
		carryLabel.Text = Locale.t("hud.carry") .. " " .. name .. "  " .. Locale.t("hud.carry_hint")
		local def = Pinatas[carry.pinataId]
		local rarity = if typeof(def) == "table" and typeof(def.Rarity) == "string" then def.Rarity else "Common"
		local style = Theme.rarity(rarity)
		local face = carryWrap:FindFirstChild("Face")
		if face and face:IsA("GuiObject") then
			face.BackgroundColor3 = style.plate
			UIKit.stroke(face, style.color, 4)
		end
		carryLabel.Text ..= "  " .. Locale.t("hud.hits", { n = tostring(num(carry.hitsLeft, 1)) })
	end

	local cooling = num(s.myLockCooldown, 0)
	local active = num(s.myLockRemaining, 0)
	if active <= 0 and cooling > 0 then
		lockOverlay.Size = UDim2.new(1, 0, math.clamp(cooling / Economy.Lock.CooldownSec, 0, 1), 0)
	else
		lockOverlay.Size = UDim2.fromScale(1, 0)
	end
	paintLocks(s)
end

local function cornerHint(parent: TextButton, text: string, keyCode: Enum.KeyCode): ImageLabel
	local hint = UIKit.label(parent, text, "body", 12, Theme.color.ink)
	hint.Name = "KeyHint"
	hint.AnchorPoint = Vector2.new(1, 1)
	hint.Position = UDim2.new(1, -4, 1, -2)
	hint.Size = UDim2.fromOffset(22, 16)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(1, 0)
	glyph.Position = UDim2.new(1, -4, 0, 4)
	glyph.Size = UDim2.fromOffset(22, 22)
	glyph.ScaleType = Enum.ScaleType.Fit
	glyph.Image = UserInputService:GetImageForKeyCode(keyCode)
	glyph.Visible = false
	glyph.ZIndex = 5
	glyph.Parent = parent
	return glyph
end

function HUDController.setActionsVisible(on: boolean)
	actionsVisible = on
	layout(Metrics.get())
end

function HUDController.start()
	local layer = UIRoot.layer("Hud")
	InventoryPanel.mount()
	SettingsPanel.mount()

	local _candyRoot, candyFace = UIKit.button(layer, {
		name = "Candy",
		color = Theme.color.sun_yellow,
		size = UDim2.fromOffset(240, 72),
	})
	candyWrap = _candyRoot
	candyFace.Active = false
	candyFace.Selectable = false
	candyFace.AutoButtonColor = false
	numberLabel = UIKit.label(candyFace, "0", "number", 40, Theme.color.white)
	Theme.outlineNumber(numberLabel)
	numberLabel.Size = UDim2.new(1, -16, 0.62, 0)
	numberLabel.Position = UDim2.fromOffset(8, 2)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Left
	numberScale = Instance.new("UIScale")
	numberScale.Parent = numberLabel
	rateLabel = UIKit.label(candyFace, "+0/s", "body", 16, Theme.color.ink)
	rateLabel.Size = UDim2.new(0.55, 0, 0.32, 0)
	rateLabel.Position = UDim2.new(0, 10, 1, -4)
	rateLabel.AnchorPoint = Vector2.new(0, 1)
	rateLabel.TextXAlignment = Enum.TextXAlignment.Left
	rateScale = Instance.new("UIScale")
	rateScale.Parent = rateLabel
	multLabel = UIKit.label(candyFace, "", "body", 14, Theme.color.hot_magenta)
	multLabel.Size = UDim2.fromOffset(64, 18)
	multLabel.Position = UDim2.new(1, -8, 1, -4)
	multLabel.AnchorPoint = Vector2.new(1, 1)
	multLabel.TextXAlignment = Enum.TextXAlignment.Right
	multLabel.Visible = false
	local vaultBg = Instance.new("Frame")
	vaultBg.Name = "Vault"
	vaultBg.BackgroundColor3 = Theme.color.cream
	vaultBg.BorderSizePixel = 0
	vaultBg.AnchorPoint = Vector2.new(0, 1)
	vaultBg.Position = UDim2.new(0, 8, 1, -6)
	vaultBg.Size = UDim2.new(0.46, 0, 0, 6)
	vaultBg.ZIndex = 3
	vaultBg.Parent = candyFace
	UIKit.corner(vaultBg, 3)
	vaultFill = Instance.new("Frame")
	vaultFill.BackgroundColor3 = Theme.color.lime
	vaultFill.BorderSizePixel = 0
	vaultFill.Size = UDim2.fromScale(0, 1)
	vaultFill.Parent = vaultBg
	UIKit.corner(vaultFill, 3)
	-- La barra pisa el rate. Subo el rate a la derecha del número.
	rateLabel.Position = UDim2.new(1, -8, 0, 6)
	rateLabel.AnchorPoint = Vector2.new(1, 0)
	rateLabel.Size = UDim2.fromOffset(90, 22)
	rateLabel.TextXAlignment = Enum.TextXAlignment.Right

	candyValue = Instance.new("NumberValue")
	candyValue.Value = 0
	candyValue.Parent = numberLabel
	candyValue.Changed:Connect(function(value)
		numberLabel.Text = Format(math.floor(value + 0.5))
	end)

	local function chip(name: string, color: Color3): (Frame, TextLabel)
		local wrap, face, caption =
			UIKit.button(layer, { name = name, color = color, size = UDim2.fromOffset(160, 40) })
		face.Active = false
		face.Selectable = false
		caption.TextSize = 16
		return wrap, caption
	end
	fiestaWrap, fiestaLabel = chip("Fiesta", Theme.color.hot_magenta)
	Theme.apply(fiestaLabel, "display", Theme.color.white)
	fiestaLabel.TextStrokeColor3 = Theme.color.ink
	fiestaLabel.TextStrokeTransparency = 0
	shieldWrap, shieldLabel = chip("Shield", Theme.color.bubblegum)
	fiestaWrap.Visible = false
	shieldWrap.Visible = false

	badge = UIKit.label(layer, "", "body", 14, Theme.color.ink_soft)
	badge.BackgroundTransparency = 1
	badge.Size = UDim2.fromOffset(140, 18)
	badge.TextXAlignment = Enum.TextXAlignment.Left
	badge.Visible = false

	settingsWrap = UIKit.button(layer, {
		name = "Settings",
		key = "hud.settings",
		color = Theme.color.cream,
		onClick = function()
			SettingsPanel.toggle()
		end,
	})
	invWrap = UIKit.button(layer, {
		name = "Inventory",
		key = "hud.inventory",
		color = Theme.color.mango,
		onClick = function()
			InventoryPanel.toggle()
		end,
	})
	shopWrap = UIKit.button(layer, {
		name = "Shop",
		key = "hud.shop",
		color = Theme.color.grape,
		onClick = function()
			ShopController.open("picker")
		end,
	})
	local shopCaption = shopWrap:FindFirstChild("Shop", true)
	if shopCaption and shopCaption:IsA("TextButton") then
		local caption = shopCaption:FindFirstChild("Caption")
		if caption and caption:IsA("TextLabel") then
			Theme.apply(caption, "display", Theme.color.white)
			caption.TextStrokeTransparency = 0
			caption.TextStrokeColor3 = Theme.color.ink
		end
	end

	collectWrap = UIKit.button(layer, {
		name = "Collect",
		color = Theme.color.lime,
		onClick = collect,
	})
	collectLabel = collectWrap:FindFirstChild("Caption", true) :: TextLabel
	collectWrap.Visible = false

	batWrap = UIKit.button(layer, {
		name = "Bat",
		key = "hud.bat",
		color = Theme.color.fiesta_pink,
		onClick = swing,
	})
	lockWrap = UIKit.button(layer, {
		name = "Lock",
		key = "hud.lock",
		color = Theme.color.turquoise,
		onClick = lockDoor,
	})
	local lockFace = lockWrap:FindFirstChild("Lock") :: TextButton
	lockOverlay = Instance.new("Frame")
	lockOverlay.Name = "Cooldown"
	lockOverlay.BackgroundColor3 = Theme.color.ink
	lockOverlay.BackgroundTransparency = 0.45
	lockOverlay.BorderSizePixel = 0
	lockOverlay.AnchorPoint = Vector2.new(0, 1)
	lockOverlay.Position = UDim2.fromScale(0, 1)
	lockOverlay.Size = UDim2.fromScale(1, 0)
	lockOverlay.ZIndex = 4
	lockOverlay.Active = false
	lockOverlay.Parent = lockFace

	local batFace = batWrap:FindFirstChild("Bat") :: TextButton
	cornerHint(batFace, "E", Enum.KeyCode.ButtonR2)
	cornerHint(lockFace, "Q", Enum.KeyCode.ButtonL1)

	carryWrap = Instance.new("Frame")
	carryWrap.Name = "Carry"
	carryWrap.BackgroundColor3 = Theme.color.chili
	carryWrap.BorderSizePixel = 0
	carryWrap.Visible = false
	carryWrap.ZIndex = 5
	carryWrap.Parent = layer
	UIKit.corner(carryWrap, 18)
	UIKit.stroke(carryWrap, Theme.color.white, 4)
	local carryFace = Instance.new("Frame")
	carryFace.Name = "Face"
	carryFace.BackgroundColor3 = Theme.color.gold
	carryFace.BorderSizePixel = 0
	carryFace.Size = UDim2.fromScale(1, 1)
	carryFace.Parent = carryWrap
	UIKit.corner(carryFace, 18)
	carryLabel = UIKit.label(carryFace, "", "body", 16, Theme.color.white)
	carryLabel.TextStrokeColor3 = Theme.color.ink
	carryLabel.TextStrokeTransparency = 0
	carryLabel.Size = UDim2.new(1, -16, 1, -8)
	carryLabel.Position = UDim2.fromOffset(8, 4)

	lockList = Instance.new("Frame")
	lockList.BackgroundTransparency = 1
	lockList.Visible = false
	lockList.Parent = layer
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.Parent = lockList

	local invHit = invWrap:FindFirstChild("Inventory") :: GuiObject
	local shopHit = shopWrap:FindFirstChild("Shop") :: GuiObject
	local batHit = batFace :: GuiObject
	local collectHit = collectWrap:FindFirstChild("Collect") :: GuiObject
	UIGuide.register("inventory", invHit)
	UIGuide.register("shop", shopHit)
	UIGuide.register("bat", batHit)
	UIGuide.register("collect", collectHit)
	UIGuide.register("lock", lockFace)

	Metrics.onChange(layout)
	UIState.onChange(function()
		refresh()
	end)
	Locale.onChange(refresh)
	layout(Metrics.get())
	refresh()

	local high = Enum.ContextActionPriority.High.Value
	local mid = Enum.ContextActionPriority.Medium.Value
	local function handle(action: string, state: Enum.UserInputState, _input: InputObject)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if action == "FiestaClose" then
			if Menus.current() then
				Menus.closeAll()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		elseif action == "FiestaBag" then
			InventoryPanel.toggle()
			return Enum.ContextActionResult.Sink
		elseif action == "FiestaSettings" then
			SettingsPanel.toggle()
			return Enum.ContextActionResult.Sink
		elseif action == "FiestaSwing" then
			if Menus.current() ~= nil or not actionsVisible then
				return Enum.ContextActionResult.Sink
			end
			swing()
			return Enum.ContextActionResult.Sink
		elseif action == "FiestaLock" then
			if Menus.current() ~= nil or not actionsVisible then
				return Enum.ContextActionResult.Sink
			end
			lockDoor()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end
	ContextActionService:BindActionAtPriority(
		"FiestaClose",
		handle,
		false,
		high,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)
	ContextActionService:BindActionAtPriority("FiestaBag", handle, false, mid, Enum.KeyCode.I, Enum.KeyCode.ButtonY)
	ContextActionService:BindActionAtPriority(
		"FiestaSettings",
		handle,
		false,
		mid,
		Enum.KeyCode.M,
		Enum.KeyCode.ButtonStart
	)
	ContextActionService:BindActionAtPriority(
		"FiestaSwing",
		handle,
		false,
		mid,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonR2,
		Enum.KeyCode.ButtonX
	)
	ContextActionService:BindActionAtPriority("FiestaLock", handle, false, mid, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)

	local glyphs = {}
	local batGlyph = batFace:FindFirstChild("Glyph")
	local lockGlyph = lockFace:FindFirstChild("Glyph")
	if batGlyph and batGlyph:IsA("ImageLabel") then
		table.insert(glyphs, batGlyph)
	end
	if lockGlyph and lockGlyph:IsA("ImageLabel") then
		table.insert(glyphs, lockGlyph)
	end
	local function syncPad(inputType: Enum.UserInputType)
		local pad = string.find(inputType.Name, "Gamepad") ~= nil
		for _, glyph in glyphs do
			glyph.Visible = pad and glyph.Image ~= ""
		end
	end
	syncPad(UserInputService:GetLastInputType())
	UserInputService.LastInputTypeChanged:Connect(syncPad)
	GuiService.AutoSelectGuiEnabled = true

	local player = Players.LocalPlayer
	local seenTool: { [Tool]: boolean } = {}
	local function watchTool(inst: Instance)
		if not inst:IsA("Tool") or inst.Name ~= "Bate" or seenTool[inst] then
			return
		end
		seenTool[inst] = true
		inst.Activated:Connect(swing)
	end
	local function watchBag(bag: Instance)
		bag.ChildAdded:Connect(watchTool)
		for _, child in bag:GetChildren() do
			watchTool(child)
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		watchBag(backpack)
	end
	player.ChildAdded:Connect(function(child)
		if child.Name == "Backpack" then
			watchBag(child)
		end
	end)
	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(watchTool)
		for _, child in character:GetChildren() do
			watchTool(child)
		end
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

return HUDController
