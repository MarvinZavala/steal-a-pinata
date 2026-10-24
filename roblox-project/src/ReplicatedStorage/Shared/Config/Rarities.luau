--!strict
-- Rarezas: orden, color de aro (ver art/ART_DIRECTION.md §5) y peso de spawn en la Pasarela (GDD §4.1).
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret" | "Event"

local Rarities = {
	Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Event" },
	Color = {
		Common = Color3.fromHex("#E6EEF9"),
		Uncommon = Color3.fromHex("#8BE530"),
		Rare = Color3.fromHex("#3DA5FF"),
		Epic = Color3.fromHex("#C59BFF"),
		Legendary = Color3.fromHex("#FFC22E"),
		Mythic = Color3.fromHex("#FF4FD8"),
		Secret = Color3.fromHex("#3FF2FF"),
		Event = Color3.fromHex("#FF5A6E"),
	},
	-- Pesos por spawn (suman 100). Valores de diseño iniciales: balancear con telemetría.
	SpawnWeight = {
		Common = 62,
		Uncommon = 25,
		Rare = 9,
		Epic = 3,
		Legendary = 0.8,
		Mythic = 0.19,
		Secret = 0.01,
	},
	-- Rarezas que la Suerte de Server dobla en la Pasarela (la tienda muestra estas probabilidades).
	LuckBoosted = { Rare = true, Epic = true, Legendary = true, Mythic = true, Secret = true },
	-- Golpes de bate necesarios para que el carrier suelte la piñata (GDD §4.3)
	HitsToDrop = { Common = 1, Uncommon = 1, Rare = 1, Epic = 1, Legendary = 2, Mythic = 2, Secret = 2, Event = 2 },
}

return Rarities
