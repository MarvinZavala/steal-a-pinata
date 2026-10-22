--!strict
local H = require("./harness")
local Payload = require("../src/ReplicatedStorage/Shared/Net/Payload")
local Pinatas = require("../src/ReplicatedStorage/Shared/Config/Pinatas")
local Security = require("../src/ReplicatedStorage/Shared/Config/Security")
local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")

H.begin()

local HONEYPOTS = { "RequestGrantCurrency", "RequestSetWalkSpeed", "AdminGivePinata" }

local function passes(name: string, args: { any })
	local ok, reason = Payload.validate(name, args, Security, Pinatas)
	H.eq(reason, nil, name)
	H.eq(ok, true, name)
end

H.check("intenciones válidas pasan y los señuelos no", function()
	passes("RequestBuy", { 4 })
	passes("RequestSteal", { 15, 2 })
	passes("RequestSteal", { -2, 1 })
	passes("RequestSwing", {})
	passes("RequestLock", {})
	passes("RequestUpgrade", { "Pedestal" })
	passes("RequestFuse", { "michi" })
	local honeypotOk, honeypotReason = Payload.validate("RequestGrantCurrency", { 100 }, Security, Pinatas)
	H.eq(honeypotOk, false)
	H.eq(honeypotReason, "honeypot")
	local directionOk, directionReason = Payload.validate("StateChanged", {}, Security, Pinatas)
	H.eq(directionOk, false)
	H.eq(directionReason, "direction")
end)

H.check("el cliente no puede mandar moneda ni un robo a 0", function()
	local currencyOk, currencyReason = Payload.validate("RequestSwing", { Dulces = 999999 }, Security, Pinatas)
	H.eq(currencyOk, false)
	H.eq(currencyReason, "client_currency")
	local nested = { 1 }
	local extra = {}
	extra.Inventory = {}
	nested.extra = extra
	local nestedOk, nestedReason = Payload.validate("RequestBuy", nested, Security, Pinatas)
	H.eq(nestedOk, false)
	H.eq(nestedReason, "client_currency")
	local userOk, userReason = Payload.validate("RequestSteal", { 0, 1 }, Security, Pinatas)
	H.eq(userOk, false)
	H.eq(userReason, "user")
	local fuseOk, fuseReason = Payload.validate("RequestFuse", { "AdminGive" }, Security, Pinatas)
	H.eq(fuseOk, false)
	H.eq(fuseReason, "enum")
end)

H.check("fuzz de tipos y valores basura no tira", function()
	local mixed = { 1 }
	mixed.Bastones = 1
	local walk = {}
	walk.WalkSpeed = 100
	local garbage = {
		nil,
		1.5,
		math.huge,
		0 / 0,
		"",
		"x",
		string.rep("a", 5000),
		{ true },
		{ "nope" },
		{ 1, 2, 3, 4, 5 },
		{ Dulces = 999 },
		mixed,
		{ walk },
	}
	for _, name in Payload.names() do
		local spec = Payload.spec(name)
		if spec ~= nil and spec.Direction == "C2S" and not spec.Honeypot then
			for _, sample in garbage do
				local ok, reason = Payload.validateSafe(name, sample, Security, Pinatas)
				H.eq(type(ok), "boolean", name)
				H.eq(ok, false, name .. " " .. tostring(reason))
				H.eq(reason == "threw", false, name)
			end
		end
	end
	for _, name in HONEYPOTS do
		local ok, reason = Payload.validateSafe(name, { Dulces = 1 }, Security, Pinatas)
		H.eq(ok, false)
		H.eq(reason, "honeypot")
	end
	local trap = setmetatable({}, {
		__iter = function()
			error("boom")
		end,
	})
	local trapOk, trapReason = Payload.validateSafe("RequestBuy", trap, Security, Pinatas)
	H.eq(trapOk, false)
	H.truthy(trapReason ~= nil)
end)

H.check("cada remote de juego tiene rate y el pedestal coincide con Economy", function()
	H.eq(Security.Bounds.Pedestal.Max, Economy.MaxPedestalSlots)
	for _, name in HONEYPOTS do
		local spec = Payload.spec(name)
		H.truthy(spec)
		H.eq(spec.Honeypot, true)
	end
	for _, name in Payload.names() do
		local spec = Payload.spec(name)
		if spec ~= nil and spec.Direction == "C2S" and not spec.Honeypot then
			H.truthy((Security.Rates :: any)[name], name)
		end
	end
end)

H.check("la UI entra por el mismo catálogo", function()
	passes("RequestCollect", {})
	passes("RequestSettings", { "auto", 0.8, 0, true, false })
	passes("RequestSettings", { "es", 1, 0.25, false, true })
	passes("RequestFTUEStep", { "5_first_bonk" })
	passes("RequestFTUEAction", { "claim" })
	local stepOk, stepReason = Payload.validate("RequestFTUEStep", { "ftue_skip" }, Security, Pinatas)
	H.eq(stepOk, false)
	H.eq(stepReason, "enum")
	local localeOk, localeReason = Payload.validate("RequestSettings", { "", 0.8, 0.8, true, true }, Security, Pinatas)
	H.eq(localeOk, false)
	H.eq(localeReason, "length")
	local unitOk, unitReason = Payload.validate("RequestSettings", { "en", 1.2, 0.5, false, true }, Security, Pinatas)
	H.eq(unitOk, false)
	H.eq(unitReason, "range")
	local shopOk, shopReason = Payload.validate("OpenShop", { "dulceria" }, Security, Pinatas)
	H.eq(shopOk, false)
	H.eq(shopReason, "direction")
	local shop = Payload.spec("OpenShop")
	H.truthy(shop)
	H.eq(shop.Direction, "S2C")
end)

H.finish()
