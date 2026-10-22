--!strict
-- Bootstrap del cliente. El cliente SOLO presenta y manda intenciones vía Remotes.fireServer.
-- El HUD se monta antes del FTUE para que las flechas encuentren sus botones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Remotes"))
local DailyPanel = require(script.UI.DailyPanel)
local FiestaPanel = require(script.UI.FiestaPanel)
local Locale = require(script.UI.Locale)
local Toast = require(script.UI.Toast)
local UIBridge = require(script.UI.UIBridge)
local UIGuide = require(script.UI.UIGuide)
local UIKit = require(script.UI.UIKit)
local UIRoot = require(script.UI.UIRoot)

local CameraController = require(script.Controllers.CameraController)
local FTUEController = require(script.Controllers.FTUEController)
local HUDController = require(script.Controllers.HUDController)
local ShopController = require(script.Controllers.ShopController)
local UIPreviewController = require(script.Controllers.UIPreviewController)
local VFXController = require(script.Controllers.VFXController)

task.spawn(Remotes.init)

Locale.install()
Locale.watchWorld()
UIRoot.mount()
UIKit.bindEffects()
UIGuide.mount()
Toast.start()

DailyPanel.start()
FiestaPanel.start()
HUDController.start()
ShopController.start()
VFXController.start()
CameraController.start()
FTUEController.start()

local function previewAllowed(): boolean
	return RunService:IsStudio() or ReplicatedStorage:GetAttribute("UIPreview") == true
end

if previewAllowed() then
	UIPreviewController.start()
else
	ReplicatedStorage:GetAttributeChangedSignal("UIPreview"):Connect(function()
		if previewAllowed() then
			UIPreviewController.start()
		end
	end)
end

task.spawn(UIBridge.start)
