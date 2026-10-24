--!strict
-- Viste la plaza con los modelos importados (ServerStorage/Templates/Lobby y la Estrellita de Pinatas).
-- Los Parts de PlaceBuilder siguen siendo la jugabilidad (piso, kioscos, Pasarela, tags del FTUE): acá solo se
-- esconden los que el arte reemplaza y los kioscos pasan a la puerta de su tienda.
-- Sin los modelos importados (place recién armado con rojo build) no hace nada y queda el mundo de bloques.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared:WaitForChild("Config"):WaitForChild("WorldLayout"))
local Art = require(Shared:WaitForChild("Config"):WaitForChild("LobbyArt"))

local LobbyArt = {}

local function template(name: string, group: string?): Model?
	local templates = ServerStorage:FindFirstChild("Templates")
	local folder = if templates ~= nil then templates:FindFirstChild(group or "Lobby") else nil
	local found = if folder ~= nil then folder:FindFirstChild(name) else nil
	if found ~= nil and found:IsA("Model") then
		return found
	end
	return nil
end

-- Clona y apoya el modelo en el piso (y = groundY) con el giro pedido; el pivot del import no es la base.
local function put(source: Model, position: Vector3, rotation: CFrame, parent: Instance, scale: number?): Model
	local model = source:Clone()
	if scale ~= nil and scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:PivotTo(CFrame.new(position) * rotation)
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, position.Y - bottom, 0))
	model.Parent = parent
	return model
end

local function hide(part: Instance?)
	if part == nil or not part:IsA("BasePart") then
		return
	end
	part.Transparency = 1
	for _, child in part:GetDescendants() do
		if child:IsA("BillboardGui") or child:IsA("SurfaceGui") then
			child.Enabled = false
		elseif child:IsA("Decal") or child:IsA("Texture") then
			child.Transparency = 1
		end
	end
end

local function facing(position: Vector3, target: Vector3): CFrame
	local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
	if flat.Magnitude < 0.01 then
		return CFrame.new()
	end
	return CFrame.lookAt(Vector3.zero, flat)
end

local function topOf(model: Model): number
	local box, size = model:GetBoundingBox()
	return box.Position.Y + size.Y / 2
end

local function dressFountain(world: Folder, art: Folder, groundY: number)
	local fountainTemplate = template(Art.Fountain)
	if fountainTemplate == nil then
		return
	end
	local fountain = put(fountainTemplate, Vector3.new(0, groundY, 0), CFrame.new(), art)
	local placeholder = world:FindFirstChild("Fountain")
	if placeholder ~= nil and placeholder:IsA("BasePart") then
		-- El tag FTUEFountain queda en el Part (la cámara de la intro lo busca); la fuente real choca.
		hide(placeholder)
		placeholder.CanCollide = false
	end
	local pinatas = ServerStorage:FindFirstChild("Pinatas")
	local star = if pinatas ~= nil then pinatas:FindFirstChild(Art.Statue.Pinata) else nil
	if star == nil or not star:IsA("Model") then
		return
	end
	local statue = put(star, Vector3.new(0, topOf(fountain) - 0.4, 0), CFrame.new(), art, Art.Statue.Scale)
	statue.Name = "EstrellitaGigante"
	for _, desc in statue:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
		end
	end
	local hub = world:FindFirstChild("EstrellitaStatue")
	if hub ~= nil and hub:IsA("BasePart") then
		-- El Part queda invisible encima de la estatua solo para el cartel "LA PLAZA".
		hub.Transparency = 1
		hub.Position = Vector3.new(0, topOf(statue) + 1, 0)
	end
end

