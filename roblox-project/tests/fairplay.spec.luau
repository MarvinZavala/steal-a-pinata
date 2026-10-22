--!strict
local H = require("./harness")
local BatSpam = require("../src/ReplicatedStorage/Shared/Gameplay/BatSpam")
local CarryIntegrity = require("../src/ReplicatedStorage/Shared/Gameplay/CarryIntegrity")
local DebugReport = require("../src/ReplicatedStorage/Shared/Gameplay/DebugReport")
local LeagueRules = require("../src/ReplicatedStorage/Shared/Gameplay/LeagueRules")
local MovementSanity = require("../src/ReplicatedStorage/Shared/Gameplay/MovementSanity")
local OfflineEarnings = require("../src/ReplicatedStorage/Shared/Gameplay/OfflineEarnings")
local PlotSolids = require("../src/ReplicatedStorage/Shared/Gameplay/PlotSolids")
local StealRules = require("../src/ReplicatedStorage/Shared/Gameplay/StealRules")
local Suspicion = require("../src/ReplicatedStorage/Shared/Gameplay/Suspicion")
local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local FairPlay = require("../src/ReplicatedStorage/Shared/Config/FairPlay")
local Security = require("../src/ReplicatedStorage/Shared/Config/Security")
local Tuning = require("../src/ReplicatedStorage/Shared/Config/Tuning")
local Layout = require("../src/ReplicatedStorage/Shared/Config/WorldLayout")

H.begin()

local cfg = MovementSanity.fromTuning(Tuning, Security, FairPlay)
local thresholds: Suspicion.Thresholds = {
	RubberBandAt = FairPlay.RubberBandAt,
	CarryLockAt = FairPlay.CarryLockAt,
	KickAt = FairPlay.KickAt,
	DecayPerSec = FairPlay.DecayPerSec,
}

local function stealInput(patch: { [string]: any }): any
	local base = {
		distance = 4,
		inRange = true,
		locked = false,
		alreadyCarrying = false,
		thiefIsRookie = false,
		victimIsRookie = false,
		thiefOutranksVictim = false,
		cooldownReady = true,
		recentStealsOnVictim = 0,
		maxStealsPerWindow = 2,
		thiefHasRoom = true,
		pinataAvailable = true,
		pinataProtected = false,
	}
	for key, value in patch do
		base[key] = value
	end
	return base
end

H.check("velocidad contra Tuning, con slack de lag", function()
	H.eq(cfg.walkSpeed, 16)
	H.eq(cfg.carrySpeed, 11)
	H.near(MovementSanity.allowedDistance(cfg, 0.3, "normal", 0, nil), 16 * 2 * 0.3 + 12)
	H.eq(MovementSanity.classify(cfg, 20, 0.3, "normal", 0, nil, 3), "ok")
	H.eq(MovementSanity.classify(cfg, 30, 0.3, "normal", 0, nil, 3), "speed")
	H.eq(MovementSanity.classify(cfg, 200, 0.3, "normal", 0, nil, 3), "teleport")
	H.eq(MovementSanity.classify(cfg, 24, 0.3, "normal", 0, nil, 3), "speed")
	H.eq(MovementSanity.classify(cfg, 24, 0.3, "normal", 0.3, nil, 3), "ok")
	H.eq(MovementSanity.classify(cfg, 0 / 0, 0.3, "normal", 0, nil, 3), "teleport")
end)

H.check("cargar es más estricto que caminar", function()
	local walking = MovementSanity.allowedDistance(cfg, 0.3, "normal", 0, nil)
	local carrying = MovementSanity.allowedDistance(cfg, 0.3, "carry", 0, nil)
	H.truthy(carrying < walking)
	H.eq(MovementSanity.classify(cfg, walking, 0.3, "carry", 0, nil, 3), "speed")
	H.eq(MovementSanity.classify(cfg, carrying, 0.3, "carry", 0, nil, 3), "ok")
end)

