--!strict
-- Flash de golpe. El confeti y el cartel ¡BONK! los crea el servidor
-- para que los vean todos; acá solo el golpe en pantalla.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))

local VFXController = {}

function VFXController.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "HitFlash"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromHex("#FFE14D")
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.Parent = gui

	local busy = false
	local function flash()
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			frame.BackgroundTransparency = 0.45
			for step = 1, 7 do
				frame.BackgroundTransparency = 0.45 + step * 0.07
				task.wait(0.03)
			end
			frame.BackgroundTransparency = 1
			busy = false
		end)
	end

	Remotes.get("Feedback").OnClientEvent:Connect(function(kind)
		if kind == "BONK" then
			flash()
		end
	end)
end

return VFXController