local function dressShops(world: Folder, art: Folder, groundY: number)
	for _, child in world:GetChildren() do
		local kioskId = child:GetAttribute("KioskId")
		local name = if type(kioskId) == "string" then Art.Shops[kioskId] else nil
		local shopTemplate = if name ~= nil then template(name) else nil
		if shopTemplate == nil or not child:IsA("BasePart") then
			continue
		end
		local kiosk = child :: BasePart
		local dir = Vector3.new(kiosk.Position.X, 0, kiosk.Position.Z).Unit
		local center = dir * Art.ShopRadius
		local shop = put(shopTemplate, Vector3.new(center.X, groundY, center.Z), facing(center, Vector3.zero), art)
		local _, size = shop:GetBoundingBox()
		local depth = math.min(size.X, size.Z)
		-- El prompt de la tienda queda en la puerta, invisible y sin chocar con quien entra.
		local door = dir * (Art.ShopRadius - depth / 2 - Art.KioskInset)
		kiosk.Size = Vector3.new(6, 6, 2)
		kiosk.CFrame = CFrame.new(door.X, groundY + 3, door.Z) * facing(door, Vector3.zero)
		kiosk.CanCollide = false
		hide(kiosk)
		local snow = world:FindFirstChild("EventDress")
		local cap = if snow ~= nil then snow:FindFirstChild("Snow" .. kiosk.Name) else nil
		if cap ~= nil and cap:IsA("BasePart") then
			-- La nieve de Posadas va sobre el techo de la tienda real.
			cap.Size = Vector3.new(size.X * 0.9, 0.45, size.Z * 0.9)
			cap.CFrame = CFrame.new(center.X, topOf(shop) - 4, center.Z) * facing(center, Vector3.zero)
		end
	end
end

local function dressPasarela(world: Folder, art: Folder)
	local segment = template(Art.PasarelaSegment)
	if segment ~= nil then
		local count = math.ceil(Layout.PasarelaLength / 24)
		local step = Layout.PasarelaLength / count
		for i = 0, count - 1 do
			local x = Layout.PasarelaSpawnX + step * (i + 0.5)
			local seg = put(segment, Vector3.new(x, 0.45, Layout.PasarelaZ), CFrame.new(), art)
			-- Estirado en X para cubrir la Pasarela justa con segmentos enteros.
			for _, desc in seg:GetDescendants() do
				if desc:IsA("BasePart") then
					local stretch = step / 24
					local offset = desc.Position - seg:GetPivot().Position
					desc.Size = Vector3.new(desc.Size.X * stretch, desc.Size.Y, desc.Size.Z)
					desc.Position = seg:GetPivot().Position + Vector3.new(offset.X * stretch, offset.Y, offset.Z)
				end
			end
		end
		for _, name in { "Pasarela", "RopeN", "RopeS" } do
			hide(world:FindFirstChild(name))
		end
		for _, child in world:GetChildren() do
			if string.match(child.Name, "^Chev%d+$") then
				hide(child)
			end
		end
	end
	local gate = template(Art.Fabrica)
	if gate ~= nil then
		-- El arco mira a lo largo de la Pasarela: las piñatas salen de la FÁBRICA.
		put(
			gate,
			Vector3.new(Layout.PasarelaSpawnX - 2, 0.45, Layout.PasarelaZ),
			CFrame.Angles(0, math.rad(-90), 0),
			art
		)
		-- El arco de SALIDA era del mismo bloque celeste; con el arte, la Pasarela termina sola.
		for _, name in { "FabricaL", "FabricaR", "FabricaBeam", "SalidaL", "SalidaR", "SalidaBeam" } do
			local piece = world:FindFirstChild(name)
			hide(piece)
			if piece ~= nil and piece:IsA("BasePart") then
				piece.CanCollide = false
			end
		end
	end
end

local function dressLamps(world: Folder, art: Folder, groundY: number)
	local lamp = template(Art.Lamp)
	if lamp == nil then
		return
	end
	for _, child in world:GetChildren() do
		local index = string.match(child.Name, "^Lamp(%d+)$")
		if index == nil or not child:IsA("BasePart") then
			continue
		end
		local base = Vector3.new(child.Position.X, groundY, child.Position.Z)
		local model = put(lamp, base, facing(base, Vector3.zero), art)
		hide(child)
		child.CanCollide = false
		-- La bombilla sigue siendo la que cambia de color en Posadas; va en el farol de verdad.
		local bulb = world:FindFirstChild("Bulb" .. index)
		local glow = model:FindFirstChild(Art.Lamp .. "_Neon", true)
		if bulb ~= nil and bulb:IsA("BasePart") and glow ~= nil and glow:IsA("BasePart") then
			bulb.Size = Vector3.new(1, 1, 1)
			bulb.CFrame = CFrame.new(glow.Position)
		end
	end
