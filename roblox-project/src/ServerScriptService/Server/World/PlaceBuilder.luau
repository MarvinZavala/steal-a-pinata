--!strict
-- Plaza de prueba. Rojo no trae el mapa: al dar Play se arma con Parts.
-- Si más adelante importás los mesh de art/export/, este bloque igual deja
-- las posiciones y los nombres que los servicios buscan.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("Config"):WaitForChild("WorldLayout"))
local Labels = require(script.Parent:WaitForChild("Labels"))

local PlaceBuilder = {}

export type Pedestal = {
	index: number,
	pad: BasePart,
	anchor: BasePart,
	uid: string?,
	model: Model?,
}

export type Plot = {
	index: number,
	model: Model,
	cframe: CFrame,
	spawn: SpawnLocation,
	laser: BasePart,
	laserBlock: BasePart,
	padlock: BasePart,
	generatorLabel: TextLabel,
	sign: TextLabel,
	ringStroke: UIStroke,
	ringLabel: TextLabel,
	collect: BasePart,
	pedestals: { Pedestal },
	ownerUserId: number?,
}

export type World = {
	folder: Folder,
	pasarela: BasePart,
	spawnPos: Vector3,
	exitPos: Vector3,
	height: number,
	plots: { Plot },
}

local PINK = Color3.fromHex("#FF3E9A")
local MAGENTA = Color3.fromHex("#E0187A")
local YELLOW = Color3.fromHex("#FFE14D")
local GOLD = Color3.fromHex("#FFC22E")
local CREAM = Color3.fromHex("#FFE6B8")
local TILE = Color3.fromHex("#FFD9A8")
local INK = Color3.fromHex("#1B1430")
local TURQ = Color3.fromHex("#16D3E8")
local GRASS = Color3.fromHex("#58D15A")
local NEON = Color3.fromHex("#FF4FD8")
local WHITE = Color3.fromHex("#FFF7EC")
local SNOW = Color3.fromHex("#F4FBFF")
local XMAS_RED = Color3.fromHex("#D7192F")
local XMAS_GREEN = Color3.fromHex("#11A35A")

