--!strict
-- Geometría del bate y del robo, la misma cuenta que Validators (producto punto y magnitud).
-- El server en vivo usa Validation → Validators para el ping; estos números se testean solos.

local Aim = {}

function Aim.distance(ax: number, ay: number, az: number, bx: number, by: number, bz: number): number
	local dx = ax - bx
	local dy = ay - by
	local dz = az - bz
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Aim.angleDeg(
	lx: number,
	ly: number,
	lz: number,
	fx: number,
	fy: number,
	fz: number,
	tx: number,
	ty: number,
	tz: number
): number
	local dx = tx - fx
	local dy = ty - fy
	local dz = tz - fz
	local mag = math.sqrt(dx * dx + dy * dy + dz * dz)
	if mag < 1e-3 then
		return 0
	end
	local lookMag = math.sqrt(lx * lx + ly * ly + lz * lz)
	if lookMag < 1e-6 then
		return 180
	end
	local dot = (lx * dx + ly * dy + lz * dz) / (lookMag * mag)
	return math.deg(math.acos(math.clamp(dot, -1, 1)))
end

function Aim.within(distance: number, maxDistance: number, slack: number): boolean
	return distance <= maxDistance + slack
end

function Aim.inFront(angleDeg: number, maxAngleDeg: number): boolean
	return angleDeg <= maxAngleDeg
end

return Aim
