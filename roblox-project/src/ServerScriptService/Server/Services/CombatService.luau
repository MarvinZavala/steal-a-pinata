--!strict
-- WP-07. El bate no hace daño: tumba, empuja y, si ya son los golpes
-- de esa rareza, suelta la piñata. El cooldown vive en el servidor.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local FairPlay = require(Shared:WaitForChild("Config"):WaitForChild("FairPlay"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local BatRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("BatRules"))
local BatSpam = require(Shared:WaitForChild("Gameplay"):WaitForChild("BatSpam"))

local Server = script.Parent.Parent
local Records = require(Server:WaitForChild("Data"):WaitForChild("Records"))
local Lifecycle = require(Server:WaitForChild("Adapters"):WaitForChild("Lifecycle"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local Validators = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Validators"))
local Logger = require(script.Parent:WaitForChild("AntiCheat"):WaitForChild("Logger"))
local Movement = require(Server:WaitForChild("World"):WaitForChild("Movement"))
local Juice = require(Server:WaitForChild("World"):WaitForChild("Juice"))
local StealService = require(script.Parent:WaitForChild("StealService"))

local CombatService = {}

local lastSwing: { [Player]: number } = {}
local spamState: { [Player]: BatSpam.State } = {}
local eventService: any = nil
local dataService: any = nil
local templates: { [string]: Tool } = {}

-- Malla importada por skin (art/export/props/bat_*.fbx → ServerStorage/Templates/Props).
local SKIN_MODEL = { wood = "bat_wood", gold = "bat_gold" }
-- Distancia del pomo a la mano: la malla tiene el pomo abajo y el barril arriba (art/scripts/props.py bat()).
local GRIP_FROM_KNOB = 0.6

-- Bate de Parts para cuando no se importó la malla (place recién armado con rojo build, CI).
local function makeTemplate(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bate"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Bate"
	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	tool:SetAttribute("Skin", "wood")
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 4.2, 0.45)
	handle.Color = Color3.fromHex("#E08A00")
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Parent = tool
	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Size = Vector3.new(0.9, 1.4, 0.9)
	barrel.Color = Color3.fromHex("#FFE6B8")
	barrel.Material = Enum.Material.Wood
	barrel.CanCollide = false
	barrel.Massless = true
	barrel.CFrame = handle.CFrame * CFrame.new(0, 2.2, 0)
	barrel.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = barrel
	weld.Parent = barrel
	tool.Parent = ServerStorage
	return tool
end

local function meshTemplate(skin: string): Tool?
	local name = SKIN_MODEL[skin]
	local folder = ServerStorage:FindFirstChild("Templates")
	local props = if folder ~= nil then folder:FindFirstChild("Props") else nil
	local model = if props ~= nil and name ~= nil then props:FindFirstChild(name) else nil
	local mesh = if model ~= nil then model:FindFirstChildWhichIsA("MeshPart", true) else nil
	if mesh == nil then
		return nil
	end
	local tool = Instance.new("Tool")
	tool.Name = "Bate"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Bate"
	local handle = mesh:Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Grip = CFrame.new(0, -handle.Size.Y / 2 + GRIP_FROM_KNOB, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	tool:SetAttribute("Skin", skin)
	return tool
end

local function skinOf(player: Player): string
	local data = if dataService ~= nil then dataService.profile(player) else nil
	if data ~= nil and data.Cosmetics ~= nil and data.Cosmetics.bat_oro == true and templates.gold ~= nil then
		return "gold"
	end
	return "wood"
end

local function give(player: Player, character: Model)
	local toolTemplate = templates[skinOf(player)]
	if toolTemplate == nil then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		local waited = player:WaitForChild("Backpack", 5)
		if waited == nil or not waited:IsA("Backpack") then
			return
		end
		backpack = waited
	end
	if backpack:FindFirstChild("Bate") == nil and character:FindFirstChild("Bate") == nil then
		local clone = toolTemplate:Clone()
		clone.Parent = backpack
	end
	task.defer(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local tool = backpack:FindFirstChild("Bate")
		if tool == nil then
			tool = character:FindFirstChild("Bate")
		end
		if humanoid ~= nil and tool ~= nil and tool:IsA("Tool") then
			humanoid:EquipTool(tool)
		end
	end)
end

-- El personaje puede aparecer antes de que cargue el perfil (sale de madera) y el bate de oro se puede
-- ganar a mitad de sesión. BaseService.pushState llama esto: si el skin cambió, se reemplaza el Bate.
function CombatService.refreshBat(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local current = character:FindFirstChild("Bate")
		or (if backpack ~= nil then backpack:FindFirstChild("Bate") else nil)
	if current == nil or current:GetAttribute("Skin") == skinOf(player) then
		return
	end
	current:Destroy()
	give(player, character)
end

function CombatService.trySwing(player: Player)
	local root = Validators.rootOf(player)
	if root == nil then
		return
	end
	local now = os.clock()
	local batCfg: BatSpam.Config = {
		WindowSec = FairPlay.Bat.WindowSec,
		MaxAttempts = FairPlay.Bat.MaxAttempts,
		MinIntervalSec = FairPlay.Bat.MinIntervalSec,
		BurstCount = FairPlay.Bat.BurstCount,
	}
	local observed, verdict = BatSpam.observe(spamState[player] or BatSpam.empty(), now, batCfg)
	spamState[player] = observed
	if verdict == "spam" then
		AntiCheatService.reportStrike(player, "bat_spam")
		lastSwing[player] = now
		return
	end
	local ready = now - (lastSwing[player] or 0) >= Economy.Bat.CooldownSec
	if not ready then
		return
	end
	local best: Player? = nil
	local bestDistance = math.huge
	local bestPosition: Vector3? = nil
	local nearest = math.huge
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = Validators.rootOf(other)
			if otherRoot ~= nil then
				local distance = (root.Position - otherRoot.Position).Magnitude
				local inFront = Validators.inFront(player, otherRoot.Position, Economy.Bat.MaxAngleDeg)
				if inFront and distance < nearest then
					nearest = distance
				end
				local allowed = AntiCheatService.authorize(player, "RequestSwing", otherRoot.Position)
				if allowed and distance < bestDistance then
					best = other
					bestDistance = distance
					bestPosition = otherRoot.Position
				end
			end
		end
	end
	lastSwing[player] = os.clock()
	Juice.sound(root.Position, Tuning.Sfx.Swing)
	if type(eventService) == "table" and type(eventService.onSwing) == "function" then
		eventService.onSwing(player, root.Position)
	end
	if best == nil or bestPosition == nil then
		if nearest < math.huge and BatRules.shouldLog(nearest, Economy.Bat.MaxDistance, "range") then
			Logger.flag(player, "RequestSwing.range", { distance = nearest })
		end
		return
	end
	local ok, reason = BatRules.evaluate({
		distance = math.min(bestDistance, Economy.Bat.MaxDistance),
		maxDistance = Economy.Bat.MaxDistance,
		inRange = true,
		inFront = true,
		cooldownReady = true,
	})
	if not ok then
		if BatRules.shouldLog(bestDistance, Economy.Bat.MaxDistance, reason) then
			Logger.flag(player, "RequestSwing.range", { distance = bestDistance, reason = reason })
		end
		return
	end
	local target = best
	local direction = bestPosition - root.Position
	local attacker = Records.get(player)
	local scale = 1
	if attacker ~= nil then
		scale = Economy.pushScale(attacker.ReFiestas, attacker.BatUpgrade)
		attacker.Stats.Bonks += 1
	end
	Movement.knock(target, direction, Economy.Bat.StunSec, function(): string
		if StealService.isCarrying(target) then
			return "carry"
		end
		return "normal"
	end, scale)
	local carry = StealService.peek(target)
	if carry ~= nil then
		carry.hitsTaken += 1
		if BatRules.shouldDrop(carry.hitsTaken, carry.hitsRequired) then
			StealService.drop(target)
		end
	end
	if target.Character ~= nil then
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromHex("#FFE14D")
		highlight.OutlineColor = Color3.fromHex("#FF3E9A")
		highlight.FillTransparency = 0.35
		highlight.Parent = target.Character
		Debris:AddItem(highlight, 0.28)
	end
	Juice.bonkSign(bestPosition)
	Juice.burst(bestPosition, 18)
	Juice.sound(bestPosition, Tuning.Sfx.Bonk)
	Juice.feedback("BONK", bestPosition)
end

function CombatService.init(services: { [string]: any })
	eventService = services.EventService
	dataService = services.DataService
	templates.wood = meshTemplate("wood") or makeTemplate()
	templates.gold = meshTemplate("gold")
	AntiCheatService.register("RequestSwing", function(player, _args)
		CombatService.trySwing(player)
	end)
	Lifecycle.onLeave(10, function(player)
		lastSwing[player] = nil
		spamState[player] = nil
		Movement.forget(player)
	end)
end

function CombatService.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			give(player, character)
		end)
		if player.Character ~= nil then
			give(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return CombatService
