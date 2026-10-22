--!strict
-- Medidas de La Plaza (art/scripts/lobby.py y art/IMPORT_GUIDE.md §5).
-- Eje: X/Z de Roblox = X/Y de Blender. La puerta de cada base mira a la plaza.

local WorldLayout = {
	PlotCount = 6,
	FloorX = 47.6,
	FloorZ = 59.6,
	GateLocalZ = -28,
	GeneratorLocalZ = 22,
	PedestalX = 13.5,
	PedestalZ0 = -16,
	PedestalStep = 10,
	PedestalRows = 4,
	FenceHeight = 10,
	PlazaRadius = 46,
	PlotX = 90, -- plaza 46 + 44, igual que lobby.py
	PlotZ = { -12, 42, 96 },
	PasarelaLength = 156,
	PasarelaWidth = 10,
	PasarelaZ = -52,
	PasarelaSpawnX = -78,
	PasarelaExitX = 78,
	PasarelaY = 3.4,
	LockRingMaxDistance = 140,
}

export type PlotSpot = { x: number, z: number, faceX: number }

function WorldLayout.plots(): { PlotSpot }
	local spots: { PlotSpot } = {}
	for _, side in { -1, 1 } do
		for _, z in WorldLayout.PlotZ do
			table.insert(spots, { x = side * WorldLayout.PlotX, z = z, faceX = -side })
		end
	end
	return spots
end

-- Índices 1..8, de adelante (la puerta) hacia el fondo, izquierda y luego derecha.
function WorldLayout.pedestalLocal(index: number): (number, number)
	local row = math.floor((index - 1) / 2)
	local side = if (index - 1) % 2 == 0 then -1 else 1
	local z = WorldLayout.PedestalZ0 + row * WorldLayout.PedestalStep
	return side * WorldLayout.PedestalX, z
end

return WorldLayout
