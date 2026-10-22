--!strict
-- Confeti de UI (tope 36, por debajo del límite de 40 partículas en móvil).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local SoundBus = require(script.Parent.Parent.UI.SoundBus)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local UIRoot = require(script.Parent.Parent.UI.UIRoot)
local UIState = require(script.Parent.Parent.UI.UIState)

local host: Frame
local alive = 0

local VFXController = {}

function VFXController.confetti(count: number, slow: boolean)
	if not host then
		return
	end
	local budget = math.min(count, 36)
	local colors = Theme.confetti
	for index = 1, budget do
		if alive >= 36 then
			break
		end
		alive += 1
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromOffset(8 + (index % 4) * 3, 12 + (index % 3) * 4)
		piece.Position = UDim2.new(math.random(), 0, -0.05, 0)
		piece.Rotation = math.random(0, 180)
		piece.BackgroundColor3 = colors[(index % #colors) + 1]
		piece.ZIndex = 4
		piece.Parent = host
		UIKit.corner(piece, 3)
		local duration = if slow then 1.5 else 0.85
		UIKit.tween(piece, duration, {
			Position = UDim2.new(math.random(), 0, 1.05, 0),
			Rotation = piece.Rotation + 180,
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quad)
		task.delay(duration + 0.05, function()
			alive = math.max(0, alive - 1)
			piece:Destroy()
		end)
	end
end

function VFXController.bonk()
	SoundBus.play("bonk")
	if not host then
		return
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.42)
	label.Size = UDim2.fromOffset(220, 70)
	label.Text = "BONK"
	label.TextSize = 64
	label.ZIndex = 8
	label.Parent = host
	Theme.outlineNumber(label)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	UIKit.tween(scale, 0.18, { Scale = 1.15 }, Enum.EasingStyle.Back)
	task.delay(0.55, function()
		UIKit.tween(label, 0.2, { TextTransparency = 1 })
		task.delay(0.22, function()
			label:Destroy()
		end)
	end)
end

function VFXController.start()
	host = Instance.new("Frame")
	host.Name = "Confetti"
	host.BackgroundTransparency = 1
	host.Size = UDim2.fromScale(1, 1)
	host.ZIndex = 3
	host.Active = false
	host.Parent = UIRoot.layer("Ftue")
	UIState.onFeedback(function(kind)
		if kind == "BONK" then
			VFXController.bonk()
			VFXController.confetti(20, true)
		elseif kind == "COLLECT" then
			SoundBus.play("candy")
			VFXController.confetti(12, false)
		elseif kind == "PURCHASE" or kind == "PURCHASED" then
			SoundBus.play("pop")
		end
	end)
end

return VFXController
