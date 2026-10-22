--!strict
-- Teatro de papel para el FTUE cuando todavía no hay plaza.
-- Si existen partes con tag FTUEFountain / FTUEBase, la cámara también hace la picada.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pinatas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Pinatas")) :: any
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format")) :: any
local Locale = require(script.Parent.Locale)
local Metrics = require(script.Parent.Metrics)
local UIGuide = require(script.Parent.UIGuide)
local UIKit = require(script.Parent.UIKit)
local UIRoot = require(script.Parent.UIRoot)

local sheet: Frame
local scene: Frame
local caption: TextLabel
local promptWrap: Frame
local promptLabel: TextLabel
local stamp: TextLabel
local slowLabel: TextLabel
local letterTop: Frame
local letterBot: Frame
local jarFill: Frame? = nil
local actors: { [string]: Frame } = {}
local animToken = 0
local onPrompt: (() -> ())? = nil
local onSkip: (() -> ())? = nil

local Cinematic = {}

local function wrapper(name: string): Frame
	local outer = Instance.new("Frame")
	outer.Name = name
	outer.BackgroundTransparency = 1
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.Size = UDim2.fromOffset(90, 90)
	outer.Position = UDim2.fromScale(-0.3, 0.6)
	outer.Visible = false
	outer.Parent = scene
	local inner = Instance.new("Frame")
	inner.Name = "Bob"
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = outer
	actors[name] = outer
	return inner
end

local function place(name: string, x: number, y: number, px: number?)
	local outer = actors[name]
	if not outer then
		return
	end
	outer.Visible = true
	outer.Position = UDim2.fromScale(x, y)
	if px then
		outer.Size = UDim2.fromOffset(px, px)
	end
end

local function hideAll()
	for _, outer in actors do
		outer.Visible = false
		outer.Position = UDim2.fromScale(-0.4, 0.7)
	end
	stamp.Visible = false
	slowLabel.Visible = false
	letterTop.Size = UDim2.new(1, 0, 0, 0)
	letterBot.Size = UDim2.new(1, 0, 0, 0)
end

function Cinematic.layout()
	local m = Metrics.get()
	local top = m.safeTop + m.margin + m.candyH + (if m.compact then m.chip + 8 else 4)
	local bottom = m.safeBottom + m.margin + math.floor(m.button * 2.35)
	local height = m.h - top - bottom
	if height < 130 then
		bottom = m.safeBottom + m.margin + 8
		height = m.h - top - bottom
	end
	sheet.Position = UDim2.fromOffset(m.safeLeft + m.margin, top)
	sheet.Size = UDim2.new(1, -(m.safeLeft + m.safeRight + m.margin * 2), 0, math.max(120, height))
	caption.TextSize = m.title
	promptLabel.TextSize = math.max(m.body + 4, 18)
	local promptH = math.max(52, m.button)
	local prompt = promptWrap
	prompt.Size = UDim2.new(0.86, 0, 0, promptH)
	prompt.Position = UDim2.new(0.5, 0, 1, -10)
end

