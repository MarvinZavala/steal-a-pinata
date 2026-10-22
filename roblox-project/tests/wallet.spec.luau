--!strict
local H = require("./harness")
local Migrations = require("../src/ReplicatedStorage/Shared/Data/Migrations")
local Wallet = require("../src/ReplicatedStorage/Shared/Data/Wallet")
local Pinatas = require("../src/ReplicatedStorage/Shared/Config/Pinatas")
local Security = require("../src/ReplicatedStorage/Shared/Config/Security")
local defaults = require("./defaults")

H.begin()

local function allowed(): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for id in Pinatas do
		set[id] = true
	end
	return set
end

H.check("gastar y otorgar solo enteros positivos", function()
	local data = Migrations.migrate({}, defaults()) :: any
	H.truthy(Wallet.grant(data, "Dulces", 100, Security.MaxCurrency))
	H.eq(data.Dulces, 100)
	H.truthy(Wallet.trySpend(data, "Dulces", 40, Security.MaxCurrency))
	H.eq(data.Dulces, 60)
	H.eq(Wallet.trySpend(data, "Dulces", 1000, Security.MaxCurrency), false)
	H.eq(data.Dulces, 60)
	H.eq(Wallet.trySpend(data, "Dulces", 60, Security.MaxCurrency), true)
	H.eq(data.Dulces, 0)
	H.eq(Wallet.grant(data, "Dulces", 0, Security.MaxCurrency), false)
	H.eq(Wallet.grant(data, "Dulces", 1.5, Security.MaxCurrency), false)
	H.eq(Wallet.grant(data, "Dulces", 0 / 0, Security.MaxCurrency), false)
	H.eq(Wallet.grant(data, "Robux", 10, Security.MaxCurrency), false)
	H.eq(Wallet.grant(data, "Dulces", -5, Security.MaxCurrency), false)
	H.eq(data.Dulces, 0)
end)

H.check("la piñata entra al inventario solo si está en el roster", function()
	local data = Migrations.migrate({}, defaults()) :: any
	local roster = allowed()
	H.eq(Wallet.grantPinata(data, "no-existe", nil, "id-1", 10, Security.MaxInventory, roster), false)
	H.truthy(Wallet.grantPinata(data, "michi", "Golden", "id-1", 10, Security.MaxInventory, roster))
	H.eq(#data.Inventory, 1)
	H.eq(data.Inventory[1].Mutation, "Golden")
	H.eq(data.Dex.michi, true)
	H.eq(Wallet.grantPinata(data, "michi", nil, "id-1", 11, Security.MaxInventory, roster), false)
	H.eq(#data.Inventory, 1)
	local again = Migrations.migrate(data, defaults()) :: any
	H.eq(again.Dulces, 0)
	H.eq(again.Inventory[1].PinataId, "michi")
end)

H.check("PurchaseId solo se marca una vez", function()
	local data = Migrations.migrate({}, defaults()) :: any
	H.truthy(Wallet.markPurchase(data, "purchase-1"))
	H.eq(Wallet.markPurchase(data, "purchase-1"), false)
	H.eq(data.ProcessedPurchases["purchase-1"], true)
end)

H.finish()
