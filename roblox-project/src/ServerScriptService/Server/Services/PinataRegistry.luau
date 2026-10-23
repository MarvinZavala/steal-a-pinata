--!strict
-- Registro de piñatas (WP-03). La fuente de verdad es Shared/Config/Pinatas.luau.
-- Si ServerStorage/Pinatas ya tiene el modelo importado, se normaliza.
-- Si no, se arma un placeholder con el MeshId de Shared/Config/Assets.luau (rbxassetid://0 hasta subirlo).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Pinatas = require(ReplicatedStorage.Shared.Config.Pinatas)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

-- 9 de fase 1 + 6 de Temporada Meme 1 (bloque al final de Pinatas.luau).
local EXPECTED_MODELED = 27

local PinataRegistry = {}

local function pinataFolder(): Folder
	local existing = ServerStorage:FindFirstChild("Pinatas")
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Pinatas"
	folder.Parent = ServerStorage
	return folder
end

local function isPlaceholder(assetId: string?): boolean
	return assetId == nil or assetId == "" or assetId == "rbxassetid://0"
end

local function rarityColor(rarity: string): Color3
	local color = (Rarities.Color :: any)[rarity]
	if typeof(color) == "Color3" then
		return color
	end
	return Color3.fromRGB(255, 255, 255)
end

local function readSize(mesh: any): Vector3
	local size = if type(mesh) == "table" then mesh.Size else nil
	local x = if type(size) == "table" and type(size[1]) == "number" then size[1] else 3
	local y = if type(size) == "table" and type(size[2]) == "number" then size[2] else 3
	local z = if type(size) == "table" and type(size[3]) == "number" then size[3] else 3
	if x <= 0 or y <= 0 or z <= 0 then
		return Vector3.new(3, 3, 3)
	end
	return Vector3.new(x, y, z)
end

local function applyAttributes(model: Model, id: string, def: any)
	model.Name = id
	model:SetAttribute("PinataId", id)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("CandyPerSec", def.CandyPerSec)
	model:SetAttribute("Modeled", def.Modeled == true)
end

local function paintNeon(model: Model, rarity: string)
	local color = rarityColor(rarity)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, -5) == "_Neon" then
			descendant.Material = Enum.Material.Neon
			descendant.Color = color
			descendant.CastShadow = false
		end
	end
end

local function makePart(
	name: string,
	size: Vector3,
	cf: CFrame,
	meshId: string?,
	neon: boolean,
	color: Color3
): BasePart
	local part: BasePart
	if isPlaceholder(meshId) then
		part = Instance.new("Part")
	else
		local mesh = Instance.new("MeshPart")
		local applied = pcall(function()
			mesh.MeshId = meshId :: string
		end)
		if applied then
			part = mesh
			pcall(function()
				(part :: MeshPart).CollisionFidelity = Enum.CollisionFidelity.Box
			end)
			-- Sin el modelo importado no hay SurfaceAppearance: la paleta como TextureID evita la malla gris.
			if not neon and not isPlaceholder(Assets.PaletteColor) then
				mesh.TextureID = Assets.PaletteColor
			end
		else
			mesh:Destroy()
			part = Instance.new("Part")
		end
	end
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = not neon
	part.Color = color
	if neon then
		part.Material = Enum.Material.Neon
	else
		part.Material = Enum.Material.SmoothPlastic
	end
	if meshId ~= nil then
		part:SetAttribute("MeshAssetId", meshId)
	end
	part:SetAttribute("MeshPlaceholder", isPlaceholder(meshId))
	return part
end

local function ensureRoot(model: Model): BasePart
	local found = model:FindFirstChild("Root")
	if found ~= nil and found:IsA("BasePart") then
		model.PrimaryPart = found
		return found
	end
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 1, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	local ok, bboxCf, bboxSize = pcall(function()
		return model:GetBoundingBox()
	end)
	if ok and typeof(bboxCf) == "CFrame" and typeof(bboxSize) == "Vector3" then
		root.CFrame = bboxCf * CFrame.new(0, -bboxSize.Y / 2 + root.Size.Y / 2, 0)
	else
		root.CFrame = CFrame.new(0, 0.5, 0)
	end
	root.Parent = model
	model.PrimaryPart = root
	return root
end

