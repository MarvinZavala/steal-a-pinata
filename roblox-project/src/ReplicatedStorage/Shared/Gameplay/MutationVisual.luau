--!strict
-- Cómo se ve una mutación en el modelo (ART_DIRECTION §5).
-- Dorada = shimmer dorado. Arcoíris = hue-shift. Puro: sin instancias, para Lune.
-- Navideña no entra: la pinta el evento, no este módulo.

local MutationVisual = {}

export type Rgb = { r: number, g: number, b: number }

export type Paint = {
	material: string?,
	tint: string,
}

export type FxProfile = {
	particleScale: number,
	maxRate: number,
	light: boolean,
	hueStep: number,
}

export type SparkleStop = { t: number, r: number, g: number, b: number }

local function hex(value: string): Rgb
	local r = tonumber(string.sub(value, 2, 3), 16) or 0
	local g = tonumber(string.sub(value, 4, 5), 16) or 0
	local b = tonumber(string.sub(value, 6, 7), 16) or 0
	return { r = r / 255, g = g / 255, b = b / 255 }
end

local GOLD = hex("#FFC22E")
local GOLD_DEEP = hex("#E08A00")
local WARM = hex("#FFD84D")

-- Paleta de confeti (ART_DIRECTION §1.4 y §5). El último stop cierra el ciclo en el rosa.
local RAINBOW_STOPS: { SparkleStop } = {
	{ t = 0, r = hex("#FF3E9A").r, g = hex("#FF3E9A").g, b = hex("#FF3E9A").b },
	{ t = 0.2, r = hex("#FFE14D").r, g = hex("#FFE14D").g, b = hex("#FFE14D").b },
	{ t = 0.4, r = hex("#8BE530").r, g = hex("#8BE530").g, b = hex("#8BE530").b },
	{ t = 0.6, r = hex("#16D3E8").r, g = hex("#16D3E8").g, b = hex("#16D3E8").b },
	{ t = 0.8, r = hex("#8A3CF0").r, g = hex("#8A3CF0").g, b = hex("#8A3CF0").b },
	{ t = 1, r = hex("#FF3E9A").r, g = hex("#FF3E9A").g, b = hex("#FF3E9A").b },
}

local FACE_TOKENS = {
	"eye",
	"face",
	"mouth",
	"smile",
	"lid",
	"lash",
	"pupil",
	"iris",
	"sclera",
	"brow",
	"blush",
	"cheek",
	"highlight",
}

MutationVisual.TAG = "MutatedPinata"
MutationVisual.GOLD = GOLD
MutationVisual.GOLD_DEEP = GOLD_DEEP
MutationVisual.WARM = WARM
MutationVisual.RAINBOW_STOPS = RAINBOW_STOPS
MutationVisual.RAINBOW_PERIOD = 3
MutationVisual.RAINBOW_SATURATION = 0.85
MutationVisual.RAINBOW_VALUE = 1
MutationVisual.GOLDEN_RATE = 8
MutationVisual.RAINBOW_RATE = 12
MutationVisual.MAX_RATE = 40
MutationVisual.MAX_ALIVE = 40
MutationVisual.LIFE_MIN = 0.35
MutationVisual.LIFE_MAX = 0.7
MutationVisual.LIGHT_BRIGHTNESS = 1
MutationVisual.LIGHT_RANGE = 10
MutationVisual.FACE_VOLUME_SHARE = 0.08
MutationVisual.FACE_DARK_LUMA = 0.12
MutationVisual.FACE_LIGHT_LUMA = 0.92

function MutationVisual.kind(mutation: any): string?
	if mutation == "Golden" or mutation == "Rainbow" then
		return mutation
	end
	return nil
end

function MutationVisual.qualityFromName(name: any): number
	if type(name) ~= "string" then
		return 0
	end
	local digits = string.match(name, "^QualityLevel(%d+)$")
	if digits == nil then
		return 0
	end
	local level = tonumber(digits)
	if level == nil or level < 1 or level > 10 then
		return 0
	end
	return level
