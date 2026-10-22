--!strict
-- Guion §10.1. El embudo sale por AnalyticsService en el cliente.
-- Con plaza y perfil, la intro usa la base real, la Pasarela y el pad.
-- El teatro de papel queda para el preview y para Studio sin mundo.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pinatas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Pinatas")) :: any
local FTUEScript =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("FTUEScript")) :: any
local CameraController = require(script.Parent.CameraController) :: any
local Cinematic = require(script.Parent.Parent.UI.Cinematic)
local Funnel = require(script.Parent.Parent.UI.Funnel)
local Intent = require(script.Parent.Parent.UI.Intent)
local UIBridge = require(script.Parent.Parent.UI.UIBridge)
local UIGuide = require(script.Parent.Parent.UI.UIGuide)
local UIState = require(script.Parent.Parent.UI.UIState)
local VFXController = require(script.Parent.VFXController) :: any

local playing = false
local forced = false
local dismissed = false
local sendRemote = false
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
	if sendRemote then
		UIBridge.ftueAction(action)
		return
	end
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

local function report(step: any)
	Funnel.log(step.index, step.name, not sendRemote and forced)
	if sendRemote then
		UIBridge.ftueStep(step.name)
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

local function ownPlot(): Model?
	local userId = Players.LocalPlayer.UserId
	for _, inst in CollectionService:GetTagged("FTUEBase") do
		if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == userId then
			return inst
		end
	end
	return nil
end

local function pointWorld(tag: string)
	local position = worldPoint(CollectionService:GetTagged(tag)[1])
	UIGuide.pointWorld(position)
end

local function owns(pinataId: string): boolean
	local owned = UIState.get().owned
	if typeof(owned) ~= "table" then
		return false
	end
	for _, item in owned do
		if typeof(item) == "table" and item.pinataId == pinataId then
			return true
		end
	end
	return false
end

local function waitUntil(token: number, timeout: number, pred: () -> boolean): string
	local t0 = os.clock()
	while token == runId do
		if pred() then
			return "ok"
		end
		if timeout > 0 and os.clock() - t0 >= timeout then
			return "timeout"
		end
		task.wait(0.1)
	end
	return "cancel"
end

local function near(tag: string, studs: number): boolean
	local position = worldPoint(CollectionService:GetTagged(tag)[1])
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if position == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - position).Magnitude <= studs
end

function FTUEController.isPlaying(): boolean
	return playing
end

function FTUEController.stop()
	runId += 1
	playing = false
	forced = false
	sendRemote = false
	waiting = ""
	dismissed = true
	Intent.bind(nil)
	Cinematic.setLive(false)
	Cinematic.setVisible(false)
	Cinematic.arm(nil)
	UIBridge.setOfflineIncome(true)
	CameraController.cancel()
end

local function finish(token: number)
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
	sendRemote = false
	Intent.bind(nil)
	Cinematic.arm(nil)
	Cinematic.setLive(false)
	Cinematic.setVisible(false)
	UIGuide.pointWorld(nil)
	UIBridge.setOfflineIncome(true)
end

local function playTheater(fromStep: number, token: number)
	Cinematic.setLive(false)
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
		elseif step.name == "6_first_income" and not UIBridge.isAuthoritative() then
			UIState.mutate(function(s)
				s.vaultStored = FTUEScript.CollectCandy
			end)
		elseif step.name == "8_first_purchase" and not UIBridge.isAuthoritative() then
			UIState.mutate(function(s)
				s.fiestaRemaining = FTUEScript.FiestaPreview
			end)
		end
		if step.mode == "auto" then
			report(step)
			if not sleep(step.seconds, token) then
				return
			end
		else
			if not sleep(step.seconds, token) then
				return
			end
			waiting = if step.action == "bonk" then "bonk" elseif step.action == "collect" then "collect" else "prompt"
			Cinematic.arm(step.promptKey)
			Cinematic.point(step.hud)
			local result = waitTap(token, 0)
			waiting = ""
			Cinematic.arm(nil)
			Cinematic.point(nil)
			if result ~= "tap" then
				return
			end
			report(step)
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
	finish(token)
end