local function buildPlaceholder(id: string, def: any): Model
	local mesh = Assets.Meshes[id]
	local size = readSize(mesh)
	local color = rarityColor(def.Rarity)
	local model = Instance.new("Model")
	model.Name = id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 1, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(0, 0.5, 0)
	root.Parent = model

	local bodyId = if type(mesh) == "table" then mesh.Body else "rbxassetid://0"
	local body = makePart("Body", size, CFrame.new(0, size.Y / 2, 0), bodyId, false, color)
	if body:IsA("Part") then
		-- Sin malla: bola de piñata en vez de un bloque.
		body.Shape = Enum.PartType.Ball
	end
	body.Parent = model

	local neonId = if type(mesh) == "table" then mesh.Neon else nil
	if neonId ~= nil then
		local neonSize =
			Vector3.new(math.max(size.X * 0.35, 0.6), math.max(size.Y * 0.25, 0.4), math.max(size.Z * 0.35, 0.6))
		local neon = makePart(id .. "_Neon", neonSize, CFrame.new(0, size.Y * 0.75, 0), neonId, true, color)
		neon.Parent = model
	end

	-- PinataVisual.weldOverHead solo suelda Root al jugador: lo demás tiene que ir soldado a Root.
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = child
			weld.Parent = child
		end
	end

	applyAttributes(model, id, def)
	model.PrimaryPart = root
	return model
end

local function normalize(model: Model, id: string, def: any)
	applyAttributes(model, id, def)
	paintNeon(model, def.Rarity)
	ensureRoot(model)
end

function PinataRegistry.get(id: string): any?
	return Pinatas[id]
end

function PinataRegistry.install()
	local folder = pinataFolder()
	local imported = 0
	local created = 0
	local total = 0
	for id, def in Pinatas do
		total += 1
		local existing = folder:FindFirstChild(id)
		if existing ~= nil and existing:IsA("Model") then
			normalize(existing, id, def)
			imported += 1
		else
			local model = buildPlaceholder(id, def)
			model.Parent = folder
			created += 1
		end
	end
	print(`[WP-03] registro: {total} piñatas ({imported} importadas, {created} placeholder)`)
end

function PinataRegistry.clone(id: string): Model?
	local template = pinataFolder():FindFirstChild(id)
	if template == nil or not template:IsA("Model") then
		return nil
	end
	return template:Clone()
end

function PinataRegistry.smokeModeled(): (boolean, string?)
	local ids: { string } = {}
	for id, def in Pinatas do
		if def.Modeled then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	if #ids ~= EXPECTED_MODELED then
		return false, string.format("se esperaban %d modeladas y hay %d", EXPECTED_MODELED, #ids)
	end

	local bin = Instance.new("Folder")
	bin.Name = "_PinataSmoke"
	bin.Parent = ServerStorage
	local problem: string? = nil
	for _, id in ids do
		if problem ~= nil then
			break
		end
		local template = pinataFolder():FindFirstChild(id)
		if template == nil or not template:IsA("Model") then
			problem = "falta el modelo " .. id
			break
		end
		local clone = template:Clone()
		clone.Parent = bin
		local def = Pinatas[id]
		if clone.PrimaryPart == nil or clone.PrimaryPart.Name ~= "Root" then
			problem = id .. " PrimaryPart no está en la base (Root)"
			break
		end
		if clone:GetAttribute("PinataId") ~= id then
			problem = id .. " PinataId"
			break
		end
		if clone:GetAttribute("Rarity") ~= def.Rarity then
			problem = id .. " Rarity"
			break
		end
		local mesh = Assets.Meshes[id]
		local expectNeon = type(mesh) == "table" and mesh.Neon ~= nil
		local foundNeon = false
		for _, descendant in clone:GetDescendants() do
			if descendant:IsA("BasePart") and string.sub(descendant.Name, -5) == "_Neon" then
				foundNeon = true
				if descendant.Material ~= Enum.Material.Neon then
					problem = id .. " _Neon no es Material Neon"
					break
				end
			end
		end
		if problem == nil and expectNeon and not foundNeon then
			problem = id .. " sin parte _Neon"
		end
	end
	bin:Destroy()
	if problem ~= nil then
		return false, problem
	end
	return true, nil
end

function PinataRegistry.init(_services: { [string]: any })
	PinataRegistry.install()
end

function PinataRegistry.start()
	local ok, err = PinataRegistry.smokeModeled()
	if ok then
		print(`[WP-03] smoke ok: {EXPECTED_MODELED} piñatas instanciadas`)
	elseif RunService:IsStudio() then
		error("[WP-03] smoke FAIL: " .. tostring(err), 0)
	else
		warn("[WP-03] smoke FAIL: " .. tostring(err))
	end
end

return PinataRegistry
