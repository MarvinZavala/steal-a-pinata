--!strict
-- Qué muestra cada kiosco. Los precios de pedestal salen de Economy.
-- Los topes de Dulcería no tienen precio en Economy todavía: DEFAULT_VAULT_COST es provisional
-- y se reemplaza solo si aparece Economy.VaultUpgradeCost (WP-09).

local Economy = require(script.Parent.Parent.Config.Economy)
local Monetization = require(script.Parent.Parent.Config.Monetization)
local Pinatas = require(script.Parent.Parent.Config.Pinatas)
local Types = require(script.Parent.Types)

export type ShopEntry = Types.ShopEntry

local DEFAULT_VAULT_COST: { [number]: number } = {
	[2] = 2500,
	[3] = 15000,
	[4] = 80000,
}

local REFIESTA_CANDY = 500000

local BOX_ODDS: { Types.OddsRow } = {
	{ key = "shop.odds_trail", percent = 50, swatch = "lime" },
	{ key = "shop.odds_ribbon", percent = 25, swatch = "fiesta_pink" },
	{ key = "shop.odds_decor", percent = 15, swatch = "turquoise" },
	{ key = "shop.odds_pedestal", percent = 8, swatch = "grape" },
	{ key = "shop.odds_bat", percent = 2, swatch = "gold" },
}

local ShopCatalog = {}

function ShopCatalog.kiosks(): { string }
	return { "dulceria", "bates", "cajas", "vip" }
end

function ShopCatalog.pedestalPrice(nextIndex: number): number
	local step = nextIndex - Economy.StartPedestals
	if step < 1 then
		step = 1
	end
	local raw = Economy.PedestalCostBase * (Economy.PedestalCostGrowth ^ (step - 1))
	return math.floor(raw + 0.5)
end

function ShopCatalog.vaultCost(tier: number): number
	local extra = Economy :: any
	local fromDesign = extra.VaultUpgradeCost
	if typeof(fromDesign) == "table" and typeof(fromDesign[tier]) == "number" then
		return fromDesign[tier]
	end
	return DEFAULT_VAULT_COST[tier] or 0
end

function ShopCatalog.refiestaCandy(): number
	local extra = Economy :: any
	if typeof(extra.ReFiestaCandy) == "number" then
		return extra.ReFiestaCandy
	end
	return REFIESTA_CANDY
end

local function countSpecies(owned: { Types.OwnedPinata }, pinataId: string): number
	local total = 0
	for _, item in owned do
		if item.pinataId == pinataId then
			total += 1
		end
	end
	return total
end

local function resolvedCap(state: Types.GameState): number
	local cap = state.pedestalCap
	if cap < Economy.MaxPedestals then
		cap = Economy.MaxPedestals
	end
	-- Un server viejo manda 8. El pase suma 2 solo en ese caso, y Re-Fiesta 3 abre el piso.
	if state.passes.extraPedestals and cap <= Economy.MaxPedestals then
		cap += Economy.ExtraPedestals
	end
	if state.reFiestas >= Economy.ReFiestaFloorAt then
		cap = Economy.MaxPedestalSlots
	end
	if cap > Economy.MaxPedestalSlots then
		cap = Economy.MaxPedestalSlots
	end
	return cap
end

local function countRank(owned: { Types.OwnedPinata }, rarity: string): number
	local need = Economy.rarityRank(rarity)
	local total = 0
	for _, item in owned do
		local def = Pinatas[item.pinataId]
		if def ~= nil and Economy.rarityRank(def.Rarity) >= need and need > 0 then
			total += 1
		end
	end
	return total
end

