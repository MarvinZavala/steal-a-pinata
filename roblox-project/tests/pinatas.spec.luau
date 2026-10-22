--!strict
local H = require("./harness")
local fs = require("@lune/fs")
local Pinatas = require("../src/ReplicatedStorage/Shared/Config/Pinatas")
local Assets = require("../src/ReplicatedStorage/Shared/Config/Assets")

H.begin()

local EXPECTED = {
	"estrellita",
	"pollito",
	"burrito",
	"sandia",
	"michi",
	"elotito",
	"ranita",
	"pupusita",
	"cohetin",
	"paleton",
	"tortuga",
	"pulpo",
	"robo",
	"dragon",
	"cadejo",
	"toro",
	"izalco",
	"torogoz",
	"sombra",
	"pixelin",
	"tamalito",
	"jengibrin",
	"renito",
	"michi_aplausos",
	"seis_siete",
	"manzanin_iq",
	"mapache_nel",
	"fichadito",
	"gemelos_pupusa",
	"garrobita_terenga",
	"fantasmita_bu",
	"cochinito_quincena",
	"lic_dos_peces",
	"pinovela",
	"chancla_teledirigida",
	"aurazoso",
	"abuelita_en_vivo",
	"caracol_turbo",
	"cactus_abrazos",
	"aguacaton",
	"pulpo_dj",
}

local MODELED: { [string]: boolean } = {
	estrellita = true,
	burrito = true,
	michi = true,
	cohetin = true,
	dragon = true,
	toro = true,
	torogoz = true,
	sombra = true,
	renito = true,
	michi_aplausos = true,
	seis_siete = true,
	manzanin_iq = true,
	mapache_nel = true,
	fichadito = true,
	gemelos_pupusa = true,
	garrobita_terenga = true,
	fantasmita_bu = true,
	cochinito_quincena = true,
	lic_dos_peces = true,
	pinovela = true,
	chancla_teledirigida = true,
	aurazoso = true,
	abuelita_en_vivo = true,
	caracol_turbo = true,
	cactus_abrazos = true,
	aguacaton = true,
	pulpo_dj = true,
}

local NEON: { [string]: boolean } = {
	cohetin = true,
	dragon = true,
	toro = true,
	torogoz = true,
	sombra = true,
	renito = true,
	izalco = true,
	pixelin = true,
	michi_aplausos = true,
	seis_siete = true,
	manzanin_iq = true,
	mapache_nel = true,
	fichadito = true,
	gemelos_pupusa = true,
	garrobita_terenga = true,
	fantasmita_bu = true,
	cochinito_quincena = true,
	lic_dos_peces = true,
	pinovela = true,
	chancla_teledirigida = true,
	aurazoso = true,
	abuelita_en_vivo = true,
	caracol_turbo = true,
	cactus_abrazos = true,
	aguacaton = true,
	pulpo_dj = true,
}

local RARITIES: { [string]: boolean } = {
	Common = true,
	Uncommon = true,
	Rare = true,
	Epic = true,
	Legendary = true,
	Mythic = true,
	Secret = true,
	Event = true,
}

