--!strict
-- Proyección de la progresión (GDD §6.3) para un jugador promedio, sin Roblox.
-- Un segundo de juego = un paso. La Fiesta cae cada 30 min de juego activo.
-- Las compras siguen una política: llenar slots con lo que pague, fusionar al llenarse,
-- ahorrar para la Re-Fiesta cuando ya tiene la rareza, y no vender (no se puede).

local Economy = if typeof(script) == "Instance"
	then require(script.Parent.Parent.Config.Economy)
	else require("../Config/Economy")
local Pinatas = if typeof(script) == "Instance"
	then require(script.Parent.Parent.Config.Pinatas)
	else require("../Config/Pinatas")
local DailyRules = if typeof(script) == "Instance" then require(script.Parent.DailyRules) else require("./DailyRules")
local Fusion = if typeof(script) == "Instance" then require(script.Parent.Fusion) else require("./Fusion")
local SpawnWeights = if typeof(script) == "Instance"
	then require(script.Parent.SpawnWeights)
	else require("./SpawnWeights")

local EconomySim = {}

local WEIGHTS = {
	Common = 62,
	Uncommon = 25,
	Rare = 9,
	Epic = 3,
	Legendary = 0.8,
	Mythic = 0.19,
	Secret = 0.01,
}
local BOOST = { Rare = true, Epic = true, Legendary = true, Mythic = true, Secret = true }

local RANK: { [string]: number } = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
	Event = 4,
}

export type Milestone = { playMin: number, day: number }
export type Flag = { id: string, ok: boolean, detail: string }
export type RunReport = {
	label: string,
	playMin: number,
	candy: number,
	perSec: number,
	pedestals: number,
	reFiestas: number,
	slots: number,
	milestones: { [string]: Milestone },
	flags: { Flag },
}

type Slot = { id: string, cps: number, rarity: string, setName: string, mutation: string }
type State = {
	candy: number,
	slots: { Slot },
	pedestals: number,
	vaultTier: number,
	reFiestas: number,
	has2x: boolean,
	hasVip: boolean,
	dex: { [string]: boolean },
	sets: number,
	playSec: number,
	day: number,
	milestones: { [string]: Milestone },
	streak: number,
	lastClaimDay: number,
	seenFiesta: { [number]: boolean },
}

type Row = { id: string, rarity: string, cps: number, price: number, setName: string }

