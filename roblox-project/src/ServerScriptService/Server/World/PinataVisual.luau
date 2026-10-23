--!strict
-- Clona una piñata de ServerStorage o arma un placeholder (bola + aro neón).
-- El arte real se monta según art/IMPORT_GUIDE.md; si el mesh no está, el juego igual corre.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MutationVisual = require(Shared:WaitForChild("Gameplay"):WaitForChild("MutationVisual"))
local Pinatas = require(Shared:WaitForChild("Config"):WaitForChild("Pinatas"))
local Rarities = require(Shared:WaitForChild("Config"):WaitForChild("Rarities"))
local Tuning = require(Shared:WaitForChild("Config"):WaitForChild("Tuning"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Text = require(Shared:WaitForChild("Locale"):WaitForChild("Text"))

local PinataVisual = {}

local function rarityColor(rarity: string): Color3
	local color = Rarities.Color[rarity]
	if typeof(color) == "Color3" then
		return color
	end
	return Color3.fromHex("#FFE14D")
end

local function ensurePrimary(model: Model): BasePart
	if model.PrimaryPart ~= nil then
		return model.PrimaryPart
	end
	local body = model:FindFirstChild("Body", true)
	if body ~= nil and body:IsA("BasePart") then
		model.PrimaryPart = body
		return body
	end
	local anyPart = model:FindFirstChildWhichIsA("BasePart", true)
	if anyPart ~= nil then
		model.PrimaryPart = anyPart
		return anyPart
	end
	local created = Instance.new("Part")
	created.Name = "Body"
	created.Size = Vector3.new(3.2, 3.2, 3.2)
	created.Parent = model
	model.PrimaryPart = created
	return created
end

-- El pivot de una importada es Root (en la base): el cartel va sobre la cabeza según el alto real
-- del modelo, con el borde de abajo apoyado ahí (SizeOffset) para no tapar la cara.
local function captionHeight(model: Model, primary: BasePart): number
	local box, size = model:GetBoundingBox()
	return math.max(box.Position.Y + size.Y / 2 - primary.Position.Y, 1) + 0.5
end

local function captionFor(model: Model): TextLabel
	local existing = model:FindFirstChild("Caption", true)
	if existing ~= nil and existing:IsA("TextLabel") then
		return existing
	end
	local primary = ensurePrimary(model)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CaptionGui"
	gui.Size = UDim2.fromOffset(160, 84)
	gui.SizeOffset = Vector2.new(0, 0.5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, captionHeight(model, primary), 0)
	gui.MaxDistance = 80
	gui.Parent = primary
	local text = Instance.new("TextLabel")
	text.Name = "Caption"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromHex("#FFF7EC")
	text.TextStrokeColor3 = Color3.fromHex("#1B1430")
	text.TextStrokeTransparency = 0
	text.Parent = gui
	return text
end

local function placeholder(pinataId: string, rarity: string): Model
	local model = Instance.new("Model")
	model.Name = pinataId
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(3.4, 3.4, 3.4)
	body.Color = rarityColor(rarity)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	local ring = Instance.new("Part")
	ring.Name = "Neon"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.28, 4.4, 4.4)
	ring.Color = rarityColor(rarity)
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CastShadow = false
	ring.CFrame = body.CFrame * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = ring
	weld.Parent = ring
	model.PrimaryPart = body
	model:SetAttribute("Placeholder", true)
	return model
end

local function fromTemplate(pinataId: string): Model?
	local Registry = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("PinataRegistry"))
	local clone = Registry.clone(pinataId)
	if clone == nil then
		return nil
	end
	ensurePrimary(clone)
	for _, desc in clone:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.Anchored = true
		end
	end
	return clone
end

function PinataVisual.describe(pinataId: string, mutation: string?): (string, number, number?, string)
	local def = Pinatas[pinataId]
	local name = if def then def.Name else pinataId
	local perSec = if def then def.CandyPerSec else 0
	local price = if def then def.Price else nil
	local rarity = if def then def.Rarity else "Common"
	if mutation == "Golden" then
		perSec *= 2
	elseif mutation == "Rainbow" then
		perSec *= 5
	elseif mutation == "Christmas" then
		perSec *= 3
	end
	return name, perSec, price, rarity
end

function PinataVisual.create(pinataId: string, mutation: string?): Model
	local _, perSec, _, rarity = PinataVisual.describe(pinataId, mutation)
	local model = fromTemplate(pinataId)
	if model == nil then
		model = placeholder(pinataId, rarity)
	end
	model.Name = pinataId
	local primary = ensurePrimary(model)
	model:SetAttribute("PinataId", pinataId)
	model:SetAttribute("Rarity", rarity)
	model:SetAttribute("CandyPerSec", perSec)
	if mutation ~= nil then
		model:SetAttribute("Mutation", mutation)
	end
	-- El cliente pinta Dorada y Arcoíris. El servidor solo marca; no anima.
	if MutationVisual.kind(mutation) ~= nil then
		CollectionService:AddTag(model, MutationVisual.TAG)
	end
	local trail = Instance.new("ParticleEmitter")
	trail.Name = "CarryTrail"
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Rate = 6
	trail.Enabled = false
	trail.Lifetime = NumberRange.new(0.3, 0.6)
	trail.Speed = NumberRange.new(1, 3)
	trail.SpreadAngle = Vector2.new(25, 25)
	trail.LightEmission = 0.5
	trail.Size = NumberSequence.new(0.28)
	trail.Color = ColorSequence.new(rarityColor(rarity))
	trail.Parent = primary
	PinataVisual.setCaption(model, pinataId, mutation)
	return model
