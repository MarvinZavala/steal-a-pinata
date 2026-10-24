--!strict
-- HUD móvil: Dulces con salto, Piñatitos, robo, candados cercanos, bate y candado.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
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
local DailyPanel = require(script.Parent.Parent.UI.DailyPanel)
local FiestaPanel = require(script.Parent.Parent.UI.FiestaPanel)
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
local numberFit: UITextSizeConstraint
local rateLabel: TextLabel
local rateScale: UIScale
local numberScale: UIScale
local candyWrap: Frame
local candyIcon: Frame
local vaultBg: Frame
local vaultFill: Frame
local fiestaLabel: TextLabel
local shieldLabel: TextLabel
local fiestaWrap: Frame
local caneWrap: Frame
local caneLabel: TextLabel
local shieldWrap: Frame
local leagueWrap: Frame
local badge: TextLabel
local carryWrap: Frame
local carryLabel: TextLabel
local carryFit: UITextSizeConstraint
local collectWrap: Frame
local collectFace: TextButton
local collectLabel: TextLabel
local batWrap: Frame
local batFace: TextButton
local batCaption: TextLabel
local lockWrap: Frame
local lockFace: TextButton
local lockCaption: TextLabel
local lockOverlay: Frame
local invWrap: Frame
local invFace: TextButton
local shopWrap: Frame
local shopFace: TextButton
local settingsWrap: Frame
local settingsFace: TextButton
local multLabel: TextLabel
local lockList: Frame
local lockSig = ""
-- Chips de estado bajo la tarjeta de Dulces, en este orden (placeStack los acomoda).
type Chip = { wrap: Frame, face: TextButton, label: TextLabel }
local chipsFlow: { Chip } = {}
local stackSig = ""
-- Borde izquierdo de Batear y base del cartel de "Llevás" (px del Stage); los fija layout.
local actionsLeft = 0
local carryBottom = 0

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

type Box = { x: number, y: number, w: number, h: number }

local function visibleBox(gui: Instance?, origin: Vector2): Box?
	if gui == nil or not gui:IsA("GuiObject") or not gui.Visible or gui.AbsoluteSize.X < 1 then
		return nil
	end
	local pos = gui.AbsolutePosition - origin
	return { x = pos.X, y = pos.Y, w = gui.AbsoluteSize.X, h = gui.AbsoluteSize.Y }
end

-- Salto y joystick de Roblox en px del Stage (TouchGui usa las mismas ScreenInsets que FiestaUI).
-- nil sin controles táctiles o con el teléfono simulado del preview de Studio.
local function touchControls(): (Box?, Box?)
	local stage = UIRoot.stage()
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local touchGui = if playerGui then playerGui:FindFirstChild("TouchGui") else nil
	if stage.Size.X.Scale ~= 1 or touchGui == nil or not touchGui:IsA("ScreenGui") or not touchGui.Enabled then
		return nil, nil
	end
	local frame = touchGui:FindFirstChild("TouchControlFrame")
	if frame == nil or not frame:IsA("GuiObject") or not frame.Visible then
		return nil, nil
	end
	local origin = stage.AbsolutePosition
	local jump = visibleBox(frame:FindFirstChild("JumpButton"), origin)
	local stick = visibleBox(frame:FindFirstChild("ThumbstickFrame"), origin)
	local dynamic = frame:FindFirstChild("DynamicThumbstickFrame")
	if dynamic ~= nil and dynamic:IsA("GuiObject") and dynamic.Visible then
		-- El aro del joystick dinámico se muda a donde tocás: uso su lugar de reposo, con la cuenta de
		-- PlayerModule (DynamicThumbstick.ResizeThumbstick): centro (3.3r, alto - 2.8r), lado 3.7r.
		local size = frame.AbsoluteSize
		local ring = if math.min(size.X, size.Y) > 500 then 40 else 20
		local side = ring * 3.7
		local base = frame.AbsolutePosition - origin
		stick = {
			x = base.X + ring * 3.3 - side / 2,
			y = base.Y + size.Y - ring * 2.8 - side / 2,
			w = side,
			h = side,
		}
	end
	return jump, stick
end

