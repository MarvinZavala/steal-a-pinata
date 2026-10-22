--!strict
-- Guion §10.1. El embudo sale por AnalyticsService en el cliente.
-- Las recompensas locales solo existen hasta que llega StateChanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pinatas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Pinatas")) :: any
local FTUEScript =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("FTUEScript")) :: any
local CameraController = require(script.Parent.CameraController) :: any
local Cinematic = require(script.Parent.Parent.UI.Cinematic)
local Funnel = require(script.Parent.Parent.UI.Funnel)
local Intent = require(script.Parent.Parent.UI.Intent)
local UIBridge = require(script.Parent.Parent.UI.UIBridge)
local UIState = require(script.Parent.Parent.UI.UIState)
local VFXController = require(script.Parent.VFXController) :: any

local playing = false
local forced = false
local dismissed = false
local runId = 0
local tapped = false
local waiting = ""

local FTUEController = {}

local function pinataRate(id: string): number
	local def = Pinatas[id]
	if typeof(def) == "table" and typeof(def.CandyPerSec) == "number" then
		return def.CandyPerSec
	end
	return 0
end

local function pinataPrice(id: string): number
	local def = Pinatas[id]
	if typeof(def) == "table" and typeof(def.Price) == "number" then
		return def.Price
	end
	return 0
end

local function grant(action: string)
	UIBridge.ftueAction(action)
	if UIBridge.isAuthoritative() then
		return
	end
	if action == "claim" then
		UIState.mutate(function(s)
			local owned = if typeof(s.owned) == "table" then s.owned else {}
			table.insert(owned, {
				uid = "ftue-michi",
				pinataId = FTUEScript.ClaimId,
				mutation = FTUEScript.ClaimMutation,
				pedestal = 1,
			})
			s.owned = owned
			s.candyPerSec = pinataRate(FTUEScript.ClaimId)
		end)
	elseif action == "collect" then
		UIState.mutate(function(s)
			s.candy = (if typeof(s.candy) == "number" then s.candy else 0) + FTUEScript.CollectCandy
			s.vaultStored = 0
		end)
		UIState.pushFeedback("COLLECT", { amount = FTUEScript.CollectCandy })
	elseif action == "buy" then
		local price = pinataPrice(FTUEScript.BuyId)
		UIState.mutate(function(s)
			local candy = if typeof(s.candy) == "number" then s.candy else 0
			s.candy = math.max(0, candy - price)
			local owned = if typeof(s.owned) == "table" then s.owned else {}
			table.insert(owned, {
				uid = "ftue-burrito",
				pinataId = FTUEScript.BuyId,
				mutation = "None",
				pedestal = 2,
			})
			s.owned = owned
			s.candyPerSec = pinataRate(FTUEScript.ClaimId) + pinataRate(FTUEScript.BuyId)
		end)
	elseif action == "complete" then
		UIState.mutate(function(s)
			s.ftueCompleted = true
			if typeof(s.rookieShieldRemaining) ~= "number" or s.rookieShieldRemaining <= 0 then
				s.rookieShieldRemaining = FTUEScript.ShieldSec
			end
		end)
	end
end

