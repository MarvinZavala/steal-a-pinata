--!strict
-- Cercas de una base como cajas. El hueco de la puerta no está: cruzarlo no es noclip.
-- El layout es el de WorldLayout (FloorX, FloorZ, FenceHeight). La base mira en ±X.

local PlotSolids = {}

export type Box = {
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
}

function PlotSolids.toWorld(
	faceX: number,
	ox: number,
	oy: number,
	oz: number,
	lx: number,
	ly: number,
	lz: number
): (number, number, number)
	local wx = ox + -faceX * lz
	local wy = oy + ly
	local wz = oz + -faceX * lx
	return wx, wy, wz
end

local function boxOf(
	faceX: number,
	ox: number,
	oy: number,
	oz: number,
	lx: number,
	ly: number,
	lz: number,
	sx: number,
	sy: number,
	sz: number,
	skin: number
): Box?
	local cx, cy, cz = PlotSolids.toWorld(faceX, ox, oy, oz, lx, ly, lz)
	local hx = sz / 2 - skin
	local hy = sy / 2 - skin
	local hz = sx / 2 - skin
	if hx <= 0.05 or hy <= 0.05 or hz <= 0.05 then
		return nil
	end
	return {
		minX = cx - hx,
		maxX = cx + hx,
		minY = cy - hy,
		maxY = cy + hy,
		minZ = cz - hz,
		maxZ = cz + hz,
	}
end

function PlotSolids.boxes(layout: any, ox: number, oy: number, oz: number, faceX: number, skin: number): { Box }
	local floorX = layout.FloorX
	local floorZ = layout.FloorZ
	local fenceH = layout.FenceHeight
	local frontW = floorX / 2 - 7
	local frontX = 7 + frontW / 2
	local specs = {
		{ -floorX / 2, fenceH / 2, 0, 1, fenceH, floorZ },
		{ floorX / 2, fenceH / 2, 0, 1, fenceH, floorZ },
		{ 0, fenceH / 2, floorZ / 2, floorX, fenceH, 1 },
		{ -frontX, fenceH / 2, -floorZ / 2, frontW, fenceH, 1 },
		{ frontX, fenceH / 2, -floorZ / 2, frontW, fenceH, 1 },
	}
	local list: { Box } = {}
	for _, spec in specs do
		local made = boxOf(faceX, ox, oy, oz, spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], skin)
		if made ~= nil then
			table.insert(list, made)
		end
	end
	return list
end

local function axis(
	p: number,
	d: number,
	minB: number,
	maxB: number,
	tmin: number,
	tmax: number
): (boolean, number, number)
	if math.abs(d) < 1e-8 then
		if p < minB or p > maxB then
			return false, tmin, tmax
		end
		return true, tmin, tmax
	end
	local t1 = (minB - p) / d
	local t2 = (maxB - p) / d
	if t1 > t2 then
		t1, t2 = t2, t1
	end
	tmin = math.max(tmin, t1)
	tmax = math.min(tmax, t2)
	return tmin <= tmax, tmin, tmax
end

function PlotSolids.hitsBox(x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, box: Box): boolean
	local dx = x2 - x1
	local dy = y2 - y1
	local dz = z2 - z1
	local okX, tmin, tmax = axis(x1, dx, box.minX, box.maxX, 0, 1)
	if not okX then
		return false
	end
	local okY, tminY, tmaxY = axis(y1, dy, box.minY, box.maxY, tmin, tmax)
	if not okY then
		return false
	end
	local okZ = axis(z1, dz, box.minZ, box.maxZ, tminY, tmaxY)
	return okZ
end

function PlotSolids.hits(
	boxes: { Box },
	x1: number,
	y1: number,
	z1: number,
	x2: number,
	y2: number,
	z2: number
): boolean
	for _, box in boxes do
		if PlotSolids.hitsBox(x1, y1, z1, x2, y2, z2, box) then
			return true
		end
	end
	return false
end

function PlotSolids.insideFloor(
	layout: any,
	ox: number,
	oy: number,
	oz: number,
	faceX: number,
	x: number,
	y: number,
	z: number
): boolean
	local lx = -faceX * (z - oz)
	local ly = y - oy
	local lz = -faceX * (x - ox)
	return math.abs(lx) <= layout.FloorX / 2 and math.abs(lz) <= layout.FloorZ / 2 and ly > -4 and ly < 28
end

-- Cruzar el borde de la base por una cerca. Rozar el lado de afuera no cuenta:
-- los dos puntos siguen afuera y el jugador pudo haber doblado la esquina.
function PlotSolids.noclip(
	layout: any,
	ox: number,
	oy: number,
	oz: number,
	faceX: number,
	x1: number,
	y1: number,
	z1: number,
	x2: number,
	y2: number,
	z2: number,
	skin: number
): boolean
	local was = PlotSolids.insideFloor(layout, ox, oy, oz, faceX, x1, y1, z1)
	local nowInside = PlotSolids.insideFloor(layout, ox, oy, oz, faceX, x2, y2, z2)
	if was == nowInside then
		return false
	end
	return PlotSolids.crosses(layout, ox, oy, oz, faceX, x1, y1, z1, x2, y2, z2, skin)
end

function PlotSolids.crosses(
	layout: any,
	ox: number,
	oy: number,
	oz: number,
	faceX: number,
	x1: number,
	y1: number,
	z1: number,
	x2: number,
	y2: number,
	z2: number,
	skin: number
): boolean
	return PlotSolids.hits(PlotSolids.boxes(layout, ox, oy, oz, faceX, skin), x1, y1, z1, x2, y2, z2)
end

return PlotSolids
