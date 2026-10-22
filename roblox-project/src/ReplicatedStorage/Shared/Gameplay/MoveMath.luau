--!strict
-- Velocidad, arco del salto e impulso. Puro, para poder afirmar los números de Tuning.

local MoveMath = {}

function MoveMath.speed(mode: string, walk: number, carry: number): number
	if mode == "stun" then
		return 0
	end
	if mode == "carry" then
		return carry
	end
	return walk
end

function MoveMath.jumpVelocity(gravity: number, jumpHeight: number): number
	return math.sqrt(2 * gravity * jumpHeight)
end

function MoveMath.apex(velocity: number, gravity: number): number
	return (velocity * velocity) / (2 * gravity)
end

function MoveMath.airtime(velocity: number, gravity: number): number
	return (2 * velocity) / gravity
end

function MoveMath.impulse(
	dirX: number,
	dirZ: number,
	mass: number,
	horizontal: number,
	vertical: number
): (number, number, number)
	local mag = math.sqrt(dirX * dirX + dirZ * dirZ)
	local ix = 0
	local iz = 0
	if mag > 1e-6 then
		ix = (dirX / mag) * horizontal * mass
		iz = (dirZ / mag) * horizontal * mass
	end
	return ix, vertical * mass, iz
end

return MoveMath
