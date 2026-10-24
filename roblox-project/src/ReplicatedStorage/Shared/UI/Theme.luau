--!strict
-- Tema de UI. Solo colores de art/textures/palette.json y de ART_DIRECTION §5–§6.
-- Títulos en Fredoka One (Luckiest Guy no trae tildes). Números grandes en Luckiest Guy.

local Rarities = require(script.Parent.Parent.Config.Rarities)

local function hex(value: string): Color3
	local r = tonumber(string.sub(value, 2, 3), 16) or 0
	local g = tonumber(string.sub(value, 4, 5), 16) or 0
	local b = tonumber(string.sub(value, 6, 7), 16) or 0
	return Color3.fromRGB(r, g, b)
end

local function fontEnum(name: string, fallback: Enum.Font): Enum.Font
	for _, item in Enum.Font:GetEnumItems() do
		if item.Name == name then
			return item
		end
	end
	return fallback
end

local color = {
	white = hex("#FFF7EC"),
	snow = hex("#F4FBFF"),
	cream = hex("#FFE6B8"),
	ink = hex("#1B1430"),
	ink_soft = hex("#3A2A55"),
	fiesta_pink = hex("#FF3E9A"),
	hot_magenta = hex("#E0187A"),
	sun_yellow = hex("#FFE14D"),
	mango = hex("#FFB400"),
	tangerine = hex("#FF7A1A"),
	chili = hex("#E8262E"),
	lime = hex("#8BE530"),
	jade = hex("#18C98A"),
	turquoise = hex("#16D3E8"),
	sky = hex("#3DA5FF"),
	grape = hex("#8A3CF0"),
	lavender = hex("#C59BFF"),
	bubblegum = hex("#FFB3D9"),
	gold = hex("#FFC22E"),
	gold_deep = hex("#E08A00"),
	gold_pale = hex("#FFE9A0"),
	silver = hex("#D9E2F2"),
	wood = hex("#C98A4B"),
	wood_dark = hex("#7A4A26"),
	donkey_grey = hex("#A9B4C9"),
	brown = hex("#8A4B2A"),
	blush = hex("#FF7FA8"),
	neon_pink = hex("#FF4FD8"),
	neon_cyan = hex("#3FF2FF"),
	neon_gold = hex("#FFD84D"),
	neon_green = hex("#5CFF8A"),
	xmas_red = hex("#D7192F"),
	xmas_green = hex("#11A35A"),
	candy_red = hex("#FF2D55"),
	candy_teal = hex("#00C2B8"),
	candy_violet = hex("#9B4DFF"),
}

export type RarityStyle = {
	color: Color3,
	text: Color3,
	shape: string,
	frame: string,
	plate: Color3,
}

local function inkOn(swatch: Color3): Color3
	local luma = swatch.R * 0.3 + swatch.G * 0.59 + swatch.B * 0.11
	if luma > 0.62 then
		return color.ink
	end
	return color.white
end

local rarityColor: { [string]: Color3 } = {
	Common = hex("#E6EEF9"),
	Uncommon = hex("#8BE530"),
	Rare = hex("#3DA5FF"),
	Epic = hex("#C59BFF"),
	Legendary = hex("#FFC22E"),
	Mythic = hex("#FF4FD8"),
	Secret = hex("#3FF2FF"),
	Event = hex("#FF5A6E"),
}

-- Solo glifos que Fredoka/Nunito (o el emoji de Roblox) dibujan: ♛ ✦ ✧ salen como cuadritos vacíos.
local rarityShape: { [string]: { shape: string, frame: string } } = {
	Common = { shape = "●", frame = "plain" },
	Uncommon = { shape = "◎", frame = "double" },
	Rare = { shape = "◆", frame = "diamond" },
	Epic = { shape = "★", frame = "star" },
	Legendary = { shape = "👑", frame = "crown" },
	Mythic = { shape = "❖", frame = "pulse" },
	Secret = { shape = "◈", frame = "glitch" },
	Event = { shape = "❄", frame = "stripe" },
}

