--!strict
-- Compra en la Pasarela (GDD §3.1). price == nil es un reclamo sin costo (Secretas).

local BuyRules = {}

export type Input = {
	candy: number,
	price: number?,
	distance: number,
	maxDistance: number,
	hasRoom: boolean,
}

function BuyRules.evaluate(input: Input): (boolean, string)
	if input.distance > input.maxDistance then
		return false, "distance"
	end
	if not input.hasRoom then
		return false, "no_room"
	end
	if input.price ~= nil and input.candy < input.price then
		return false, "funds"
	end
	return true, "ok"
end

return BuyRules
