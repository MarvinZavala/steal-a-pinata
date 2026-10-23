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
		estrellita = { Body = "rbxassetid://91837733891032", Size = { 4.44, 3.53, 2.12 } },
		pollito = { Body = "rbxassetid://103381151664768", Size = { 3.46, 3.66, 3.25 } },
		burrito = { Body = "rbxassetid://73284072914260", Size = { 2.28, 4.27, 4.62 } },
		sandia = { Body = "rbxassetid://100756169868886", Size = { 4.36, 3.56, 1.57 } },
		michi = { Body = "rbxassetid://110759221603334", Size = { 2.94, 4.1, 2.43 } },
		elotito = { Body = "rbxassetid://132059480418703", Size = { 3.26, 4.1, 2.91 } },
		ranita = { Body = "rbxassetid://100716188965664", Size = { 3.23, 4.1, 3.94 } },
		pupusita = { Body = "rbxassetid://110179690086484", Size = { 3.86, 3.93, 1.62 } },
		cohetin = {
			Body = "rbxassetid://126081045259964",
			Neon = "rbxassetid://116559400663573",
			Size = { 2.39, 4.04, 2.63 },
		},
		paleton = { Body = "rbxassetid://131465428680981", Size = { 3.09, 4.03, 1.3 } },
		tortuga = { Body = "rbxassetid://127928448861100", Size = { 2.75, 3.47, 4.7 } },
		pulpo = {
			Body = "rbxassetid://75100251137670",
			Neon = "rbxassetid://134006219453330",
			Size = { 3.99, 5.17, 3.83 },
		},
		robo = {
			Body = "rbxassetid://79755470467856",
			Neon = "rbxassetid://90739852558320",
			Size = { 3.46, 4.57, 2.54 },
		},
		dragon = {
			Body = "rbxassetid://101055935582483",
			Neon = "rbxassetid://77682646028505",
			Size = { 4.43, 4.11, 3.75 },
		},
		cadejo = { Body = "rbxassetid://139901822528479", Size = { 3.55, 3.8, 3.14 } },
		toro = {
			Body = "rbxassetid://124150643600403",
			Neon = "rbxassetid://100649555346240",
			Size = { 3.48, 3.94, 6.14 },
		},
		izalco = {
			Body = "rbxassetid://128028251302460",
			Neon = "rbxassetid://86029571312972",
			Size = { 3.55, 4.71, 3.36 },
		},
		torogoz = {
			Body = "rbxassetid://78990921018142",
			Neon = "rbxassetid://89493551989735",
			Size = { 2.82, 4.1, 3.62 },
		},
		sombra = {
			Body = "rbxassetid://100428149725094",
			Neon = "rbxassetid://138920868950383",
			Size = { 2.86, 2.72, 2.91 },
		},
		pixelin = {
			Body = "rbxassetid://111861313420111",
			Neon = "rbxassetid://111293925991661",
			Size = { 4.09, 3.97, 2.38 },
		},
		tamalito = { Body = "rbxassetid://72717162467587", Size = { 3.47, 3.57, 2.13 } },
		jengibrin = { Body = "rbxassetid://96110571543830", Size = { 4.25, 4.08, 1.9 } },
		renito = {
			Body = "rbxassetid://114810051228966",
			Neon = "rbxassetid://129185136635245",
			Size = { 2.79, 4.54, 2.67 },
		},
		-- Temporada Meme 1. Size = art/export/creatures/_meta.json. Las seis traen malla _Neon.
		michi_aplausos = {
			Body = "rbxassetid://96798412567575",
			Neon = "rbxassetid://128033039806614",
			Size = { 2.98, 4.06, 3.21 },
		},
		seis_siete = {
			Body = "rbxassetid://114997866055963",
			Neon = "rbxassetid://92150959313528",
			Size = { 6.99, 3.53, 2.03 },
		},
		manzanin_iq = {
			Body = "rbxassetid://130157664664982",
			Neon = "rbxassetid://107309229229981",
			Size = { 4.36, 3.83, 3.93 },
		},
		mapache_nel = {
			Body = "rbxassetid://126677475284322",
			Neon = "rbxassetid://83892902023591",
			Size = { 4.37, 6.02, 6.89 },
		},
		fichadito = {
			Body = "rbxassetid://100488482406724",
			Neon = "rbxassetid://86188379650627",
			Size = { 4.4, 4.94, 2.47 },
		},
		gemelos_pupusa = {
			Body = "rbxassetid://131176437892673",
			Neon = "rbxassetid://90923602378573",
			Size = { 7.75, 4.56, 1.59 },
		},
		-- Temporada Meme 2 (fase 3). Size = art/export/creatures/_meta.json. Las ocho traen malla _Neon.
		garrobita_terenga = {
			Body = "rbxassetid://106681015722083",
			Neon = "rbxassetid://91248037031799",
			Size = { 3.48, 4.43, 3.02 },
		},
		fantasmita_bu = {
			Body = "rbxassetid://134981825333259",
			Neon = "rbxassetid://84160132299612",
			Size = { 4.43, 4.24, 3.08 },
		},
		cochinito_quincena = {
			Body = "rbxassetid://113073898684563",
			Neon = "rbxassetid://132396495718926",
			Size = { 3.84, 4.39, 4.98 },
		},
		lic_dos_peces = {
			Body = "rbxassetid://113359572298996",
			Neon = "rbxassetid://124380047885793",
			Size = { 5.35, 3.81, 1.74 },
		},
		pinovela = {
			Body = "rbxassetid://80207679543626",
			Neon = "rbxassetid://88299355212209",
			Size = { 4.11, 4.38, 2.48 },
		},
		chancla_teledirigida = {
			Body = "rbxassetid://92979094633817",
			Neon = "rbxassetid://106613457802925",
			Size = { 5.28, 4.6, 2.85 },
		},
		aurazoso = {
			Body = "rbxassetid://70468156797463",
			Neon = "rbxassetid://92312405364022",
			Size = { 4.05, 4.95, 3.4 },
		},
		abuelita_en_vivo = {
			Body = "rbxassetid://120936987003767",
			Neon = "rbxassetid://137995475362908",
			Size = { 4.36, 5.03, 2.96 },
		},
		-- Colección Random (fase 3). Las cuatro traen malla _Neon.
		caracol_turbo = {
			Body = "rbxassetid://86404898213424",
			Neon = "rbxassetid://137041668862389",
			Size = { 2.15, 3.81, 6 },
		},
		cactus_abrazos = {
			Body = "rbxassetid://139807769215829",
			Neon = "rbxassetid://81998916150671",
			Size = { 3.62, 4.06, 2.38 },
		},
		aguacaton = {
			Body = "rbxassetid://134822035529796",
			Neon = "rbxassetid://89003120225014",
			Size = { 3.74, 4.2, 2.61 },
		},
		pulpo_dj = {
			Body = "rbxassetid://96129682217921",
			Neon = "rbxassetid://120095349325045",
			Size = { 4.96, 5.74, 4.16 },
		},
		-- Colección LatAm. Las 13 de Rara para arriba traen malla _Neon; las 6 comunes/poco comunes no.
		saltena_jugosa = { Body = "rbxassetid://82308743407796", Size = { 3.06, 3.27, 1.69 } },
		cucurucho_mani = { Body = "rbxassetid://126551329852404", Size = { 3.07, 4.75, 2.22 } },
		arepa_reina = { Body = "rbxassetid://108880612210616", Size = { 3.23, 3.97, 1.04 } },
		completito_italiano = { Body = "rbxassetid://120198559699765", Size = { 4.35, 2.97, 1.67 } },
		platanito_merenguero = { Body = "rbxassetid://75300139604803", Size = { 3.88, 4.49, 1.72 } },
		baleada_con_todo = { Body = "rbxassetid://136566788425042", Size = { 4.09, 3.59, 1.2 } },
		coqui_bocina = {
			Body = "rbxassetid://83279137889369",
			Neon = "rbxassetid://135414304964116",
			Size = { 3.9, 3.56, 3.33 },
		},
		matecito_termero = {
			Body = "rbxassetid://90513166160231",
			Neon = "rbxassetid://110756535834539",
			Size = { 3.67, 4.33, 2.39 },
		},
		gallo_pinton = {
			Body = "rbxassetid://71263389888826",
			Neon = "rbxassetid://81679028792343",
			Size = { 4.02, 4.27, 3.82 },
		},
		aranita_nanduti = {
			Body = "rbxassetid://84990025464204",
			Neon = "rbxassetid://110491420935936",
			Size = { 4.28, 5.33, 3.31 },
		},
		piquero_patazul = {
			Body = "rbxassetid://136396369461918",
			Neon = "rbxassetid://76039517136833",
			Size = { 4.2, 4.61, 3.25 },
		},
		alpaca_esponjada = {
			Body = "rbxassetid://114116544942741",
			Neon = "rbxassetid://116703487363346",
			Size = { 3.9, 5.32, 3.24 },
		},
		carretica_pura_vida = {
			Body = "rbxassetid://94017223298369",
			Neon = "rbxassetid://119500591071009",
			Size = { 4.1, 4.25, 3.68 },
		},
		harpia_despeinada = {
			Body = "rbxassetid://139633754054158",
			Neon = "rbxassetid://73814366562260",
			Size = { 3.6, 5.22, 2.55 },
		},
		carpincho_tranqui = {
			Body = "rbxassetid://111817875099195",
			Neon = "rbxassetid://76375855584183",
			Size = { 4.2, 4.18, 4.2 },
		},
		quetzalete = {
			Body = "rbxassetid://121503514282950",
			Neon = "rbxassetid://70991626695926",
			Size = { 4.77, 5.2, 3.72 },
		},
		chivita_rumbera = {
			Body = "rbxassetid://77293731845609",
			Neon = "rbxassetid://138091323010637",
			Size = { 3.61, 4.17, 4.68 },
		},
		boto_bailao = {
			Body = "rbxassetid://112747788562670",
			Neon = "rbxassetid://86376950548411",
			Size = { 3.8, 4.67, 3.8 },
		},
		ajolote_trajinero = {
			Body = "rbxassetid://127048131676915",
			Neon = "rbxassetid://130575076415354",
			Size = { 5, 4.89, 2.9 },
		},
	} :: { [string]: MeshRef },
}

return Assets