local swatchByPinata: { [string]: string } = {
	estrellita = "sun_yellow",
	pollito = "sun_yellow",
	burrito = "donkey_grey",
	sandia = "lime",
	michi = "tangerine",
	elotito = "mango",
	ranita = "lime",
	pupusita = "cream",
	cohetin = "chili",
	paleton = "fiesta_pink",
	tortuga = "jade",
	pulpo = "grape",
	robo = "silver",
	dragon = "chili",
	cadejo = "snow",
	toro = "gold",
	izalco = "tangerine",
	torogoz = "turquoise",
	sombra = "ink",
	pixelin = "neon_cyan",
	tamalito = "jade",
	jengibrin = "brown",
	renito = "xmas_red",
}

local palette: { [string]: Color3 } = color :: any

local silhouetteByPinata: { [string]: string } = {
	estrellita = "star",
	michi = "cat",
	burrito = "donkey",
	dragon = "horn",
	toro = "horn",
	renito = "horn",
	sombra = "cyclops",
	torogoz = "beak",
	cohetin = "rocket",
	cadejo = "donkey",
}

local Theme = {
	color = color,
	radius = 20,
	stroke = 4,
	shadow = 4,
	minTouch = 48,
	font = {
		display = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		number = Font.new("rbxasset://fonts/families/LuckiestGuy.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	},
	fontEnum = {
		display = fontEnum("FredokaOne", Enum.Font.FredokaOne),
		number = fontEnum("FredokaOne", Enum.Font.FredokaOne),
		body = fontEnum("Nunito", Enum.Font.GothamBold),
	},
	confetti = {
		color.fiesta_pink,
		color.sun_yellow,
		color.turquoise,
		color.lime,
		color.grape,
		color.tangerine,
		color.sky,
		color.gold,
	},
	kiosk = {
		dulceria = color.sun_yellow,
		bates = color.wood,
		cajas = color.grape,
		vip = color.gold,
	},
}

function Theme.rarity(name: string): RarityStyle
	local swatch = rarityColor[name] or rarityColor.Common
	local shape = rarityShape[name] or rarityShape.Common
	local plate = swatch
	local text = inkOn(swatch)
	if name == "Secret" then
		plate = color.ink
		text = swatch
	end
	return {
		color = swatch,
		text = text,
		shape = shape.shape,
		frame = shape.frame,
		plate = plate,
	}
end

function Theme.rarityOrder(name: string): number
	for index, rarity in Rarities.Order do
		if rarity == name then
			return index
		end
	end
	return 99
end

function Theme.pinataColor(id: string): Color3
	local name = swatchByPinata[id]
	local swatch = if name then palette[name] else nil
	if swatch then
		return swatch
	end
	return color.fiesta_pink
end

function Theme.pinataAlt(id: string): Color3
	if id == "estrellita" then
		return color.fiesta_pink
	elseif id == "michi" then
		return color.cream
	elseif id == "sombra" then
		return color.neon_cyan
	elseif id == "dragon" then
		return color.jade
	end
	return color.cream
end

function Theme.silhouette(id: string): string
	return silhouetteByPinata[id] or "pom"
end

function Theme.apply(label: TextLabel, role: string, fill: Color3?)
	local face = Theme.font.body
	local enumFont = Theme.fontEnum.body
	if role == "display" then
		face = Theme.font.display
		enumFont = Theme.fontEnum.display
	elseif role == "number" then
		face = Theme.font.number
		enumFont = Theme.fontEnum.number
	end
	label.Font = enumFont
	label.FontFace = face
	label.TextColor3 = fill or color.ink
	label.TextStrokeTransparency = 1
	label.AutoLocalize = false
	label.RichText = false
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
end

function Theme.outlineNumber(label: TextLabel)
	Theme.apply(label, "number", color.white)
	label.TextStrokeColor3 = color.ink
	label.TextStrokeTransparency = 0
end

return Theme
