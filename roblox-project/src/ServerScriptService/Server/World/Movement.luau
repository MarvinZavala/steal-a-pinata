--!strict
-- Gravedad, salto y velocidad. El servidor los vuelve a aplicar: el cliente no manda.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local MoveMath = require(Shared:WaitForChild("Gameplay"):WaitForChild("MoveMath"))
local Juice = require(script.Parent:WaitForChild("Juice"))

local Movement = {}

local modeOf: { [Player]: string } = {}
local tokenOf: { [Player]: {} } = {}

local function desiredSpeed(mode: string): number
	return MoveMath.speed(mode, Tuning.WalkSpeed, Tuning.CarrySpeed)
end

local function applySpeed(character: Model, mode: string)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	humanoid.WalkSpeed = desiredSpeed(mode)
end

function Movement.applyWorld()
	workspace.Gravity = Tuning.Gravity
	workspace.FallenPartsDestroyHeight = Tuning.FallenPartsDestroyHeight
	local starter = game:GetService("StarterPlayer")
	starter.CharacterWalkSpeed = Tuning.WalkSpeed
	starter.CharacterJumpHeight = Tuning.JumpHeight
	starter.CharacterUseJumpPower = false
end

function Movement.setMode(player: Player, mode: string)
	modeOf[player] = mode
	local character = player.Character
	if character ~= nil then
		applySpeed(character, mode)
	end
end

function Movement.mode(player: Player): string
	return modeOf[player] or "normal"
end

function Movement.forget(player: Player)
	modeOf[player] = nil
	tokenOf[player] = nil
end

function Movement.watch(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 8)
	local root = character:WaitForChild("HumanoidRootPart", 8)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	if root == nil or not root:IsA("BasePart") then
		return
	end
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Tuning.JumpHeight
	humanoid.JumpPower = MoveMath.jumpVelocity(Tuning.Gravity, Tuning.JumpHeight)
	applySpeed(character, modeOf[player] or "normal")

	local phys = Tuning.Phys
	local props =
		PhysicalProperties.new(phys.Density, phys.Friction, phys.Elasticity, phys.FrictionWeight, phys.ElasticityWeight)
	local function soften(inst: Instance)
		if inst:IsA("BasePart") then
			inst.CustomPhysicalProperties = props
		end
	end
	for _, desc in character:GetDescendants() do
		soften(desc)
	end
	character.DescendantAdded:Connect(soften)

	local peak = 0
	local falling = false
	local heartbeat: RBXScriptConnection
	heartbeat = RunService.Heartbeat:Connect(function()
		if character.Parent == nil or humanoid.Parent == nil then
			heartbeat:Disconnect()
			return
		end
		local want = desiredSpeed(modeOf[player] or "normal")
		if humanoid.Health > 0 and humanoid.WalkSpeed ~= want then
			humanoid.WalkSpeed = want
		end
		if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
			falling = true
			peak = math.min(peak, root.AssemblyLinearVelocity.Y)
		end
	end)

	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed and falling then
			falling = false
			local impact = -peak
			peak = 0
			local velocity = root.AssemblyLinearVelocity
			if velocity.Y > 0 then
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
			end
			if impact >= Tuning.LandHardSpeed then
				Juice.burst(root.Position, 10)
				Juice.feedbackOne(player, "LAND", root.Position)
			end
		end
	end)

	humanoid.Died:Connect(function()
		heartbeat:Disconnect()
	end)
end

function Movement.knock(player: Player, direction: Vector3, stunSec: number, restore: () -> string)
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return
	end
	local token = {}
	tokenOf[player] = token
	Movement.setMode(player, "stun")
	humanoid.PlatformStand = true
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local mass = root.AssemblyMass
	if mass < 0.1 then
		mass = 1
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		local look = root.CFrame.LookVector
		flat = Vector3.new(look.X, 0, look.Z)
	end
	local ix, iy, iz = MoveMath.impulse(flat.X, flat.Z, mass, Tuning.KnockbackHorizontal, Tuning.KnockbackVertical)
	root:ApplyImpulse(Vector3.new(ix, iy, iz))
	task.delay(stunSec, function()
		if tokenOf[player] ~= token then
			return
		end
		tokenOf[player] = nil
		if humanoid.Parent ~= nil then
			humanoid.PlatformStand = false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			pcall(function()
				root:SetNetworkOwner(player)
			end)
		end
		if player.Parent ~= nil then
			Movement.setMode(player, restore())
		end
	end)
end

return Movement
