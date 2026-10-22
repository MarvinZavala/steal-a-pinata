--!strict
-- Leaky bucket por jugador y por clave (patrón recomendado por Roblox; GDD §7 / WP-10).
-- local rl = RateLimiter.new(5, 2)  -- capacidad 5, se vacía 2 por segundo
-- if not rl:allow(player, "RequestSwing") then return end
-- El tercer argumento (reloj) existe para los tests. En el servidor se usa os.clock.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { level: number, t: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		capacity: number,
		leakPerSec: number,
		clock: () -> number,
		buckets: { [string]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, leakPerSec: number, clock: (() -> number)?): RateLimiter
	local self = setmetatable({
		capacity = capacity,
		leakPerSec = leakPerSec,
		clock = if clock ~= nil then clock else os.clock,
		buckets = {},
	}, RateLimiter)
	-- En Lune (tests) no hay DataModel. El límite igual funciona; solo se pierde la limpieza al salir.
	local ok, Players = pcall(function()
		return game:GetService("Players")
	end)
	if ok and Players ~= nil then
		Players.PlayerRemoving:Connect(function(player)
			self:forgetPlayer(player.UserId)
		end)
	end
	return self
end

function RateLimiter.forgetPlayer(self: RateLimiter, userId: number)
	local prefix = tostring(userId) .. ":"
	local drop: { string } = {}
	for key in self.buckets do
		if string.sub(key, 1, #prefix) == prefix then
			table.insert(drop, key)
		end
	end
	for _, key in drop do
		self.buckets[key] = nil
	end
end

local function userIdOf(player: any): number?
	if type(player) ~= "table" then
		local ok, kind = pcall(typeof, player)
		if not ok or kind ~= "Instance" then
			return nil
		end
	end
	local userId = player.UserId
	if type(userId) ~= "number" then
		return nil
	end
	return userId
end

function RateLimiter.allow(self: RateLimiter, player: any, key: string): boolean
	if type(key) ~= "string" or key == "" then
		return false
	end
	local userId = userIdOf(player)
	if userId == nil then
		return false
	end
	return self:_allow(tostring(userId) .. ":" .. key)
end

function RateLimiter._allow(self: RateLimiter, key: string): boolean
	local now = self.clock()
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { level = 0, t = now }
		self.buckets[key] = bucket
	end
	bucket.level = math.max(0, bucket.level - (now - bucket.t) * self.leakPerSec)
	bucket.t = now
	if bucket.level + 1 > self.capacity then
		return false
	end
	bucket.level += 1
	return true
end

return RateLimiter
