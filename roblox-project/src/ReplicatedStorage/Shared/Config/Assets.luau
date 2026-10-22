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
		burrito = { Body = PLACEHOLDER, Size = { 2.28, 4.27, 4.62 } },
		sandia = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		michi = { Body = PLACEHOLDER, Size = { 2.94, 4.1, 2.43 } },
		elotito = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		ranita = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		pupusita = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		cohetin = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.39, 4.04, 2.63 } },
		paleton = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		tortuga = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		pulpo = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		robo = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		dragon = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 4.43, 4.11, 3.75 } },
		cadejo = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		toro = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3.48, 3.94, 6.14 } },
		izalco = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		torogoz = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.82, 4.1, 3.62 } },
		sombra = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.86, 2.72, 2.91 } },
		pixelin = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		tamalito = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		jengibrin = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		renito = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.79, 4.54, 2.67 } },
		-- Temporada Meme 1. Size = art/export/creatures/_meta.json. Las seis traen malla _Neon.
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/michi_aplausos.fbx
		michi_aplausos = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.98, 4.06, 3.21 } },
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
		-- Temporada Meme 2 (fase 3). Size = art/export/creatures/_meta.json. Las ocho traen malla _Neon.
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/garrobita_terenga.fbx
		garrobita_terenga = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3.48, 4.43, 3.02 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/fantasmita_bu.fbx
		fantasmita_bu = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 4.43, 4.24, 3.08 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/cochinito_quincena.fbx
		cochinito_quincena = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3.84, 4.39, 4.98 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/lic_dos_peces.fbx
		lic_dos_peces = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 5.35, 3.81, 1.74 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/pinovela.fbx
		pinovela = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 4.11, 4.38, 2.48 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/chancla_teledirigida.fbx
		chancla_teledirigida = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 5.28, 4.6, 2.85 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/aurazoso.fbx
		aurazoso = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 4.05, 4.95, 3.4 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/abuelita_en_vivo.fbx
		abuelita_en_vivo = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 4.36, 5.03, 2.96 } },
		-- Colección Random (fase 3). Las cuatro traen malla _Neon.
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/caracol_turbo.fbx
		caracol_turbo = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 2.15, 3.81, 6 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/cactus_abrazos.fbx
		cactus_abrazos = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3.62, 4.06, 2.38 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/aguacaton.fbx
		aguacaton = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3.74, 4.2, 2.61 } },
		-- TODO: reemplazar rbxassetid://0 al subir art/export/creatures/pulpo_dj.fbx
		pulpo_dj = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 4.96, 5.74, 4.16 } },
	} :: { [string]: MeshRef },
}

return Assets
