-- Ordena lo que deja File → Import 3D en Workspace (art/export/**/*.fbx) según art/IMPORT_GUIDE.md.
-- Pegalo entero en la Command Bar de Studio, en modo Edit (no en Play). Se puede correr varias veces:
-- lo que ya estaba en el destino con el mismo nombre se reemplaza.
--
--   piñatas      → ServerStorage/Pinatas/<id>       (Root + Body + _Neon soldadas, attributes)
--   base_*       → ServerStorage/Templates/Base
--   bat_*, etc.  → ServerStorage/Templates/Props
--   lobby_*      → ServerStorage/Templates/Lobby
--
-- Rojo no borra nada de eso: Pinatas/ y Templates/ tienen init.meta.json con ignoreUnknownInstances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Pinatas = require(Config:WaitForChild("Pinatas"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Assets = require(Config:WaitForChild("Assets"))

local PROPS = {
	bat_wood = true,
	bat_gold = true,
	caja_sorpresa = true,
	candy_pile = true,
	papel_picado_banner = true,
}

-- Neón de lo que no es piñata (las piñatas usan el color de su rareza). El láser del candado sale de §3.
local NEON_COLOR = {
	base_gate_Neon = Color3.fromHex("#FF4FD8"),
}
local WARM_NEON = Color3.fromHex("#FFD98A")

local function isPlaceholder(id: string?): boolean
	return id == nil or id == "" or id == "rbxassetid://0"
end

local function kindOf(name: string): string?
	if Pinatas[name] ~= nil then
		return "Pinata"
	elseif string.sub(name, 1, 5) == "base_" then
		return "Base"
	elseif string.sub(name, 1, 6) == "lobby_" then
		return "Lobby"
	elseif PROPS[name] then
		return "Props"
	end
	return nil
end

local function folder(parent: Instance, name: string): Folder
	local found = parent:FindFirstChild(name)
	if found ~= nil and found:IsA("Folder") then
		return found
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local function hasSuffix(name: string, suffix: string): boolean
	return string.sub(name, -#suffix) == suffix
end

-- Paleta compartida (§3 opción A). El importador sube palette_*.png una vez por FBX y deja
-- un asset distinto en cada malla; todas son la misma imagen, así que se unifican en un solo ID
-- (54 texturas de 1024² iguales en memoria son caras en móvil).
local palette = {
	Color = Assets.PaletteColor,
	Roughness = Assets.PaletteRoughness,
	Metalness = Assets.PaletteMetalness,
}

-- Sin IDs en Assets.luau, se adopta la paleta que el importador subió con el primer FBX.
local function adoptImportedPalette()
	if not isPlaceholder(palette.Color) then
		return
	end
	for _, child in workspace:GetChildren() do
		local main = child:FindFirstChild(child.Name)
		local sa = if main ~= nil then main:FindFirstChildOfClass("SurfaceAppearance") else nil
		if sa ~= nil and sa.ColorMap ~= "" then
			palette.Color = sa.ColorMap
			palette.Roughness = sa.RoughnessMap
			palette.Metalness = sa.MetalnessMap
			return
		end
	end
end

local function clearTexture(part: BasePart)
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	if part:IsA("MeshPart") then
		part.TextureID = ""
	end
end

local function applyPalette(part: MeshPart)
	if isPlaceholder(palette.Color) then
		return
	end
	local ok = pcall(function()
		local sa = part:FindFirstChildOfClass("SurfaceAppearance") or Instance.new("SurfaceAppearance")
		sa.ColorMap = palette.Color
		sa.RoughnessMap = if isPlaceholder(palette.Roughness) then "" else palette.Roughness
		sa.MetalnessMap = if isPlaceholder(palette.Metalness) then "" else palette.Metalness
		sa.AlphaMode = Enum.AlphaMode.Opaque
		sa.Parent = part
	end)
	if ok then
		part.TextureID = ""
	else
		part.TextureID = palette.Color
	end
end

-- Materiales por sufijo (§0 y §3, "Partes especiales").
local function dressPart(part: BasePart, neonColor: Color3?)
	part.Anchored = true
	pcall(function()
		(part :: any).RenderFidelity = Enum.RenderFidelity.Automatic
	end)
	local name = part.Name
	if hasSuffix(name, "_Neon") then
		clearTexture(part)
		part.Material = Enum.Material.Neon
		part.CastShadow = false
		part.Color = neonColor or NEON_COLOR[name] or WARM_NEON
	elseif hasSuffix(name, "_Glass") then
		clearTexture(part)
		part.Material = Enum.Material.Glass
		part.Transparency = 0.45
		part.Color = Color3.fromHex("#BFF4FF")
	elseif hasSuffix(name, "_Water") then
		clearTexture(part)
		part.Material = Enum.Material.Glass
		part.Transparency = 0.35
		part.Color = Color3.fromHex("#25C7E0")
	elseif hasSuffix(name, "_Flags") then
		pcall(function()
			(part :: any).DoubleSided = true
		end)
		if not isPlaceholder(Assets.PapelPicadoAtlas) and part:FindFirstChildOfClass("SurfaceAppearance") == nil then
			pcall(function()
				local sa = Instance.new("SurfaceAppearance")
				sa.ColorMap = Assets.PapelPicadoAtlas
				sa.AlphaMode = Enum.AlphaMode.Transparency
				sa.Parent = part
			end)
		end
	elseif part:IsA("MeshPart") then
		applyPalette(part)
	end
end

local function makeRoot(model: Model): BasePart
	local old = model:FindFirstChild("Root")
	if old ~= nil then
		old:Destroy()
	end
	local cf, size = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 1, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2 - root.Size.Y / 2, 0))
	root.Parent = model
	model.PrimaryPart = root
	return root
end

-- §4: Model jugable. PinataVisual.weldOverHead solo suelda Root al jugador, así que todo lo demás va soldado a Root.
local function buildPinata(model: Model, id: string)
	local def = Pinatas[id]
	local neonColor = Rarities.Color[def.Rarity]
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			dressPart(desc, neonColor)
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
			if desc:IsA("MeshPart") then
				pcall(function()
					desc.CollisionFidelity = Enum.CollisionFidelity.Box
				end)
			end
			if desc.Name == id then
				desc.Name = "Body"
			end
		elseif desc:IsA("WeldConstraint") then
			desc:Destroy()
		end
	end
	local root = makeRoot(model)
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = desc
			weld.Parent = desc
		end
	end
	model:SetAttribute("PinataId", id)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("CandyPerSec", def.CandyPerSec)
	model:SetAttribute("Modeled", true)
end

local function buildTemplate(model: Model, kind: string)
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			dressPart(desc, nil)
			if kind == "Props" and desc:IsA("MeshPart") then
				pcall(function()
					desc.CollisionFidelity = Enum.CollisionFidelity.Box
				end)
			end
		end
	end
end

-- El importador a veces deja un MeshPart suelto en vez de un Model.
local function asModel(inst: Instance, name: string): Model
	if inst:IsA("Model") then
		return inst
	end
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = inst.Parent
	inst.Parent = model
	return model
end

local recording = ChangeHistoryService:TryBeginRecording("OrganizeImports")
local pinataFolder = folder(ServerStorage, "Pinatas")
local templates = folder(ServerStorage, "Templates")
local counts = { Pinata = 0, Base = 0, Props = 0, Lobby = 0 }
local meshIds: { string } = {}
local sizeWarnings: { string } = {}
adoptImportedPalette()

for _, child in workspace:GetChildren() do
	local name = string.gsub(child.Name, "%.fbx$", "")
	local kind = kindOf(name)
	if kind == nil or not (child:IsA("Model") or child:IsA("MeshPart")) then
		continue
	end
	local model = asModel(child, name)
	model.Name = name
	local dest = if kind == "Pinata" then pinataFolder else folder(templates, kind)
	if kind == "Pinata" then
		buildPinata(model, name)
	else
		buildTemplate(model, kind)
	end
	local old = dest:FindFirstChild(name)
	if old ~= nil and old ~= model then
		old:Destroy()
	end
	model.Parent = dest
	counts[kind] += 1

	if kind == "Pinata" then
		local body = model:FindFirstChild("Body")
		local neon = model:FindFirstChild(name .. "_Neon")
		local bodyId = if body ~= nil and body:IsA("MeshPart") then body.MeshId else "?"
		local neonId = if neon ~= nil and neon:IsA("MeshPart") then neon.MeshId else nil
		table.insert(meshIds, `{name} Body={bodyId}` .. (if neonId then ` Neon={neonId}` else ""))
		local expected = Assets.Meshes[name]
		if expected ~= nil then
			local _, size = model:GetBoundingBox()
			local ratio = size.Y / expected.Size[2]
			if ratio < 0.8 or ratio > 1.25 then
				table.insert(
					sizeWarnings,
					string.format("%s mide %.2f de alto (esperado %.2f, x%.2f)", name, size.Y, expected.Size[2], ratio)
				)
			end
		end
	end
end

if recording ~= nil then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

table.sort(meshIds)
print(
	string.format(
		"[organize] piñatas %d · base %d · props %d · lobby %d",
		counts.Pinata,
		counts.Base,
		counts.Props,
		counts.Lobby
	)
)
print(
	string.format(
		"[organize] paleta Color=%s Roughness=%s Metalness=%s",
		palette.Color,
		palette.Roughness,
		palette.Metalness
	)
)
for _, line in meshIds do
	print("[organize] mesh " .. line)
end
for _, line in sizeWarnings do
	warn("[organize] escala: " .. line .. " → revisá Scale Unit en el importador (IMPORT_GUIDE §1)")
end
if counts.Pinata + counts.Base + counts.Props + counts.Lobby == 0 then
	warn("[organize] no encontré nada importado en Workspace (¿ya se movió, o el Model no se llama como el .fbx?)")
end
