--!strict
-- Pruebas de los criterios de WP-04..WP-08 que no necesitan el motor.
-- La corren Studio (SelfCheck) y `lune tests/run.luau`.

local SelfTest = {}

export type Report = { ok: boolean, passed: number, failed: { string }, worstSpawnDelta: number }

type Mods = { [string]: any }

local function lcg(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state = 1
	end
	return function(): number
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
end

function SelfTest.run(m: Mods): Report
	local failed: { string } = {}
	local passed = 0
	local function check(name: string, cond: boolean, detail: string?)
		if cond then
			passed += 1
		else
			table.insert(failed, if detail then name .. " — " .. detail else name)
		end
	end

	local Candy = m.CandyMath
	local Spawn = m.SpawnWeights
	local Steal = m.StealRules
	local Bat = m.BatRules
	local Lock = m.LockRules
	local Offline = m.OfflineEarnings
	local Plots = m.AssignPlots
	local Inv = m.Inventory
	local Aim = m.Aim
	local Move = m.MoveMath
	local Buy = m.BuyRules
	local Layout = m.WorldLayout
	local Economy = m.Economy

	-- WP-04: 8 jugadores, parcelas distintas, y al salir se libera.
	local state = Plots.new()
	local seen: { [number]: boolean } = {}
	local claimed = 0
	for n = 1, 8 do
		local plot = Plots.claim(state, 8, 1000 + n)
		if plot == nil then
			check("claim-8", false, "nil en el jugador " .. tostring(n))
		else
			claimed += 1
			seen[plot] = true
		end
	end
	local distinct = 0
	for _ in seen do
		distinct += 1
	end
	check("8 parcelas distintas", claimed == 8 and distinct == 8, tostring(distinct))
	check("la novena no entra", Plots.claim(state, 8, 2000) == nil)
	local freed = Plots.release(state, 1001)
	check("release devuelve la parcela", freed ~= nil)
	check("el siguiente recibe la que se liberó", Plots.claim(state, 8, 2000) == freed)
	local six = Plots.new()
	for n = 1, 6 do
		Plots.claim(six, 6, n)
	end
	check("el mapa de 6 no da una séptima", Plots.claim(six, 6, 99) == nil)

	-- El layout real son 6 bases y no se pisan.
	local spots = Layout.plots()
	check("6 plots en el layout", #spots == Layout.PlotCount and Layout.PlotCount == 6, tostring(#spots))
	local hx = Layout.FloorZ / 2
	local hz = Layout.FloorX / 2
	local overlap = false
	for i = 1, #spots do
		for j = i + 1, #spots do
			local sepX = math.abs(spots[i].x - spots[j].x) - hx * 2
			local sepZ = math.abs(spots[i].z - spots[j].z) - hz * 2
			if sepX <= 0 and sepZ <= 0 then
				overlap = true
			end
		end
	end
	check("las bases no se solapan", not overlap)

	-- WP-04: Dulces/s exactos en 10 min, y el tope se respeta.
	local muts = { Golden = 2, Rainbow = 5, Christmas = 3 }
	local rate = Candy.perSecond({
		{ candyPerSec = 1, mutation = nil },
		{ candyPerSec = 9, mutation = "Golden" },
	}, 1, muts)
	check("ritmo 1 + 9*2", math.abs(rate - 19) < 1e-9, tostring(rate))
	local boosted =
		Candy.perSecond({ { candyPerSec = 19, mutation = nil } }, Economy.totalMultiplier(2, true, true, 2), muts)
	check("multiplicador 3.6", math.abs(Economy.totalMultiplier(2, true, true, 2) - 3.6) < 1e-9)
	check("ritmo con multiplicador", math.abs(boosted - 19 * 3.6) < 1e-6, tostring(boosted))
	local capSeconds = 300
	local capAmount = Candy.cap(rate, capSeconds)
	local vault = 0
	for _ = 1, 600 do
		vault = Candy.accrue(vault, rate, 1, capAmount)
	end
	local expectedCap = rate * capSeconds
	check("tope a los 10 min", math.abs(vault - expectedCap) / expectedCap < 0.01, tostring(vault))
	local open = 0
	for _ = 1, 600 do
		open = Candy.accrue(open, rate, 1, math.huge)
	end
	local expectedOpen = rate * 600
	check("10 min sin tope ±1%", math.abs(open - expectedOpen) / expectedOpen < 0.01, tostring(open))
	local okSpend, left = Candy.trySpend(0, 15)
	check("sin Dulces no se gasta", okSpend == false and left == 0)
	local paid, after = Candy.trySpend(100, 15)
	check("con Dulces se descuenta", paid == true and after == 85)

	-- WP-04 offline: el inventario no cambia y el cálculo da 50% con tope de 8 h.
	local before = { "a", "b", "c" }
	local afterUids = { "a", "b", "c" }
	check("offline no pierde piñatas", Inv.sameUids(before, afterUids))
	local twoHours = Offline.earned(10, 2 * 3600, 0.5, 8)
	check("2 h al 50%", math.abs(twoHours - 36000) < 1e-6, tostring(twoHours))
	local tooLong = Offline.earned(10, 10 * 3600, 0.5, 8)
	check("tope de 8 h", math.abs(tooLong - 8 * 3600 * 10 * 0.5) < 1e-6, tostring(tooLong))
	check("sin tiempo no hay ganancia", Offline.earned(10, 0, 0.5, 8) == 0)

	-- Entrega: se mueve, no se duplica.
	local victim = { { uid = "p1" }, { uid = "p2" } }
	local thief = { { uid = "q1" } }
	check("mover p1", Inv.move(victim, thief, "p1") == true)
	check("la víctima ya no lo tiene", not Inv.contains(victim, "p1"))
	check("el ladrón lo tiene una vez", Inv.contains(thief, "p1"))
	check("no se duplica si se mueve de nuevo", Inv.move(victim, thief, "p1") == false)

	-- WP-05: pesos. Fronteras exactas + Monte Carlo.
	local weights = m.weights
	local boost = m.boosted
	check("pesos suman 100", math.abs(Spawn.total(weights, false, boost) - 100) < 1e-9)
	check("suerte duplica de Rara para arriba", math.abs(Spawn.total(weights, true, boost) - 113) < 1e-6)
	check("roll 0 es Common", Spawn.pick(weights, 0, false, boost) == "Common")
	check("borde 0.62 pasa a Epic", Spawn.pick(weights, 0.62, false, boost) == "Epic")
	check("casi 1 es Uncommon (última clave)", Spawn.pick(weights, 0.999999, false, boost) == "Uncommon")
	local ids = Spawn.eligibleIds({
		{ id = "burrito", rarity = "Common", currency = "Dulces" },
		{ id = "tamalito", rarity = "Event", currency = "Bastones" },
		{ id = "estrellita", rarity = "Common", currency = "Dulces" },
	}, "Common")
	check("filtra evento y ordena", #ids == 2 and ids[1] == "burrito" and ids[2] == "estrellita")

	local N = 200000
	local counts: { [string]: number } = {}
	local rng = lcg(42)
	for _ = 1, N do
		local rarity = Spawn.pick(weights, rng(), false, boost)
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	local worst = 0
	for rarity, weight in weights do
		local pct = ((counts[rarity] or 0) / N) * 100
		local delta = math.abs(pct - weight)
		if delta > worst then
			worst = delta
		end
		check("spawn " .. rarity .. " ±0.5", delta <= 0.5, string.format("obs %.3f vs %.3f", pct, weight))
	end

	-- WP-05: compra sin Dulces se rechaza. Lejos también.
	local noCash, whyCash = Buy.evaluate({ candy = 0, price = 15, distance = 4, maxDistance = 12, hasRoom = true })
	check("compra sin Dulces", noCash == false and whyCash == "funds", whyCash)
	local farBuy, whyFar = Buy.evaluate({ candy = 999, price = 15, distance = 200, maxDistance = 12, hasRoom = true })
	check("compra a 200 studs", farBuy == false and whyFar == "distance")
	local freeSecret, whySecret =
		Buy.evaluate({ candy = 0, price = nil, distance = 5, maxDistance = 12, hasRoom = true })
	check("secreta sin precio se reclama", freeSecret == true and whySecret == "ok")
	local noRoom, whyRoom = Buy.evaluate({ candy = 100, price = 15, distance = 2, maxDistance = 12, hasRoom = false })
	check("sin pedestal no compra", noRoom == false and whyRoom == "no_room")

	-- WP-06: validaciones de la sección 7.
	local function stealInput(patch: { [string]: any }): any
		local base = {
			distance = 4,
			inRange = true,
			locked = false,
			alreadyCarrying = false,
			thiefIsRookie = false,
			victimIsRookie = false,
			cooldownReady = true,
			recentStealsOnVictim = 0,
			maxStealsPerWindow = 2,
			thiefHasRoom = true,
			pinataAvailable = true,
			pinataProtected = false,
		}
		for k, v in patch do
			base[k] = v
		end
		return base
	end
	local okSteal, whyOk = Steal.evaluate(stealInput({}))
	check("robo válido", okSteal == true and whyOk == "ok", whyOk)
	local farSteal, whyFarSteal = Steal.evaluate(stealInput({ distance = 200, inRange = false }))
	check("exploit a 200 studs", farSteal == false and whyFarSteal == "far" and Steal.shouldLogFar(200, whyFarSteal))
	local mid, whyMid = Steal.evaluate(stealInput({ distance = 30, inRange = false }))
	check(
		"fuera de rango cercano no es far",
		mid == false and whyMid == "distance" and not Steal.shouldLogFar(30, whyMid)
	)
	local locked, whyLocked = Steal.evaluate(stealInput({ locked = true }))
	check("candado bloquea el robo", locked == false and whyLocked == "locked")
	local rookie, whyRookie = Steal.evaluate(stealInput({ thiefIsRookie = true }))
	check("novato no roba", rookie == false and whyRookie == "rookie")
	local victimR, whyVictim = Steal.evaluate(stealInput({ victimIsRookie = true }))
	check("nadie roba a un novato", victimR == false and whyVictim == "rookie")
	local busy, whyBusy = Steal.evaluate(stealInput({ alreadyCarrying = true }))
	check("ya carga algo", busy == false and whyBusy == "carrying")
	local cooled, whyCool = Steal.evaluate(stealInput({ cooldownReady = false }))
	check("cooldown de robo", cooled == false and whyCool == "cooldown")
	local capped, whyCap = Steal.evaluate(stealInput({ recentStealsOnVictim = 2 }))
	check("máximo 2 por víctima", capped == false and whyCap == "cap")
	local prot, whyProt = Steal.evaluate(stealInput({ pinataProtected = true }))
	check("regreso protegido 3 s", prot == false and whyProt == "protected")
	local stamps =
		{ { victim = 5, at = 100 }, { victim = 5, at = 200 }, { victim = 5, at = 0 }, { victim = 9, at = 250 } }
	check("cuenta la ventana de 5 min", Steal.countRecent(stamps, 5, 300, 300) == 2)
	check("robos sufridos en la ventana", Steal.countSince({ 100, 200, 0 }, 300, 300) == 2)

	-- WP-07: hit, cooldown, fuera de rango, y el drop a 1 o 2 golpes.
	local function batInput(patch: { [string]: any }): any
		local base = { distance = 5, maxDistance = 9, inRange = true, inFront = true, cooldownReady = true }
		for k, v in patch do
			base[k] = v
		end
		return base
	end
	local bonk, whyBonk = Bat.evaluate(batInput({}))
	check("hit válido", bonk == true and whyBonk == "ok")
	local tooSoon, whySoon = Bat.evaluate(batInput({ cooldownReady = false }))
	check("cooldown 0.8 s", tooSoon == false and whySoon == "cooldown" and not Bat.shouldLog(1, 9, whySoon))
	local outRange, whyRange = Bat.evaluate(batInput({ distance = 40, inRange = false }))
	check(
		"fuera de rango se descarta y se loguea",
		outRange == false and whyRange == "range" and Bat.shouldLog(40, 9, whyRange)
	)
	local whiff, whyWhiff = Bat.evaluate(batInput({ distance = 10, inRange = false }))
	check("un whiff pegado no es cheat", whiff == false and not Bat.shouldLog(10, 9, whyWhiff))
	local behind, whyBehind = Bat.evaluate(batInput({ inFront = false }))
	check("ángulo", behind == false and whyBehind == "angle")
	check("común cae a 1 golpe", Bat.shouldDrop(1, 1) and not Bat.shouldDrop(0, 1))
	check("legendaria cae a 2", not Bat.shouldDrop(1, 2) and Bat.shouldDrop(2, 2))

	local ahead = Aim.angleDeg(0, 0, -1, 0, 0, 0, 0, 0, -8)
	check("al frente son 0°", ahead < 0.01, tostring(ahead))
	local rad70 = math.rad(70)
	local ang70 = Aim.angleDeg(0, 0, -1, 0, 0, 0, math.sin(rad70) * 8, 0, -math.cos(rad70) * 8)
	check("70° entra", math.abs(ang70 - 70) < 0.05 and Aim.inFront(ang70, 70), tostring(ang70))
	local rad80 = math.rad(80)
	local ang80 = Aim.angleDeg(0, 0, -1, 0, 0, 0, math.sin(rad80) * 8, 0, -math.cos(rad80) * 8)
	check("80° no entra", ang80 > 70 and not Aim.inFront(ang80, 70), tostring(ang80))
	local dist200 = Aim.distance(0, 0, 0, 200, 0, 0)
	check("200 studs no está a 8", dist200 >= 200 and not Aim.within(dist200, 8, 2))
	check("8 + slack de ping sí", Aim.within(9, 8, 1.5))

	-- WP-08: duración y cooldown.
	check("candado base 30 s", Lock.duration(30, 10, false, 5, 0, 60) == 30)
	check("VIP suma 10", Lock.duration(30, 10, true, 5, 0, 60) == 40)
	check("Re-Fiesta suma y topa en 60", Lock.duration(30, 10, true, 5, 6, 60) == 60)
	check("cooldown bloquea", not Lock.canStart(10, 20) and Lock.canStart(20, 20))
	check("tiempo restante", Lock.remaining(5, 12) == 7 and Lock.remaining(20, 12) == 0)

	-- Movimiento: 16 → 11, y el salto llega a JumpHeight con esta gravedad.
	check("walk de diseño", m.walkSpeed == 16 and m.economyWalk == 16 and m.carrySpeed == 11 and m.economyCarry == 11)
	check("cargar es 11", Move.speed("carry", m.walkSpeed, m.carrySpeed) == 11)
	check("stun es 0", Move.speed("stun", m.walkSpeed, m.carrySpeed) == 0)
	local vJump = Move.jumpVelocity(m.gravity, m.jumpHeight)
	local apex = Move.apex(vJump, m.gravity)
	check("el ápice es JumpHeight", math.abs(apex - m.jumpHeight) < 1e-6, tostring(apex))
	local air = Move.airtime(vJump, m.gravity)
	check("el aire dura menos de 0.6 s", air > 0.3 and air < 0.6, tostring(air))
	local ix, iy, iz = Move.impulse(1, 0, 10, m.knockH, m.knockV)
	check("impulso horizontal", math.abs(ix - m.knockH * 10) < 1e-6 and iy == m.knockV * 10 and iz == 0)

	return { ok = #failed == 0, passed = passed, failed = failed, worstSpawnDelta = worst }
end

return SelfTest