function Cinematic.mount()
	local layer = UIRoot.layer("Ftue")
	sheet = Instance.new("Frame")
	sheet.Name = "Theater"
	sheet.BackgroundColor3 = Theme.color.snow
	sheet.BorderSizePixel = 0
	sheet.Visible = false
	sheet.ClipsDescendants = true
	sheet.Parent = layer
	UIKit.corner(sheet, 24)
	UIKit.stroke(sheet, Theme.color.white, 4)

	local sky = Instance.new("Frame")
	sky.Name = "Sky"
	sky.Size = UDim2.fromScale(1, 1)
	sky.BorderSizePixel = 0
	sky.BackgroundColor3 = Theme.color.turquoise
	sky.Parent = sheet
	local skyGrad = Instance.new("UIGradient")
	skyGrad.Color = ColorSequence.new(Theme.color.turquoise, Theme.color.sun_yellow)
	skyGrad.Rotation = 90
	skyGrad.Parent = sky

	caption = UIKit.label(sheet, "", "display", 28, Theme.color.ink)
	caption.Size = UDim2.new(1, -24, 0, 36)
	caption.Position = UDim2.fromOffset(12, 8)
	caption.ZIndex = 5
	caption.TextStrokeColor3 = Theme.color.white
	caption.TextStrokeTransparency = 0

	scene = Instance.new("Frame")
	scene.Name = "Scene"
	scene.BackgroundTransparency = 1
	scene.ClipsDescendants = true
	scene.Position = UDim2.fromOffset(0, 44)
	scene.Size = UDim2.new(1, 0, 1, -108)
	scene.ZIndex = 2
	scene.Parent = sheet

	local carpet = Instance.new("Frame")
	carpet.AnchorPoint = Vector2.new(0.5, 1)
	carpet.Position = UDim2.new(0.5, 0, 1, 8)
	carpet.Size = UDim2.new(0.92, 0, 0.18, 0)
	carpet.BackgroundColor3 = Theme.color.hot_magenta
	carpet.BorderSizePixel = 0
	carpet.Parent = scene
	UIKit.corner(carpet, 16)
	UIKit.stroke(carpet, Theme.color.gold, 3)

	local function prop(name: string, color: Color3, w: number, h: number): Frame
		local inner = wrapper(name)
		local body = Instance.new("Frame")
		body.BackgroundColor3 = color
		body.BorderSizePixel = 0
		body.Size = UDim2.fromScale(w, h)
		body.AnchorPoint = Vector2.new(0.5, 0.5)
		body.Position = UDim2.fromScale(0.5, 0.5)
		body.Parent = inner
		UIKit.corner(body, 18)
		UIKit.stroke(body, Theme.color.ink, 3)
		return body
	end

	prop("fountain", Theme.color.turquoise, 0.8, 0.55)
	local arch = prop("base", Theme.color.fiesta_pink, 0.7, 0.85)
	UIKit.fringe(arch, Theme.color.fiesta_pink, Theme.color.sun_yellow)
	prop("jar", Theme.color.cream, 0.55, 0.7)
	local jarInner = actors.jar:FindFirstChild("Bob")
	if jarInner then
		jarFill = Instance.new("Frame")
		jarFill.Name = "Fill"
		jarFill.AnchorPoint = Vector2.new(0, 1)
		jarFill.Position = UDim2.fromScale(0.18, 0.82)
		jarFill.Size = UDim2.fromScale(0.64, 0.05)
		jarFill.BackgroundColor3 = Theme.color.lime
		jarFill.BorderSizePixel = 0
		jarFill.ZIndex = 3
		jarFill.Parent = jarInner
		UIKit.corner(jarFill, 6)
	end

	local michi = wrapper("michi")
	UIKit.pinataFace(michi, "michi", "Golden", 86).Size = UDim2.fromScale(1, 1)
	local burrito = wrapper("burrito")
	UIKit.pinataFace(burrito, "burrito", "None", 86).Size = UDim2.fromScale(1, 1)
	local dragon = wrapper("dragon")
	UIKit.pinataFace(dragon, "dragon", "None", 86).Size = UDim2.fromScale(1, 1)

	local thiefInner = wrapper("thief")
	local thiefBody = Instance.new("Frame")
	thiefBody.BackgroundColor3 = Theme.color.ink_soft
	thiefBody.BorderSizePixel = 0
	thiefBody.Size = UDim2.fromScale(0.55, 0.7)
	thiefBody.AnchorPoint = Vector2.new(0.5, 0.6)
	thiefBody.Position = UDim2.fromScale(0.5, 0.55)
	thiefBody.Parent = thiefInner
	UIKit.corner(thiefBody, 16)
	UIKit.stroke(thiefBody, Theme.color.ink, 3)
	local mask = Instance.new("Frame")
	mask.BackgroundColor3 = Theme.color.fiesta_pink
	mask.BorderSizePixel = 0
	mask.AnchorPoint = Vector2.new(0.5, 0.5)
	mask.Position = UDim2.fromScale(0.5, 0.38)
	mask.Size = UDim2.fromScale(0.85, 0.22)
	mask.Parent = thiefBody
	UIKit.corner(mask, 8)
	local thiefName = UIKit.label(thiefInner, "", "body", 13, Theme.color.ink)
	thiefName.Size = UDim2.new(1.4, 0, 0, 16)
	thiefName.Position = UDim2.new(0.5, 0, 0, -2)
	thiefName.AnchorPoint = Vector2.new(0.5, 1)
	Locale.bind(thiefName, "ftue.thief")

	stamp = UIKit.label(scene, "", "display", 22, Theme.color.chili)
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.fromScale(0.62, 0.28)
	stamp.Size = UDim2.fromOffset(160, 36)
	stamp.Rotation = -8
	stamp.Visible = false
	stamp.ZIndex = 6
	stamp.TextStrokeTransparency = 0
	stamp.TextStrokeColor3 = Theme.color.white

	letterTop = Instance.new("Frame")
	letterTop.BackgroundColor3 = Theme.color.ink
	letterTop.BackgroundTransparency = 0.35
	letterTop.BorderSizePixel = 0
	letterTop.Size = UDim2.new(1, 0, 0, 0)
	letterTop.ZIndex = 7
	letterTop.Parent = scene
	letterBot = letterTop:Clone()
	letterBot.AnchorPoint = Vector2.new(0, 1)
	letterBot.Position = UDim2.fromScale(0, 1)
	letterBot.Parent = scene
	slowLabel = UIKit.label(scene, "", "number", 28, Theme.color.white)
	slowLabel.Size = UDim2.fromScale(1, 0.3)
	slowLabel.Position = UDim2.fromScale(0, 0.35)
	slowLabel.Visible = false
	slowLabel.ZIndex = 8
	Theme.outlineNumber(slowLabel)

	promptWrap = UIKit.button(sheet, {
		name = "FtuePrompt",
		color = Theme.color.fiesta_pink,
		anchor = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -10),
		size = UDim2.new(0.86, 0, 0, 56),
		z = 6,
		onClick = function()
			if onPrompt then
				onPrompt()
			end
		end,
	})
	promptLabel = promptWrap:FindFirstChild("Caption", true) :: TextLabel
	promptWrap.Visible = false
	local promptHit = promptWrap:FindFirstChild("FtuePrompt")
	if promptHit and promptHit:IsA("GuiObject") then
		UIGuide.register("ftuePrompt", promptHit)
	end

	if RunService:IsStudio() then
		UIKit.button(sheet, {
			name = "SkipFtue",
			key = "ftue.skip",
			color = Theme.color.cream,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -8, 0, 8),
			size = UDim2.fromOffset(88, 36),
			z = 7,
			onClick = function()
				if onSkip then
					onSkip()
				end
			end,
		})
	end

	RunService.Heartbeat:Connect(function()
		if not sheet.Visible or UIKit.motion() <= 0 then
			return
		end
		local bob = math.sin(os.clock() * 4) * 4
		for _, outer in actors do
			local inner = outer:FindFirstChild("Bob")
			if inner and inner:IsA("GuiObject") and outer.Visible then
				inner.Position = UDim2.fromOffset(0, bob)
			end
		end
	end)
	Metrics.onChange(function()
		if sheet then
			Cinematic.layout()
		end
	end)
