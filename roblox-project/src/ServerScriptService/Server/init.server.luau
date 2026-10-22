--!strict
-- Bootstrap del servidor: carga servicios en orden de dependencia (GDD §13).
local Remotes = require(game:GetService("ReplicatedStorage").Shared.Net.Remotes)
Remotes.init()

-- Server Authority (GDD §7) se activa en Studio: Workspace > Properties > Server Authority > AuthorityMode = Server.
-- Eso fuerza StreamingEnabled, SignalBehavior=Deferred, NextGenerationReplication, etc. (ver README).
if workspace.StreamingEnabled ~= true then
	warn("[Steal a Piñata] StreamingEnabled está apagado: ¿activaste AuthorityMode = Server en Workspace?")
end

local ORDER = {
	"PinataRegistry", -- WP-03
	"DataService", -- WP-02
	"AntiCheatService", -- WP-10a
	"BaseService", -- WP-04
	"ConveyorService", -- WP-05
	"StealService", -- WP-06
	"CombatService", -- WP-07
	"LockService", -- WP-08
	"EconomyService", -- WP-09
	"MonetizationService", -- WP-11
	"EventService", -- WP-14
	"DailyService", -- WP-15
	"LeagueService", -- WP-16
}

local services = {}
for _, name in ORDER do
	local mod = require(script.Services:FindFirstChild(name)) :: any
	services[name] = mod
end
for _, name in ORDER do
	if services[name].init then
		services[name].init(services)
	end
end
for _, name in ORDER do
	if services[name].start then
		task.spawn(services[name].start)
	end
end
print("[Steal a Piñata] server listo")
