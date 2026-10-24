--!strict
-- Contratos de estado que el HUD entiende. El servidor manda parches por StateChanged
-- (ver UI_INTEGRATION.md). Los nil no viajan en remotes: para soltar la carga se manda carrying = false.

export type OwnedPinata = {
	uid: string,
	pinataId: string,
	mutation: string,
	pedestal: number?,
}

export type CarryInfo = {
	pinataId: string,
	mutation: string,
	fromUserId: number,
	hitsLeft: number,
}

export type LockPing = {
	userId: number,
	name: string,
	remaining: number,
	cooldown: number,
}

export type Passes = {
	doubleCandy: boolean,
	vip: boolean,
	extraPedestals: boolean,
	autoCollect: boolean,
	batPack: boolean,
}

export type Settings = {
	locale: string,
	music: number,
	sfx: number,
	reduceMotion: boolean,
	cameraShake: boolean,
}

export type GameState = {
	candy: number,
	candyPerSec: number,
	bastones: number,
	owned: { OwnedPinata },
	pedestalCount: number,
	pedestalCap: number,
	vaultTier: number,
	vaultStored: number,
	carrying: CarryInfo?,
	rookieShieldRemaining: number,
	myLockRemaining: number,
	myLockCooldown: number,
	nearbyLocks: { LockPing },
	fiestaRemaining: number,
	reFiestas: number,
	passes: Passes,
	batSkin: string,
	-- ArePaidRandomItemsRestricted: la caja muestra la secuencia (boxNext) y se bloquean Suerte y Pasarela Dorada.
	paidRandomRestricted: boolean,
	boxNext: string?,
	settings: Settings,
	ftueCompleted: boolean,
	multiplier: number,
	batUpgrade: number,
	eventActive: boolean?,
	eventShop: boolean?,
	eventGift: boolean?,
	fiestaVariant: string?,
	league: string?,
	cosmetics: { [string]: boolean }?,
}

export type ShopEntry = {
	id: string,
	titleKey: string,
	bodyKey: string,
	titleArgs: { [string]: string }?,
	bodyArgs: { [string]: string }?,
	priceCandy: number?,
	priceBastones: number?,
	priceRobux: number?,
	action: string,
	owned: boolean,
	enabled: boolean,
	badgeKey: string?,
	odds: { OddsRow }?,
	-- Nota bajo las probabilidades (por defecto, la de repetidos de la Caja Sorpresa).
	oddsNoteKey: string?,
}

export type OddsRow = {
	key: string,
	percent: number,
	swatch: string,
}

return {}