end

function Cinematic.setHandlers(promptFn: () -> (), skipFn: () -> ())
	onPrompt = promptFn
	onSkip = skipFn
end

function Cinematic.setVisible(on: boolean)
	sheet.Visible = on
	if on then
		Cinematic.layout()
	else
		UIGuide.pointAt(nil)
		UIGuide.pointWorld(nil)
	end
end

-- En la plaza real el teatro no tapa el mundo: quedan el texto y la flecha.
function Cinematic.setLive(on: boolean)
	if not sheet then
		return
	end
	local sky = sheet:FindFirstChild("Sky")
	if sky and sky:IsA("GuiObject") then
		sky.Visible = not on
	end
	if scene then
		scene.Visible = not on
	end
	sheet.BackgroundTransparency = if on then 1 else 0
	sheet.Active = false
	local stroke = sheet:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Enabled = not on
	end
end

function Cinematic.arm(key: string?)
	promptWrap.Visible = key ~= nil
	if key and promptLabel then
		promptLabel.Text = Locale.t(key)
		local hit = promptWrap:FindFirstChild("FtuePrompt")
		if hit and hit:IsA("TextButton") then
			local luma = Theme.color.fiesta_pink
			if key == "ftue.buy" or key == "ftue.collect_btn" then
				UIKit.retint(hit, Theme.color.lime)
			elseif key == "ftue.hit" then
				UIKit.retint(hit, Theme.color.chili)
			else
				UIKit.retint(hit, luma)
			end
		end
	end
end

function Cinematic.point(name: string?)
	UIGuide.pointAt(name)
end

function Cinematic.caption(key: string, args: { [string]: string }?)
	caption.Text = Locale.t(key, args)
end

local function cancelAnim()
	animToken += 1
	return animToken
end

