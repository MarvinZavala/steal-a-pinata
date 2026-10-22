--!strict
-- Texturas y mallas. Pegá los asset IDs reales después de subirlos (art/IMPORT_GUIDE.md §2 y §4).
-- "rbxassetid://0" es un placeholder: PinataRegistry no pide esa malla a Roblox.
-- Size = { X, Y, Z } en studs. Las modeladas salen de art/export/creatures/_meta.json.
export type MeshRef = {
	Body: string,
	Neon: string?,
	Size: { number },
}

local PLACEHOLDER = "rbxassetid://0"

local Assets = {
	PaletteColor = PLACEHOLDER,
	PaletteRoughness = PLACEHOLDER,
	PaletteMetalness = PLACEHOLDER,
	PapelPicadoAtlas = PLACEHOLDER,
	Logo = PLACEHOLDER,
	Meshes = {
		estrellita = { Body = PLACEHOLDER, Size = { 4.44, 3.53, 2.12 } },
		pollito = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		burrito = { Body = PLACEHOLDER, Size = { 2.17, 3.98, 4.5 } },
		sandia = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		michi = { Body = PLACEHOLDER, Size = { 2.91, 3.96, 2.29 } },
		elotito = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		ranita = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		pupusita = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		cohetin = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.39, 4.04, 2.63 } },
		paleton = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		tortuga = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		pulpo = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		robo = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		dragon = { Body = PLACEHOLDER, Size = { 4.43, 4.06, 3.66 } },
		cadejo = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		toro = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3.48, 3.94, 6.09 } },
		izalco = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		torogoz = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.82, 3.77, 3.55 } },
		sombra = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.86, 2.72, 2.91 } },
		pixelin = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		tamalito = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		jengibrin = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		renito = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.56, 4.52, 2.42 } },
		-- Temporada Meme 1. Size = art/export/creatures/_meta.json. Las seis traen malla _Neon.
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/michi_aplausos.fbx
		michi_aplausos = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.98, 4.06, 3.16 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/seis_siete.fbx
		seis_siete = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 6.99, 3.53, 2.03 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/manzanin_iq.fbx
		manzanin_iq = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 4.36, 3.83, 3.93 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/mapache_nel.fbx
		mapache_nel = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 4.37, 6.02, 6.89 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/fichadito.fbx
		fichadito = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 4.4, 4.94, 2.47 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/gemelos_pupusa.fbx
		gemelos_pupusa = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 7.75, 4.56, 1.59 } },
	} :: { [string]: MeshRef },
}

return Assets
