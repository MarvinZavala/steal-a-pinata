--!strict
-- Asignación de parcelas. Una parcela por jugador; al salir se libera.
-- Funciona para 6 (el mapa) y para 8 (criterio de WP-04).

local AssignPlots = {}

export type State = { [number]: number }

function AssignPlots.new(): State
	return {}
end

function AssignPlots.claim(state: State, plotCount: number, userId: number): number?
	for index = 1, plotCount do
		if state[index] == userId then
			return index
		end
	end
	for index = 1, plotCount do
		if state[index] == nil then
			state[index] = userId
			return index
		end
	end
	return nil
end

function AssignPlots.release(state: State, userId: number): number?
	for index, owner in state do
		if owner == userId then
			state[index] = nil
			return index
		end
	end
	return nil
end

return AssignPlots
