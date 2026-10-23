--!strict
-- Piezas con forma de sticker: sombra ink al 25%, borde blanco, flecos y carita kawaii.

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local Locale = require(script.Parent.Locale)
local Metrics = require(script.Parent.Metrics)
local SoundBus = require(script.Parent.SoundBus)

local motion = 1
local live: { Tween } = {}
local chips: { TextLabel } = {}
local shimmers: { UIGradient } = {}

local UIKit = {}

function UIKit.setMotion(scale: number)
	motion = if scale <= 0 then 0 else 1
end

function UIKit.motion(): number
	return motion
end

function UIKit.tween(instance: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween?
	if motion <= 0 then
		for key, value in props do
			(instance :: any)[key] = value
		end
		return nil
	end
	local info = TweenInfo.new(math.max(0.05, seconds), style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, props)
	table.insert(live, tween)
	tween.Completed:Connect(function()
		local index = table.find(live, tween)
		if index then
			table.remove(live, index)
		end
	end)
	tween:Play()
	return tween
end

function UIKit.corner(gui: GuiObject, radius: number?)
	local existing = gui:FindFirstChild("Round")
	local corner = if existing and existing:IsA("UICorner") then existing else Instance.new("UICorner")
	corner.Name = "Round"
	corner.CornerRadius = if radius == nil then UDim.new(1, 0) else UDim.new(0, radius)
	corner.Parent = gui
end

function UIKit.stroke(gui: GuiObject, color: Color3, thickness: number): UIStroke
	local existing = gui:FindFirstChild("Rim")
	local stroke = if existing and existing:IsA("UIStroke") then existing else Instance.new("UIStroke")
	stroke.Name = "Rim"
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = gui
	return stroke
end

function UIKit.clock(seconds: number): string
	local sec = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

function UIKit.label(parent: Instance, text: string, role: string, size: number, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 2
	label.Parent = parent
	Theme.apply(label, role, color or Theme.color.ink)
	return label
end

local function styleCaption(label: TextLabel, background: Color3)
	local luma = background.R * 0.3 + background.G * 0.59 + background.B * 0.11
	if luma > 0.58 then
		Theme.apply(label, "display", Theme.color.ink)
	else
		Theme.apply(label, "display", Theme.color.white)
		label.TextStrokeColor3 = Theme.color.ink
		label.TextStrokeTransparency = 0
	end
end

export type ButtonOpts = {
	name: string?,
	key: string?,
	text: string?,
	color: Color3?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	z: number?,
	onClick: (() -> ())?,
}

function UIKit.button(parent: Instance, opts: ButtonOpts): (Frame, TextButton, TextLabel)
	local m = Metrics.get()
	local fill = opts.color or Theme.color.fiesta_pink
	local root = Instance.new("Frame")
	root.Name = (opts.name or "Btn") .. "Wrap"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = opts.size or UDim2.fromOffset(m.button, m.button)
	root.Position = opts.position or UDim2.fromOffset(0, 0)
	root.AnchorPoint = opts.anchor or Vector2.zero
	root.ZIndex = opts.z or 2
	root.Parent = parent

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = Theme.color.ink
	shadow.BackgroundTransparency = 0.75
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, m.stroke)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.ZIndex = root.ZIndex
	shadow.Parent = root
	UIKit.corner(shadow, m.radius)

	local hit = Instance.new("TextButton")
	hit.Name = opts.name or "Hit"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BorderSizePixel = 0
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundColor3 = fill
	hit.ZIndex = root.ZIndex + 1
	hit.Selectable = true
	hit.ClipsDescendants = true
	hit.Parent = root
	UIKit.corner(hit, m.radius)
	UIKit.stroke(hit, Theme.color.white, m.stroke)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(fill, fill:Lerp(Theme.color.ink, 0.14))
	gradient.Rotation = 90
	gradient.Parent = hit

	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Theme.color.white
	gloss.BackgroundTransparency = 0.74
	gloss.BorderSizePixel = 0
	gloss.Active = false
	gloss.Size = UDim2.new(1, -12, 0.36, 0)
	gloss.Position = UDim2.fromOffset(6, 5)
	gloss.ZIndex = hit.ZIndex + 1
	gloss.Parent = hit
	UIKit.corner(gloss, 10)

	local caption = UIKit.label(hit, opts.text or "", "display", m.body, Theme.color.ink)
	caption.Name = "Caption"
	caption.Size = UDim2.new(1, -16, 1, -8)
	caption.Position = UDim2.fromOffset(8, 4)
	caption.ZIndex = hit.ZIndex + 2
	-- Con tamaño fijo, una palabra que no cabe se parte ("Setting" / "s"). Escalado con techo en m.body:
	-- igual que antes cuando cabe, más chico cuando no (Inventario, Configuración, etc.).
	caption.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = m.body
	fit.MinTextSize = math.max(9, math.floor(m.body * 0.55))
	fit.Parent = caption
	-- Quien después asigna TextSize (el HUD al redimensionar) sigue mandando: pasa a ser el techo.
	caption:GetPropertyChangedSignal("TextSize"):Connect(function()
		fit.MinTextSize = math.min(fit.MinTextSize, caption.TextSize)
		fit.MaxTextSize = caption.TextSize
	end)
	styleCaption(caption, fill)
	if opts.key then
		Locale.bind(caption, opts.key)
	end

	local scaler = Instance.new("UIScale")
	scaler.Parent = root
	hit.MouseButton1Down:Connect(function()
		UIKit.tween(scaler, 0.08, { Scale = 0.94 }, Enum.EasingStyle.Quad)
	end)
	hit.MouseButton1Up:Connect(function()
		UIKit.tween(scaler, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	hit.MouseLeave:Connect(function()
		if scaler.Scale ~= 1 then
			UIKit.tween(scaler, 0.1, { Scale = 1 })
		end
	end)
	hit.SelectionGained:Connect(function()
		UIKit.tween(scaler, 0.1, { Scale = 1.05 }, Enum.EasingStyle.Back)
	end)
	hit.SelectionLost:Connect(function()
		UIKit.tween(scaler, 0.1, { Scale = 1 })
	end)
	hit.Activated:Connect(function()
		SoundBus.play("click")
		if opts.onClick then
			opts.onClick()
		end
	end)
	return root, hit, caption
end

function UIKit.retint(hit: TextButton, fill: Color3)
	hit.BackgroundColor3 = fill
	local gradient = hit:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(fill, fill:Lerp(Theme.color.ink, 0.14))
	end
	local caption = hit:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		styleCaption(caption, fill)
	end
	local m = Metrics.get()
	local wrap = hit.Parent
	if wrap and wrap:IsA("GuiObject") then
		local shadow = wrap:FindFirstChild("Shadow")
		if shadow and shadow:IsA("GuiObject") then
			shadow.Position = UDim2.fromOffset(0, m.stroke)
		end
	end
	UIKit.stroke(hit, Theme.color.white, m.stroke)
	UIKit.corner(hit, m.radius)
end

function UIKit.fringe(parent: GuiObject, colorA: Color3, colorB: Color3)
	local row = Instance.new("Frame")
	row.Name = "Fringe"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 1, -3)
	row.Size = UDim2.new(1.05, 0, 0.22, 0)
	row.ZIndex = parent.ZIndex + 2
	row.Parent = parent
	for index = 1, 7 do
		local tooth = Instance.new("Frame")
		tooth.BorderSizePixel = 0
		tooth.BackgroundColor3 = if index % 2 == 0 then colorB else colorA
		tooth.Size = UDim2.new(1 / 7, -1, 1, 0)
		tooth.Position = UDim2.new((index - 1) / 7, 0, 0, 0)
		tooth.Rotation = if index % 2 == 0 then 7 else -7
		tooth.ZIndex = row.ZIndex
		tooth.Parent = row
		UIKit.corner(tooth, 2)
	end
end

local function eye(parent: GuiObject, x: number, y: number, scale: number)
	local socket = Instance.new("Frame")
	socket.AnchorPoint = Vector2.new(0.5, 0.5)
	socket.Position = UDim2.fromScale(x, y)
	socket.Size = UDim2.fromScale(scale, scale * 1.15)
	socket.BackgroundColor3 = Theme.color.white
	socket.BorderSizePixel = 0
	socket.ZIndex = parent.ZIndex + 3
	socket.Parent = parent
	UIKit.corner(socket, nil)
	local pupil = Instance.new("Frame")
	pupil.AnchorPoint = Vector2.new(0.5, 0.5)
	pupil.Position = UDim2.fromScale(0.5, 0.55)
	pupil.Size = UDim2.fromScale(0.48, 0.5)
	pupil.BackgroundColor3 = Theme.color.ink
	pupil.BorderSizePixel = 0
	pupil.ZIndex = socket.ZIndex + 1
	pupil.Parent = socket
	UIKit.corner(pupil, nil)
	local shine = Instance.new("Frame")
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(0.32, 0.3)
	shine.Size = UDim2.fromScale(0.28, 0.28)
	shine.BackgroundColor3 = Theme.color.white
	shine.BorderSizePixel = 0
	shine.ZIndex = pupil.ZIndex + 1
	shine.Parent = socket
	UIKit.corner(shine, nil)
end

local function smile(parent: GuiObject)
	local mask = Instance.new("Frame")
	mask.Name = "Smile"
	mask.ClipsDescendants = true
	mask.BackgroundTransparency = 1
	mask.AnchorPoint = Vector2.new(0.5, 0.5)
	mask.Position = UDim2.fromScale(0.5, 0.72)
	mask.Size = UDim2.fromScale(0.42, 0.28)
	mask.ZIndex = parent.ZIndex + 3
	mask.Parent = parent
	local arc = Instance.new("Frame")
	arc.AnchorPoint = Vector2.new(0.5, 0)
	arc.Position = UDim2.fromScale(0.5, -0.35)
	arc.Size = UDim2.fromScale(1, 1.5)
	arc.BackgroundColor3 = Theme.color.ink
	arc.BorderSizePixel = 0
	arc.Parent = mask
	UIKit.corner(arc, nil)
	local cover = Instance.new("Frame")
	cover.BackgroundColor3 = parent.BackgroundColor3
	cover.BorderSizePixel = 0
	cover.Size = UDim2.fromScale(1, 0.55)
	cover.ZIndex = arc.ZIndex + 1
	cover.Parent = mask
end

local function pom(parent: GuiObject, x: number, y: number, tint: Color3)
	local ball = Instance.new("Frame")
	ball.AnchorPoint = Vector2.new(0.5, 0.5)
	ball.Position = UDim2.fromScale(x, y)
	ball.Size = UDim2.fromScale(0.28, 0.28)
	ball.BackgroundColor3 = tint
	ball.BorderSizePixel = 0
	ball.ZIndex = parent.ZIndex + 2
	ball.Parent = parent
	UIKit.corner(ball, nil)
	UIKit.stroke(ball, Theme.color.ink, 2)
end

function UIKit.pinataFace(parent: Instance, pinataId: string, mutation: string, px: number): Frame
	local root = Instance.new("Frame")
	root.Name = "PinataFace"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(px, px)
	root.Parent = parent

	local bodyColor = Theme.pinataColor(pinataId)
	local alt = Theme.pinataAlt(pinataId)
	local silhouette = Theme.silhouette(pinataId)
	if pinataId == "sombra" then
		bodyColor = Theme.color.ink
	end

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.56)
	body.Size = if silhouette == "rocket" then UDim2.fromScale(0.5, 0.7) else UDim2.fromScale(0.7, 0.58)
	body.BackgroundColor3 = bodyColor
	body.BorderSizePixel = 0
	body.ZIndex = 2
	body.Parent = root
	UIKit.corner(body, math.floor(px * 0.28))
	UIKit.stroke(body, Theme.color.ink, math.max(2, math.floor(px * 0.035)))
	UIKit.fringe(body, bodyColor, alt)

	if silhouette == "cat" or silhouette == "donkey" or silhouette == "pom" or silhouette == "beak" then
		local earH = if silhouette == "donkey" then 0.42 else 0.24
		pom(root, 0.28, 0.24, bodyColor)
		pom(root, 0.72, 0.24, bodyColor)
		local left = root:FindFirstChildWhichIsA("Frame")
		if left and earH > 0.3 then
			left.Size = UDim2.fromScale(0.18, earH)
		end
	elseif silhouette == "horn" then
		pom(root, 0.3, 0.2, Theme.color.gold_pale)
		pom(root, 0.7, 0.2, Theme.color.gold_pale)
	elseif silhouette == "star" then
		for _, spot in
			{ Vector2.new(0.5, 0.08), Vector2.new(0.08, 0.5), Vector2.new(0.92, 0.5), Vector2.new(0.5, 0.96) }
		do
			local point = Instance.new("Frame")
			point.AnchorPoint = Vector2.new(0.5, 0.5)
			point.Position = UDim2.fromScale(spot.X, spot.Y)
			point.Size = UDim2.fromOffset(math.floor(px * 0.16), math.floor(px * 0.16))
			point.Rotation = 45
			point.BackgroundColor3 = Theme.color.sun_yellow
			point.BorderSizePixel = 0
			point.ZIndex = 1
			point.Parent = root
		end
	end

	if silhouette == "cyclops" then
		eye(body, 0.5, 0.42, 0.42)
	else
		eye(body, 0.34, 0.4, 0.24)
		eye(body, 0.66, 0.4, 0.24)
	end
	local blush = Instance.new("Frame")
	blush.AnchorPoint = Vector2.new(0.5, 0.5)
	blush.Position = UDim2.fromScale(0.18, 0.58)
	blush.Size = UDim2.fromScale(0.14, 0.1)
	blush.BackgroundColor3 = Theme.color.blush
	blush.BackgroundTransparency = 0.15
	blush.BorderSizePixel = 0
	blush.ZIndex = body.ZIndex + 3
	blush.Parent = body
	UIKit.corner(blush, nil)
	local blush2 = blush:Clone()
	blush2.Position = UDim2.fromScale(0.82, 0.58)
	blush2.Parent = body
	smile(body)

	if mutation == "Golden" or mutation == "Rainbow" or mutation == "Christmas" then
		local fx = Instance.new("UIGradient")
		fx.Parent = body
		if mutation == "Golden" then
			fx.Color = ColorSequence.new(Theme.color.gold_pale, Theme.color.gold)
			fx:SetAttribute("Fx", "gold")
		elseif mutation == "Rainbow" then
			fx.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.color.fiesta_pink),
				ColorSequenceKeypoint.new(0.5, Theme.color.sun_yellow),
				ColorSequenceKeypoint.new(1, Theme.color.turquoise),
			})
			fx:SetAttribute("Fx", "rainbow")
		else
			fx.Color = ColorSequence.new(Theme.color.xmas_red, Theme.color.xmas_green)
			fx:SetAttribute("Fx", "xmas")
		end
		table.insert(shimmers, fx)
		local crown = UIKit.label(
			root,
			if mutation == "Christmas" then "❄" else "♛",
			"display",
			math.floor(px * 0.28),
			Theme.color.gold_deep
		)
		crown.AnchorPoint = Vector2.new(0.5, 0.5)
		crown.Position = UDim2.fromScale(0.5, 0.02)
		crown.Size = UDim2.fromOffset(px, math.floor(px * 0.28))
	end
	return root
