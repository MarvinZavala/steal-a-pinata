--!strict
-- Bootstrap del cliente. El cliente SOLO presenta y manda intenciones vía Remotes.fireServer.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
task.spawn(Remotes.init)

local ORDER = { "HUDController", "ShopController", "FTUEController", "VFXController", "CameraController" }
for _, name in ORDER do
	local c = require(script.Controllers:FindFirstChild(name)) :: any
	if c.start then
		task.spawn(c.start)
	end
end
