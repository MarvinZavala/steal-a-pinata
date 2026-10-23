--!strict
-- VFX/SFX que replica el servidor (todos los ven el confeti y el ¡BONK!).
-- El cliente suma shake y el flash. Texturas y sonidos son placeholders del motor.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))

local Juice = {}

local COLORS = {
	Color3.fromHex("#FF3E9A"),
	Color3.fromHex("#FFE14D"),
	Color3.fromHex("#16D3E8"),
	Color3.fromHex("#8BE530"),
	Color3.fromHex("#C59BFF"),
	Color3.fromHex("#FF7A1A"),
}

local function host(): Instance
	local world = workspace:FindFirstChild("World")
	local parent: Instance = if world ~= nil then world else workspace
	local folder = parent:FindFirstChild("FX")
	if folder == nil then
		local created = Instance.new("Folder")
		created.Name = "FX"
		created.Parent = parent
		folder = created
	end
	return folder
end

local function anchorAt(position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "FX"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.4, 0.4, 0.4)
	part.Position = position
	part.Parent = host()
	return part
end

function Juice.sound(position: Vector3, soundId: string)
	local part = anchorAt(position)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = Tuning.SfxVolume
	sound.RollOffMaxDistance = 90
	sound.Parent = part
	sound:Play()
	Debris:AddItem(part, 3)
end

function Juice.burst(position: Vector3, count: number)
	local part = anchorAt(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.35, 0.8)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -28, 0)
	emitter.LightEmission = 0.55
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.08),
	})
	emitter.Color = ColorSequence.new(COLORS[1], COLORS[2])
	emitter.Parent = part
	emitter:Emit(math.clamp(count, 1, 40))
	Debris:AddItem(part, 2)
end

function Juice.bonkSign(position: Vector3)
	local part = anchorAt(position + Vector3.new(0, 2.2, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 60)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text:SetAttribute("LKey", "toast.bonk")
	text.Text = "BONK"
	text.TextColor3 = Color3.fromHex("#FFE14D")
	text.TextStrokeColor3 = Color3.fromHex("#1B1430")
	text.TextStrokeTransparency = 0
	text.Parent = gui
	Debris:AddItem(part, 0.6)
end

function Juice.feedback(kind: string, position: Vector3)
	Remotes.get("Feedback"):FireAllClients(kind, { position = position })
end

function Juice.feedbackOne(player: Player, kind: string, position: Vector3)
	Remotes.get("Feedback"):FireClient(player, kind, { position = position })
end

function Juice.confetti(position: Vector3, soundId: string?)
	Juice.burst(position, Tuning.ConfettiCount)
	if soundId ~= nil then
		Juice.sound(position, soundId)
	end
	Juice.feedback("CONFETTI", position)
end

return Juice
