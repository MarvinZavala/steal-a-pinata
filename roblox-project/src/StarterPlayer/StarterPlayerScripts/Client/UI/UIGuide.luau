--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")) :: any
local UIRoot = require(script.Parent.UIRoot)

local targets: { [string]: GuiObject } = {}
local current: string? = nil
local worldPosition: Vector3? = nil
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
		if not arrow then
			return
		end
		bob = math.sin(os.clock() * 6) * 8
		local stage = UIRoot.stage()
		if worldPosition ~= nil then
			local cam = workspace.CurrentCamera
			if cam == nil then
				arrow.Visible = false
				return
			end
			local screen, visible = cam:WorldToViewportPoint(worldPosition)
			local size = stage.AbsoluteSize
			local x = screen.X - stage.AbsolutePosition.X
			local y = screen.Y - stage.AbsolutePosition.Y
			if not visible then
				x = math.clamp(x, 28, math.max(28, size.X - 28))
				y = math.clamp(y, 28, math.max(28, size.Y - 28))
			end
			arrow.Visible = true
			arrow.Position = UDim2.fromOffset(x, y + bob)
			return
		end
		if not current then
			arrow.Visible = false
			return
		end
		local target = targets[current]
		if not target or not target.Parent or not target.Visible then
			arrow.Visible = false
			return
		end
		local center = target.AbsolutePosition + (target.AbsoluteSize / 2) - stage.AbsolutePosition
		arrow.Visible = true
		arrow.Position = UDim2.fromOffset(center.X, center.Y - target.AbsoluteSize.Y * 0.5 - 8 + bob)
	end)
end

function UIGuide.register(name: string, gui: GuiObject)
	targets[name] = gui
end

function UIGuide.pointAt(name: string?)
	current = name
	if name ~= nil then
		worldPosition = nil
	end
	if arrow then
		arrow.Visible = name ~= nil or worldPosition ~= nil
	end
end

function UIGuide.pointWorld(position: Vector3?)
	worldPosition = position
	if position ~= nil then
		current = nil
	end
	if arrow then
		arrow.Visible = position ~= nil or current ~= nil
	end
end

return UIGuide