function Cinematic.show(stepName: string)
	local token = cancelAnim()
	hideAll()
	Cinematic.arm(nil)
	local px = if Metrics.get().compact then 72 else 96
	if stepName == "1_spawn" then
		Cinematic.caption("ftue.your_base")
		place("fountain", 0.55, 0.42, px)
		place("base", 0.28, 0.58, px + 10)
		stamp.Text = Locale.t("ftue.your_base")
		stamp.Visible = true
		stamp.Position = UDim2.fromScale(0.32, 0.22)
	elseif stepName == "2_arrow_followed" then
		Cinematic.caption("ftue.guide_arrow")
		place("base", 0.16, 0.62, px)
		place("michi", 0.78, 0.58, px)
		stamp.Text = Locale.t("ftue.free")
		stamp.Visible = true
		stamp.Position = UDim2.fromScale(0.78, 0.28)
	elseif stepName == "3_first_claim" then
		Cinematic.caption("ftue.guaranteed")
		place("michi", 0.5, 0.55, px + 20)
		stamp.Text = Locale.t("ftue.free")
		stamp.Visible = true
	elseif stepName == "4_thief_seen" or stepName == "5_first_bonk" then
		Cinematic.caption("ftue.guide_thief")
		place("thief", 0.62, 0.58, px)
		place("michi", 0.48, 0.52, px * 0.8)
		if stepName == "4_thief_seen" then
			local t0 = os.clock()
			local conn: RBXScriptConnection
			conn = RunService.Heartbeat:Connect(function()
				if token ~= animToken or not sheet.Visible then
					conn:Disconnect()
					return
				end
				local alpha = math.clamp((os.clock() - t0) / 5.6, 0, 1)
				local x = 1.15 - (1.15 - 0.58) * alpha
				place("thief", x, 0.58, px)
				place("michi", x - 0.14, 0.5, px * 0.78)
				if alpha >= 1 then
					conn:Disconnect()
				end
			end)
		end
	elseif stepName == "6_first_income" then
		Cinematic.caption("ftue.guide_income")
		place("base", 0.32, 0.58, px)
		place("michi", 0.32, 0.42, px)
		place("jar", 0.68, 0.58, px)
		local rate = 9
		local michi = Pinatas.michi
		if typeof(michi) == "table" and typeof(michi.CandyPerSec) == "number" then
			rate = michi.CandyPerSec
		end
		stamp.Text = Locale.t("ftue.income", { n = tostring(rate) })
		stamp.Visible = true
		stamp.Position = UDim2.fromScale(0.32, 0.16)
		task.spawn(function()
			local t0 = os.clock()
			while token == animToken and sheet.Visible and os.clock() - t0 < 3.6 do
				local alpha = math.clamp((os.clock() - t0) / 3.6, 0, 1)
				if jarFill then
					jarFill.Size = UDim2.fromScale(0.64, 0.08 + alpha * 0.55)
				end
				task.wait(0.05)
			end
		end)
	elseif stepName == "7_first_collect" then
		Cinematic.caption("ftue.guide_income")
		place("jar", 0.5, 0.52, px + 16)
		if jarFill then
			jarFill.Size = UDim2.fromScale(0.64, 0.62)
		end
		stamp.Text = Locale.t("ftue.plus_candy", { n = "250" })
		stamp.Visible = true
	elseif stepName == "8_first_purchase" then
		Cinematic.caption("ftue.next")
		place("burrito", 0.42, 0.55, px)
		place("dragon", 0.82, 0.48, px * 0.7)
		local price = 110000
		local dragon = Pinatas.dragon
		if typeof(dragon) == "table" and typeof(dragon.Price) == "number" then
			price = dragon.Price
		end
		stamp.Text = Format(price)
		stamp.Visible = true
		stamp.Position = UDim2.fromScale(0.82, 0.22)
	end
end

function Cinematic.celebrate(stepName: string)
	if stepName == "3_first_claim" then
		stamp.Text = Locale.t("ftue.yours")
		stamp.Visible = true
		place("michi", 0.3, 0.48, if Metrics.get().compact then 72 else 96)
		place("base", 0.3, 0.66, 100)
	elseif stepName == "5_first_bonk" then
		slowLabel.Text = Locale.t("ftue.bonk")
		slowLabel.Visible = true
		letterTop.Size = UDim2.new(1, 0, 0, 18)
		letterBot.Size = UDim2.new(1, 0, 0, 18)
		local thief = actors.thief
		if thief then
			UIKit.tween(thief, 0.4, { Position = UDim2.fromScale(0.62, 0.34), Rotation = -18 }, Enum.EasingStyle.Quad)
		end
		task.delay(0.4, function()
			slowLabel.Visible = false
			letterTop.Size = UDim2.new(1, 0, 0, 0)
			letterBot.Size = UDim2.new(1, 0, 0, 0)
			if actors.thief then
				actors.thief.Visible = false
			end
			place("michi", 0.3, 0.48, 90)
			place("base", 0.28, 0.64, 100)
		end)
	elseif stepName == "8_first_purchase" then
		stamp.Text = Locale.t("ftue.summary")
		place("burrito", 0.3, 0.5, 90)
		place("base", 0.28, 0.66, 100)
	end
end

return Cinematic
