--!strict
-- WP-10b. Custodia de una piñata robada.
-- El ítem sigue en el inventario de la víctima hasta deliver. Un rejoin o un crash
-- a mitad del robo no lo copia: el ledger es memoria de este server y deliver es una sola vez.

local CarryIntegrity = {}

export type Entry = {
	state: "home" | "transit",
	ownerUserId: number,
	carrierUserId: number,
	generation: number,
}

export type Ledger = { [string]: Entry }

local function copy(ledger: Ledger): Ledger
	local nextLedger: Ledger = {}
	for uid, entry in ledger do
		nextLedger[uid] = {
			state = entry.state,
			ownerUserId = entry.ownerUserId,
			carrierUserId = entry.carrierUserId,
			generation = entry.generation,
		}
	end
	return nextLedger
end

function CarryIntegrity.empty(): Ledger
	return {}
end

function CarryIntegrity.get(ledger: Ledger, uid: string): Entry?
	return ledger[uid]
end

function CarryIntegrity.begin(
	ledger: Ledger,
	uid: string,
	ownerUserId: number,
	carrierUserId: number
): (Ledger, boolean, string, number)
	if ownerUserId == carrierUserId or uid == "" then
		return ledger, false, "owner", 0
	end
	for otherId, entry in ledger do
		if otherId ~= uid and entry.state == "transit" and entry.carrierUserId == carrierUserId then
			return ledger, false, "carrying", 0
		end
	end
	local current = ledger[uid]
	if current ~= nil and current.state == "transit" then
		return ledger, false, "busy", current.generation
	end
	if current ~= nil and current.ownerUserId ~= ownerUserId then
		return ledger, false, "owner", current.generation
	end
	local nextLedger = copy(ledger)
	local generation = if current ~= nil then current.generation + 1 else 1
	nextLedger[uid] = {
		state = "transit",
		ownerUserId = ownerUserId,
		carrierUserId = carrierUserId,
		generation = generation,
	}
	return nextLedger, true, "ok", generation
end

function CarryIntegrity.abort(ledger: Ledger, uid: string, generation: number): (Ledger, boolean)
	local current = ledger[uid]
	if current == nil or current.state ~= "transit" or current.generation ~= generation then
		return ledger, false
	end
	local nextLedger = copy(ledger)
	nextLedger[uid] = {
		state = "home",
		ownerUserId = current.ownerUserId,
		carrierUserId = 0,
		generation = current.generation,
	}
	return nextLedger, true
end

function CarryIntegrity.rejoin(ledger: Ledger, userId: number): (Ledger, { string })
	local returned: { string } = {}
	local nextLedger = ledger
	for uid, entry in ledger do
		if entry.state == "transit" and entry.carrierUserId == userId then
			local aborted, ok = CarryIntegrity.abort(nextLedger, uid, entry.generation)
			if ok then
				nextLedger = aborted
				table.insert(returned, uid)
			end
		end
	end
	return nextLedger, returned
end

function CarryIntegrity.deliver(
	ledger: Ledger,
	uid: string,
	generation: number,
	carrierUserId: number
): (Ledger, boolean, string)
	local current = ledger[uid]
	if current == nil or current.state ~= "transit" then
		return ledger, false, "duplicate"
	end
	if current.generation ~= generation or current.carrierUserId ~= carrierUserId then
		return ledger, false, "generation"
	end
	local nextLedger = copy(ledger)
	nextLedger[uid] = {
		state = "home",
		ownerUserId = carrierUserId,
		carrierUserId = 0,
		generation = current.generation,
	}
	return nextLedger, true, "ok"
end

-- Crash del server: el ledger muere. Lo que quedó guardado manda.
-- A mitad del robo el ladrón todavía no tiene el ítem, así que no se duplica.
function CarryIntegrity.restore(ledger: Ledger, uid: string, ownerUserId: number): Ledger
	local current = ledger[uid]
	local nextLedger = copy(ledger)
	nextLedger[uid] = {
		state = "home",
		ownerUserId = ownerUserId,
		carrierUserId = 0,
		generation = if current ~= nil then current.generation else 1,
	}
	return nextLedger
end

-- Crash del server: el ledger muere. Lo que quedó guardado manda.
-- A mitad del robo el ladrón todavía no tiene el ítem, así que no se duplica.
function CarryIntegrity.persistence(victimHas: boolean, thiefHas: boolean): string
	if victimHas and thiefHas then
		return "duplicated"
	end
	if not victimHas and not thiefHas then
		return "lost"
	end
	return "ok"
end

export type DeliverInput = {
	inside: boolean,
	modelOffset: number,
	maxOffset: number,
	age: number,
	minAge: number,
	crossesSolid: boolean,
}

function CarryIntegrity.canDeliver(input: DeliverInput): (boolean, string)
	if input.age < input.minAge then
		return false, "soon"
	end
	if input.crossesSolid then
		return false, "wall"
	end
	if not input.inside then
		return false, "zone"
	end
	if input.modelOffset > input.maxOffset then
		return false, "far"
	end
	return true, "ok"
end

function CarryIntegrity.canDrop(crossesSolid: boolean): (boolean, string)
	if crossesSolid then
		return false, "wall"
	end
	return true, "ok"
end

return CarryIntegrity