H.check("el knockback no es teleport y fuera de la ventana sí", function()
	H.eq(MovementSanity.classify(cfg, 40, 0.3, "stun", 0, nil, 3), "speed")
	H.eq(MovementSanity.classify(cfg, 40, 0.3, "stun", 0, 0.2, 3), "ok")
	H.eq(MovementSanity.classify(cfg, 40, 0.3, "stun", 0, cfg.knockbackGraceSec + 0.1, 3), "speed")
	H.eq(MovementSanity.classify(cfg, 1, 0.3, "normal", 0, nil, 40), "fly")
	H.eq(MovementSanity.classify(cfg, 1, 0.3, "normal", 0, nil, 10), "ok")
	local high = MovementSanity.maxHeight(cfg, 0.3, 0.1)
	H.eq(MovementSanity.classify(cfg, 1, 0.3, "stun", 0, 0.1, high - 0.5), "ok")
end)

H.check("la puerta no es noclip y la cerca sí", function()
	local ox, oy, oz, face = -90, 0, -12, 1
	local function at(lx: number, ly: number, lz: number): (number, number, number)
		return PlotSolids.toWorld(face, ox, oy, oz, lx, ly, lz)
	end
	local gx1, gy1, gz1 = at(0, 3, -40)
	local gx2, gy2, gz2 = at(0, 3, -10)
	H.eq(PlotSolids.crosses(Layout, ox, oy, oz, face, gx1, gy1, gz1, gx2, gy2, gz2, FairPlay.NoclipSkin), false)
	H.eq(PlotSolids.noclip(Layout, ox, oy, oz, face, gx1, gy1, gz1, gx2, gy2, gz2, FairPlay.NoclipSkin), false)
	local wx1, wy1, wz1 = at(-30, 3, 0)
	local wx2, wy2, wz2 = at(-10, 3, 0)
	H.eq(PlotSolids.noclip(Layout, ox, oy, oz, face, wx1, wy1, wz1, wx2, wy2, wz2, FairPlay.NoclipSkin), true)
	local rx1, ry1, rz1 = at(-26, 3, 0)
	local rx2, ry2, rz2 = at(-24.4, 3, 0)
	H.eq(PlotSolids.noclip(Layout, ox, oy, oz, face, rx1, ry1, rz1, rx2, ry2, rz2, FairPlay.NoclipSkin), false)
end)

H.check("soltar por la cerca y entregar de lejos", function()
	local okWall, whyWall = CarryIntegrity.canDrop(true)
	H.eq(okWall, false)
	H.eq(whyWall, "wall")
	H.eq(CarryIntegrity.canDrop(false), true)
	local far, whyFar = CarryIntegrity.canDeliver({
		inside = true,
		modelOffset = FairPlay.MaxCarrySeparation + 1,
		maxOffset = FairPlay.MaxCarrySeparation,
		age = 1,
		minAge = 0.4,
		crossesSolid = false,
	})
	H.eq(far, false)
	H.eq(whyFar, "far")
	local through, whyThrough = CarryIntegrity.canDeliver({
		inside = true,
		modelOffset = 3,
		maxOffset = FairPlay.MaxCarrySeparation,
		age = 1,
		minAge = 0.4,
		crossesSolid = true,
	})
	H.eq(through, false)
	H.eq(whyThrough, "wall")
	local good, whyGood = CarryIntegrity.canDeliver({
		inside = true,
		modelOffset = 3.6,
		maxOffset = FairPlay.MaxCarrySeparation,
		age = 1,
		minAge = 0.4,
		crossesSolid = false,
	})
	H.eq(good, true)
	H.eq(whyGood, "ok")
	local soon, whySoon = CarryIntegrity.canDeliver({
		inside = true,
		modelOffset = 3,
		maxOffset = 8,
		age = 0.1,
		minAge = 0.4,
		crossesSolid = false,
	})
	H.eq(soon, false)
	H.eq(whySoon, "soon")
end)

