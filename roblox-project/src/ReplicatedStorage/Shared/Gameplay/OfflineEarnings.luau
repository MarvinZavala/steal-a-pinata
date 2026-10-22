--!strict
-- Ganancias offline (GDD §4.2): 50% del ritmo, tope de horas.
-- "No se pierde nada" es responsabilidad de quien guarda el inventario; aquí solo se calcula el dulce.

local OfflineEarnings = {}

function OfflineEarnings.earned(perSec: number, elapsedSec: number, rate: number, capHours: number): number
	if perSec <= 0 or elapsedSec <= 0 or rate <= 0 or capHours <= 0 then
		return 0
	end
	local seconds = math.min(elapsedSec, capHours * 3600)
	return perSec * seconds * rate
end

return OfflineEarnings