local dressParts: { BasePart } = {}
local paradeParts: { BasePart } = {}
local bulbParts: { BasePart } = {}
local shopPart: BasePart? = nil

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function caption(parent: BasePart, name: string, key: string, offset: Vector3, px: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(px, math.floor(px * 0.45))
	gui.StudsOffset = offset
	gui.MaxDistance = Layout.LockRingMaxDistance
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	Labels.line(label, key)
	label.TextColor3 = WHITE
	label.TextStrokeColor3 = INK
	label.TextStrokeTransparency = 0
	label.Parent = gui
	return label
end

local function applyLighting()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.4
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromHex("#FFE6B8")
	Lighting.Ambient = Color3.fromHex("#FFD0E8")
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	if Lighting:FindFirstChild("FiestaAtmosphere") == nil then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "FiestaAtmosphere"
		atmosphere.Density = 0.28
		atmosphere.Offset = 0.15
		atmosphere.Color = Color3.fromHex("#FFD6EC")
		atmosphere.Decay = Color3.fromHex("#7CC8FF")
		atmosphere.Glare = 0.15
		atmosphere.Haze = 0.4
		atmosphere.Parent = Lighting
	end
end

local function buildPlot(index: number, spot: { x: number, z: number, faceX: number }, parent: Folder): Plot
	local origin = Vector3.new(spot.x, 0, spot.z)
	local cf = CFrame.lookAt(origin, origin + Vector3.new(spot.faceX, 0, 0))
	local model = Instance.new("Model")
	model.Name = "Plot" .. tostring(index)
	model.Parent = parent
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)
	CollectionService:AddTag(model, "Plot")
	CollectionService:AddTag(model, "FTUEBase")

	local floor = part("Floor", Vector3.new(Layout.FloorX, 1, Layout.FloorZ), cf * CFrame.new(0, 0.5, 0), TILE, model)
	floor.Material = Enum.Material.SmoothPlastic
	model.PrimaryPart = floor
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local border =
		part("Rug", Vector3.new(Layout.FloorX - 4, 0.2, Layout.FloorZ - 6), cf * CFrame.new(0, 1.05, 1), PINK, model)
	border.CanCollide = false

	local fenceH = Layout.FenceHeight
	part(
		"FenceL",
		Vector3.new(1, fenceH, Layout.FloorZ),
		cf * CFrame.new(-Layout.FloorX / 2, fenceH / 2, 0),
		CREAM,
		model
	)
	part(
		"FenceR",
		Vector3.new(1, fenceH, Layout.FloorZ),
		cf * CFrame.new(Layout.FloorX / 2, fenceH / 2, 0),
		CREAM,
		model
	)
	part(
		"FenceBack",
		Vector3.new(Layout.FloorX, fenceH, 1),
		cf * CFrame.new(0, fenceH / 2, Layout.FloorZ / 2),
		CREAM,
		model
	)
	local frontW = Layout.FloorX / 2 - 7
	local frontX = 7 + frontW / 2
	part(
		"FenceFrontL",
		Vector3.new(frontW, fenceH, 1),
		cf * CFrame.new(-frontX, fenceH / 2, -Layout.FloorZ / 2),
		CREAM,
		model
	)
	part(
		"FenceFrontR",
		Vector3.new(frontW, fenceH, 1),
		cf * CFrame.new(frontX, fenceH / 2, -Layout.FloorZ / 2),
		CREAM,
		model
	)

	local gateCf = cf * CFrame.new(0, 6, Layout.GateLocalZ)
	local gate = part("Gate", Vector3.new(14, 10, 1.2), gateCf, TURQ, model)
	gate.CanCollide = false
	gate.Material = Enum.Material.SmoothPlastic
	part("GateL", Vector3.new(1.4, 10, 1.4), cf * CFrame.new(-7.2, 5, Layout.GateLocalZ), GOLD, model)
	part("GateR", Vector3.new(1.4, 10, 1.4), cf * CFrame.new(7.2, 5, Layout.GateLocalZ), GOLD, model)

	local laser = part("Laser", Vector3.new(12, 7, 0.35), cf * CFrame.new(0, 4.2, Layout.GateLocalZ), NEON, model)
	laser.Material = Enum.Material.Neon
	laser.CanCollide = false
	laser.CastShadow = false
	laser.Transparency = 1
	local laserBlock = part("LaserBlock", Vector3.new(12, 8, 2), cf * CFrame.new(0, 4.2, Layout.GateLocalZ), INK, model)
	laserBlock.Transparency = 1
	laserBlock.CanCollide = false
	laserBlock.CastShadow = false

	local padlock = part("Padlock", Vector3.new(1.6, 2, 0.6), cf * CFrame.new(8.8, 6.5, Layout.GateLocalZ), GOLD, model)
	padlock.Material = Enum.Material.Metal
	padlock.CanCollide = false

	local ringGui = Instance.new("BillboardGui")
	ringGui.Name = "LockRing"
	ringGui.Size = UDim2.fromOffset(74, 74)
	ringGui.StudsOffset = Vector3.new(0, 7, 0)
	ringGui.MaxDistance = Layout.LockRingMaxDistance
	ringGui.Parent = gate
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundColor3 = INK
	ring.BackgroundTransparency = 0.4
	ring.Parent = ringGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 5
	stroke.Color = TURQ
	stroke.Transparency = 0.45
	stroke.Parent = ring
	local ringLabel = Instance.new("TextLabel")
	ringLabel.Name = "Text"
	ringLabel.BackgroundTransparency = 1
	ringLabel.Size = UDim2.fromScale(1, 1)
	ringLabel.Font = Enum.Font.FredokaOne
	ringLabel.TextScaled = true
	Labels.line(ringLabel, "world.open")
	ringLabel.TextColor3 = WHITE
	ringLabel.TextStrokeTransparency = 0
	ringLabel.TextStrokeColor3 = INK
	ringLabel.Parent = ring

	local generator =
		part("Generator", Vector3.new(8, 6, 8), cf * CFrame.new(0, 4, Layout.GeneratorLocalZ), WHITE, model)
	generator.Material = Enum.Material.SmoothPlastic
	local dome = part(
		"GeneratorGlass",
		Vector3.new(6, 3, 6),
		cf * CFrame.new(0, 8, Layout.GeneratorLocalZ),
		Color3.fromHex("#BFF4FF"),
		model
	)
	dome.Material = Enum.Material.Glass
	dome.Transparency = 0.45
	dome.CanCollide = false
	local generatorLabel = caption(generator, "Vault", "shop.kiosk_dulceria", Vector3.new(0, 5, 0), 180)

	local collect =
		part("Collect", Vector3.new(12, 0.6, 12), cf * CFrame.new(0, 1.4, Layout.GeneratorLocalZ - 8), YELLOW, model)
	collect.Material = Enum.Material.Neon
	caption(collect, "CollectHint", "world.step_collect", Vector3.new(0, 3, 0), 160)

	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "Spawn"
	spawnPart.Size = Vector3.new(6, 1, 6)
	spawnPart.CFrame = cf * CFrame.new(0, 1.2, Layout.GateLocalZ + 8)
	spawnPart.Anchored = true
	spawnPart.Neutral = false
	spawnPart.Duration = 0
	spawnPart.Transparency = 1
	spawnPart.CanCollide = false
	spawnPart.AllowTeamChangeOnTouch = false
	spawnPart.Parent = model

	local signPart = part("Sign", Vector3.new(8, 3, 0.4), cf * CFrame.new(0, 11.5, Layout.GateLocalZ), PINK, model)
	signPart.CanCollide = false
	local sign = caption(signPart, "Owner", "world.free", Vector3.new(0, 0, 0), 200)

	local pedestals: { Pedestal } = {}
	for indexPed = 1, 12 do
		local x, z = Layout.pedestalLocal(indexPed)
		local lift = Layout.pedestalHeight(indexPed)
		local pad = part(
			"Pedestal" .. tostring(indexPed),
			Vector3.new(4.2, 1.2, 4.2),
			cf * CFrame.new(x, 1.7 + lift, z),
			CREAM,
			model
		)
		pad:SetAttribute("Index", indexPed)
		local anchor = part(
			"Anchor" .. tostring(indexPed),
			Vector3.new(1, 0.2, 1),
			cf * CFrame.new(x, 2.4 + lift, z),
			CREAM,
			model
		)
		anchor.Transparency = 1
		anchor.CanCollide = false
		anchor.CanQuery = false
		table.insert(pedestals, { index = indexPed, pad = pad, anchor = anchor, uid = nil, model = nil })
	end

	return {
		index = index,
		model = model,
		cframe = cf,
		spawn = spawnPart,
		laser = laser,
		laserBlock = laserBlock,
		padlock = padlock,
		generatorLabel = generatorLabel,
		sign = sign,
		ringStroke = stroke,
		ringLabel = ringLabel,
		collect = collect,
		pedestals = pedestals,
		ownerUserId = nil,
	}
