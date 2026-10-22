--!strict
-- Puente al anti-cheat (WP-10a). No reimplementa Validators / RateLimiter / Logger:
-- los llama. Si S1 cambia la fórmula de ping, el gameplay la hereda.

local Server = script.Parent.Parent
local AntiCheat = Server:WaitForChild("Services"):WaitForChild("AntiCheat")

local Validators = require(AntiCheat:WaitForChild("Validators"))
local RateLimiter = require(AntiCheat:WaitForChild("RateLimiter"))
local Logger = require(AntiCheat:WaitForChild("Logger"))

local Validation = {}

local limiter = RateLimiter.new(5, 2)

function Validation.allow(player: Player, key: string): boolean
	return limiter:allow(player, key)
end

function Validation.root(player: Player): BasePart?
	return Validators.rootOf(player)
end

function Validation.inRange(player: Player, target: Vector3, maxDistance: number): boolean
	return Validators.withinDistance(player, target, maxDistance)
end

function Validation.inFront(player: Player, target: Vector3, maxAngleDeg: number): boolean
	return Validators.inFront(player, target, maxAngleDeg)
end

function Validation.isFinite(value: any): boolean
	return Validators.isFiniteNumber(value)
end

function Validation.distance(player: Player, target: Vector3): number
	local root = Validators.rootOf(player)
	if not root then
		return math.huge
	end
	return (root.Position - target).Magnitude
end

function Validation.flag(player: Player, reason: string, data: { [string]: any }?)
	Logger.flag(player, reason, data)
end

return Validation
