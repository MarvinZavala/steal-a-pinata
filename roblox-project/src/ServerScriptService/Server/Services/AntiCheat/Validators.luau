--!strict
-- Validadores reutilizables (WP-10). Todos usan posiciones del SERVIDOR.
local Validators = {}

function Validators.isFiniteNumber(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Validators.rootOf(player: Player): BasePart?
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return if hrp and hrp:IsA("BasePart") then hrp else nil
end

-- Distancia con tolerancia por latencia (studs extra por cada 100 ms de ping)
function Validators.withinDistance(player: Player, target: Vector3, maxDist: number): boolean
	local root = Validators.rootOf(player)
	if not root then
		return false
	end
	local pingSec = player:GetNetworkPing()
	local slack = 16 * math.clamp(pingSec, 0, 0.3) -- velocidad normal * ping
	return (root.Position - target).Magnitude <= maxDist + slack
end

function Validators.inFront(player: Player, target: Vector3, maxAngleDeg: number): boolean
	local root = Validators.rootOf(player)
	if not root then
		return false
	end
	local dir = target - root.Position
	if dir.Magnitude < 1e-3 then
		return true
	end
	local dot = root.CFrame.LookVector:Dot(dir.Unit)
	return dot >= math.cos(math.rad(maxAngleDeg))
end

return Validators