end

function PinataVisual.setCaption(model: Model, pinataId: string, mutation: string?)
	local _, perSec, price = PinataVisual.describe(pinataId, mutation)
	local def = Pinatas[pinataId]
	local currency = if def ~= nil and def.Currency == "Bastones" then "Bastones" else "Dulces"
	local storedMutation = if mutation == nil or mutation == "" then "None" else mutation
	model:SetAttribute("CaptionPrice", if price == nil then -1 else price)
	model:SetAttribute("CaptionCurrency", currency)
	model:SetAttribute("Mutation", storedMutation)
	local label = captionFor(model)
	label:SetAttribute("CaptionKind", "pinata")
	label.AutoLocalize = false
	local name = Text.line("pinata." .. pinataId, "es")
	if name == "[" .. "pinata." .. pinataId .. "]" then
		name = if def ~= nil then def.Name else pinataId
	end
	if storedMutation ~= "None" then
		local mut = Text.line("mutation." .. storedMutation, "es")
		if mut ~= "" then
			name ..= " " .. mut
		end
	end
	local priceText = Text.line("caption.free", "es")
	if price ~= nil then
		priceText = Text.line("caption.price", "es", {
			n = Format(price),
			currency = Text.line(if currency == "Bastones" then "currency.bastones" else "currency.dulces", "es"),
		})
	end
	label.Text = name .. "\n" .. Text.line("hud.per_sec", "es", { n = Format(perSec) }) .. "\n" .. priceText
end

-- Cambia el tamaño (1 = el de la malla) y sube el cartel al alto nuevo. Sobre el pedestal van a
-- Tuning.PedestalScale (IMPORT_GUIDE §4); al cargarlas vuelven a 1.
function PinataVisual.setScale(model: Model, scale: number)
	if math.abs(model:GetScale() - scale) < 1e-3 then
		return
	end
	model:ScaleTo(scale)
	local gui = model:FindFirstChild("CaptionGui", true)
	local primary = model.PrimaryPart
	if gui ~= nil and gui:IsA("BillboardGui") and primary ~= nil then
		gui.StudsOffsetWorldSpace = Vector3.new(0, captionHeight(model, primary), 0)
	end
end

-- Altura del pivot sobre la base del modelo: Root (en la base) en las importadas, el centro del cuerpo en los rellenos.
function PinataVisual.restLift(model: Model): number
	local box, size = model:GetBoundingBox()
	return model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
end

-- Rotación para mirar (el -Z del modelo) en la dirección del plano; nil si no hay dirección.
function PinataVisual.facing(direction: Vector3): CFrame?
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		return nil
	end
	return CFrame.lookAt(Vector3.zero, flat)
end

-- lookAt: punto hacia el que mira la cara (el -Z del modelo), solo en el plano.
function PinataVisual.place(model: Model, feet: Vector3, lookAt: Vector3?)
	ensurePrimary(model)
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
		end
	end
	local facing = (if lookAt ~= nil then PinataVisual.facing(lookAt - feet) else nil) or CFrame.new()
	model:PivotTo(CFrame.new(feet) * facing)
	model:PivotTo(CFrame.new(feet + Vector3.new(0, PinataVisual.restLift(model), 0)) * facing)
end

function PinataVisual.setTrail(model: Model, enabled: boolean)
	local trail = model:FindFirstChild("CarryTrail", true)
	if trail ~= nil and trail:IsA("ParticleEmitter") then
		trail.Enabled = enabled
	end
end

function PinataVisual.weldOverHead(model: Model, root: BasePart)
	local primary = ensurePrimary(model)
	local old = primary:FindFirstChild("CarryWeld")
	if old ~= nil then
		old:Destroy()
	end
	model.Parent = root.Parent
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
			desc.CanCollide = false
			desc.Massless = true
			pcall(function()
				desc:SetNetworkOwner(nil)
			end)
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = primary
	weld.C0 = CFrame.new(Tuning.CarryOffsetX, Tuning.CarryOffsetY, Tuning.CarryOffsetZ)
	weld.Parent = primary
	PinataVisual.setTrail(model, true)
end

function PinataVisual.unweld(model: Model)
	local primary = model.PrimaryPart
	if primary ~= nil then
		local weld = primary:FindFirstChild("CarryWeld")
		if weld ~= nil then
			weld:Destroy()
		end
	end
	PinataVisual.setTrail(model, false)
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.AssemblyLinearVelocity = Vector3.zero
			desc.AssemblyAngularVelocity = Vector3.zero
			desc.Anchored = true
			desc.CanCollide = false
		end
	end
end

return PinataVisual