local function touchSig(): string
	local jump, stick = touchControls()
	local parts = {}
	for _, box in { jump, stick } do
		table.insert(parts, if box then string.format("%d,%d,%d,%d", box.x, box.y, box.w, box.h) else "-")
	end
	return table.concat(parts, "|")
end

-- Ancho de la tarjeta de Dulces: proporcional a la pantalla, con piso y techo (antes en el celular
-- ocupaba todo el ancho).
local function cardWidth(m: any): number
	return math.clamp(math.floor(m.w * (if m.compact then 0.3 else 0.22)), 200, 320)
end

local function chipHeight(m: any): number
	return if m.compact then math.max(32, m.chip - 4) else m.chip
end

local function sideWidth(m: any): number
	return math.max(120, math.floor(m.button * 2.2))
end

-- Ancho justo para ícono + texto. Los dígitos se miden como "0" para que el reloj no haga bailar la fila.
local function chipWidth(text: string, height: number, size: number): number
	local sample = string.gsub(text, "%d", "0")
	local bounds = TextService:GetTextSize(sample, size, Theme.fontEnum.display, Vector2.new(1000, height))
	local pad = math.max(6, math.floor(height * 0.2))
	local side = math.floor(height * 0.58)
	return pad * 2 + side + 2 + math.ceil(bounds.X) + 8
end

-- Chips bajo la tarjeta, en fila y con salto de línea; debajo van los candados cercanos y (en pantallas
-- angostas) el cartel de "Llevás". Corre en cada refresh, pero solo reacomoda si algo cambió.
local function placeStack(m: any, force: boolean?)
	local left = m.safeLeft + m.margin
	local right = m.safeRight + m.margin
	local top = m.safeTop + m.margin + m.candyH + 8
	local h = chipHeight(m)
	local gap = 6
	local parts = { tostring(m.w), tostring(m.h), tostring(carryWrap.Visible) }
	for _, item in chipsFlow do
		table.insert(parts, if item.wrap.Visible then string.gsub(item.label.Text, "%d", "0") else "-")
	end
	local sig = table.concat(parts, "|")
	if sig == stackSig and not force then
		return
	end
	stackSig = sig

	local maxX = left + math.max(cardWidth(m), math.min(math.floor(m.w * 0.55), 440))
	local x, y = left, top
	local bottomY = top - 8
	for _, item in chipsFlow do
		if item.wrap.Visible then
			item.label.TextSize = m.small
			local w = chipWidth(item.label.Text, h, m.small)
			if x > left and x + w > maxX then
				x = left
				y += h + gap
			end
			item.wrap.AnchorPoint = Vector2.zero
			item.wrap.Position = UDim2.fromOffset(x, y)
			item.wrap.Size = UDim2.fromOffset(w, h)
			UIKit.stroke(item.face, Theme.color.white, if m.compact then 2 else 3)
			UIKit.iconLayout(item.face, w, h)
			x += w + gap
			bottomY = y + h
		end
	end

	lockList.Position = UDim2.fromOffset(left, bottomY + 8)
	lockList.Size = UDim2.fromOffset(180, m.chip * 3)
	carryFit.MaxTextSize = m.body

	-- Centrado entre la barra de la izquierda y Batear; si no cabe, bajo los chips.
	local carryW = 2 * (actionsLeft - m.w / 2 - 8)
	if carryW < 200 then
		carryWrap.AnchorPoint = Vector2.new(0, 0)
		carryWrap.Position = UDim2.fromOffset(left, bottomY + 8)
		carryWrap.Size = UDim2.fromOffset(math.min(m.w - left - right, 420), m.chip + 6)
	else
		carryWrap.AnchorPoint = Vector2.new(0.5, 1)
		carryWrap.Position = UDim2.new(0.5, 0, 0, carryBottom)
		carryWrap.Size = UDim2.fromOffset(math.min(math.floor(carryW), 460), m.chip + 8)
	end
end