local function dulceria(state: Types.GameState): { ShopEntry }
	local list: { ShopEntry } = {}
	local cap = resolvedCap(state)
	local nextIndex = state.pedestalCount + 1
	if nextIndex <= cap then
		local price = ShopCatalog.pedestalPrice(nextIndex)
		table.insert(list, {
			id = "Pedestal",
			titleKey = "shop.pedestal_title",
			bodyKey = "shop.pedestal_body",
			titleArgs = { n = tostring(nextIndex) },
			priceCandy = price,
			action = "upgrade",
			owned = false,
			enabled = state.candy >= price,
		})
	else
		table.insert(list, {
			id = "pedestal:max",
			titleKey = "shop.pedestal_title",
			bodyKey = "common.max",
			titleArgs = { n = tostring(state.pedestalCount) },
			action = "info",
			owned = true,
			enabled = false,
		})
	end

	local tiers = Economy.VaultCapSeconds
	local currentTier = math.clamp(state.vaultTier, 1, #tiers)
	if currentTier < #tiers then
		local nextTier = currentTier + 1
		local minutes = math.floor(tiers[nextTier] / 60)
		local price = ShopCatalog.vaultCost(nextTier)
		table.insert(list, {
			id = "VaultCap",
			titleKey = "shop.vault_title",
			bodyKey = "shop.vault_body",
			titleArgs = { min = tostring(minutes) },
			priceCandy = price,
			action = "upgrade",
			owned = false,
			enabled = state.candy >= price,
		})
	end

	local offer = Economy.refiestaOffer(state.reFiestas + 1)
	local ready = countRank(state.owned, offer.Rarity) >= offer.Count and state.candy >= offer.Candy
	table.insert(list, {
		id = "ReFiesta",
		titleKey = "shop.refiesta_title",
		bodyKey = if ready then "shop.refiesta_body" else "shop.refiesta_need",
		bodyArgs = {
			count = tostring(offer.Count),
			rarityKey = "rarity." .. offer.Rarity,
			n = tostring(offer.Candy),
		},
		priceCandy = offer.Candy,
		action = "upgrade",
		owned = false,
		enabled = ready,
	})
	return list
end

local function bates(state: Types.GameState): { ShopEntry }
	local stun = string.format("%.1f", Economy.Bat.StunSec)
	local cd = string.format("%.1f", Economy.Bat.CooldownSec)
	local pack = Monetization.GamePasses.BatSkinPack
	local list: { ShopEntry } = {
		{
			id = "bat:wood",
			titleKey = "shop.bat_wood_title",
			bodyKey = "shop.bat_wood_body",
			bodyArgs = { stun = stun, cd = cd },
			action = "info",
			owned = state.batSkin == "wood" or state.batSkin == "",
			enabled = false,
			badgeKey = "common.equipped",
		},
		{
			id = "Bat",
			titleKey = "shop.bat_upgrade_title",
			bodyKey = if Economy.batUpgradeCost(state.batUpgrade + 1) > 0
				then "shop.bat_upgrade_body"
				else "common.max",
			priceCandy = Economy.batUpgradeCost(state.batUpgrade + 1),
			action = "upgrade",
			owned = Economy.batUpgradeCost(state.batUpgrade + 1) <= 0,
			enabled = Economy.batUpgradeCost(state.batUpgrade + 1) > 0
				and state.candy >= Economy.batUpgradeCost(state.batUpgrade + 1),
		},
		{
			id = "pass:BatSkinPack",
			titleKey = "shop.bat_pack_title",
			bodyKey = "shop.bat_pack_body",
			priceRobux = pack.Price,
			action = "pass",
			owned = state.passes.batPack,
			enabled = not state.passes.batPack and pack.Id ~= 0,
			badgeKey = if pack.Id == 0 then "common.soon" else nil,
		},
		{
			id = "skin:gold",
			titleKey = "shop.bat_gold",
			bodyKey = "shop.cosmetic_only",
			action = "info",
			owned = state.batSkin == "gold",
			enabled = false,
		},
		{
			id = "skin:fiesta",
			titleKey = "shop.bat_fiesta",
			bodyKey = "shop.cosmetic_only",
			action = "info",
			owned = state.batSkin == "fiesta",
			enabled = false,
		},
		{
			id = "skin:ribbon",
			titleKey = "shop.bat_ribbon",
			bodyKey = "shop.cosmetic_only",
			action = "info",
			owned = state.batSkin == "ribbon",
			enabled = false,
		},
	}
	return list
end

local function cajas(state: Types.GameState): { ShopEntry }
	local box = Monetization.Products.SurpriseBox
	local list: { ShopEntry } = {
		{
			id = "product:SurpriseBox",
			titleKey = "shop.box_title",
			bodyKey = "shop.box_body",
			priceRobux = box.Price,
			action = "product",
			owned = false,
			enabled = box.Id ~= 0,
			badgeKey = if box.Id == 0 then "common.soon" else "shop.odds_title",
			odds = BOX_ODDS,
		},
	}
	local seen: { [string]: boolean } = {}
	for _, item in state.owned do
		if not seen[item.pinataId] and countSpecies(state.owned, item.pinataId) >= 3 then
			seen[item.pinataId] = true
			table.insert(list, {
				id = "fuse:" .. item.pinataId,
				titleKey = "shop.fuse_title",
				bodyKey = "shop.fuse_body",
				titleArgs = { name = item.pinataId },
				action = "fuse",
				owned = false,
				enabled = true,
			})
		end
	end
	if next(seen) == nil then
		table.insert(list, {
			id = "fuse:empty",
			titleKey = "shop.fuse_title",
			bodyKey = "shop.fuse_empty",
			titleArgs = { name = "×3" },
			action = "info",
			owned = false,
			enabled = false,
		})
	end
	return list
end

local function vip(state: Types.GameState): { ShopEntry }
	local passes = Monetization.GamePasses
	local products = Monetization.Products
	local function passEntry(
		id: string,
		titleKey: string,
		bodyKey: string,
		price: number,
		productId: number,
		owned: boolean
	): ShopEntry
		return {
			id = "pass:" .. id,
			titleKey = titleKey,
			bodyKey = bodyKey,
			priceRobux = price,
			action = "pass",
			owned = owned,
			enabled = not owned and productId ~= 0,
			badgeKey = if productId == 0 then "common.soon" else nil,
		}
	end
	local function productEntry(
		id: string,
		titleKey: string,
		bodyKey: string,
		price: number,
		productId: number,
		bodyArgs: { [string]: string }?,
		badgeKey: string?
	): ShopEntry
		return {
			id = "product:" .. id,
			titleKey = titleKey,
			bodyKey = bodyKey,
			bodyArgs = bodyArgs,
			priceRobux = price,
			action = "product",
			owned = false,
			enabled = productId ~= 0,
			badgeKey = if productId == 0 then "common.soon" else badgeKey,
		}
	end

	return {
		passEntry(
			"DoubleCandy",
			"shop.pass_double",
			"shop.pass_double_body",
			passes.DoubleCandy.Price,
			passes.DoubleCandy.Id,
			state.passes.doubleCandy
		),
		passEntry(
			"VipFiesta",
			"shop.pass_vip",
			"shop.pass_vip_body",
			passes.VipFiesta.Price,
			passes.VipFiesta.Id,
			state.passes.vip
		),
		passEntry(
			"ExtraPedestals",
			"shop.pass_pedestals",
			"shop.pass_pedestals_body",
			passes.ExtraPedestals.Price,
			passes.ExtraPedestals.Id,
			state.passes.extraPedestals
		),
		passEntry(
			"AutoCollect",
			"shop.pass_auto",
			"shop.pass_auto_body",
			passes.AutoCollect.Price,
			passes.AutoCollect.Id,
			state.passes.autoCollect
		),
		productEntry(
			"ServerLuck2x",
			"shop.prod_luck",
			"shop.prod_luck_body",
			products.ServerLuck2x.Price,
			products.ServerLuck2x.Id,
			nil,
			"shop.social"
		),
		productEntry(
			"GoldenConveyor",
			"shop.prod_golden",
			"shop.prod_golden_body",
			products.GoldenConveyor.Price,
			products.GoldenConveyor.Id,
			nil,
			"shop.social"
		),
		productEntry(
			"CandyPackS",
			"shop.prod_candy_s",
			"shop.prod_candy_body",
			products.CandyPackS.Price,
			products.CandyPackS.Id,
			{ min = tostring(products.CandyPackS.Minutes) }
		),
		productEntry(
			"CandyPackM",
			"shop.prod_candy_m",
			"shop.prod_candy_body",
			products.CandyPackM.Price,
			products.CandyPackM.Id,
			{ min = tostring(products.CandyPackM.Minutes) }
		),
		productEntry(
			"CandyPackL",
			"shop.prod_candy_l",
			"shop.prod_candy_body",
			products.CandyPackL.Price,
			products.CandyPackL.Id,
			{ min = tostring(products.CandyPackL.Minutes) }
		),
		productEntry(
			"EmergencyLock",
			"shop.prod_lock",
			"shop.prod_lock_body",
			products.EmergencyLock.Price,
			products.EmergencyLock.Id
		),
		{
			id = "private",
			titleKey = "shop.private_title",
			bodyKey = "shop.private_body",
			bodyArgs = { n = tostring(Monetization.PrivateServerPrice) },
			action = "info",
			owned = false,
			enabled = false,
		},
		{
			id = "subscription",
			titleKey = "shop.sub_title",
			bodyKey = "shop.sub_body",
			priceRobux = Monetization.Subscription.Price,
			action = "subscription",
			owned = false,
			enabled = Monetization.Subscription.Id ~= "",
			badgeKey = if Monetization.Subscription.Id == "" then "common.soon" else nil,
		},
		{
			id = "rewarded",
			titleKey = "shop.rewarded_title",
			bodyKey = "shop.rewarded_body",
			action = "rewarded",
			owned = false,
			enabled = true,
		},
		productEntry(
			"CosmeticTrail",
			"shop.cosmetic_trail",
			"shop.cosmetic_only",
			products.CosmeticTrail.Price,
			products.CosmeticTrail.Id
		),
		productEntry(
			"CosmeticBat",
			"shop.cosmetic_bat",
			"shop.cosmetic_only",
			products.CosmeticBat.Price,
			products.CosmeticBat.Id
		),
	}
end

function ShopCatalog.entries(kiosk: string, state: Types.GameState): { ShopEntry }
	if kiosk == "dulceria" then
		return dulceria(state)
	elseif kiosk == "bates" then
		return bates(state)
	elseif kiosk == "cajas" then
		return cajas(state)
	elseif kiosk == "vip" then
		return vip(state)
	end
	return {}
end

function ShopCatalog.blurb(kiosk: string): string
	return "shop.blurb_" .. kiosk
end

function ShopCatalog.title(kiosk: string): string
	return "shop.kiosk_" .. kiosk
end

function ShopCatalog.productId(action: string, id: string): number
	local key = string.split(id, ":")[2]
	if action == "pass" then
		if key == "DoubleCandy" then
			return Monetization.GamePasses.DoubleCandy.Id
		elseif key == "VipFiesta" then
			return Monetization.GamePasses.VipFiesta.Id
		elseif key == "ExtraPedestals" then
			return Monetization.GamePasses.ExtraPedestals.Id
		elseif key == "AutoCollect" then
			return Monetization.GamePasses.AutoCollect.Id
		elseif key == "BatSkinPack" then
			return Monetization.GamePasses.BatSkinPack.Id
		end
	elseif action == "product" then
		if key == "ServerLuck2x" then
			return Monetization.Products.ServerLuck2x.Id
		elseif key == "GoldenConveyor" then
			return Monetization.Products.GoldenConveyor.Id
		elseif key == "SurpriseBox" then
			return Monetization.Products.SurpriseBox.Id
		elseif key == "CandyPackS" then
			return Monetization.Products.CandyPackS.Id
		elseif key == "CandyPackM" then
			return Monetization.Products.CandyPackM.Id
		elseif key == "CandyPackL" then
			return Monetization.Products.CandyPackL.Id
		elseif key == "EmergencyLock" then
			return Monetization.Products.EmergencyLock.Id
		elseif key == "CosmeticTrail" then
			return Monetization.Products.CosmeticTrail.Id
		elseif key == "CosmeticRibbon" then
			return Monetization.Products.CosmeticRibbon.Id
		elseif key == "CosmeticDecor" then
			return Monetization.Products.CosmeticDecor.Id
		elseif key == "CosmeticPedestal" then
			return Monetization.Products.CosmeticPedestal.Id
		elseif key == "CosmeticBat" then
			return Monetization.Products.CosmeticBat.Id
		elseif key == "RewardedBoost" then
			return Monetization.Products.RewardedBoost.Id
		end
	end
	return 0
end

return ShopCatalog