local function playLive(token: number)
	Cinematic.setLive(true)
	Cinematic.setVisible(true)
	Cinematic.arm(nil)
	Intent.bind(function(name: string): boolean
		if not playing then
			return false
		end
		-- El bate del HUD tiene que llegar a RequestSwing. El bot lo saca la acción de intro.
		if waiting == "bonk" and (name == "bat" or name == "bonk") then
			tapped = true
			return false
		end
		return false
	end)

	local steps = FTUEScript.Steps
	local spawn = steps[1]
	Cinematic.caption("ftue.your_base")
	CameraController.swoop()
	VFXController.confetti(18, false)
	report(spawn)
	if not sleep(spawn.seconds, token) then
		return
	end

	local arrow = steps[2]
	Cinematic.caption("ftue.guide_arrow")
	pointWorld("Pasarela")
	local approached = waitUntil(token, 12, function()
		return near("Pasarela", 30)
	end)
	if approached == "cancel" then
		return
	end
	report(arrow)
	if not sleep(0.3, token) then
		return
	end

	local claim = steps[3]
	Cinematic.caption("ftue.guaranteed")
	pointWorld("Pasarela")
	local claimed = waitUntil(token, 60, function()
		return owns(FTUEScript.ClaimId)
	end)
	if claimed == "cancel" then
		return
	end
	report(claim)
	UIGuide.pointWorld(nil)
	VFXController.confetti(18, false)
	if not sleep(claim.after, token) then
		return
	end

	local thief = steps[4]
	Cinematic.caption("ftue.guide_thief")
	local plot = ownPlot()
	local thiefPart = CollectionService:GetTagged("FTUEThief")[1]
	UIGuide.pointWorld(worldPoint(thiefPart) or worldPoint(plot))
	report(thief)
	if not sleep(thief.seconds, token) then
		return
	end

	local bonk = steps[5]
	waiting = "bonk"
	Cinematic.caption("ftue.guide_thief")
	Cinematic.point("bat")
	local hit = waitTap(token, 30)
	waiting = ""
	Cinematic.point(nil)
	if hit == "cancel" then
		return
	end
	report(bonk)
	grant("bonk")
	CameraController.slowMo(FTUEScript.SlowMo)
	VFXController.confetti(24, true)
	VFXController.bonk()
	if not sleep(bonk.after, token) then
		return
	end

	local income = steps[6]
	Cinematic.caption("ftue.income", { n = tostring(pinataRate(FTUEScript.ClaimId)) })
	UIGuide.pointWorld(worldPoint(ownPlot()))
	report(income)
	if not sleep(income.seconds, token) then
		return
	end

	local collect = steps[7]
	local before = if typeof(UIState.get().candy) == "number" then UIState.get().candy else 0
	Cinematic.caption("ftue.pad")
	local collectPart = nil
	local livePlot = ownPlot()
	if livePlot then
		collectPart = livePlot:FindFirstChild("Collect", true)
	end
	UIGuide.pointWorld(worldPoint(collectPart))
	report(collect)
	local picked = waitUntil(token, 45, function()
		local candy = UIState.get().candy
		return typeof(candy) == "number" and candy > before + 0.5
	end)
	if picked == "cancel" then
		return
	end
	UIGuide.pointWorld(nil)
	if not sleep(collect.after, token) then
		return
	end

	local purchase = steps[8]
	Cinematic.caption("ftue.next")
	pointWorld("Pasarela")
	report(purchase)
	local bought = waitUntil(token, 60, function()
		return owns(FTUEScript.BuyId)
	end)
	if bought == "cancel" then
		return
	end
	UIGuide.pointWorld(nil)
	VFXController.confetti(18, false)
	if not sleep(purchase.after, token) then
		return
	end
	finish(token)
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
	local live = not preview and UIBridge.isAuthoritative()
	sendRemote = live
	Funnel.resetSession()
	UIBridge.setOfflineIncome(false)
	if not UIBridge.isAuthoritative() then
		UIState.mutate(function(s)
			if typeof(s.rookieShieldRemaining) ~= "number" or s.rookieShieldRemaining <= 0 then
				s.rookieShieldRemaining = FTUEScript.ShieldSec
			end
		end)
	end
	task.spawn(function()
		if live then
			playLive(token)
		else
			playTheater(fromStep, token)
		end
	end)
end

local function worldBuilt(): boolean
	return #CollectionService:GetTagged("Pasarela") > 0 or #CollectionService:GetTagged("FTUEBase") > 0
end

local function beginIfNeeded()
	if playing or dismissed then
		return
	end
	if UIState.get().ftueCompleted == true then
		dismissed = true
		return
	end
	FTUEController.play(nil)
end

function FTUEController.start()
	Cinematic.mount()
	Cinematic.setHandlers(function()
		tapped = true
	end, function()
		Funnel.skip(0)
		if sendRemote or UIBridge.isAuthoritative() then
			UIBridge.ftueAction("skip")
		end
		FTUEController.stop()
	end)
	if ReplicatedStorage:GetAttribute("SkipFTUE") == true then
		dismissed = true
		task.delay(1, function()
			UIBridge.ftueAction("skip")
		end)
		return
	end
	ReplicatedStorage:GetAttributeChangedSignal("SkipFTUE"):Connect(function()
		if ReplicatedStorage:GetAttribute("SkipFTUE") == true then
			UIBridge.ftueAction("skip")
			FTUEController.stop()
		end
	end)
	UIState.onChange(function(s)
		if s.ftueCompleted == true and playing and not forced then
			FTUEController.stop()
			return
		end
		if UIBridge.isAuthoritative() and s.ftueCompleted ~= true then
			beginIfNeeded()
		end
	end)
	task.delay(2.5, function()
		if playing or dismissed or UIState.get().ftueCompleted == true then
			return
		end
		if UIBridge.isAuthoritative() or not worldBuilt() then
			beginIfNeeded()
		end
	end)
end

return FTUEController
