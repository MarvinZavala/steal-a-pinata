--!strict
-- Pinta las piñatas con tag MutatedPinata. Un solo Heartbeat cicla el matiz
-- de todas las Arcoíris; no hay un loop por modelo en el servidor.
-- Chispas y luz nacen acá (no se replican). Menos movimiento o calidad baja las baja.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationVisual =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Gameplay"):WaitForChild("MutationVisual"))
local UIState = require(script.Parent.Parent.UI.UIState)

type SavedPart = {
	part: BasePart,
	color: Color3,
	material: Enum.Material,
	role: string,
	phase: number,
	surface: SurfaceAppearance?,
	surfaceColor: Color3?,
}

type Entry = {
	model: Model,
	kind: string,
	parts: { SavedPart },
	partOf: { [BasePart]: SavedPart },
	conns: { RBXScriptConnection },
	emitter: ParticleEmitter?,
	light: PointLight?,
	largest: number,
	dead: boolean,
}

local MutationVisualController = {}

local tracked: { [Model]: Entry } = {}
local started = false
local quality = 0
local reduceMotion = false
local fx = MutationVisual.fxProfile(0, false)
local hueAccum = 0
local heartbeat: RBXScriptConnection? = nil

local materialByName: { [string]: Enum.Material } = {}

local function enumMaterial(name: string): Enum.Material
	local cached = materialByName[name]
	if cached ~= nil then
		return cached
	end
	for _, item in Enum.Material:GetEnumItems() do
		if item.Name == name then
			materialByName[name] = item
			return item
		end
	end
	materialByName[name] = Enum.Material.Metal
	return Enum.Material.Metal
end

local function lumaOf(color: Color3): number
	return color.R * 0.3 + color.G * 0.59 + color.B * 0.11
end

local function colorOf(rgb: MutationVisual.Rgb): Color3
	return Color3.new(rgb.r, rgb.g, rgb.b)
end

local function sequenceOf(stops: { MutationVisual.SparkleStop }): ColorSequence
	local keys = {}
	for _, stop in stops do
		table.insert(keys, ColorSequenceKeypoint.new(stop.t, Color3.new(stop.r, stop.g, stop.b)))
	end
	return ColorSequence.new(keys)
end

local function pullQuality(): number
	local savedName: string? = nil
	local renderName: string? = nil
	pcall(function()
		local user = UserSettings():GetService("UserGameSettings")
		local level = (user :: any).SavedQualityLevel
		if typeof(level) == "EnumItem" then
			savedName = level.Name
		end
	end)
	pcall(function()
		local rendering = settings().Rendering
		local level = rendering.QualityLevel
		if typeof(level) == "EnumItem" then
			renderName = level.Name
		end
	end)
	return MutationVisual.qualityFromNames(savedName, renderName)
end

local function refreshFx()
	quality = pullQuality()
	fx = MutationVisual.fxProfile(quality, reduceMotion)
end

local function anyRainbow(): boolean
	for _, entry in tracked do
		if entry.kind == "Rainbow" and not entry.dead then
			return true
		end
	end
	return false
end

local function stopHeartbeat()
	if heartbeat ~= nil then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	hueAccum = 0
end

local function restorePart(saved: SavedPart)
	pcall(function()
		if saved.part.Parent == nil then
			return
		end
		saved.part.Color = saved.color
		saved.part.Material = saved.material
		local surface = saved.surface
		if surface ~= nil and surface.Parent ~= nil and saved.surfaceColor ~= nil then
			surface.Color = saved.surfaceColor
		end
	end)
end

local function applyMaterial(saved: SavedPart, kind: string)
	local paint = MutationVisual.paintFor(kind, saved.role)
	if paint == nil or paint.material == nil then
		return
	end
	pcall(function()
		if saved.part.Parent == nil then
			return
		end
		saved.part.Material = enumMaterial(paint.material :: string)
	end)
end

local function applyColor(saved: SavedPart, kind: string, now: number)
	local paint = MutationVisual.paintFor(kind, saved.role)
	if paint == nil then
		return
	end
	local rgb = MutationVisual.tintRgb(paint.tint, now, saved.phase)
	if rgb == nil then
		return
	end
	local color = colorOf(rgb)
	pcall(function()
		if saved.part.Parent == nil then
			return
		end
		saved.part.Color = color
		local surface = saved.surface
		if surface ~= nil and surface.Parent ~= nil then
			surface.Color = color
		end
	end)
end

local function paintAll(entry: Entry, now: number)
	for _, saved in entry.parts do
		applyMaterial(saved, entry.kind)
		applyColor(saved, entry.kind, now)
	end
end

local function relayout(entry: Entry)
	local count = #entry.parts
	for index, saved in entry.parts do
		saved.phase = MutationVisual.phaseForIndex(index, count)
	end
end

local function recomputeLargest(entry: Entry)
	local largest = 0
	for _, desc in entry.model:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name ~= "Root" and desc.Transparency < 0.99 then
			local size = desc.Size
			local volume = size.X * size.Y * size.Z
			if volume > largest then
				largest = volume
			end
		end
	end
	entry.largest = largest
