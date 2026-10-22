--!strict
local H = require("./harness")
local RateLimiter = require("../src/ServerScriptService/Server/Services/AntiCheat/RateLimiter")
local Logger = require("../src/ServerScriptService/Server/Services/AntiCheat/Logger")
local Security = require("../src/ReplicatedStorage/Shared/Config/Security")

H.begin()

H.check("100 req/s en el mismo instante se throttlean", function()
	local now = 0
	local rate = Security.Rates.RequestSwing
	H.truthy(rate.Capacity < 100, "la capacidad tiene que quedar bajo 100")
	local limiter = RateLimiter.new(rate.Capacity, rate.LeakPerSec, function()
		return now
	end)
	local player = { UserId = 42 }
	local allowed = 0
	for _ = 1, 100 do
		if limiter:allow(player, "RequestSwing") then
			allowed += 1
		end
	end
	H.eq(allowed, rate.Capacity)
	H.eq(limiter:allow(player, "RequestSwing"), false)
end)

H.check("el balde se vacía con el tiempo y no se comparte entre jugadores", function()
	local now = 0
	local limiter = RateLimiter.new(4, 2, function()
		return now
	end)
	local first = { UserId = 1 }
	local second = { UserId = 2 }
	for _ = 1, 4 do
		H.truthy(limiter:allow(first, "RequestSwing"))
	end
	H.eq(limiter:allow(first, "RequestSwing"), false)
	H.truthy(limiter:allow(second, "RequestSwing"))
	now += 1
	local recovered = 0
	for _ = 1, 10 do
		if limiter:allow(first, "RequestSwing") then
			recovered += 1
		end
	end
	H.eq(recovered, 2)
end)

H.check("olvidar al jugador reinicia su balde", function()
	local limiter = RateLimiter.new(1, 0, function()
		return 0
	end)
	local player = { UserId = 7 }
	H.truthy(limiter:allow(player, "RequestBuy"))
	H.eq(limiter:allow(player, "RequestBuy"), false)
	limiter:forgetPlayer(7)
	H.truthy(limiter:allow(player, "RequestBuy"))
end)

H.check("la escalera marca restrict sin ban", function()
	H.eq(Logger.levelFor(1, Security.FlagRestrictAt), "log")
	H.eq(Logger.levelFor(Security.FlagRestrictAt - 1, Security.FlagRestrictAt), "log")
	H.eq(Logger.levelFor(Security.FlagRestrictAt, Security.FlagRestrictAt), "restrict")
end)

H.finish()
