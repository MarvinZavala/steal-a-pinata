--!strict
-- Orden de salida. El handler lee la lista en el momento del evento,
-- así los servicios que inician después igual alcanzan a registrarse.

local Players = game:GetService("Players")

local Lifecycle = {}

type Hook = { priority: number, fn: (Player) -> () }

local hooks: { Hook } = {}
local installed = false

function Lifecycle.onLeave(priority: number, fn: (Player) -> ())
	table.insert(hooks, { priority = priority, fn = fn })
end

function Lifecycle.install()
	if installed then
		return
	end
	installed = true
	Players.PlayerRemoving:Connect(function(player)
		local ordered: { Hook } = {}
		for _, hook in hooks do
			table.insert(ordered, hook)
		end
		table.sort(ordered, function(a, b)
			return a.priority < b.priority
		end)
		for _, hook in ordered do
			hook.fn(player)
		end
	end)
end

return Lifecycle