end

local function roleFor(part: BasePart, sample: Color3, largest: number): string
	local size = part.Size
	local volume = size.X * size.Y * size.Z
	return MutationVisual.paintRole(part.Name, part.Transparency, lumaOf(sample), volume, largest)
end

local function capture(entry: Entry, part: BasePart): SavedPart?
	if entry.partOf[part] ~= nil then
		return entry.partOf[part]
	end
	local role = roleFor(part, part.Color, entry.largest)
	if role == "skip" then
		return nil
	end
	local surface = part:FindFirstChildOfClass("SurfaceAppearance")
	local saved: SavedPart = {
		part = part,
		color = part.Color,
		material = part.Material,
		role = role,
		phase = 0,
		surface = if surface ~= nil and surface:IsA("SurfaceAppearance") then surface else nil,
		surfaceColor = if surface ~= nil and surface:IsA("SurfaceAppearance") then surface.Color else nil,
	}
	table.insert(entry.parts, saved)
	entry.partOf[part] = saved
	return saved
end

local function chooseHost(entry: Entry): BasePart?
	local best: BasePart? = nil
	local bestVolume = -1
	for _, saved in entry.parts do
		if saved.role == "body" and saved.part.Parent ~= nil then
			local size = saved.part.Size
			local volume = size.X * size.Y * size.Z
			if volume > bestVolume then
				best = saved.part
				bestVolume = volume
			end
		end
	end
	if best ~= nil then
		return best
	end
	for _, saved in entry.parts do
		if saved.part.Parent ~= nil then
			return saved.part
		end
	end
	return entry.model.PrimaryPart
end

local function styleEmitter(emitter: ParticleEmitter, kind: string)
	local stops = MutationVisual.sparkleStops(kind)
	if stops ~= nil then
		emitter.Color = sequenceOf(stops)
	end
	local rate = MutationVisual.particleRate(MutationVisual.rateFor(kind), quality, reduceMotion)
	emitter.Rate = rate
	emitter.Enabled = rate > 0
	emitter.LightEmission = if kind == "Rainbow" then 0.65 else 0.4
end

local function styleLight(light: PointLight, kind: string, now: number)
	light.Shadows = false
	light.Range = MutationVisual.LIGHT_RANGE
	light.Enabled = fx.light
	light.Brightness = if fx.light then MutationVisual.LIGHT_BRIGHTNESS else 0
	local rgb = MutationVisual.lightRgb(kind, now)
	if rgb ~= nil then
		light.Color = colorOf(rgb)
	end
end

local function makeEmitter(host: BasePart): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MutationSparkle"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Lifetime = NumberRange.new(MutationVisual.LIFE_MIN, MutationVisual.LIFE_MAX)
	emitter.Speed = NumberRange.new(0.25, 1.1)
	emitter.SpreadAngle = Vector2.new(28, 28)
	emitter.Acceleration = Vector3.new(0, 0.45, 0)
	emitter.Drag = 2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightInfluence = 0
	emitter.LockedToPart = true
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Enabled = false
	emitter.Parent = host
	return emitter
end

local function makeLight(host: BasePart): PointLight
	local light = Instance.new("PointLight")
	light.Name = "MutationGlow"
	light.Shadows = false
	light.Range = MutationVisual.LIGHT_RANGE
	light.Brightness = 0
	light.Enabled = false
	light.Parent = host
	return light
end

local function placeFx(entry: Entry, now: number)
	if entry.kind == "" then
		return
	end
	local host = chooseHost(entry)
	if host == nil then
		return
	end
	local emitter = entry.emitter
	if emitter == nil then
		emitter = makeEmitter(host)
		entry.emitter = emitter
	elseif emitter.Parent ~= host then
		emitter.Parent = host
	end
	local light = entry.light
	if light == nil then
		light = makeLight(host)
		entry.light = light
	elseif light.Parent ~= host then
		light.Parent = host
	end
	styleEmitter(emitter, entry.kind)
	styleLight(light, entry.kind, now)
end

local function rescan(entry: Entry, now: number)
	if entry.dead or entry.kind == "" then
		return
	end
	recomputeLargest(entry)
	local keep: { SavedPart } = {}
	local keepOf: { [BasePart]: SavedPart } = {}
	for _, saved in entry.parts do
		if saved.part.Parent == nil then
			continue
		end
		local role = roleFor(saved.part, saved.color, entry.largest)
		if role == "skip" then
			restorePart(saved)
		else
			saved.role = role
			table.insert(keep, saved)
			keepOf[saved.part] = saved
		end
	end
	entry.parts = keep
	entry.partOf = keepOf
	for _, desc in entry.model:GetDescendants() do
		if desc:IsA("BasePart") then
			capture(entry, desc)
		end
	end
	for _, saved in entry.parts do
		if saved.surface == nil then
			local surface = saved.part:FindFirstChildOfClass("SurfaceAppearance")
			if surface ~= nil and surface:IsA("SurfaceAppearance") then
				saved.surface = surface
				saved.surfaceColor = surface.Color
			end
		end
	end
	relayout(entry)
	paintAll(entry, now)
	placeFx(entry, now)
