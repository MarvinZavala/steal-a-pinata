--!strict
-- Dónde va el arte importado de la plaza (ServerStorage/Templates/Lobby). Coordenadas de Roblox, en studs.
-- El layout de juego manda (WorldLayout: plaza redonda, kioscos a 155/115/65/25°, Pasarela en z = -52);
-- esto solo lo viste. art/scripts/lobby.py → scene() es la referencia de estilo (render lobby_hub.png).
export type Prop = {
	name: string,
	x: number,
	z: number,
	yaw: number?, -- grados; sin yaw y con faceCenter, mira a la fuente
	faceCenter: boolean?,
	scale: number?,
}

local LobbyArt = {
	-- Centro de cada tienda: a este radio los cuatro frentes (25 de ancho) no se tocan y miran a la fuente.
	ShopRadius = 48,
	-- El kiosco (ProximityPrompt de la tienda) queda delante de la puerta.
	KioskInset = 2,
	Shops = {
		dulceria = "lobby_shop_dulceria",
		bates = "lobby_shop_bates",
		cajas = "lobby_shop_cajas",
		vip = "lobby_shop_vip",
	} :: { [string]: string },
	Fountain = "lobby_fountain",
	-- Estrellita gigante sobre la fuente (con sus colores: queda más fiestera que la versión dorada del render).
	Statue = { Pinata = "estrellita", Scale = 2.4 },
	-- Cartel "LA PLAZA" sobre la estatua (px del BillboardGui y distancia en studs).
	HubSign = { Width = 140, MaxDistance = 90 },
	-- Bases (ServerStorage/Templates/Base). Las paredes de PlaceBuilder quedan como muros invisibles.
	Base = {
		Floor = "base_floor",
		Gate = "base_gate",
		Generator = "base_generator",
		Fence = "base_fence",
		Pedestal = "base_pedestal",
		FenceInset = 0.5, -- la cerca va apenas adentro del borde del piso
		PadDisc = 0.12, -- el pad de color (abierto/cerrado) queda como un disco fino sobre el pedestal
	},
	-- Con el arte puesto, el pasto y la plaza dejan el plástico liso (render: pasto con ruido y baldosa de barro).
	Ground = { Material = Enum.Material.Grass, Color = Color3.fromHex("#5DBE52") },
	Plaza = { Material = Enum.Material.Brick, Color = Color3.fromHex("#F7D9B0") },
	Fabrica = "lobby_fabrica_gate",
	PasarelaSegment = "lobby_pasarela_seg",
	Lamp = "lobby_lamp",
	Props = {
		-- Maceteros entre las puertas de las tiendas y a los costados de la fuente.
		{ name = "lobby_planter", x = 31.5, z = 0 },
		{ name = "lobby_planter", x = 22.3, z = 22.3 },
		{ name = "lobby_planter", x = 0, z = 31.5 },
		{ name = "lobby_planter", x = -22.3, z = 22.3 },
		{ name = "lobby_planter", x = -31.5, z = 0 },
		-- Bancas alrededor de la fuente, mirándola.
		{ name = "lobby_bench", x = 21, z = 0, faceCenter = true },
		{ name = "lobby_bench", x = -21, z = 0, faceCenter = true },
		{ name = "lobby_bench", x = 0, z = 21, faceCenter = true },
		-- Carritos de dulces del lado de la Pasarela (como en el render).
		{ name = "lobby_candy_cart", x = 33, z = -26, faceCenter = true },
		{ name = "lobby_candy_cart", x = -33, z = -26, faceCenter = true },
		-- Palmeras en las esquinas de la Pasarela, fuera de la plaza.
		{ name = "lobby_palm", x = 56, z = -36, yaw = 200, scale = 1.05 },
		{ name = "lobby_palm", x = -56, z = -36, yaw = 40, scale = 1.05 },
	} :: { Prop },
}

return LobbyArt
