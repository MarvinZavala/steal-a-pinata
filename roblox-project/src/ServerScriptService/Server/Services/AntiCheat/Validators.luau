--!strict
-- Validadores reutilizables (WP-10). Las funciones *Points no tocan instancias: las usan los tests.
-- withinDistance / inFront miden con la posición del SERVIDOR, nunca con un Vector3 del cliente.
local Validators = {}

function Validators.isFiniteNumber(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Validators.distanceBetween(x1: number, y1: number, z1: number, x2: number, y2: number, z2: number): number
	local dx = x2 - x1
	local dy = y2 - y1
	local dz = z2 - z1
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Validators.withinPoints(
	x1: number,
	y1: number,
	z1: number,
	x2: number,
	y2: number,
	z2: number,
	maxDist: number,
	slack: number
): boolean
	if not Validators.isFiniteNumber(maxDist) or not Validators.isFiniteNumber(slack) or maxDist < 0 or slack < 0 then
		return false
	end
	local distance = Validators.distanceBetween(x1, y1, z1, x2, y2, z2)
	if not Validators.isFiniteNumber(distance) then
		return false
	end
	return distance <= maxDist + slack
end

function Validators.inFrontPoints(
	lookX: number,
	lookY: number,
	lookZ: number,
	originX: number,
	originY: number,
	originZ: number,
	targetX: number,
	targetY: number,
	targetZ: number,
	maxAngleDeg: number
): boolean
	if not Validators.isFiniteNumber(maxAngleDeg) then
		return false
	end
	local dx = targetX - originX
	local dy = targetY - originY
	local dz = targetZ - originZ
	local magnitude = math.sqrt(dx * dx + dy * dy + dz * dz)
	if not Validators.isFiniteNumber(magnitude) then
		return false
	end
	if magnitude < 1e-3 then
		return true
	end
	local dot = lookX * dx / magnitude + lookY * dy / magnitude + lookZ * dz / magnitude
	return dot >= math.cos(math.rad(maxAngleDeg))
end

-- Studs extra por latencia, a la velocidad de caminata. El ping se recorta a 300 ms.
function Validators.pingSlack(pingSec: number, speed: number): number
	if not Validators.isFiniteNumber(pingSec) or not Validators.isFiniteNumber(speed) or speed < 0 then
		return 0
	end
	return speed * math.clamp(pingSec, 0, 0.3)
end

function Validators.positionSane(x: number, y: number, z: number, halfExtent: number): boolean
	if not Validators.isFiniteNumber(halfExtent) or halfExtent <= 0 then
		return false
	end
	if not Validators.isFiniteNumber(x) or not Validators.isFiniteNumber(y) or not Validators.isFiniteNumber(z) then
		return false
	end
	return math.abs(x) <= halfExtent and math.abs(y) <= halfExtent and math.abs(z) <= halfExtent
end

function Validators.speedSane(distance: number, dt: number, maxSpeed: number, slack: number): boolean
	if not Validators.isFiniteNumber(distance) or not Validators.isFiniteNumber(dt) or dt <= 0 then
		return false
	end
	if not Validators.isFiniteNumber(maxSpeed) or not Validators.isFiniteNumber(slack) or maxSpeed < 0 or slack < 0 then
		return false
	end
	return distance <= maxSpeed * dt + slack
end

function Validators.rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Validators.withinDistance(player: Player, target: Vector3, maxDist: number, walkSpeed: number): boolean
	local root = Validators.rootOf(player)
	if root == nil then
		return false
	end
	local ping = 0
	local ok, value = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and type(value) == "number" then
		ping = value
	end
	local slack = Validators.pingSlack(ping, walkSpeed)
	local position = root.Position
	return Validators.withinPoints(position.X, position.Y, position.Z, target.X, target.Y, target.Z, maxDist, slack)
end

function Validators.inFront(player: Player, target: Vector3, maxAngleDeg: number): boolean
	local root = Validators.rootOf(player)
	if root == nil then
		return false
	end
	local look = root.CFrame.LookVector
	local position = root.Position
	return Validators.inFrontPoints(
		look.X,
		look.Y,
		look.Z,
		position.X,
		position.Y,
		position.Z,
		target.X,
		target.Y,
		target.Z,
		maxAngleDeg
	)
end

return Validators
