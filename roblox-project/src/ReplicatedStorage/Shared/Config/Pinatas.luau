--!strict
-- Roster fase 1 (GDD §5). Price = nil -> no se vende en la Pasarela (Secretas).
-- Modeled = true -> existe en art/export/creatures/<id>.fbx y en ServerStorage/Pinatas/<id>.
export type PinataDef = {
	Name: string,
	Rarity: string,
	CandyPerSec: number,
	Price: number?,
	Currency: string,
	Set: string,
	Modeled: boolean,
}

local Pinatas: { [string]: PinataDef } = {
	estrellita = { Name = "Estrellita", Rarity = "Common", CandyPerSec = 1, Price = 15, Currency = "Dulces", Set = "Classics", Modeled = true },
	pollito = { Name = "Pollito Pío", Rarity = "Common", CandyPerSec = 2, Price = 40, Currency = "Dulces", Set = "Fauna", Modeled = false },
	burrito = { Name = "Burrito", Rarity = "Common", CandyPerSec = 3, Price = 75, Currency = "Dulces", Set = "Classics", Modeled = true },
	sandia = { Name = "Sandía Sonriente", Rarity = "Common", CandyPerSec = 5, Price = 150, Currency = "Dulces", Set = "Food", Modeled = false },
	michi = { Name = "Michi", Rarity = "Uncommon", CandyPerSec = 9, Price = 350, Currency = "Dulces", Set = "Fauna", Modeled = true },
	elotito = { Name = "Elotito", Rarity = "Uncommon", CandyPerSec = 14, Price = 600, Currency = "Dulces", Set = "Food", Modeled = false },
	ranita = { Name = "Ranita Fiestera", Rarity = "Uncommon", CandyPerSec = 20, Price = 950, Currency = "Dulces", Set = "Fauna", Modeled = false },
	pupusita = { Name = "Pupusita", Rarity = "Uncommon", CandyPerSec = 28, Price = 1500, Currency = "Dulces", Set = "Food", Modeled = false },
	cohetin = { Name = "Cohetín", Rarity = "Rare", CandyPerSec = 60, Price = 4500, Currency = "Dulces", Set = "Classics", Modeled = true },
	paleton = { Name = "Paletón", Rarity = "Rare", CandyPerSec = 90, Price = 7500, Currency = "Dulces", Set = "Food", Modeled = false },
	tortuga = { Name = "Tortuga Tambor", Rarity = "Rare", CandyPerSec = 130, Price = 12000, Currency = "Dulces", Set = "Fauna", Modeled = false },
	pulpo = { Name = "Pulpo Confeti", Rarity = "Epic", CandyPerSec = 300, Price = 40000, Currency = "Dulces", Set = "Fauna", Modeled = false },
	robo = { Name = "Robo-Piñata", Rarity = "Epic", CandyPerSec = 450, Price = 65000, Currency = "Dulces", Set = "Classics", Modeled = false },
	dragon = { Name = "Dragón Chile", Rarity = "Epic", CandyPerSec = 700, Price = 110000, Currency = "Dulces", Set = "Folklore", Modeled = true },
	cadejo = { Name = "Cadejo", Rarity = "Legendary", CandyPerSec = 2000, Price = 450000, Currency = "Dulces", Set = "Folklore", Modeled = false },
	toro = { Name = "Toro de Oro", Rarity = "Legendary", CandyPerSec = 3500, Price = 900000, Currency = "Dulces", Set = "Classics", Modeled = true },
	izalco = { Name = "Volcán Izalco", Rarity = "Mythic", CandyPerSec = 12000, Price = 4500000, Currency = "Dulces", Set = "Folklore", Modeled = false },
	torogoz = { Name = "Torogoz Cósmico", Rarity = "Mythic", CandyPerSec = 20000, Price = 9000000, Currency = "Dulces", Set = "Folklore", Modeled = true },
	sombra = { Name = "Sombra", Rarity = "Secret", CandyPerSec = 75000, Price = nil, Currency = "Dulces", Set = "Secrets", Modeled = true },
	pixelin = { Name = "Pixelín", Rarity = "Secret", CandyPerSec = 120000, Price = nil, Currency = "Dulces", Set = "Secrets", Modeled = false },
	tamalito = { Name = "Tamalito", Rarity = "Event", CandyPerSec = 400, Price = 2500, Currency = "Bastones", Set = "Christmas", Modeled = false },
	jengibrin = { Name = "Jengibrín", Rarity = "Event", CandyPerSec = 1500, Price = 9000, Currency = "Bastones", Set = "Christmas", Modeled = false },
	renito = { Name = "Renito", Rarity = "Event", CandyPerSec = 5000, Price = 25000, Currency = "Bastones", Set = "Christmas", Modeled = true },
	-- Temporada Meme 1 (GDD §5.1, plan/TRENDS_MEMES.md). Bloque aparte para que el merge sea fácil.
	michi_aplausos = { Name = "Michi Aplausos", Rarity = "Legendary", CandyPerSec = 2750, Price = 650000, Currency = "Dulces", Set = "Memes", Modeled = true },
	seis_siete = { Name = "Seis-Siete", Rarity = "Legendary", CandyPerSec = 6767, Price = 1676767, Currency = "Dulces", Set = "Memes", Modeled = true },
	manzanin_iq = { Name = "Manzanín IQ", Rarity = "Mythic", CandyPerSec = 13000, Price = 5200000, Currency = "Dulces", Set = "Memes", Modeled = true },
	mapache_nel = { Name = "Mapache Nel", Rarity = "Mythic", CandyPerSec = 16500, Price = 7000000, Currency = "Dulces", Set = "Memes", Modeled = true },
	fichadito = { Name = "Fichadito", Rarity = "Secret", CandyPerSec = 100000, Price = nil, Currency = "Dulces", Set = "Memes", Modeled = true },
	gemelos_pupusa = { Name = "Los Gemelos Pupusa", Rarity = "Secret", CandyPerSec = 150000, Price = nil, Currency = "Dulces", Set = "Memes", Modeled = true },
}

return Pinatas
