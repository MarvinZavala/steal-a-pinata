--!strict
-- WP-10b y WP-16. Umbrales de juego limpio. Las velocidades siguen en Tuning;
-- el slack de ping y el multiplicador de velocidad siguen en Security.
-- La economía (precios, offline, escudo en segundos) sigue en Economy.

local FairPlay = {
	-- Movimiento. Un sample corto con este extra todavía es "speed"; más allá es teleport.
	TeleportExtra = 40,
	KnockbackGraceSec = 1.8,
	PingCapSec = 0.3,
	-- Cadera de un avatar parado en la plaza. El salto de Tuning se suma encima.
	GroundY = 3,
	FlySlack = 8,
	-- La cerca mide 1 stud. Este margen deja rozar la esquina y no el cruce.
	NoclipSkin = 0.2,
	-- La piñata va soldada a ~3.6 studs. Más que esto, el weld está roto.
	MaxCarrySeparation = 8,
	CarryLockSec = 25,
	-- La misma falta de carga no suma puntaje en cada frame.
	RepeatStrikeSec = 2,
	-- Puntaje de la sesión. Decae para que un tirón de lag no se acumule.
	-- No persiste en el perfil y no es un ban.
	Weights = {
		speed = 2,
		teleport = 5,
		noclip = 5,
		fly = 4,
		carry_wall = 4,
		carry_far = 3,
		carry_dupe = 8,
		bat_spam = 2,
	},
	RubberBandAt = 6,
	CarryLockAt = 12,
	KickAt = 18,
	DecayPerSec = 0.25,
	Bat = {
		WindowSec = 6,
		-- Un humano al cooldown de 0.8 s cabe. El leaky bucket deja pasar ~2/s.
		MaxAttempts = 9,
		MinIntervalSec = 0.2,
		BurstCount = 4,
		FlagCooldownSec = 2,
	},
	-- Poder de base (Dulces/s). Confeti [0, 2K), Serpentina [2K, 100K), Fuego [100K, inf).
	-- Arranque con dos ligas abiertas (GDD §4.10). Sumar "Fuego" abre la tercera.
	Bands = {
		{ id = "Confeti", min = 0, max = 2000 },
		{ id = "Serpentina", min = 2000, max = 100000 },
		{ id = "Fuego", min = 100000, max = math.huge },
	},
	OpenLeagues = { "Confeti", "Serpentina" },
	-- Si la liga de destino no tiene server, se usa uno Mixto antes de reservar otro.
	PreferMixedWhenEmpty = true,
	MemoryStoreName = "StealAPinata_Leagues_v1",
	DirectoryHeartbeatSec = 15,
	DirectoryStaleSec = 40,
	DirectoryTtlSec = 60,
}

return FairPlay