end

-- Enum.QualityLevel del render ("Level01" …). Por encima de 10 cuenta como calidad alta.
function MutationVisual.levelFromQuality(name: any): number
	if type(name) ~= "string" then
		return 0
	end
	local digits = string.match(name, "^Level(%d+)$")
	if digits == nil then
		return 0
	end
	local level = tonumber(digits)
	if level == nil or level < 1 then
		return 0
	end
	if level > 10 then
		return 10
	end
	return level
end

-- 0 = automática o desconocida (fx completos). Si hay dos lecturas, manda la más baja.
function MutationVisual.qualityFromNames(savedName: any, renderName: any): number
	local saved = MutationVisual.qualityFromName(savedName)
	local render = MutationVisual.levelFromQuality(renderName)
	if saved == 0 then
		return render
	end
	if render == 0 then
		return saved
	end
	return math.min(saved, render)
end

function MutationVisual.fxProfile(quality: number, reduceMotion: boolean): FxProfile
	local calm = reduceMotion == true
	local q = quality
	if type(q) ~= "number" or q ~= q or q < 1 then
		q = 0
	else
		q = math.clamp(math.floor(q), 0, 10)
	end
	local scale = 1
	local hueStep = 0
	local light = true
	if calm then
		scale = 0.25
		hueStep = 0.25
		light = false
	elseif q >= 1 and q <= 2 then
		scale = 0.35
		hueStep = 0.12
		light = false
	elseif q >= 3 and q <= 4 then
		scale = 0.55
		hueStep = 0.08
		light = true
	elseif q >= 5 and q <= 6 then
		scale = 0.75
		hueStep = 0
		light = true
	end
	return {
		particleScale = scale,
		maxRate = MutationVisual.MAX_RATE,
		light = light,
		hueStep = hueStep,
	}
end

function MutationVisual.rateFor(kind: string): number
	if kind == "Golden" then
		return MutationVisual.GOLDEN_RATE
	end
	if kind == "Rainbow" then
		return MutationVisual.RAINBOW_RATE
	end
	return 0
end

function MutationVisual.particleRate(base: number, quality: number, reduceMotion: boolean): number
	if type(base) ~= "number" or base ~= base or base <= 0 then
		return 0
	end
	local profile = MutationVisual.fxProfile(quality, reduceMotion)
	local rate = math.floor(base * profile.particleScale + 0.5)
	if rate < 1 then
		rate = 1
	end
	return math.min(rate, profile.maxRate)
end

function MutationVisual.hueAt(timeSec: number, period: number, phase: number): number
	local span = period
	if type(span) ~= "number" or span ~= span or span <= 0 then
		span = 1
	end
	local t = if type(timeSec) == "number" and timeSec == timeSec then timeSec else 0
	local shift = if type(phase) == "number" and phase == phase then phase else 0
	local wrapped = (t / span + shift) % 1
	if wrapped < 0 then
		wrapped += 1
	end
	return wrapped
end

function MutationVisual.phaseForIndex(index: number, count: number): number
	if type(count) ~= "number" or count ~= count or count <= 1 then
		return 0
	end
	local i = if type(index) == "number" and index == index and index >= 1 then index else 1
	return ((i - 1) % count) / count
end

function MutationVisual.hsvToRgb(h: number, s: number, v: number): Rgb
	local hue = if type(h) == "number" and h == h then h % 1 else 0
	if hue < 0 then
		hue += 1
	end
	local sat = if type(s) == "number" and s == s then math.clamp(s, 0, 1) else 0
	local val = if type(v) == "number" and v == v then math.clamp(v, 0, 1) else 0
	local sector = hue * 6
	local i = math.floor(sector) % 6
	local f = sector - math.floor(sector)
	local p = val * (1 - sat)
	local q = val * (1 - f * sat)
	local t = val * (1 - (1 - f) * sat)
	if i == 0 then
		return { r = val, g = t, b = p }
	elseif i == 1 then
		return { r = q, g = val, b = p }
	elseif i == 2 then
		return { r = p, g = val, b = t }
	elseif i == 3 then
		return { r = p, g = q, b = val }
	elseif i == 4 then
		return { r = t, g = p, b = val }
	end
	return { r = val, g = p, b = q }