H.check("rejoin y crash a mitad del robo no duplican", function()
	local ledger, opened, why, generation = CarryIntegrity.begin(CarryIntegrity.empty(), "pinata-1", 10, 20)
	H.eq(opened, true)
	H.eq(why, "ok")
	local _, againOk, againWhy = CarryIntegrity.begin(ledger, "pinata-1", 10, 30)
	H.eq(againOk, false)
	H.eq(againWhy, "busy")
	local victimHas = true
	local thiefHas = false
	local crashed = CarryIntegrity.empty()
	H.eq(CarryIntegrity.get(crashed, "pinata-1"), nil)
	H.eq(CarryIntegrity.persistence(victimHas, thiefHas), "ok")
	H.eq(CarryIntegrity.persistence(true, true), "duplicated")
	local returnedLedger, uids = CarryIntegrity.rejoin(ledger, 20)
	H.eq(#uids, 1)
	H.eq(uids[1], "pinata-1")
	local home = CarryIntegrity.get(returnedLedger, "pinata-1")
	H.truthy(home ~= nil and home.state == "home" and home.ownerUserId == 10)
	local _, lateOk, lateWhy = CarryIntegrity.deliver(returnedLedger, "pinata-1", generation, 20)
	H.eq(lateOk, false)
	H.eq(lateWhy, "duplicate")
	H.eq(thiefHas, false)
end)

H.check("deliver una vez y la segunda es duplicado", function()
	local ledger, opened, _, generation = CarryIntegrity.begin(CarryIntegrity.empty(), "pinata-1", 10, 20)
	H.eq(opened, true)
	local moved, okMove = CarryIntegrity.deliver(ledger, "pinata-1", generation, 20)
	H.eq(okMove, true)
	local owner = CarryIntegrity.get(moved, "pinata-1")
	H.truthy(owner ~= nil and owner.ownerUserId == 20 and owner.state == "home")
	local _, again, why = CarryIntegrity.deliver(moved, "pinata-1", generation, 20)
	H.eq(again, false)
	H.eq(why, "duplicate")
	local restored = CarryIntegrity.restore(moved, "pinata-1", 10)
	local back = CarryIntegrity.get(restored, "pinata-1")
	H.truthy(back ~= nil and back.ownerUserId == 10)
end)

H.check("autoclick por debajo del cooldown y el ritmo legal no", function()
	local bat: BatSpam.Config = {
		WindowSec = FairPlay.Bat.WindowSec,
		MaxAttempts = FairPlay.Bat.MaxAttempts,
		MinIntervalSec = FairPlay.Bat.MinIntervalSec,
		BurstCount = FairPlay.Bat.BurstCount,
	}
	local state = BatSpam.empty()
	local verdict = "ok"
	for step = 0, 7 do
		local nextState, stepVerdict = BatSpam.observe(state, step * 0.8, bat)
		state = nextState
		verdict = stepVerdict
	end
	H.eq(verdict, "ok")
	state = BatSpam.empty()
	for step = 0, 5 do
		local nextState, stepVerdict = BatSpam.observe(state, step * 0.05, bat)
		state = nextState
		verdict = stepVerdict
	end
	H.eq(verdict, "spam")
end)

H.check("escalera de puntaje sin ban en el primer flag", function()
	local memory = Suspicion.blank()
	memory = Suspicion.strike(memory, 10, "speed", FairPlay.Weights.speed, thresholds)
	H.eq(memory.response, "log")
	H.eq(Suspicion.shouldCorrect("speed", memory.response), false)
	H.eq(Suspicion.shouldCorrect("teleport", "log"), true)
	memory = Suspicion.strike(memory, 10, "speed", FairPlay.Weights.speed, thresholds)
	memory = Suspicion.strike(memory, 10, "speed", FairPlay.Weights.speed, thresholds)
	H.eq(memory.response, "rubberband")
	memory = Suspicion.blank()
	memory = Suspicion.strike(memory, 5, "teleport", FairPlay.Weights.teleport, thresholds)
	H.eq(memory.response, "log")
	memory = Suspicion.strike(memory, 5, "teleport", FairPlay.Weights.teleport, thresholds)
	H.eq(memory.response, "rubberband")
	memory = Suspicion.strike(memory, 5, "teleport", FairPlay.Weights.teleport, thresholds)
	H.eq(memory.response, "carry_lock")
	memory = Suspicion.strike(memory, 5, "teleport", FairPlay.Weights.teleport, thresholds)
	H.eq(memory.response, "kick")
	local cooled = Suspicion.strike(memory, 5 + 1000, "speed", FairPlay.Weights.speed, thresholds)
	H.eq(cooled.response, "log")
	H.truthy(cooled.value < FairPlay.RubberBandAt)
end)

H.check("ligas: Fuego no entra a Confeti", function()
	H.eq(FairPlay.Bands[1].id, "Confeti")
	H.eq(FairPlay.Bands[1].max, 2000)
	H.eq(FairPlay.Bands[2].max, 100000)
	H.eq(LeagueRules.leagueOf(0, FairPlay.Bands), "Confeti")
	H.eq(LeagueRules.leagueOf(1999.9, FairPlay.Bands), "Confeti")
	H.eq(LeagueRules.leagueOf(2000, FairPlay.Bands), "Serpentina")
	H.eq(LeagueRules.leagueOf(99999, FairPlay.Bands), "Serpentina")
	H.eq(LeagueRules.leagueOf(100000, FairPlay.Bands), "Fuego")
	H.eq(LeagueRules.destination("Fuego", FairPlay.OpenLeagues), "Serpentina")
	H.eq(LeagueRules.destination("Fuego", { "Confeti" }), "Mixto")
	H.eq(LeagueRules.destination("Fuego", { "Confeti", "Serpentina", "Fuego" }), "Fuego")
	local wrong = LeagueRules.decide({
		studio = false,
		vip = false,
		serverLeague = "Confeti",
		playerLeague = "Fuego",
		openLeagues = FairPlay.OpenLeagues,
		lockedMixed = false,
	})
	H.eq(wrong.action, "redirect")
	H.eq(wrong.league, "Serpentina")
	local third = LeagueRules.decide({
		studio = false,
		vip = false,
		serverLeague = "Confeti",
		playerLeague = "Fuego",
		openLeagues = { "Confeti", "Serpentina", "Fuego" },
		lockedMixed = false,
	})
	H.eq(third.action, "redirect")
	H.eq(third.league, "Fuego")
	local claim = LeagueRules.decide({
		studio = false,
		vip = false,
		serverLeague = "Mixto",
		playerLeague = "Fuego",
		openLeagues = FairPlay.OpenLeagues,
		lockedMixed = false,
	})
	H.eq(claim.action, "claim")
	H.eq(claim.league, "Serpentina")
end)

H.check("privado, Studio y mixto no mandan a Confeti", function()
	local studio = LeagueRules.decide({
		studio = true,
		vip = false,
		serverLeague = "Confeti",
		playerLeague = "Fuego",
		openLeagues = FairPlay.OpenLeagues,
		lockedMixed = false,
	})
	H.eq(studio.action, "stay")
	local vip = LeagueRules.decide({
		studio = false,
		vip = true,
		serverLeague = "Confeti",
		playerLeague = "Fuego",
		openLeagues = FairPlay.OpenLeagues,
		lockedMixed = false,
	})
	H.eq(vip.action, "stay")
	H.eq(vip.league, "Privado")
	local mixed = LeagueRules.decide({
		studio = false,
		vip = false,
		serverLeague = "Mixto",
		playerLeague = "Fuego",
		openLeagues = FairPlay.OpenLeagues,
		lockedMixed = true,
	})
	H.eq(mixed.action, "stay")
	H.eq(mixed.league, "Mixto")
	H.eq(LeagueRules.serverKind("", 0), "public")
	H.eq(LeagueRules.serverKind("abc", 0), "reserved")
	H.eq(LeagueRules.serverKind("abc", 42), "vip")
	H.eq(LeagueRules.shouldPublish("vip", "code"), false)
	H.eq(LeagueRules.shouldPublish("public", nil), false)
	H.eq(LeagueRules.shouldPublish("reserved", "code"), true)
end)

H.check("directorio: liga propia, mixto si está vacía, reservar si no hay", function()
	local now = 1_000
	local fuego = { league = "Fuego", jobId = "f", players = 2, accessCode = "ff", updatedAt = now }
	local mix = { league = "Mixto", jobId = "m", players = 1, accessCode = "mm", updatedAt = now }
	local picked = LeagueRules.whereTo("Fuego", { fuego }, { mix }, now, 40, 6, "me", true)
	H.eq(picked.kind, "join")
	H.eq(picked.league, "Fuego")
	H.eq(picked.accessCode, "ff")
	local fallback = LeagueRules.whereTo("Fuego", {}, { mix }, now, 40, 6, "me", true)
	H.eq(fallback.kind, "join")
	H.eq(fallback.league, "Mixto")
	local reserve = LeagueRules.whereTo("Fuego", {}, {}, now, 40, 6, "me", true)
	H.eq(reserve.kind, "reserve")
	H.eq(reserve.league, "Fuego")
	local stale = { league = "Fuego", jobId = "old", players = 1, accessCode = "zz", updatedAt = now - 100 }
	local full = { league = "Fuego", jobId = "full", players = 6, accessCode = "ff", updatedAt = now }
	local skipped = LeagueRules.whereTo("Fuego", { stale, full }, {}, now, 40, 6, "me", false)
	H.eq(skipped.kind, "reserve")
end)

H.check("el veterano no roba al de liga más baja", function()
	H.eq(LeagueRules.canSteal("Fuego", "Confeti"), false)
	H.eq(LeagueRules.canSteal("Serpentina", "Confeti"), false)
	H.eq(LeagueRules.canSteal("Confeti", "Confeti"), true)
	H.eq(LeagueRules.canSteal("Confeti", "Fuego"), true)
	H.eq(LeagueRules.canSteal("Fuego", "Fuego"), true)
	local blocked, why = StealRules.evaluate(stealInput({ thiefOutranksVictim = true }))
	H.eq(blocked, false)
	H.eq(why, "tier")
	local rookie, whyRookie = StealRules.evaluate(stealInput({ victimIsRookie = true, thiefOutranksVictim = true }))
	H.eq(rookie, false)
	H.eq(whyRookie, "rookie")
	local same, whySame = StealRules.evaluate(stealInput({}))
	H.eq(same, true)
	H.eq(whySame, "ok")
end)

H.check("escudo de 15 min y offline 50% con tope de 8 h", function()
	H.eq(Economy.RookieShieldSec, 15 * 60)
	H.eq(LeagueRules.shielded(0, Economy.RookieShieldSec), true)
	H.eq(LeagueRules.shielded(Economy.RookieShieldSec - 1, Economy.RookieShieldSec), true)
	H.eq(LeagueRules.shielded(Economy.RookieShieldSec, Economy.RookieShieldSec), false)
	H.eq(LeagueRules.shieldLeft(60, Economy.RookieShieldSec), Economy.RookieShieldSec - 60)
	local cap = 8 * 3600 * 10 * Economy.OfflineRate
	H.near(OfflineEarnings.earned(10, 2 * 3600, Economy.OfflineRate, Economy.OfflineCapHours), 2 * 3600 * 10 * 0.5)
	H.near(OfflineEarnings.earned(10, 10 * 3600, Economy.OfflineRate, Economy.OfflineCapHours), cap)
	H.eq(Economy.OfflineRate, 0.5)
	H.eq(Economy.OfflineCapHours, 8)
end)

H.check("la vista de admin no lleva inventario", function()
	local text = DebugReport.format({
		{
			userId = 7,
			name = "Nia",
			score = 4,
			response = "log",
			league = "Confeti",
			power = 12,
			carryLocked = false,
			lastReason = "speed",
		},
	}, {
		{ userId = 7, playerName = "Nia", reason = "speed", count = 1 },
	})
	H.truthy(string.find(text, "score=4.0", 1, true) ~= nil)
	H.truthy(string.find(text, "liga=Confeti", 1, true) ~= nil)
	H.truthy(string.find(text, "no se replica", 1, true) ~= nil)
	H.eq(string.find(text, "Inventory", 1, true), nil)
	H.eq(string.find(text, "Dulces", 1, true), nil)
end)

H.finish()
