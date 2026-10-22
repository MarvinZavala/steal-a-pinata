--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Metrics = require(script.Parent.Metrics)

local UIRoot = {}

local stage: Frame
local dim: Frame
local layers: { [string]: Frame } = {}
local fit: UIScale
local host: ScreenGui

function UIRoot.mount()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	host = Instance.new("ScreenGui")
	host.Name = "FiestaUI"
	host.ResetOnSpawn = false
	host.IgnoreGuiInset = false
	host.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	host.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	host.DisplayOrder = 5
	host.Parent = playerGui

	dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 =
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Theme")).color.ink
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Visible = false
	dim.ZIndex = 1
	dim.Parent = host

	stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.BorderSizePixel = 0
	stage.Size = UDim2.fromScale(1, 1)
	stage.ZIndex = 2
	stage.ClipsDescendants = false
	stage.Parent = host

	fit = Instance.new("UIScale")
	fit.Name = "Fit"
	fit.Parent = stage

	local z: { [string]: number } = { Hud = 2, Menus = 20, Ftue = 30, Guide = 40, Toasts = 50 }
	for _, name in { "Hud", "Menus", "Ftue", "Guide", "Toasts" } do
		local layer = Instance.new("Frame")
		layer.Name = name
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.Size = UDim2.fromScale(1, 1)
		layer.ZIndex = z[name]
		layer.Parent = stage
		layers[name] = layer
	end

	Metrics.bind(stage)
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if stage.Size.X.Scale == 0 then
			UIRoot.refit()
		end
	end)
end

function UIRoot.layer(name: string): Frame
	return layers[name]
end

function UIRoot.stage(): Frame
	return stage
end

function UIRoot.refit()
	if stage.Size.X.Scale ~= 0 then
		fit.Scale = 1
		dim.Visible = false
		return
	end
	local size = stage.Size.X.Offset
	local height = stage.Size.Y.Offset
	if size < 1 or height < 1 then
		return
	end
	local bounds = host.AbsoluteSize
	local scale = math.min(bounds.X / size, bounds.Y / height) * 0.96
	fit.Scale = math.clamp(scale, 0.35, 2.4)
	dim.Visible = true
end

function UIRoot.setDevice(size: Vector2?)
	if not size then
		stage.AnchorPoint = Vector2.zero
		stage.Position = UDim2.fromScale(0, 0)
		stage.Size = UDim2.fromScale(1, 1)
		fit.Scale = 1
		dim.Visible = false
		return
	end
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(size.X, size.Y)
	UIRoot.refit()
end

return UIRoot