end

local function dressProps(art: Folder, groundY: number)
	for _, prop in Art.Props do
		local source = template(prop.name)
		if source == nil then
			continue
		end
		local position = Vector3.new(prop.x, groundY, prop.z)
		local rotation = if prop.yaw ~= nil
			then CFrame.Angles(0, math.rad(prop.yaw), 0)
			elseif prop.faceCenter then facing(position, Vector3.zero)
			else CFrame.new()
		put(source, position, rotation, art, prop.scale)
	end
end

-- Solo transparente: los carteles de juego (aro del candado, dueño, Vault) siguen colgando de estos Parts.
local function ghost(part: Instance?)
	if part ~= nil and part:IsA("BasePart") then
		part.Transparency = 1
	end
end

-- Fila de cercas entre a y b (coordenadas locales de la base), estiradas para que entren segmentos enteros.
local function fenceRun(fence: Model, cf: CFrame, a: Vector3, b: Vector3, groundY: number, parent: Instance)
	local span = b - a
	local length = span.Magnitude
	local _, size = fence:GetBoundingBox()
	local count = math.max(1, math.ceil(length / size.X))
	local step = length / count
	local yaw = CFrame.lookAt(Vector3.zero, Vector3.new(span.Z, 0, -span.X))
	for i = 0, count - 1 do
		local localPos = a + span.Unit * step * (i + 0.5)
		local world = cf:PointToWorldSpace(Vector3.new(localPos.X, 0, localPos.Z))
		local piece = put(fence, Vector3.new(world.X, groundY, world.Z), cf.Rotation * yaw, parent)
		for _, desc in piece:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Size = Vector3.new(desc.Size.X * step / size.X, desc.Size.Y, desc.Size.Z)
			end
		end
	end
end