end

function UIKit.rarityChip(parent: Instance, rarity: string, height: number): Frame
	local style = Theme.rarity(rarity)
	local chip = Instance.new("Frame")
	chip.Name = "Rarity"
	chip.BackgroundColor3 = style.plate
	chip.BorderSizePixel = 0
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, height)
	chip.Parent = parent
	UIKit.corner(chip, math.floor(height / 2))
	UIKit.stroke(chip, Theme.color.white, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = chip
	local label = UIKit.label(
		chip,
		style.shape .. " " .. Locale.t("rarity." .. rarity),
		"body",
		math.floor(height * 0.52),
		style.text
	)
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextWrapped = false
	label:SetAttribute("RarityId", rarity)
	table.insert(chips, label)
	return chip
end

function UIKit.trackChip(label: TextLabel)
	table.insert(chips, label)
end

function UIKit.bindEffects()
	Locale.onChange(function()
		for _, label in chips do
			if label.Parent then
				local rarity = label:GetAttribute("RarityId")
				if typeof(rarity) == "string" then
					local style = Theme.rarity(rarity)
					label.Text = style.shape .. " " .. Locale.t("rarity." .. rarity)
					label.TextColor3 = style.text
				end
			end
		end
	end)
	RunService.Heartbeat:Connect(function()
		if motion <= 0 then
			return
		end
		local now = os.clock()
		for index = #shimmers, 1, -1 do
			local fx = shimmers[index]
			if not fx.Parent then
				table.remove(shimmers, index)
			else
				local kind = fx:GetAttribute("Fx")
				if kind == "gold" then
					fx.Offset = Vector2.new((now * 0.35) % 1, 0)
				elseif kind == "rainbow" then
					fx.Rotation = (now * 48) % 360
				end
			end
		end
	end)
end

return UIKit
