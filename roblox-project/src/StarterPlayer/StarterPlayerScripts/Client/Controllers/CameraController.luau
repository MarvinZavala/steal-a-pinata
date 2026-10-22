--!strict
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local UIState = require(script.Parent.Parent.UI.UIState)

local savedType: Enum.CameraType? = nil
local savedFov: number? = nil
local token = 0

local CameraController = {}

local function camera(): Camera?
	return workspace.CurrentCamera
end

local function remember(cam: Camera)
	if not savedType then
		savedType = cam.CameraType
		savedFov = cam.FieldOfView
	end
end

function CameraController.cancel()
	token += 1
	local cam = camera()
	if not cam then
		return
	end
	if savedType then
		cam.CameraType = savedType
	else
		cam.CameraType = Enum.CameraType.Custom
	end
	if savedFov then
		cam.FieldOfView = savedFov
	end
	savedType = nil
	savedFov = nil
end

local function worldPoint(inst: Instance?): Vector3?
	if inst == nil then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst.Position
	end
	if inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local function ownBasePoint(): Vector3?
	local userId = Players.LocalPlayer.UserId
	for _, inst in CollectionService:GetTagged("FTUEBase") do
		if inst:GetAttribute("OwnerUserId") == userId then
			return worldPoint(inst)
		end
	end
	return nil
end

function CameraController.swoop()
	local cam = camera()
	if not cam then
		return
	end
	local fountainPos = worldPoint(CollectionService:GetTagged("FTUEFountain")[1])
	local basePos = ownBasePoint()
	if fountainPos == nil or basePos == nil then
		return
	end
	local settings = UIState.get().settings
	if typeof(settings) == "table" and settings.reduceMotion == true then
		return
	end
	token += 1
	local id = token
	remember(cam)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(fountainPos + Vector3.new(0, 18, 22), fountainPos)
	local goal = CFrame.lookAt(basePos + Vector3.new(0, 12, 18), basePos + Vector3.new(0, 2, 0))
	UIKit.tween(cam, 2.4, { CFrame = goal }, Enum.EasingStyle.Quad)
	task.delay(2.7, function()
		if id ~= token then
			return
		end
		CameraController.cancel()
	end)
end

function CameraController.slowMo(seconds: number)
	local cam = camera()
	if not cam then
		return
	end
	local settings = UIState.get().settings
	if typeof(settings) == "table" and settings.reduceMotion == true then
		return
	end
	remember(cam)
	local baseFov = cam.FieldOfView
	cam.FieldOfView = math.max(46, baseFov - 14)
	task.delay(seconds, function()
		if cam.Parent and savedFov then
			cam.FieldOfView = savedFov
		end
	end)
end

function CameraController.shake()
	local settings = UIState.get().settings
	if typeof(settings) ~= "table" or settings.cameraShake ~= true or settings.reduceMotion == true then
		return
	end
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.CameraOffset = Vector3.new(0.35, -0.22, 0)
	task.delay(0.12, function()
		if humanoid.Parent then
			humanoid.CameraOffset = Vector3.zero
		end
	end)
end

function CameraController.start()
	-- La picada y el slow-mo los dispara el FTUE. El BONK del servidor sacude acá.
	local UIStateModule = UIState
	UIStateModule.onFeedback(function(kind)
		if kind == "BONK" or kind == "LAND" then
			CameraController.shake()
		end
	end)
end

return CameraController
