--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format")) :: any
local Locale = require(script.Parent.Locale)
local UIRoot = require(script.Parent.UIRoot)
local UIKit = require(script.Parent.UIKit)
local UIState = require(script.Parent.UIState)
local Metrics = require(script.Parent.Metrics)

local rack: Frame
local cards: { Frame } = {}

local Toast = {}

local function kindColor(kind: string): Color3
	if kind == "bad" then
		return Theme.color.chili
	elseif kind == "legend" or kind == "announce" then
		return Theme.color.gold
	elseif kind == "good" then
		return Theme.color.lime
	end
	return Theme.color.cream
end

local function restack(intro: boolean?)
	local m = Metrics.get()
	local y0 = m.safeTop + m.margin + m.candyH + 8
	for index, card in cards do
		local target = UDim2.new(0.5, 0, 0, y0 + (index - 1) * (m.chip + 8))
		if intro and index == 1 then
			card.Position = UDim2.new(0.5, 0, 0, -40)
			UIKit.tween(card, 0.28, { Position = target }, Enum.EasingStyle.Back)
		else
			card.Position = target
		end
	end
end

function Toast.push(kind: string, text: string)
	if text == "" then
		return
	end
	if #text > 90 then
		text = string.sub(text, 1, 90)
	end
	local m = Metrics.get()
	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(math.min(420, m.w - m.margin * 4), m.chip + 8)
	root.ZIndex = 6
	root.Parent = rack

	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = Theme.color.ink
	shadow.BackgroundTransparency = 0.75
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Parent = root
	UIKit.corner(shadow, m.radius)

	local face = Instance.new("Frame")
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = kindColor(kind)
	face.BorderSizePixel = 0
	face.ZIndex = 2
	face.Parent = root
	UIKit.corner(face, m.radius)
	UIKit.stroke(face, Theme.color.white, m.stroke)

	local label = UIKit.label(face, text, "body", m.body, Theme.color.ink)
	label.Size = UDim2.new(1, -20, 1, -6)
	label.Position = UDim2.fromOffset(10, 3)
	if kind == "bad" or kind == "announce" then
		Theme.apply(label, "body", Theme.color.white)
		label.TextStrokeColor3 = Theme.color.ink
		label.TextStrokeTransparency = 0
	end

	table.insert(cards, 1, root)
	while #cards > 4 do
		local old = table.remove(cards)
		if old then
			old:Destroy()
		end
	end
	restack(true)
	task.delay(if kind == "announce" then 4.2 else 3.1, function()
		local index = table.find(cards, root)
		if index then
			table.remove(cards, index)
		end
		if root.Parent then
			UIKit.tween(root, 0.2, { BackgroundTransparency = 1 })
			task.delay(0.22, function()
				root:Destroy()
				restack()
			end)
		end
	end)
end

local function stringArgs(raw: any): { [string]: string }?
	if typeof(raw) ~= "table" then
		return nil
	end
	local args: { [string]: string } = {}
	for key, value in raw do
		if typeof(key) == "string" then
			args[key] = tostring(value)
		end
	end
	return args
end

local function announceText(raw: string): string
	if raw == "" then
		return Locale.t("hud.fiesta_now")
	end
	if Locale.has(raw) then
		return Locale.t(raw)
	end
	local key, rest = string.match(raw, "^([%w%._]+):(.*)$")
	if key == "announce.runway" and rest ~= nil and rest ~= "" then
		return Locale.t("announce.runway", { name = Locale.pinataName(rest) })
	elseif (key == "announce.luck" or key == "announce.golden") and rest ~= nil then
		return Locale.t(key, { name = rest })
	end
	return raw
end

local function onFeedback(kind: string, payload: { [string]: any })
	if kind == "BONK" then
		Toast.push("legend", Locale.t("toast.bonk"))
	elseif kind == "ROBBED" then
		Toast.push("bad", Locale.t("toast.robbed"))
	elseif kind == "PURCHASE" or kind == "PURCHASED" then
		Toast.push("good", Locale.t("toast.purchase"))
	elseif kind == "COLLECT" then
		local amount = if typeof(payload.amount) == "number" then payload.amount else 0
		Toast.push("good", Locale.t("toast.collect", { n = Format(amount) }))
	elseif kind == "RETURNED" then
		Toast.push("good", Locale.t("toast.returned"))
	elseif kind == "DENIED" then
		local key = payload.key
		if typeof(key) == "string" and Locale.has("deny." .. key) then
			Toast.push("bad", Locale.t("deny." .. key))
		elseif typeof(key) == "string" and Locale.has(key) then
			Toast.push("bad", Locale.t(key))
		elseif typeof(payload.text) == "string" then
			Toast.push("bad", string.sub(payload.text, 1, 90))
		else
			Toast.push("bad", Locale.t("toast.denied"))
		end
	elseif kind == "ANNOUNCE" then
		local raw = if typeof(payload.text) == "string" then payload.text else ""
		Toast.push("announce", announceText(raw))
	elseif kind == "TOAST" then
		if typeof(payload.key) == "string" and Locale.has(payload.key) then
			Toast.push(
				if typeof(payload.kind) == "string" then payload.kind else "info",
				Locale.t(payload.key, stringArgs(payload.args))
			)
		elseif typeof(payload.text) == "string" then
			Toast.push("info", payload.text)
		end
	end
end

function Toast.start()
	rack = Instance.new("Frame")
	rack.Name = "Rack"
	rack.BackgroundTransparency = 1
	rack.Size = UDim2.fromScale(1, 1)
	rack.ZIndex = 6
	rack.Parent = UIRoot.layer("Toasts")
	UIState.onFeedback(onFeedback)
	Metrics.onChange(function()
		restack()
	end)
end

return Toast