end

local function showPart(piece: BasePart, on: boolean)
	piece.Transparency = if on then 0 else 1
	piece.CanCollide = false
	piece.CanQuery = on
	piece.CanTouch = false
end

function PlaceBuilder.setEventDress(decor: boolean, parade: boolean, shopOpen: boolean)
	for _, piece in dressParts do
		showPart(piece, decor)
	end
	for _, piece in paradeParts do
		showPart(piece, parade)
	end
	for index, bulb in bulbParts do
		bulb.Color = if decor then (if index % 2 == 0 then XMAS_RED else XMAS_GREEN) else YELLOW
	end
	local holiday = shopPart
	if holiday ~= nil then
		holiday.Transparency = if shopOpen then 0 else 1
		holiday.CanCollide = shopOpen
		holiday.CanQuery = shopOpen
		local prompt = holiday:FindFirstChild("OpenShop")
		if prompt ~= nil and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = shopOpen
		end
		local sign = holiday:FindFirstChild("NavidadSign", true)
		if sign ~= nil then
			sign.Enabled = shopOpen
		end
	end
	if decor then
		Lighting.ClockTime = 18.4
		Lighting.OutdoorAmbient = Color3.fromHex("#D7E7FF")
		Lighting.Ambient = Color3.fromHex("#C9D8FF")
	else
		applyLighting()
	end
end

