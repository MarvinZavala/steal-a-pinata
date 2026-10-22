--!strict
-- WP-07. El bate no hace daño: tumba, empuja y, si ya son los golpes
-- de esa rareza, suelta la piñata. El cooldown vive en el servidor.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local BatRules = require(Shared:WaitForChild("Gameplay"):WaitForChild("BatRules"))

local Server = script.Parent.Parent
local Validation = require(Server:WaitForChild("Adapters"):WaitForChild("Validation"))
local Lifecycle = require(Server:WaitForChild("Adapters"):WaitForChild("Lifecycle"))
local Movement = require(Server:WaitForChild("World"):WaitForChild("Movement"))
local Juice = require(Server:WaitForChild("World"):WaitForChild("Juice"))
local StealService = require(script.Parent:WaitForChild("StealService"))

local CombatService = {}

local lastSwing: { [Player]: number } = {}
local template: Tool? = nil

local function makeTemplate(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bate"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Bate"
	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-90), 0, 0)
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

local function give(player: Player, character: Model)
	local toolTemplate = template
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

function CombatService.trySwing(player: Player)
	if not Validation.allow(player, "RequestSwing") then
		return
	end
	local root = Validation.root(player)
	if root == nil then
		return
	end
	local ready = os.clock() - (lastSwing[player] or 0) >= Economy.Bat.CooldownSec
	if not ready then
		return
	end
	local best: Player? = nil
	local bestDistance = math.huge
	local bestPosition: Vector3? = nil
	local nearest = math.huge
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local otherRoot = Validation.root(other)
			if otherRoot ~= nil then
				local distance = (root.Position - otherRoot.Position).Magnitude
				local inFront = Validation.inFront(player, otherRoot.Position, Economy.Bat.MaxAngleDeg)
				if inFront and distance < nearest then
					nearest = distance
				end
				local inRange = Validation.inRange(player, otherRoot.Position, Economy.Bat.MaxDistance)
				if inFront and inRange and distance < bestDistance then
					best = other
					bestDistance = distance
					bestPosition = otherRoot.Position
				end
			end
		end
	end
	lastSwing[player] = os.clock()
	Juice.sound(root.Position, Tuning.Sfx.Swing)
	if best == nil or bestPosition == nil then
		if nearest < math.huge and BatRules.shouldLog(nearest, Economy.Bat.MaxDistance, "range") then
			Validation.flag(player, "RequestSwing.range", { distance = nearest })
		end
		return
	end
	local ok, reason = BatRules.evaluate({
		distance = bestDistance,
		maxDistance = Economy.Bat.MaxDistance,
		inRange = true,
		inFront = true,
		cooldownReady = true,
	})
	if not ok then
		if BatRules.shouldLog(bestDistance, Economy.Bat.MaxDistance, reason) then
			Validation.flag(player, "RequestSwing.range", { distance = bestDistance, reason = reason })
		end
		return
	end
	local target = best
	local direction = bestPosition - root.Position
	Movement.knock(target, direction, Economy.Bat.StunSec, function(): string
		if StealService.isCarrying(target) then
			return "carry"
		end
		return "normal"
	end)
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

function CombatService.init(_services: { [string]: any })
	template = makeTemplate()
	Lifecycle.onLeave(10, function(player)
		lastSwing[player] = nil
		Movement.forget(player)
	end)
end

function CombatService.start()
	Remotes.get("RequestSwing").OnServerEvent:Connect(function(player)
		CombatService.trySwing(player)
	end)
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
