--!strict
-- Compra en la Pasarela (GDD §3.1). price == nil es un reclamo sin costo (Secretas).

local BuyRules = {}

export type Input = {
	candy: number,
	price: number?,
	distance: number,
	maxDistance: number,
	hasRoom: boolean,
	-- Si viene, es el saldo de la moneda del slot (Bastones en el evento). Si no, se usa candy.
	balance: number?,
}

function BuyRules.evaluate(input: Input): (boolean, string)
	if input.distance > input.maxDistance then
		return false, "distance"
	end
	if not input.hasRoom then
		return false, "no_room"
	end
	local purse = if input.balance ~= nil then input.balance else input.candy
	if input.price ~= nil and purse < input.price then
		return false, "funds"
	end
	return true, "ok"
end

return BuyRules