local function lcg(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
end

local function rowsOf(): { Row }
	local list: { Row } = {}
	for id, def in Pinatas do
		if def.Currency == "Dulces" and def.Price ~= nil then
			table.insert(list, {
				id = id,
				rarity = def.Rarity,
				cps = def.CandyPerSec,
				price = def.Price :: number,
				setName = def.Set,
			})
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

local function idsOf(rows: { Row }, rarity: string): { string }
	local ids: { string } = {}
	for _, row in rows do
		if row.rarity == rarity then
			table.insert(ids, row.id)
		end
	end
	return ids
end

local function rowById(rows: { Row }, id: string): Row?
	for _, row in rows do
		if row.id == id then
			return row
		end
	end
	return nil
end

local function mark(state: State, name: string)
	if state.milestones[name] == nil then
		state.milestones[name] = {
			playMin = state.playSec / 60,
			day = state.day,
		}
	end
end

local function recomputeSets(state: State)
	local need: { [string]: number } = {}
	local have: { [string]: number } = {}
	for _, def in Pinatas do
		need[def.Set] = (need[def.Set] or 0) + 1
	end
	for id, owned in state.dex do
		local def = Pinatas[id]
		if owned and def ~= nil then
			have[def.Set] = (have[def.Set] or 0) + 1
		end
	end
	local done = 0
	for setName, total in need do
		if (have[setName] or 0) >= total then
			done += 1
		end
	end
	state.sets = done
	local classicsNeed = need.Classics or 0
	if classicsNeed > 0 and (have.Classics or 0) >= classicsNeed then
		mark(state, "classics")
	end
end

local function multiplier(state: State): number
	return Economy.totalMultiplier(state.reFiestas, state.has2x, state.hasVip, state.sets)
end

local function slotCps(slot: Slot): number
	local mut = 1
	if slot.mutation == "Golden" then
		mut = Economy.Mutations.Golden.Multiplier
	elseif slot.mutation == "Rainbow" then
		mut = Economy.Mutations.Rainbow.Multiplier
	end
	return slot.cps * mut
end

local function perSec(state: State): number
	local sum = 0
	for _, slot in state.slots do
		sum += slotCps(slot)
	end
	return sum * multiplier(state)
end

local function own(state: State, row: Row, mutation: string)
	table.insert(state.slots, {
		id = row.id,
		cps = row.cps,
		rarity = row.rarity,
		setName = row.setName,
		mutation = mutation,
	})
	state.dex[row.id] = true
	recomputeSets(state)
	local rank = RANK[row.rarity] or 0
	if rank >= (RANK.Rare :: number) then
		mark(state, "rareOwned")
	end
	if rank >= (RANK.Epic :: number) then
		mark(state, "epicOwned")
	end
	if rank >= (RANK.Legendary :: number) then
		mark(state, "legendaryOwned")
	end
	if #state.slots >= 4 then
		mark(state, "fourFull")
	end
end

local function countRarity(state: State, rarity: string): number
	local need = RANK[rarity] or 0
	local total = 0
	for _, slot in state.slots do
		if (RANK[slot.rarity] or 0) >= need then
			total += 1
		end
	end
	return total
end

local function tryRebirth(state: State)
	local offer = Economy.refiestaOffer(state.reFiestas + 1)
	if state.candy < offer.Candy then
		return
	end
	if countRarity(state, offer.Rarity) < offer.Count then
		return
	end
	local keep: { Slot } = {}
	for _, slot in state.slots do
		if Fusion.keptOnRebirth(slot.rarity) then
			table.insert(keep, slot)
		end
	end
	state.slots = keep
	state.candy = 0
	state.pedestals = Economy.StartPedestals
	state.reFiestas += 1
	mark(state, "rebirth")
end

local function tryFuse(state: State, rng: () -> number)
	local counts: { [string]: number } = {}
	for _, slot in state.slots do
		counts[slot.id] = (counts[slot.id] or 0) + 1
	end
	for id, count in counts do
		if count >= 3 then
			local removed = 0
			local kept: { Slot } = {}
			local sample: Slot? = nil
			for _, slot in state.slots do
				if slot.id == id and removed < 3 then
					removed += 1
					sample = slot
				else
					table.insert(kept, slot)
				end
			end
			state.slots = kept
			if sample ~= nil then
				local mutation = Fusion.pickMutation(rng(), Economy.FusionRainbowChance)
				table.insert(state.slots, {
					id = sample.id,
					cps = sample.cps,
					rarity = sample.rarity,
					setName = sample.setName,
					mutation = mutation,
				})
			end
			return
		end
	end
end

local function countId(state: State, id: string): number
	local total = 0
	for _, slot in state.slots do
		if slot.id == id then
			total += 1
		end
	end
	return total
end

local function bestRank(state: State): number
	local best = 0
	for _, slot in state.slots do
		local rank = RANK[slot.rarity] or 0
		if rank > best then
			best = rank
		end
	end
	return best
end

local function savingForRebirth(state: State): number
	local offer = Economy.refiestaOffer(state.reFiestas + 1)
	if countRarity(state, offer.Rarity) >= offer.Count then
		return offer.Candy
	end
	return 0
end

-- Mientras falta la siguiente rareza se deja un pedestal vacío. Si no, no hay fusión que haga sitio.
local function slotBudget(state: State): number
	local hold = state.pedestals
	if countRarity(state, "Rare") == 0 then
		hold = math.min(hold, 3)
	elseif countRarity(state, "Epic") == 0 then
		hold = math.min(hold, math.max(3, state.pedestals - 1))
	elseif state.reFiestas == 0 then
		hold = math.min(hold, math.max(4, state.pedestals - 1))
	end
	return hold
end

local function tryPedestal(state: State, needed: boolean)
	local cap = Economy.pedestalCap(state.reFiestas, false)
	if state.pedestals >= cap then
		return
	end
	if not needed and #state.slots < state.pedestals - 1 then
		return
	end
	-- El pedestal 5 y 6 se compran al tener la Rara; el 7 y el 8, al tener la Épica.
	if countRarity(state, "Rare") == 0 and state.pedestals >= Economy.StartPedestals then
		return
	end
	if countRarity(state, "Epic") == 0 and state.pedestals >= 6 then
		return
	end
	local price = Economy.pedestalPrice(state.pedestals + 1)
	local reserve = savingForRebirth(state)
	if reserve > 0 and state.candy - price < reserve then
		return
	end
	if state.candy < price then
		return
	end
	state.candy -= price
	state.pedestals += 1
	if state.pedestals >= 6 then
		mark(state, "pedestals6")
	end
end

local function tryVault(state: State)
	local nextTier = state.vaultTier + 1
	local price = Economy.vaultCost(nextTier)
	if price <= 0 then
		return
	end
	if state.candy < price * 4 then
		return
	end
	local reserve = savingForRebirth(state)
	if reserve > 0 and state.candy - price < reserve then
		return
	end
	state.candy -= price
	state.vaultTier = nextTier
end

local function holdingRank(state: State): number
	if countRarity(state, "Rare") == 0 then
		return RANK.Rare :: number
	end
	if countRarity(state, "Epic") == 0 then
		return RANK.Epic :: number
	end
	if state.reFiestas == 0 then
		return 99
	end
	if countRarity(state, "Legendary") == 0 then
		return RANK.Legendary :: number
	end
	return 99
end

local function wants(state: State, row: Row): boolean
	local rank = RANK[row.rarity] or 0
	local hold = holdingRank(state)
	local owned = countId(state, row.id)
	local best = bestRank(state)
	if rank >= hold then
		return true
	end
	-- El set Clásicas se completa de paso: son baratas al principio y el Toro entra con las Legendarias.
	if row.setName == "Classics" and state.dex[row.id] ~= true and rank <= best then
		return true
	end
	-- Apilar la especie que ya se tiene (hasta 3) para fusionar y subir Dulces/s.
	if
		owned >= 1
		and owned < 3
		and rank >= (RANK.Uncommon :: number)
		and rank >= best - 1
		and rank >= (RANK.Rare :: number) - 1
	then
		return true
	end
	if #state.slots < 3 and rank >= (if state.playSec < 90 then 1 else RANK.Uncommon :: number) then
		if owned == 0 and state.pedestals - #state.slots <= 1 then
			return false
		end
		return true
	end
	return false
end

local function considerBuy(state: State, row: Row, mutation: string, rng: () -> number)
	if not wants(state, row) then
		return
	end
	local reserve = savingForRebirth(state)
	if reserve > 0 and state.candy - row.price < reserve then
		return
	end
	if state.candy < row.price then
		return
	end
	local owned = countId(state, row.id)
	local rank = RANK[row.rarity] or 0
	if #state.slots >= slotBudget(state) or #state.slots >= state.pedestals then
		tryFuse(state, rng)
	end
	if #state.slots >= state.pedestals then
		tryPedestal(state, rank >= holdingRank(state))
	end
	if #state.slots >= slotBudget(state) or #state.slots >= state.pedestals then
		return
	end
	local hold = holdingRank(state)
	if rank < hold and #state.slots + 1 >= slotBudget(state) and owned < 2 then
		return
	end
	state.candy -= row.price
	own(state, row, mutation)
	if countId(state, row.id) >= 3 then
		tryFuse(state, rng)
	end
end

local function rollMutation(rng: () -> number): string
	local roll = rng()
	if roll < Economy.Mutations.Rainbow.ConveyorChance then
		return "Rainbow"
	end
	if roll < Economy.Mutations.Rainbow.ConveyorChance + Economy.Mutations.Golden.ConveyorChance then
		return "Golden"
	end
	return "None"
end

local function spawn(state: State, rows: { Row }, rng: () -> number)
	local rarity = SpawnWeights.pick(WEIGHTS, rng(), false, BOOST)
	if (RANK[rarity] or 0) >= (RANK.Rare :: number) then
		mark(state, "rareSeen")
	end
	local ids = idsOf(rows, rarity)
	local id = SpawnWeights.chooseId(ids, rng())
	if id == nil then
		return
	end
	local row = rowById(rows, id)
	if row == nil then
		return
	end
	considerBuy(state, row, rollMutation(rng), rng)
end

local function fiesta(state: State, rows: { Row }, rng: () -> number)
	local window = math.floor(state.playSec / Economy.Fiesta.EverySec)
	if window <= 0 or state.seenFiesta[window] then
		return
	end
	if state.playSec % Economy.Fiesta.EverySec > 2 then
		return
	end
	state.seenFiesta[window] = true
	mark(state, "fiesta")
	local rate = perSec(state)
	state.candy += math.floor(rate * 45 + Economy.Fiesta.PoolBase / 8)
	if rng() < 0.35 and #state.slots < state.pedestals then
		local rare = rowById(rows, "cohetin")
		if rare ~= nil then
			own(state, rare, "None")
		end
	end
end

local function claimDaily(state: State, rows: { Row }, calendarDay: number)
	local streak, reason = DailyRules.nextStreak(state.lastClaimDay, state.streak, calendarDay)
	if reason == "already" or reason == "clock" then
		return
	end
	state.streak = streak
	state.lastClaimDay = calendarDay
	local reward = DailyRules.rewardForStreak(streak)
	state.candy += reward.Candy
	if reward.PinataId ~= nil and #state.slots < state.pedestals then
		local row = rowById(rows, reward.PinataId)
		if row ~= nil then
			own(state, row, "None")
		end
	elseif reward.PinataId ~= nil then
		state.candy += 4000
	end
	-- Dos de tres misiones, el promedio del diseño.
	state.candy += 5000 + 2500
end

local function offline(state: State, gapSec: number)
	local rate = perSec(state)
	local capped = math.min(gapSec, Economy.OfflineCapHours * 3600)
	local gain = rate * Economy.OfflineRate * capped
	local tiers = Economy.VaultCapSeconds
	local seconds = tiers[state.vaultTier] or tiers[1]
	local cap = rate * seconds
	if gain > cap then
		gain = cap
	end
	state.candy += math.floor(gain)
end

local function newState(day: number, has2x: boolean, hasVip: boolean): State
	return {
		candy = 250,
		slots = {},
		pedestals = Economy.StartPedestals,
		vaultTier = 1,
		reFiestas = 0,
		has2x = has2x,
		hasVip = hasVip,
		dex = {},
		sets = 0,
		playSec = 0,
		day = day,
		milestones = {},
		streak = 0,
		lastClaimDay = 0,
		seenFiesta = {},
	}
end

local function playSession(state: State, rows: { Row }, rng: () -> number, minutes: number, day: number)
	state.day = day
	claimDaily(state, rows, day)
	local steps = math.floor(minutes * 60)
	for _ = 1, steps do
		state.playSec += 1
		local rate = perSec(state)
		state.candy += rate * 0.85
		if state.playSec % Economy.Conveyor.SpawnEverySec == 0 then
			spawn(state, rows, rng)
		end
		if state.playSec % 20 == 0 then
			tryPedestal(state, #state.slots >= state.pedestals)
			tryVault(state)
			tryFuse(state, rng)
		end
		fiesta(state, rows, rng)
		tryRebirth(state)
		if state.playSec == 10 * 60 then
			mark(state, "min10")
		elseif state.playSec == 30 * 60 then
			mark(state, "min30")
		elseif state.playSec == 60 * 60 then
			mark(state, "min60")
		end
	end
end

local function schedule(kind: string): { { day: number, minutes: number } }
	local list: { { day: number, minutes: number } } = { { day = 1, minutes = 45 } }
	if kind == "D1" then
		return list
	end
	local last = if kind == "D7" then 7 else 28
	for day = 2, last do
		local minutes = 35
		if kind == "D28" and day <= 7 then
			minutes = 40
		elseif kind == "D28" then
			minutes = 30
		end
		table.insert(list, { day = day, minutes = minutes })
	end
	return list
end

function EconomySim.run(kind: string, seed: number, has2x: boolean, hasVip: boolean): RunReport
	local rows = rowsOf()
	local rng = lcg(seed)
	local state = newState(1, has2x, hasVip)
	local michi = rowById(rows, "michi")
	if michi ~= nil then
		own(state, michi, "Golden")
	end
	local sessions = schedule(kind)
	local previous: { day: number, minutes: number }? = nil
	for _, session in sessions do
		if previous ~= nil then
			local gap = (session.day - previous.day) * 86400 - previous.minutes * 60
			if gap < 0 then
				gap = 0
			end
			offline(state, gap)
		end
		playSession(state, rows, rng, session.minutes, session.day)
		previous = session
	end
	return {
		label = kind,
		playMin = state.playSec / 60,
		candy = math.floor(state.candy),
		perSec = perSec(state),
		pedestals = state.pedestals,
		reFiestas = state.reFiestas,
		slots = #state.slots,
		milestones = state.milestones,
		flags = {},
	}
end

local function minutesOf(report: RunReport, name: string): number?
	local row = report.milestones[name]
	if row == nil then
		return nil
	end
	return row.playMin
end

local function dayOf(report: RunReport, name: string): number?
	local row = report.milestones[name]
	if row == nil then
		return nil
	end
	return row.day
end

local function add(flags: { Flag }, id: string, ok: boolean, detail: string)
	table.insert(flags, { id = id, ok = ok, detail = detail })
end

function EconomySim.evaluate(d1: RunReport, d7: RunReport, d28: RunReport, payer: RunReport): { Flag }
	local flags: { Flag } = {}
	local rare = minutesOf(d1, "rareOwned")
	add(
		flags,
		"d1-rare",
		rare ~= nil and rare <= 25,
		if rare ~= nil then string.format("primera Rara propia a los %.1f min", rare) else "D1 no compró una Rara"
	)
	local seen = minutesOf(d1, "rareSeen")
	add(
		flags,
		"d1-rare-seen",
		seen ~= nil and seen <= 8,
		if seen ~= nil then string.format("primera Rara en la Pasarela a los %.1f min", seen) else "no apareció"
	)
	local six = minutesOf(d7, "pedestals6")
	add(
		flags,
		"d7-pedestals",
		six ~= nil and six <= 60,
		if six ~= nil then string.format("6 pedestales a los %.1f min", six) else "no llegó a 6 pedestales"
	)
	local epic = minutesOf(d7, "epicOwned")
	add(
		flags,
		"d7-epic",
		epic ~= nil and epic >= 8 and epic <= 120,
		if epic ~= nil then string.format("primera Épica a los %.1f min", epic) else "sin Épica en D7"
	)
	local rebirth = minutesOf(d7, "rebirth")
	add(
		flags,
		"d7-rebirth",
		rebirth ~= nil and rebirth >= 75 and rebirth <= 240,
		if rebirth ~= nil
			then string.format("primera Re-Fiesta a los %.1f min de juego (objetivo 120 a 180)", rebirth)
			else "sin Re-Fiesta en la semana"
	)
	local fiestaMin = minutesOf(d1, "fiesta")
	add(
		flags,
		"d1-fiesta",
		fiestaMin ~= nil and fiestaMin <= 40,
		if fiestaMin ~= nil then string.format("primera Fiesta a los %.1f min", fiestaMin) else "D1 no jugó una Fiesta"
	)
	local legend = dayOf(d28, "legendaryOwned")
	add(
		flags,
		"d28-legendary",
		legend ~= nil and legend >= 3 and legend <= 14,
		if legend ~= nil then string.format("primera Legendaria el día %d", legend) else "sin Legendaria en 28 días"
	)
	local classics = dayOf(d28, "classics")
	add(
		flags,
		"d28-classics",
		classics ~= nil and classics <= 14,
		if classics ~= nil then string.format("set Clásicas el día %d", classics) else "set Clásicas incompleto"
	)
	local freeRe = minutesOf(d7, "rebirth")
	local payRe = minutesOf(payer, "rebirth")
	local ratioOk = true
	local ratioDetail = "el pase no cambia la Re-Fiesta"
	if freeRe ~= nil and payRe ~= nil and freeRe > 0 then
		local ratio = payRe / freeRe
		ratioOk = ratio >= 0.35
		ratioDetail = string.format("pagador / F2P = %.2f (%.0f min vs %.0f min)", ratio, payRe, freeRe)
	elseif payRe ~= nil and freeRe == nil then
		ratioOk = false
		ratioDetail = "el pagador llega a Re-Fiesta y el F2P no"
	end
	add(flags, "payer-ratio", ratioOk, ratioDetail)
	return flags
end

function EconomySim.project(
	seed: number
): { d1: RunReport, d7: RunReport, d28: RunReport, payer: RunReport, flags: { Flag } }
	local d1 = EconomySim.run("D1", seed, false, false)
	local d7 = EconomySim.run("D7", seed + 1, false, false)
	local d28 = EconomySim.run("D28", seed + 2, false, false)
	local payer = EconomySim.run("D7", seed + 3, true, true)
	payer.label = "D7-pagador"
	local flags = EconomySim.evaluate(d1, d7, d28, payer)
	d1.flags = flags
	return { d1 = d1, d7 = d7, d28 = d28, payer = payer, flags = flags }
end

function EconomySim.imbalanced(flags: { Flag }): boolean
	for _, flag in flags do
		if not flag.ok then
			return true
		end
	end
	return false
end

return EconomySim