local function layout(m: any)
	local left = m.safeLeft + m.margin
	local right = m.safeRight + m.margin
	local top = m.safeTop + m.margin
	local bottom = m.safeBottom + m.margin

	-- Tarjeta de Dulces: ícono a la izquierda, número grande, ritmo y barra de la Dulcería debajo.
	local cardW = cardWidth(m)
	local h = m.candyH
	candyWrap.Position = UDim2.fromOffset(left, top)
	candyWrap.Size = UDim2.fromOffset(cardW, h)
	local iconSide = math.clamp(h - 14, 30, 64)
	candyIcon.Position = UDim2.new(0, 8, 0.5, 0)
	candyIcon.Size = UDim2.fromOffset(iconSide, iconSide)
	local cx = 8 + iconSide + 8
	local numH = math.floor(h * 0.56)
	local rateH = math.floor(h * 0.26)
	numberLabel.Position = UDim2.fromOffset(cx, 3)
	numberLabel.Size = UDim2.new(1, -(cx + 10), 0, numH)
	numberLabel.TextSize = m.num
	numberFit.MaxTextSize = m.num
	rateLabel.Position = UDim2.fromOffset(cx, numH)
	rateLabel.Size = UDim2.new(1, -(cx + 10), 0, rateH)
	rateLabel.TextSize = m.small
	multLabel.Position = UDim2.new(1, -10, 0, numH)
	multLabel.Size = UDim2.fromOffset(56, rateH)
	multLabel.TextSize = m.small
	vaultBg.Position = UDim2.new(0, cx, 1, -6)
	vaultBg.Size = UDim2.new(1, -(cx + 12), 0, if m.compact then 4 else 5)

	-- Ajustes: solo el engranaje.
	settingsWrap.AnchorPoint = Vector2.new(1, 0)
	settingsWrap.Position = UDim2.new(1, -right, 0, top)
	settingsWrap.Size = UDim2.fromOffset(m.button, m.button)
	UIKit.iconLayout(settingsFace, m.button, m.button)

	-- Batear y Candado abajo a la derecha (ícono arriba, palabra abajo). En táctil van alrededor del salto
	-- de Roblox (Batear a su izquierda, Candado encima): antes lo tapaban.
	local jump, stick = touchControls()
	local bat = math.floor(m.button * 1.22)
	batWrap.Size = UDim2.fromOffset(bat, bat)
	lockWrap.Size = UDim2.fromOffset(m.button, m.button)
	if jump ~= nil then
		local batX = jump.x - 10 - bat
		batWrap.AnchorPoint = Vector2.zero
		batWrap.Position = UDim2.fromOffset(batX, jump.y + jump.h - bat)
		lockWrap.AnchorPoint = Vector2.zero
		lockWrap.Position = UDim2.fromOffset(jump.x + math.floor((jump.w - m.button) / 2), jump.y - 10 - m.button)
		actionsLeft = batX
	else
		batWrap.AnchorPoint = Vector2.new(1, 1)
		batWrap.Position = UDim2.new(1, -right, 1, -bottom)
		lockWrap.AnchorPoint = Vector2.new(1, 1)
		lockWrap.Position = UDim2.new(1, -right, 1, -(bottom + bat + 8))
		actionsLeft = m.w - right - bat
	end
	batCaption.TextSize = m.small
	UIKit.iconLayout(batFace, bat, bat)
	lockCaption.TextSize = m.small
	UIKit.iconLayout(lockFace, m.button, m.button)

	-- Piñatas y Tienda abajo a la izquierda (ícono + palabra); en táctil, a la derecha del joystick.
	-- Si ahí chocan con Batear (pantalla angosta), suben en columna encima del joystick.
	local sideW = sideWidth(m)
	local barX = left
	local barBottom = bottom
	local column = false
	if stick ~= nil then
		barX = math.max(left, math.floor(stick.x + stick.w + 12))
		if barX + sideW * 2 + 16 > actionsLeft then
			barX = left
			barBottom = math.max(bottom, m.h - stick.y + 8)
			column = true
		end
	end
	invWrap.AnchorPoint = Vector2.new(0, 1)
	invWrap.Position = UDim2.new(0, barX, 1, -barBottom)
	invWrap.Size = UDim2.fromOffset(sideW, m.button)
	UIKit.iconLayout(invFace, sideW, m.button)
	shopWrap.AnchorPoint = Vector2.new(0, 1)
	if column then
		shopWrap.Position = UDim2.new(0, barX, 1, -(barBottom + m.button + 8))
	else
		shopWrap.Position = UDim2.new(0, barX + sideW + 8, 1, -barBottom)
	end
	shopWrap.Size = UDim2.fromOffset(sideW, m.button)
	UIKit.iconLayout(shopFace, sideW, m.button)

	local collectW = if column then sideW else sideW * 2 + 8
	local collectUp = if column then m.button * 2 + 16 else m.button + 8
	collectWrap.AnchorPoint = Vector2.new(0, 1)
	collectWrap.Position = UDim2.new(0, barX, 1, -(barBottom + collectUp))
	collectWrap.Size = UDim2.fromOffset(collectW, m.button)
	UIKit.iconLayout(collectFace, collectW, m.button)
	-- El cartel de "Llevás" va abajo al centro: encima de la barra, o al ras si la barra subió en columna.
	carryBottom = if column then m.h - bottom - 10 else m.h - barBottom - m.button - 10

	placeStack(m, true)

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
	local variant = if typeof(s.fiestaVariant) == "string" then s.fiestaVariant else "fiesta"
	local nowKey = "hud.fiesta_now"
	local inKey = "hud.fiesta_in"
	if variant == "posada" then
		nowKey = "event.hud_posada"
		inKey = "event.hud_posada_in"
	elseif variant == "newyear" then
		nowKey = "event.hud_newyear"
		inKey = "event.hud_newyear_in"
	elseif variant == "rosca" then
		nowKey = "event.hud_rosca"
		inKey = "event.hud_rosca_in"
	end
	fiestaLabel.Text = if fiesta <= 0 then Locale.t(nowKey) else Locale.t(inKey, { time = UIKit.clock(fiesta) })
	local bastones = num(s.bastones, 0)
	caneWrap.Visible = s.eventActive == true or bastones > 0
	caneLabel.Text = Locale.t("hud.bastones", { n = Format(bastones) })
	local shield = num(s.rookieShieldRemaining, 0)
	shieldWrap.Visible = shield > 0
	shieldLabel.Text = Locale.t("hud.shield", { time = UIKit.clock(shield) })
	local league = s.league
	if RunService:IsStudio() and not UIBridge.isAuthoritative() then
		leagueWrap.Visible = true
		badge.Text = Locale.t("hud.local_badge")
	elseif typeof(league) == "string" and league ~= "" and Locale.has("league." .. league) then
		leagueWrap.Visible = true
		badge.Text = Locale.t("league." .. league)
	else
		leagueWrap.Visible = false
	end

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
	placeStack(Metrics.get())
	paintLocks(s)