end

function MutationVisual.rainbowRgb(timeSec: number, phase: number): Rgb
	local hue = MutationVisual.hueAt(timeSec, MutationVisual.RAINBOW_PERIOD, phase)
	return MutationVisual.hsvToRgb(hue, MutationVisual.RAINBOW_SATURATION, MutationVisual.RAINBOW_VALUE)
end

function MutationVisual.tintRgb(tint: string, timeSec: number, phase: number): Rgb?
	if tint == "gold" then
		return GOLD
	end
	if tint == "cycle" then
		return MutationVisual.rainbowRgb(timeSec, phase)
	end
	return nil
end

function MutationVisual.lightRgb(kind: string, timeSec: number): Rgb?
	if kind == "Golden" then
		return WARM
	end
	if kind == "Rainbow" then
		return MutationVisual.rainbowRgb(timeSec, 0)
	end
	return nil
end

function MutationVisual.sparkleStops(kind: string): { SparkleStop }?
	if kind == "Golden" then
		return {
			{ t = 0, r = GOLD_DEEP.r, g = GOLD_DEEP.g, b = GOLD_DEEP.b },
			{ t = 1, r = WARM.r, g = WARM.g, b = WARM.b },
		}
	end
	if kind == "Rainbow" then
		return RAINBOW_STOPS
	end
	return nil
end

function MutationVisual.isAura(name: string): boolean
	return name == "Neon" or string.sub(name, -5) == "_Neon"
end

function MutationVisual.readsAsFace(name: string, luma: number, volume: number, largest: number): boolean
	local lower = string.lower(name)
	for _, token in FACE_TOKENS do
		if string.find(lower, token, 1, true) ~= nil then
			return true
		end
	end
	if type(largest) ~= "number" or largest <= 0 or type(volume) ~= "number" or volume <= 0 then
		return false
	end
	if volume / largest > MutationVisual.FACE_VOLUME_SHARE then
		return false
	end
	if type(luma) ~= "number" then
		return false
	end
	if luma <= MutationVisual.FACE_DARK_LUMA or luma >= MutationVisual.FACE_LIGHT_LUMA then
		return true
	end
	return false
end

function MutationVisual.skipPart(
	name: string,
	transparency: number,
	luma: number,
	volume: number,
	largest: number
): boolean
	if name == "Root" or (type(transparency) == "number" and transparency >= 0.99) then
		return true
	end
	return MutationVisual.readsAsFace(name, luma, volume, largest)
end

function MutationVisual.paintRole(
	name: string,
	transparency: number,
	luma: number,
	volume: number,
	largest: number
): string
	if MutationVisual.skipPart(name, transparency, luma, volume, largest) then
		return "skip"
	end
	if MutationVisual.isAura(name) then
		return "aura"
	end
	return "body"
end

-- Foil en el cuerpo (oro metálico). El neón se queda en Neon para que el aura siga leyéndose.
-- Arcoíris no cambia el material: solo cicla el color (hue-shift del cuerpo y del aura).
function MutationVisual.paintFor(kind: string, role: string): Paint?
	if MutationVisual.kind(kind) == nil or role == "skip" then
		return nil
	end
	if kind == "Golden" then
		if role == "aura" then
			return { material = "Neon", tint = "gold" }
		end
		return { material = "Foil", tint = "gold" }
	end
	if role == "aura" then
		return { material = "Neon", tint = "cycle" }
	end
	return { material = nil, tint = "cycle" }
end

return MutationVisual
