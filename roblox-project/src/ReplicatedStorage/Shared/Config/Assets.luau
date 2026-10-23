--!strict
-- Texturas y mallas. Los IDs reales salen del 3D Importer (scripts/studio/organize_imports.luau los imprime).
-- "rbxassetid://0" es un placeholder: PinataRegistry no pide esa malla a Roblox.
-- Size = { X, Y, Z } en studs. Las modeladas salen de art/export/creatures/_meta.json.
export type MeshRef = {
	Body: string,
	Neon: string?,
	Size: { number },
}

local PLACEHOLDER = "rbxassetid://0"

local Assets = {
	PaletteColor = "rbxassetid://116210999439297",
	PaletteRoughness = "rbxassetid://110004172800827",
	PaletteMetalness = "rbxassetid://114477100334395",
	PapelPicadoAtlas = "rbxassetid://128519372817331",
	Logo = PLACEHOLDER,
	Meshes = {
		estrellita = { Body = "rbxassetid://131009986503875", Size = { 4.44, 3.53, 2.12 } },
		pollito = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		burrito = { Body = "rbxassetid://100926591139430", Size = { 2.28, 4.27, 4.62 } },
		sandia = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		michi = { Body = "rbxassetid://85515127392541", Size = { 2.94, 4.1, 2.43 } },
		elotito = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		ranita = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		pupusita = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		cohetin = {
			Body = "rbxassetid://126044637014150",
			Neon = "rbxassetid://128232107575367",
			Size = { 2.39, 4.04, 2.63 },
		},
		paleton = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		tortuga = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		pulpo = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		robo = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		dragon = {
			Body = "rbxassetid://98481319195520",
			Neon = "rbxassetid://131230708584198",
			Size = { 4.43, 4.11, 3.75 },
		},
		cadejo = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		toro = {
			Body = "rbxassetid://138625204443256",
			Neon = "rbxassetid://128952015501450",
			Size = { 3.48, 3.94, 6.14 },
		},
		izalco = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		torogoz = {
			Body = "rbxassetid://80657026561917",
			Neon = "rbxassetid://109512114024071",
			Size = { 2.82, 4.1, 3.62 },
		},
		sombra = {
			Body = "rbxassetid://127286863016808",
			Neon = "rbxassetid://95086634953088",
			Size = { 2.86, 2.72, 2.91 },
		},
		pixelin = { Body = PLACEHOLDER, Neon = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		tamalito = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		jengibrin = { Body = PLACEHOLDER, Size = { 3, 3.2, 3 } },
		renito = {
			Body = "rbxassetid://123326326399503",
			Neon = "rbxassetid://129185136635245",
			Size = { 2.79, 4.54, 2.67 },
		},
		-- Temporada Meme 1. Size = art/export/creatures/_meta.json. Las seis traen malla _Neon.
		michi_aplausos = {
			Body = "rbxassetid://79947411171384",
			Neon = "rbxassetid://128033039806614",
			Size = { 2.98, 4.06, 3.21 },
		},
		seis_siete = {
			Body = "rbxassetid://126907931713942",
			Neon = "rbxassetid://92150959313528",
			Size = { 6.99, 3.53, 2.03 },
		},
		manzanin_iq = {
			Body = "rbxassetid://133463038939237",
			Neon = "rbxassetid://85648226168458",
			Size = { 4.36, 3.83, 3.93 },
		},
		mapache_nel = {
			Body = "rbxassetid://76865536671078",
			Neon = "rbxassetid://83892902023591",
			Size = { 4.37, 6.02, 6.89 },
		},
		fichadito = {
			Body = "rbxassetid://79913867027283",
			Neon = "rbxassetid://79214379244500",
			Size = { 4.4, 4.94, 2.47 },
		},
		gemelos_pupusa = {
			Body = "rbxassetid://111876290495311",
			Neon = "rbxassetid://90923602378573",
			Size = { 7.75, 4.56, 1.59 },
		},
		-- Temporada Meme 2 (fase 3). Size = art/export/creatures/_meta.json. Las ocho traen malla _Neon.
		garrobita_terenga = {
			Body = "rbxassetid://85984952060526",
			Neon = "rbxassetid://91248037031799",
			Size = { 3.48, 4.43, 3.02 },
		},
		fantasmita_bu = {
			Body = "rbxassetid://93009068219000",
			Neon = "rbxassetid://97806865714798",
			Size = { 4.43, 4.24, 3.08 },
		},
		cochinito_quincena = {
			Body = "rbxassetid://111053337333625",
			Neon = "rbxassetid://132396495718926",
			Size = { 3.84, 4.39, 4.98 },
		},
		lic_dos_peces = {
			Body = "rbxassetid://121434412376111",
			Neon = "rbxassetid://124380047885793",
			Size = { 5.35, 3.81, 1.74 },
		},
		pinovela = {
			Body = "rbxassetid://138741399499820",
			Neon = "rbxassetid://120310963507757",
			Size = { 4.11, 4.38, 2.48 },
		},
		chancla_teledirigida = {
			Body = "rbxassetid://125691517809666",
			Neon = "rbxassetid://72865701839239",
			Size = { 5.28, 4.6, 2.85 },
		},
		aurazoso = {
			Body = "rbxassetid://135043405497049",
			Neon = "rbxassetid://82104597042369",
			Size = { 4.05, 4.95, 3.4 },
		},
		abuelita_en_vivo = {
			Body = "rbxassetid://102871532133777",
			Neon = "rbxassetid://72878859865832",
			Size = { 4.36, 5.03, 2.96 },
		},
		-- Colección Random (fase 3). Las cuatro traen malla _Neon.
		caracol_turbo = {
			Body = "rbxassetid://140073852910639",
			Neon = "rbxassetid://139174579595266",
			Size = { 2.15, 3.81, 6 },
		},
		cactus_abrazos = {
			Body = "rbxassetid://98098106470554",
			Neon = "rbxassetid://88744065156126",
			Size = { 3.62, 4.06, 2.38 },
		},
		aguacaton = {
			Body = "rbxassetid://85907858953696",
			Neon = "rbxassetid://89003120225014",
			Size = { 3.74, 4.2, 2.61 },
		},
		pulpo_dj = {
			Body = "rbxassetid://109337369965333",
			Neon = "rbxassetid://84469322995136",
			Size = { 4.96, 5.74, 4.16 },
		},
	} :: { [string]: MeshRef },
}

return Assets
