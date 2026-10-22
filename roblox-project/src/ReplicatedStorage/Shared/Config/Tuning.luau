--!strict
-- "La gravedad": todos los números de movimiento y de golpe viven aquí.
-- Las velocidades de caminar/cargar coinciden con Economy.Walk (GDD §4.3 y §12).
-- El porqué de cada valor está en roblox-project/PHYSICS.md.

local Tuning = {
	-- Workspace.Gravity. Default del motor: 196.2. Un poco más alto = arco corto y aterrizaje seco.
	Gravity = 210,
	-- Humanoid.UseJumpPower = false, así la altura NO cambia si se retoca la gravedad.
	-- Default del motor: JumpHeight 7.2 / JumpPower 50. 6.2 studs salta rico y no cruza la cerca.
	JumpHeight = 6.2,
	WalkSpeed = 16,
	CarrySpeed = 11,
	-- Impulso = delta-v * AssemblyMass (ApplyImpulse). Pop corto, no un cohete.
	KnockbackHorizontal = 62,
	KnockbackVertical = 32,
	-- Offset del weld: sobre la cabeza, un poco atrás, para que se lea en cámara.
	CarryOffsetX = 0,
	CarryOffsetY = 3.6,
	CarryOffsetZ = 0.35,
	-- No entregar en el mismo instante del robo si las zonas se tocaran.
	MinCarrySec = 0.4,
	-- Aterrizaje: elasticidad 0 y, si la caída pasó de esto (studs/s), shake chico.
	LandHardSpeed = 45,
	FallenPartsDestroyHeight = -80,
	Phys = {
		Density = 0.7,
		Friction = 0.35,
		Elasticity = 0,
		FrictionWeight = 1,
		ElasticityWeight = 100,
	},
	Shake = {
		BonkAmplitude = 0.16,
		BonkDuration = 0.2,
		LandAmplitude = 0.08,
		LandDuration = 0.12,
	},
	-- Dulces de práctica solo en Studio (el adaptador de memoria). En un server publicado no se regalan.
	PlaytestCandy = 2500,
	-- Tope de partículas por ráfaga (ART_DIRECTION: ≤ 40 por emisor en móvil).
	ConfettiCount = 28,
	Sfx = {
		Bonk = "rbxasset://sounds/collide.wav",
		Buy = "rbxasset://sounds/electronicpingshort.wav",
		Collect = "rbxasset://sounds/button.wav",
		Deliver = "rbxasset://sounds/Victory.wav",
		Lock = "rbxasset://sounds/switch.wav",
		Swing = "rbxasset://sounds/electronicpingshort.wav",
	},
	SfxVolume = 0.7,
}

return Tuning