local function dressPlots(world: Folder, art: Folder)
	local plots = world:FindFirstChild("Plots")
	local base = Art.Base
	local floorT, gateT = template(base.Floor, "Base"), template(base.Gate, "Base")
	local generatorT, fenceT = template(base.Generator, "Base"), template(base.Fence, "Base")
	local pedestalT = template(base.Pedestal, "Base")
	if plots == nil or floorT == nil or gateT == nil or generatorT == nil or fenceT == nil or pedestalT == nil then
		return
	end
	for _, plot in plots:GetChildren() do
		local floor = plot:FindFirstChild("Floor")
		if not plot:IsA("Model") or floor == nil or not floor:IsA("BasePart") then
			continue
		end
		local folder = Instance.new("Folder")
		folder.Name = plot.Name .. "Art"
		folder.Parent = art
		-- Marco de la base igual que PlaceBuilder.buildPlot: -Z local mira a la plaza (puerta en GateLocalZ).
		local cf = floor.CFrame * CFrame.new(0, -floor.Size.Y / 2, 0)
		local groundY = floor.Position.Y + floor.Size.Y / 2
		local function at(x: number, z: number): Vector3
			local p = cf:PointToWorldSpace(Vector3.new(x, 0, z))
			return Vector3.new(p.X, groundY, p.Z)
		end
		-- Piso: la cara de arriba del modelo queda donde se camina (el Part sigue siendo el que choca).
		local _, floorSize = floorT:GetBoundingBox()
		put(floorT, at(0, 0) - Vector3.new(0, floorSize.Y, 0), cf.Rotation, folder)
		ghost(floor)
		ghost(plot:FindFirstChild("Rug"))
		-- Portón real; el láser del candado sigue siendo el Part que LockService prende y apaga.
		local gate = put(gateT, at(0, Layout.GateLocalZ), cf.Rotation, folder)
		ghost(gate:FindFirstChild(base.Gate .. "_Neon", true))
		for _, name in { "Gate", "GateL", "GateR", "Sign" } do
			ghost(plot:FindFirstChild(name))
		end
		-- Generador (Dulcería de la base); el cartel "Vault" sube por encima del modelo.
		local generator = put(generatorT, at(0, Layout.GeneratorLocalZ), cf.Rotation, folder)
		local generatorPart = plot:FindFirstChild("Generator")
		ghost(generatorPart)
		ghost(plot:FindFirstChild("GeneratorGlass"))
		local vault = if generatorPart ~= nil then generatorPart:FindFirstChild("Vault") else nil
		if vault ~= nil and vault:IsA("BillboardGui") and generatorPart ~= nil and generatorPart:IsA("BasePart") then
			vault.StudsOffset = Vector3.new(0, topOf(generator) - generatorPart.Position.Y + 1.5, 0)
		end
		-- Cercas bajas de papel picado; las paredes de bloque quedan como muros invisibles.
		local hx, hz = Layout.FloorX / 2 - base.FenceInset, Layout.FloorZ / 2 - base.FenceInset
		local runs = {
			{ Vector3.new(-hx, 0, -hz), Vector3.new(-hx, 0, hz) },
			{ Vector3.new(hx, 0, -hz), Vector3.new(hx, 0, hz) },
			{ Vector3.new(-hx, 0, hz), Vector3.new(hx, 0, hz) },
			{ Vector3.new(-hx, 0, -hz), Vector3.new(-7, 0, -hz) },
			{ Vector3.new(7, 0, -hz), Vector3.new(hx, 0, -hz) },
		}
		for _, run in runs do
			fenceRun(fenceT, cf, run[1], run[2], groundY, folder)
		end
		for _, name in { "FenceL", "FenceR", "FenceBack", "FenceFrontL", "FenceFrontR" } do
			ghost(plot:FindFirstChild(name))
		end
		-- Pedestales: el modelo debajo y el pad de color (abierto/cerrado) como disco fino arriba.
		for _, child in plot:GetChildren() do
			if not string.match(child.Name, "^Pedestal%d+$") or not child:IsA("BasePart") then
				continue
			end
			local pad = child :: BasePart
			local top = pad.Position.Y + pad.Size.Y / 2
			local _, pedSize = pedestalT:GetBoundingBox()
			local seat = cf:PointToObjectSpace(pad.Position)
			local turn = CFrame.Angles(0, math.rad(if seat.X > 0 then 90 else -90), 0)
			put(pedestalT, Vector3.new(pad.Position.X, top - pedSize.Y, pad.Position.Z), cf.Rotation * turn, folder)
			pad.Size = Vector3.new(pad.Size.X * 0.85, base.PadDisc, pad.Size.Z * 0.85)
			pad.CFrame = pad.CFrame.Rotation + Vector3.new(pad.Position.X, top + base.PadDisc / 2, pad.Position.Z)
		end
	end
end

function LobbyArt.dress(world: Folder)
	local art = Instance.new("Folder")
	art.Name = "LobbyArt"
	art.Parent = world
	local plaza = world:FindFirstChild("Plaza")
	local groundY = if plaza ~= nil and plaza:IsA("BasePart") then plaza.Position.Y + plaza.Size.X / 2 else 0.9
	dressFountain(world, art, groundY)
	dressShops(world, art, groundY)
	dressPasarela(world, art)
	dressLamps(world, art, groundY)
	dressProps(art, groundY)
	dressPlots(world, art)
	if #art:GetChildren() == 0 then
		art:Destroy()
		return
	end
	local ground = world:FindFirstChild("Ground")
	if ground ~= nil and ground:IsA("BasePart") then
		ground.Material = Art.Ground.Material
		ground.Color = Art.Ground.Color
	end
	if plaza ~= nil and plaza:IsA("BasePart") then
		plaza.Material = Art.Plaza.Material
		plaza.Color = Art.Plaza.Color
	end
end

return LobbyArt
