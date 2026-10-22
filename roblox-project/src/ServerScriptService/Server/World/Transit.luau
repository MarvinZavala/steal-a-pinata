--!strict
-- Piñatas que están en el aire (cargadas o volviendo). No es un segundo perfil:
-- el ítem sigue en Inventory del dueño. Al cargar en frío este set está vacío,
-- así que un crash se las devuelve al pedestal.

local Transit = {}

local ids: { [string]: boolean } = {}

function Transit.set(instanceId: string, on: boolean)
	if on then
		ids[instanceId] = true
	else
		ids[instanceId] = nil
	end
end

function Transit.has(instanceId: string): boolean
	return ids[instanceId] == true
end

return Transit
