--!strict
-- Posadas Piñateras (GDD §11). Fechas en unix UTC para activar sin republicar.
-- ForceActive queda en false en el código que se publica.
-- En Studio, Workspace.ForcePosadas = true prende el evento fuera de la ventana
-- (fase ForcePhase, o Workspace.ForcePosadasPhase) y no convierte Bastones.

local Events = {
	ForceActive = false,
	-- soft | posadas | navidad | newyear | reyes. Solo aplica si el reloj real está fuera.
	ForcePhase = "posadas",
	PosadasPinateras = {
		StartUnix = 1796342400, -- 2026-12-04 00:00 UTC
		PosadasUnix = 1796947200, -- 2026-12-11 00:00 UTC
		NavidadUnix = 1798070400, -- 2026-12-24 00:00 UTC
		NavidadEndUnix = 1798243200, -- 2026-12-26 00:00 UTC (cubre el 24 y el 25)
		NewYearUnix = 1798675200, -- 2026-12-31 00:00 UTC
		NewYearEndUnix = 1798761600, -- 2027-01-01 00:00 UTC
		ReyesUnix = 1799193600, -- 2027-01-06 00:00 UTC
		EndUnix = 1799280000, -- 2027-01-07 00:00 UTC. Activo hasta el 6; conversión el 7.
		AdventEndUnix = 1798156800, -- 2026-12-25 00:00 UTC. El 24 es el último día.
		Currency = "Bastones",
		Pinatas = { "tamalito", "jengibrin", "renito" },
		RunwayId = "renito",
		RunwayChance = 0.005,
		ShopIds = { "tamalito", "jengibrin" },
		HatId = "gorro_navidad",
		HatPrice = 1500,
		HugId = "abrazo",
		HugPrice = 600,
		ChristmasMutationChance = 0.03,
		DulcesPerBaston = 20,
		AdventMaxMisses = 3,
		AdventFirstDay = 11,
		AdventFinaleDay = 24,
		AdventFinalePinata = "renito",
		AdventBastonesBase = 120,
		AdventBastonesStep = 30,
		AdventFinaleBastones = 2500,
		AdventFinaleBonus = 400,
		HitBastones = 4,
		FiestaBastonesBase = 180,
		FiestaBastonesPerHit = 6,
		RoscaFloor = 80,
		GiantId = "renito",
		Quests = {
			{ id = "e1", stat = "Buys", goal = 2, bastones = 150, titleKey = "event.quest_buy" },
			{ id = "e2", stat = "Bonks", goal = 2, bastones = 120, titleKey = "event.quest_bonk" },
			{ id = "e3", stat = "Collects", goal = 2, bastones = 80, titleKey = "event.quest_collect" },
		},
	},
}

return Events