end

local function ensureHeartbeat()
	if heartbeat ~= nil or not anyRainbow() then
		return
	end
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not anyRainbow() then
			stopHeartbeat()
			return
		end
		local step = fx.hueStep
		if step > 0 then
			hueAccum += dt
			if hueAccum < step then
				return
			end
			hueAccum = 0
		end
		local now = os.clock()
		for _, entry in tracked do
			if entry.kind == "Rainbow" and not entry.dead then
				for _, saved in entry.parts do
					applyColor(saved, entry.kind, now)
				end
				local light = entry.light
				if light ~= nil and light.Parent ~= nil and fx.light then
					local rgb = MutationVisual.lightRgb("Rainbow", now)
					if rgb ~= nil then
						light.Color = colorOf(rgb)
					end
				end
			end
		end
	end)
end

local function restyleAll()
	refreshFx()
	local now = os.clock()
	for _, entry in tracked do
		if not entry.dead and entry.kind ~= "" then
			placeFx(entry, now)
		end
	end
end

local function release(model: Model)
	local entry = tracked[model]
	if entry == nil or entry.dead then
		return
	end
	entry.dead = true
	tracked[model] = nil
	for _, conn in entry.conns do
		conn:Disconnect()
	end
	table.clear(entry.conns)
	for _, saved in entry.parts do
		restorePart(saved)
	end
	table.clear(entry.parts)
	table.clear(entry.partOf)
	if entry.emitter ~= nil then
		entry.emitter:Destroy()
		entry.emitter = nil
	end
	if entry.light ~= nil then
		entry.light:Destroy()
		entry.light = nil
	end
	if not anyRainbow() then
		stopHeartbeat()
	end
end

local function sync(entry: Entry)
	if entry.dead then
		return
	end
	local kind = MutationVisual.kind(entry.model:GetAttribute("Mutation"))
	if kind == nil then
		return
	end
	if entry.kind == kind and #entry.parts > 0 then
		return
	end
	if entry.kind ~= "" and entry.kind ~= kind then
		for _, saved in entry.parts do
			restorePart(saved)
		end
	end
	entry.kind = kind
	rescan(entry, os.clock())
	if kind == "Rainbow" then
		ensureHeartbeat()
	elseif not anyRainbow() then
		stopHeartbeat()
	end
end

local function mount(model: Model)
	if tracked[model] ~= nil then
		return
	end
	local entry: Entry = {
		model = model,
		kind = "",
		parts = {},
		partOf = {},
		conns = {},
		emitter = nil,
		light = nil,
		largest = 0,
		dead = false,
	}
	tracked[model] = entry
	table.insert(
		entry.conns,
		model:GetAttributeChangedSignal("Mutation"):Connect(function()
			sync(entry)
		end)
	)
	table.insert(
		entry.conns,
		model.DescendantAdded:Connect(function(desc)
			if entry.dead or entry.kind == "" then
				return
			end
			if desc:IsA("BasePart") then
				rescan(entry, os.clock())
			elseif desc:IsA("SurfaceAppearance") then
				local parent = desc.Parent
				if parent ~= nil and parent:IsA("BasePart") then
					local saved = entry.partOf[parent]
					if saved ~= nil and saved.surface == nil then
						saved.surface = desc
						saved.surfaceColor = desc.Color
						applyColor(saved, entry.kind, os.clock())
					end
				end
			end
		end)
	)
	table.insert(
		entry.conns,
		model.Destroying:Connect(function()
			release(model)
		end)
	)
	sync(entry)
end

local function onAdded(inst: Instance)
	if inst:IsA("Model") then
		mount(inst)
	end
end

function MutationVisualController.start()
	if started then
		return
	end
	started = true
	local current = UIState.get().settings
	reduceMotion = typeof(current) == "table" and current.reduceMotion == true
	refreshFx()
	CollectionService:GetInstanceAddedSignal(MutationVisual.TAG):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(MutationVisual.TAG):Connect(function(inst)
		if inst:IsA("Model") then
			release(inst)
		end
	end)
	for _, inst in CollectionService:GetTagged(MutationVisual.TAG) do
		onAdded(inst)
	end
	UIState.onChange(function(state)
		local nextSettings = state.settings
		local calm = typeof(nextSettings) == "table" and nextSettings.reduceMotion == true
		if calm == reduceMotion then
			return
		end
		reduceMotion = calm
		restyleAll()
	end)
	pcall(function()
		local user = UserSettings():GetService("UserGameSettings")
		user:GetPropertyChangedSignal("SavedQualityLevel"):Connect(restyleAll)
	end)
	pcall(function()
		local rendering = settings().Rendering
		rendering:GetPropertyChangedSignal("QualityLevel"):Connect(restyleAll)
	end)
end

return MutationVisualController