H.check("hay 41 piñatitos y 27 modeladas", function()
	local seen: { [string]: boolean } = {}
	local count = 0
	local modeled = 0
	for id, def in Pinatas do
		count += 1
		seen[id] = true
		H.truthy(def.Name ~= nil and def.Name ~= "", id)
		H.truthy(RARITIES[def.Rarity] == true, id)
		H.truthy(type(def.CandyPerSec) == "number" and def.CandyPerSec > 0, id)
		H.truthy(def.Currency == "Dulces" or def.Currency == "Bastones", id)
		H.truthy(type(def.Set) == "string", id)
		if def.Price ~= nil then
			H.truthy(type(def.Price) == "number" and def.Price > 0, id)
		end
		if def.Modeled then
			modeled += 1
			H.truthy(MODELED[id] == true, id)
		end
		local mesh = Assets.Meshes[id]
		H.truthy(mesh, "mesh " .. id)
		H.truthy(string.sub(mesh.Body, 1, 13) == "rbxassetid://", id)
		H.eq(#mesh.Size, 3, id)
		for _, axis in mesh.Size do
			H.truthy(type(axis) == "number" and axis > 0, id)
		end
		if NEON[id] then
			H.truthy(mesh.Neon ~= nil and string.sub(mesh.Neon :: string, 1, 13) == "rbxassetid://", id)
		else
			H.eq(mesh.Neon, nil, id)
		end
	end
	H.eq(count, 41)
	H.eq(modeled, 27)
	for _, id in EXPECTED do
		H.truthy(seen[id] == true, id)
	end
	H.eq(Pinatas.sombra.Price, nil)
	H.eq(Pinatas.pixelin.Price, nil)
	H.eq(Pinatas.michi_aplausos.Rarity, "Legendary")
	H.eq(Pinatas.michi_aplausos.CandyPerSec, 2750)
	H.eq(Pinatas.michi_aplausos.Price, 650000)
	H.eq(Pinatas.seis_siete.CandyPerSec, 6767)
	H.eq(Pinatas.seis_siete.Price, 1676767)
	H.eq(Pinatas.manzanin_iq.Rarity, "Mythic")
	H.eq(Pinatas.manzanin_iq.Price, 5200000)
	H.eq(Pinatas.mapache_nel.CandyPerSec, 16500)
	H.eq(Pinatas.mapache_nel.Price, 7000000)
	H.eq(Pinatas.fichadito.Price, nil)
	H.eq(Pinatas.gemelos_pupusa.Price, nil)
	H.eq(Pinatas.gemelos_pupusa.CandyPerSec, 150000)
	H.eq(Pinatas.michi_aplausos.Set, "Memes")
	-- Temporada Meme 2 + Colección Random (fase 3)
	H.eq(Pinatas.garrobita_terenga.Rarity, "Epic")
	H.eq(Pinatas.cochinito_quincena.CandyPerSec, 2515)
	H.eq(Pinatas.cochinito_quincena.Price, 515150)
	H.eq(Pinatas.pinovela.Rarity, "Mythic")
	H.eq(Pinatas.pinovela.Price, 8000000)
	H.eq(Pinatas.aurazoso.Price, nil)
	H.eq(Pinatas.abuelita_en_vivo.Price, nil)
	H.eq(Pinatas.abuelita_en_vivo.CandyPerSec, 135000)
	H.eq(Pinatas.lic_dos_peces.Set, "Memes2")
	H.eq(Pinatas.caracol_turbo.Rarity, "Epic")
	H.eq(Pinatas.aguacaton.Rarity, "Mythic")
	H.eq(Pinatas.pulpo_dj.Price, nil)
	H.eq(Pinatas.pulpo_dj.Set, "Random")
end)

H.check("cada piñata tiene nombre traducido en el catálogo", function()
	local Catalog = require("../src/ReplicatedStorage/Shared/Locale/Catalog")
	for id in Pinatas do
		local e = Catalog.entries["pinata." .. id]
		H.truthy(e ~= nil, "pinata." .. id)
		if e then
			H.truthy(e.es ~= nil and e.en ~= nil and e.pt ~= nil, "pinata." .. id)
		end
	end
end)

H.check("pesos de rareza suman 100", function()
	-- Rarities.luau llama Color3.fromHex al cargar; Lune no tiene esa API.
	-- El peso se lee del fuente, que es la fuente de verdad.
	local text = if fs.isFile("src/ReplicatedStorage/Shared/Config/Rarities.luau")
		then fs.readFile("src/ReplicatedStorage/Shared/Config/Rarities.luau")
		else fs.readFile("roblox-project/src/ReplicatedStorage/Shared/Config/Rarities.luau")
	local block = string.match(text, "SpawnWeight%s*=%s*{(.-)}")
	H.truthy(block, "SpawnWeight")
	local sum = 0
	local found = 0
	for num in string.gmatch(block :: string, "=%s*([%d%.]+)") do
		sum += tonumber(num) :: number
		found += 1
	end
	H.eq(found, 7)
	H.near(sum, 100, 1e-6)
end)

H.finish()