end

local function cornerHint(parent: TextButton, text: string, keyCode: Enum.KeyCode): ImageLabel
	-- Arriba a la izquierda: abajo va la palabra del botón.
	local hint = UIKit.label(parent, text, "display", 13, Theme.color.white)
	hint.Name = "KeyHint"
	hint.AnchorPoint = Vector2.zero
	hint.Position = UDim2.fromOffset(6, 4)
	hint.Size = UDim2.fromOffset(18, 16)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextStrokeColor3 = Theme.color.ink
	hint.TextStrokeTransparency = 0
	hint.ZIndex = parent.ZIndex + 3
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

	-- Tarjeta de Dulces: morada oscura para que el número se lea sobre la plaza (que es toda de colores).
	local _candyRoot, candyFace = UIKit.button(layer, {
		name = "Candy",
		color = Theme.color.grape:Lerp(Theme.color.ink, 0.4),
		size = UDim2.fromOffset(240, 72),
	})
	candyWrap = _candyRoot
	candyFace.Active = false
	candyFace.Selectable = false
	candyFace.AutoButtonColor = false
	-- Sin el brillo de botón: sobre el morado parecía una caja vacía detrás del número.
	local candyGloss = candyFace:FindFirstChild("Gloss")
	if candyGloss and candyGloss:IsA("Frame") then
		candyGloss.Visible = false
	end
	local inner = candyFace.ZIndex + 2
	candyIcon = Instance.new("Frame")
	candyIcon.Name = "CandyIcon"
	candyIcon.AnchorPoint = Vector2.new(0, 0.5)
	candyIcon.BackgroundColor3 = Theme.color.fiesta_pink
	candyIcon.BorderSizePixel = 0
	candyIcon.ZIndex = inner
	candyIcon.Parent = candyFace
	UIKit.corner(candyIcon, nil)
	UIKit.stroke(candyIcon, Theme.color.white, 2)
	local candyGlyph = UIKit.label(candyIcon, "🍬", "display", 24, Theme.color.white)
	candyGlyph.TextScaled = true
	candyGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
	candyGlyph.Position = UDim2.fromScale(0.5, 0.5)
	candyGlyph.Size = UDim2.fromScale(0.72, 0.72)
	candyGlyph.ZIndex = inner + 1

	numberLabel = UIKit.label(candyFace, "0", "number", 40, Theme.color.white)
	Theme.outlineNumber(numberLabel)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Left
	numberLabel.TextWrapped = false
	numberLabel.TextScaled = true
	numberLabel.ZIndex = inner
	numberFit = Instance.new("UITextSizeConstraint")
	numberFit.MinTextSize = 12
	numberFit.MaxTextSize = 40
	numberFit.Parent = numberLabel
	numberScale = Instance.new("UIScale")
	numberScale.Parent = numberLabel
	rateLabel = UIKit.label(candyFace, "+0/s", "display", 16, Theme.color.lime)
	rateLabel.TextXAlignment = Enum.TextXAlignment.Left
	rateLabel.TextWrapped = false
	rateLabel.ZIndex = inner
	rateScale = Instance.new("UIScale")
	rateScale.Parent = rateLabel
	multLabel = UIKit.label(candyFace, "", "display", 14, Theme.color.gold)
	multLabel.AnchorPoint = Vector2.new(1, 0)
	multLabel.TextXAlignment = Enum.TextXAlignment.Right
	multLabel.TextWrapped = false
	multLabel.ZIndex = inner
	multLabel.Visible = false
	vaultBg = Instance.new("Frame")
	vaultBg.Name = "Vault"
	vaultBg.BackgroundColor3 = Theme.color.white
	vaultBg.BackgroundTransparency = 0.75
	vaultBg.BorderSizePixel = 0
	vaultBg.AnchorPoint = Vector2.new(0, 1)
	vaultBg.ZIndex = inner
	vaultBg.Parent = candyFace
	UIKit.corner(vaultBg, nil)
	vaultFill = Instance.new("Frame")
	vaultFill.BackgroundColor3 = Theme.color.lime
	vaultFill.BorderSizePixel = 0
	vaultFill.Size = UDim2.fromScale(0, 1)
	vaultFill.ZIndex = inner + 1
	vaultFill.Parent = vaultBg
	UIKit.corner(vaultFill, nil)

	candyValue = Instance.new("NumberValue")
	candyValue.Value = 0
	candyValue.Parent = numberLabel
	candyValue.Changed:Connect(function(value)
		numberLabel.Text = Format(math.floor(value + 0.5))
	end)

	-- Chips: pastillas chicas con ícono + texto; el ancho sale del texto (placeStack).
	local function chip(name: string, color: Color3, icon: string, key: string?, onClick: (() -> ())?): Chip
		local wrap, face, caption = UIKit.button(layer, {
			name = name,
			key = key,
			icon = icon,
			color = color,
			size = UDim2.fromOffset(120, 34),
			onClick = onClick,
		})
		face.Active = onClick ~= nil
		face.Selectable = onClick ~= nil
		-- Tamaño fijo y una sola línea: placeStack mide el texto y le da el ancho justo.
		caption.TextScaled = false
		caption.TextWrapped = false
		caption.TextSize = 16
		local item: Chip = { wrap = wrap, face = face, label = caption }
		table.insert(chipsFlow, item)
		return item
	end
	local hoy = chip("Hoy", Theme.color.sun_yellow, "🎁", "hud.hoy", function()
		DailyPanel.toggle()
	end)
	local fiesta = chip("Fiesta", Theme.color.hot_magenta, "🎉", nil, function()
		FiestaPanel.toggle()
	end)
	local shield = chip("Shield", Theme.color.sky, "🛡")
	local cane = chip("Bastones", Theme.color.xmas_red, "🎄", nil, function()
		if UIState.get().eventShop == true then
			ShopController.open("navidad")
		else
			DailyPanel.toggle()
		end
	end)
	local league = chip("League", Theme.color.lavender, "🏆")
	fiestaWrap, fiestaLabel = fiesta.wrap, fiesta.label
	shieldWrap, shieldLabel = shield.wrap, shield.label
	caneWrap, caneLabel = cane.wrap, cane.label
	leagueWrap, badge = league.wrap, league.label
	hoy.wrap.Visible = true
	fiestaWrap.Visible = false
	shieldWrap.Visible = false
	caneWrap.Visible = false
	leagueWrap.Visible = false

	settingsWrap, settingsFace = UIKit.button(layer, {
		name = "Settings",
		icon = "⚙",
		color = Theme.color.cream,
		onClick = function()
			SettingsPanel.toggle()
		end,
	})
	invWrap, invFace = UIKit.button(layer, {
		name = "Inventory",
		key = "hud.inventory",
		icon = "🎒",
		color = Theme.color.mango,
		onClick = function()
			InventoryPanel.toggle()
		end,
	})
	local shopCaption: TextLabel
	shopWrap, shopFace, shopCaption = UIKit.button(layer, {
		name = "Shop",
		key = "hud.shop",
		icon = "🛍",
		color = Theme.color.grape,
		onClick = function()
			ShopController.open("picker")
		end,
	})
	Theme.apply(shopCaption, "display", Theme.color.white)
	shopCaption.TextStrokeTransparency = 0
	shopCaption.TextStrokeColor3 = Theme.color.ink

	collectWrap, collectFace, collectLabel = UIKit.button(layer, {
		name = "Collect",
		icon = "🍬",
		color = Theme.color.lime,
		onClick = collect,
	})
	collectWrap.Visible = false

	batWrap, batFace, batCaption = UIKit.button(layer, {
		name = "Bat",
		key = "hud.bat",
		icon = "⚾",
		color = Theme.color.fiesta_pink,
		onClick = swing,
	})
	lockWrap, lockFace, lockCaption = UIKit.button(layer, {
		name = "Lock",
		key = "hud.lock",
		icon = "🔒",
		color = Theme.color.turquoise,
		onClick = lockDoor,
	})
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
	carryLabel = UIKit.label(carryFace, "", "display", 16, Theme.color.white)
	carryLabel.TextStrokeColor3 = Theme.color.ink
	carryLabel.TextStrokeTransparency = 0
	carryLabel.Size = UDim2.new(1, -20, 1, -8)
	carryLabel.Position = UDim2.fromOffset(10, 4)
	carryLabel.TextScaled = true
	carryFit = Instance.new("UITextSizeConstraint")
	carryFit.MinTextSize = 11
	carryFit.MaxTextSize = 20
	carryFit.Parent = carryLabel

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
	-- Salto y joystick aparecen con el personaje y cambian con la orientación o al pasar a teclado.
	task.spawn(function()
		local last = touchSig()
		while true do
			task.wait(0.5)
			local sig = touchSig()
			if sig ~= last then
				last = sig
				layout(Metrics.get())
			end
		end
	end)

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

	-- Glifo del control con gamepad, letra (E/Q) con teclado o mouse, nada en táctil.
	local glyphs: { ImageLabel } = {}
	local hints: { TextLabel } = {}
	for _, face in { batFace, lockFace } do
		local glyph = face:FindFirstChild("Glyph")
		if glyph and glyph:IsA("ImageLabel") then
			table.insert(glyphs, glyph)
		end
		local hint = face:FindFirstChild("KeyHint")
		if hint and hint:IsA("TextLabel") then
			table.insert(hints, hint)
		end
	end
	local function syncPad(inputType: Enum.UserInputType)
		local pad = string.find(inputType.Name, "Gamepad") ~= nil
		local keys = inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse") ~= nil
		for _, glyph in glyphs do
			glyph.Visible = pad and glyph.Image ~= ""
		end
		for _, hint in hints do
			hint.Visible = keys
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