function PlaceBuilder.build(): World
	table.clear(dressParts)
	table.clear(paradeParts)
	table.clear(bulbParts)
	shopPart = nil
	applyLighting()
	local existing = workspace:FindFirstChild("World")
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = workspace
	local fx = Instance.new("Folder")
	fx.Name = "FX"
	fx.Parent = folder

	part("Ground", Vector3.new(640, 2, 640), CFrame.new(0, -1.2, 20), GRASS, folder)

	local plaza = part(
		"Plaza",
		Vector3.new(1, Layout.PlazaRadius * 2, Layout.PlazaRadius * 2),
		CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		TILE,
		folder
	)
	plaza.Shape = Enum.PartType.Cylinder
	local ring = part(
		"PlazaRing",
		Vector3.new(1, 46, 46),
		CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		PINK,
		folder
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.CanCollide = false

	local fountain =
		part("Fountain", Vector3.new(10, 16, 16), CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), TURQ, folder)
	fountain.Shape = Enum.PartType.Cylinder
	CollectionService:AddTag(fountain, "FTUEFountain")
	local star = part("EstrellitaStatue", Vector3.new(6, 6, 6), CFrame.new(0, 12, 0), YELLOW, folder)
	star.Shape = Enum.PartType.Ball
	star.Material = Enum.Material.Neon
	star.CanCollide = false
	caption(star, "Hub", "world.plaza", Vector3.new(0, 5, 0), 220)

	local pasarela = part(
		"Pasarela",
		Vector3.new(Layout.PasarelaLength, 0.5, Layout.PasarelaWidth),
		CFrame.new(0, 0.7, Layout.PasarelaZ),
		MAGENTA,
		folder
	)
	pasarela.Material = Enum.Material.SmoothPlastic
	CollectionService:AddTag(pasarela, "Pasarela")
	part(
		"RopeN",
		Vector3.new(Layout.PasarelaLength, 0.4, 0.6),
		CFrame.new(0, 1.1, Layout.PasarelaZ - 5.2),
		GOLD,
		folder
	)
	part(
		"RopeS",
		Vector3.new(Layout.PasarelaLength, 0.4, 0.6),
		CFrame.new(0, 1.1, Layout.PasarelaZ + 5.2),
		GOLD,
		folder
	)
	for i = 0, 14 do
		local chev = part(
			"Chev" .. tostring(i),
			Vector3.new(2.2, 0.15, 3.2),
			CFrame.new(Layout.PasarelaSpawnX + 6 + i * 10, 1.05, Layout.PasarelaZ),
			PINK,
			folder
		)
		chev.CanCollide = false
	end

	local function arch(x: number, partName: string, key: string)
		part(partName .. "L", Vector3.new(2, 12, 2), CFrame.new(x, 6, Layout.PasarelaZ - 6), TURQ, folder)
		part(partName .. "R", Vector3.new(2, 12, 2), CFrame.new(x, 6, Layout.PasarelaZ + 6), TURQ, folder)
		local beam =
			part(partName .. "Beam", Vector3.new(2, 2, 14), CFrame.new(x, 12.5, Layout.PasarelaZ), GOLD, folder)
		caption(beam, partName .. "Sign", key, Vector3.new(0, 2, 0), 180)
	end
	arch(Layout.PasarelaSpawnX, "Fabrica", "world.factory")
	arch(Layout.PasarelaExitX, "Salida", "world.exit")

	local shops: { { name: string, key: string, id: string, angle: number, color: Color3 } } = {
		{ name = "Dulceria", key = "shop.kiosk_dulceria", id = "dulceria", angle = 155, color = YELLOW },
		{ name = "Bates", key = "shop.kiosk_bates", id = "bates", angle = 115, color = Color3.fromHex("#3DA5FF") },
		{ name = "Cajas", key = "shop.kiosk_cajas", id = "cajas", angle = 65, color = Color3.fromHex("#C59BFF") },
		{ name = "Vip", key = "shop.kiosk_vip", id = "vip", angle = 25, color = GOLD },
	}
	for _, shop in shops do
		local angle = math.rad(shop.angle)
		local x = math.cos(angle) * 33
		local z = math.sin(angle) * 33
		local kiosk = part(shop.name, Vector3.new(10, 8, 10), CFrame.new(x, 4, z), shop.color, folder)
		kiosk:SetAttribute("KioskId", shop.id)
		caption(kiosk, shop.name .. "Sign", shop.key, Vector3.new(0, 6, 0), 160)
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = folder
	local plots: { Plot } = {}
	for index, spot in Layout.plots() do
		local plot = buildPlot(index, spot, plotsFolder)
		table.insert(plots, plot)
		local gatePos = plot.cframe:PointToWorldSpace(Vector3.new(0, 0.4, Layout.GateLocalZ - 6))
		local toward = Vector3.new(gatePos.X * 0.35, 0.4, gatePos.Z * 0.55)
		local delta = toward - gatePos
		if delta.Magnitude > 2 then
			local mid = (gatePos + toward) / 2
			local flat = Vector3.new(delta.X, 0, delta.Z)
			part(
				"Path" .. tostring(index),
				Vector3.new(delta.Magnitude, 0.4, 8),
				CFrame.lookAt(mid, mid + flat),
				TILE,
				folder
			)
		end
	end

	-- Un farol para que la plaza no se vea vacía de noche.
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45)
		local lamp = part(
			"Lamp" .. tostring(i),
			Vector3.new(0.8, 7, 0.8),
			CFrame.new(math.cos(angle) * 40, 3.5, math.sin(angle) * 40),
			GOLD,
			folder
		)
		local bulb = part(
			"Bulb" .. tostring(i),
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(lamp.Position + Vector3.new(0, 4, 0)),
			YELLOW,
			folder
		)
		bulb.Material = Enum.Material.Neon
		bulb.Shape = Enum.PartType.Ball
		bulb.CanCollide = false
		table.insert(bulbParts, bulb)
	end

	-- TODO(WP-18): mallas nuevas que todavía no están en art/export:
	-- nieve de techos y palmeras, faroles del desfile, Tamalito, Jengibrín y el gorro.
	-- Hasta que lleguen, el vestido usa los faroles, las luces y los kioscos que ya existen.
	local dress = Instance.new("Folder")
	dress.Name = "EventDress"
	dress.Parent = folder
	for _, shopName in { "Dulceria", "Bates", "Cajas", "Vip" } do
		local kiosk = folder:FindFirstChild(shopName)
		if kiosk ~= nil and kiosk:IsA("BasePart") then
			local cap = part(
				"Snow" .. shopName,
				Vector3.new(10.4, 0.45, 10.4),
				kiosk.CFrame * CFrame.new(0, 4.3, 0),
				SNOW,
				dress
			)
			cap.Material = Enum.Material.SmoothPlastic
			cap.CanCollide = false
			table.insert(dressParts, cap)
		end
	end
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45 + 12)
		local light = part(
			"StringLight" .. tostring(i),
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(math.cos(angle) * 36, 8.2, math.sin(angle) * 36),
			if i % 2 == 0 then XMAS_RED else XMAS_GREEN,
			dress
		)
		light.Shape = Enum.PartType.Ball
		light.Material = Enum.Material.Neon
		light.CanCollide = false
		table.insert(dressParts, light)
	end
	for i = 0, 7 do
		local x = Layout.PasarelaSpawnX + 12 + i * 16
		local lantern = part(
			"ParadeLantern" .. tostring(i),
			Vector3.new(1.1, 1.6, 1.1),
			CFrame.new(x, 6.2, Layout.PasarelaZ - 7),
			if i % 2 == 0 then XMAS_RED else GOLD,
			dress
		)
		lantern.Material = Enum.Material.Neon
		lantern.CanCollide = false
		table.insert(paradeParts, lantern)
	end
	local holidayAngle = math.rad(200)
	local holiday = part(
		"Navidad",
		Vector3.new(10, 8, 10),
		CFrame.new(math.cos(holidayAngle) * 33, 4, math.sin(holidayAngle) * 33),
		XMAS_RED,
		folder
	)
	holiday:SetAttribute("KioskId", "navidad")
	caption(holiday, "NavidadSign", "shop.kiosk_navidad", Vector3.new(0, 6, 0), 160)
	shopPart = holiday
	PlaceBuilder.setEventDress(false, false, false)

	return {
		folder = folder,
		pasarela = pasarela,
		spawnPos = Vector3.new(Layout.PasarelaSpawnX, Layout.PasarelaY, Layout.PasarelaZ),
		exitPos = Vector3.new(Layout.PasarelaExitX, Layout.PasarelaY, Layout.PasarelaZ),
		height = Layout.PasarelaY,
		plots = plots,
	}
end

return PlaceBuilder
