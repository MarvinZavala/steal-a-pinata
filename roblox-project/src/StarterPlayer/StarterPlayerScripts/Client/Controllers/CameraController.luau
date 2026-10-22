--!strict
-- Shake chico. No mueve la cámara de verdad: suma un offset que se apaga solo.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))

local CameraController = {}

local amplitude = 0
local untilClock = 0

function CameraController.shake(amount: number, duration: number)
	amplitude = math.max(amplitude, amount)
	untilClock = math.max(untilClock, os.clock() + duration)
end

function CameraController.start()
	RunService:BindToRenderStep("PinataCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local left = untilClock - os.clock()
		if left <= 0 or amplitude <= 0 then
			amplitude = 0
			return
		end
		local mag = amplitude * math.clamp(left / 0.2, 0, 1)
		local offset = CFrame.new((math.random() - 0.5) * 2 * mag, (math.random() - 0.5) * 2 * mag, 0)
		camera.CFrame = camera.CFrame * offset
	end)

	Remotes.get("Feedback").OnClientEvent:Connect(function(kind)
		if kind == "BONK" then
			CameraController.shake(Tuning.Shake.BonkAmplitude, Tuning.Shake.BonkDuration)
		elseif kind == "LAND" then
			CameraController.shake(Tuning.Shake.LandAmplitude, Tuning.Shake.LandDuration)
		end
	end)
end

return CameraController
