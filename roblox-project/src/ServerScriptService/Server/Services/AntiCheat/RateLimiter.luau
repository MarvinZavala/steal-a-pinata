--!strict
-- Leaky bucket por jugador y por clave (patrón recomendado por Roblox; GDD §7 / WP-10).
-- local rl = RateLimiter.new(5, 2)  -- capacidad 5, se vacía 2 por segundo
-- if not rl:allow(player, "RequestSwing") then return end
local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable({} :: {
	capacity: number,
	leakPerSec: number,
	buckets: { [Player]: { [string]: { level: number, t: number } } },
}, RateLimiter))

function RateLimiter.new(capacity: number, leakPerSec: number): RateLimiter
	local self = setmetatable({ capacity = capacity, leakPerSec = leakPerSec, buckets = {} }, RateLimiter)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		self.buckets[p] = nil
	end)
	return self
end

function RateLimiter.allow(self: RateLimiter, player: Player, key: string): boolean
	local now = os.clock()
	local pb = self.buckets[player]
	if not pb then
		pb = {}
		self.buckets[player] = pb
	end
	local b = pb[key]
	if not b then
		b = { level = 0, t = now }
		pb[key] = b
	end
	b.level = math.max(0, b.level - (now - b.t) * self.leakPerSec)
	b.t = now
	if b.level + 1 > self.capacity then
		return false
	end
	b.level += 1
	return true
end

return RateLimiter