local function sleep(seconds: number, token: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if token ~= runId then
			return false
		end
		task.wait(0.05)
	end
	return token == runId
end

local function waitTap(token: number, timeout: number): string
	tapped = false
	local t0 = os.clock()
	while token == runId and not tapped do
		if timeout > 0 and os.clock() - t0 >= timeout then
			return "timeout"
		end
		task.wait(0.05)
	end
	if token ~= runId then
		return "cancel"
	end
	return "tap"
end

function FTUEController.isPlaying(): boolean
	return playing
end

function FTUEController.stop()
	runId += 1
	playing = false
	forced = false
	waiting = ""
	dismissed = true
	Intent.bind(nil)
	Cinematic.setVisible(false)
	Cinematic.arm(nil)
	UIBridge.setOfflineIncome(true)
	CameraController.cancel()
end

function FTUEController.play(options: { preview: boolean?, from: number? }?)
	local preview = options ~= nil and options.preview == true
	local fromStep = if options and typeof(options.from) == "number" then options.from else 1
	if playing then
		runId += 1
	end
	playing = true
	forced = preview
	dismissed = false
	runId += 1
	local token = runId
	Funnel.resetSession()
	UIBridge.setOfflineIncome(false)
	if not UIBridge.isAuthoritative() then
		UIState.mutate(function(s)
			if typeof(s.rookieShieldRemaining) ~= "number" or s.rookieShieldRemaining <= 0 then
				s.rookieShieldRemaining = FTUEScript.ShieldSec
			end
		end)
	end
	Cinematic.setVisible(true)
	Intent.bind(function(name: string): boolean
		if not playing then
			return false
		end
		if waiting == "bonk" and (name == "bat" or name == "bonk") then
			tapped = true
			return true
		end
		if waiting == "collect" and name == "collect" then
			tapped = true
			return true
		end
		return false
	end)

	task.spawn(function()
		for _, step in FTUEScript.Steps do
			if token ~= runId then
				return
			end
			if step.index < fromStep then
				continue
			end
			Cinematic.show(step.name)
			if step.name == "1_spawn" then
				CameraController.swoop()
				VFXController.confetti(28, false)
			elseif step.name == "6_first_income" then
				if not UIBridge.isAuthoritative() then
					UIState.mutate(function(s)
						s.vaultStored = FTUEScript.CollectCandy
					end)
				end
			elseif step.name == "8_first_purchase" then
				if not UIBridge.isAuthoritative() then
					UIState.mutate(function(s)
						s.fiestaRemaining = FTUEScript.FiestaPreview
					end)
				end
			end
			if step.mode == "auto" then
				Funnel.log(step.index, step.name, preview)
				UIBridge.ftueStep(step.name)
				if not sleep(step.seconds, token) then
					return
				end
			else
				if not sleep(step.seconds, token) then
					return
				end
				waiting = if step.action == "bonk"
					then "bonk"
					elseif step.action == "collect" then "collect"
					else "prompt"
				Cinematic.arm(step.promptKey)
				Cinematic.point(step.hud)
				local result = waitTap(token, 0)
				waiting = ""
				Cinematic.arm(nil)
				Cinematic.point(nil)
				if result ~= "tap" then
					return
				end
				Funnel.log(step.index, step.name, preview)
				UIBridge.ftueStep(step.name)
				if step.action then
					grant(step.action)
				end
				if step.name == "5_first_bonk" then
					CameraController.slowMo(FTUEScript.SlowMo)
					VFXController.confetti(36, true)
					VFXController.bonk()
				elseif step.name == "3_first_claim" or step.name == "8_first_purchase" then
					VFXController.confetti(18, false)
				end
				Cinematic.celebrate(step.name)
				if not sleep(step.after, token) then
					return
				end
			end
		end
		if token ~= runId then
			return
		end
		Cinematic.caption("ftue.summary")
		Cinematic.arm("ftue.play")
		waitTap(token, 3.2)
		if token ~= runId then
			return
		end
		grant("complete")
		playing = false
		waiting = ""
		dismissed = true
		forced = false
		Intent.bind(nil)
		Cinematic.arm(nil)
		Cinematic.setVisible(false)
		UIBridge.setOfflineIncome(true)
	end)
end

function FTUEController.start()
	Cinematic.mount()
	Cinematic.setHandlers(function()
		tapped = true
	end, function()
		local step = 0
		Funnel.skip(step)
		FTUEController.stop()
	end)
	if ReplicatedStorage:GetAttribute("SkipFTUE") == true then
		dismissed = true
		return
	end
	ReplicatedStorage:GetAttributeChangedSignal("SkipFTUE"):Connect(function()
		if ReplicatedStorage:GetAttribute("SkipFTUE") == true then
			FTUEController.stop()
		end
	end)
	UIState.onChange(function(s)
		if s.ftueCompleted == true and playing and not forced then
			FTUEController.stop()
		end
	end)
	task.delay(0.45, function()
		if playing or dismissed then
			return
		end
		if UIState.get().ftueCompleted == true then
			return
		end
		FTUEController.play(nil)
	end)
end

return FTUEController
