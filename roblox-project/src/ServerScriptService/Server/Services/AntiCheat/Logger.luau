--!strict
-- Log silencioso de sospechas (primer peldaño de la escalera de consecuencias, GDD §7).
local Logger = {}
local counts: { [number]: number } = {}

function Logger.flag(player: Player, reason: string, data: { [string]: any }?)
	counts[player.UserId] = (counts[player.UserId] or 0) + 1
	warn(string.format("[AC] %s (%d) %s #%d", player.Name, player.UserId, reason, counts[player.UserId]), data)
	-- TODO(WP-10): AnalyticsService:LogCustomEvent / DataStore de auditoría; umbrales para restricciones.
end

return Logger
