--!strict
-- Tamaños en píxeles a partir del alto real (o de un teléfono simulado en el preview).
-- Botones nunca bajan de 48 px. En horizontal corto se reserva margen lateral para el notch.

export type Metrics = {
	w: number,
	h: number,
	margin: number,
	button: number,
	candyH: number,
	chip: number,
	title: number,
	body: number,
	small: number,
	num: number,
	radius: number,
	stroke: number,
	compact: boolean,
	portrait: boolean,
	safeTop: number,
	safeBottom: number,
	safeLeft: number,
	safeRight: number,
}

export type Insets = {
	l: number,
	t: number,
	r: number,
	b: number,
}

local ZERO: Insets = { l = 0, t = 0, r = 0, b = 0 }

local override: Vector2? = nil
local extra: Insets = ZERO
local listeners: { (Metrics) -> () } = {}
local current: Metrics = {
	w = 1280,
	h = 720,
	margin = 12,
	button = 64,
	candyH = 72,
	chip = 40,
	title = 28,
	body = 18,
	small = 15,
	num = 40,
	radius = 20,
	stroke = 4,
	compact = false,
	portrait = false,
	safeTop = 0,
	safeBottom = 0,
	safeLeft = 0,
	safeRight = 0,
}
local update: () -> () = function() end

local Metrics = {}

local function compute(w: number, h: number): Metrics
	if w < 1 then
		w = 1280
	end
	if h < 1 then
		h = 720
	end
	local short = math.min(w, h)
	local portrait = h > w * 1.05
	local compact = h < 460 or w < 760
	local button = if portrait
		then math.clamp(math.floor(short * 0.14), 48, 76)
		else math.clamp(math.floor(h * 0.16), 48, 74)
	local body = math.clamp(math.floor(short * 0.042), 16, 22)
	local num = math.clamp(math.floor(h * 0.085), 28, 52)
	return {
		w = w,
		h = h,
		margin = math.clamp(math.floor(short * 0.025), 8, 16),
		button = button,
		candyH = num + math.floor(body * 0.9) + 16,
		chip = math.max(36, math.floor(button * 0.62)),
		title = math.clamp(math.floor(short * 0.065), 20, 36),
		body = body,
		small = math.max(14, body - 2),
		num = num,
		radius = math.clamp(math.floor(short * 0.045), 16, 24),
		stroke = if compact then 3 else 4,
		compact = compact,
		portrait = portrait,
		safeTop = extra.t,
		safeBottom = extra.b,
		safeLeft = extra.l,
		safeRight = extra.r,
	}
end

function Metrics.bind(stage: Frame)
	update = function()
		local w = stage.AbsoluteSize.X
		local h = stage.AbsoluteSize.Y
		if override then
			w = override.X
			h = override.Y
		end
		current = compute(w, h)
		for _, fn in listeners do
			fn(current)
		end
	end
	stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if override then
			return
		end
		update()
	end)
	task.defer(update)
end

function Metrics.setOverride(size: Vector2?, insets: Insets?)
	override = size
	extra = insets or ZERO
	update()
end

function Metrics.get(): Metrics
	return current
end

function Metrics.onChange(fn: (Metrics) -> ())
	table.insert(listeners, fn)
	fn(current)
end

return Metrics
