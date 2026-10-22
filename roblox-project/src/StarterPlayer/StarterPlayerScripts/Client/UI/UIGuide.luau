--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local UIRoot = require(script.Parent.UIRoot)

local targets: { [string]: GuiObject } = {}
local current: string? = nil
local arrow: TextLabel
local bob = 0

local UIGuide = {}

function UIGuide.mount()
	local layer = UIRoot.layer("Guide")
	arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 1)
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromOffset(54, 54)
	arrow.Text = "▼"
	arrow.TextSize = 42
	arrow.Visible = false
	arrow.ZIndex = 8
	arrow.Parent = layer
	Theme.apply(arrow, "display", Theme.color.fiesta_pink)
	arrow.TextStrokeColor3 = Theme.color.ink
	arrow.TextStrokeTransparency = 0
	RunService.Heartbeat:Connect(function()
		if not current or not arrow.Visible then
			return
		end
		local target = targets[current]
		if not target or not target.Parent or not target.Visible then
			arrow.Visible = false
			return
		end
		bob = math.sin(os.clock() * 6) * 8
		local stage = UIRoot.stage()
		local center = target.AbsolutePosition + (target.AbsoluteSize / 2) - stage.AbsolutePosition
		arrow.Position = UDim2.fromOffset(center.X, center.Y - target.AbsoluteSize.Y * 0.5 - 8 + bob)
	end)
end

function UIGuide.register(name: string, gui: GuiObject)
	targets[name] = gui
end

function UIGuide.pointAt(name: string?)
	current = name
	if arrow then
		arrow.Visible = name ~= nil
	end
end

return UIGuide
