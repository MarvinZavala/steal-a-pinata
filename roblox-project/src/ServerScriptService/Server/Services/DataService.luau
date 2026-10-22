--!strict
-- DataService (WP-02) — ProfileStore: StartSessionAsync al entrar, EndSession al salir, esquema v1 + migraciones.
-- Criterios de aceptación: plan/GDD.md §13.2 (WP-02).
local DataService = {}

function DataService.init(_services: { [string]: any })
	-- TODO(WP-02): obtener referencias a otros servicios y crear estado.
end

function DataService.start()
	-- TODO(WP-02): conectar eventos/remotes y loops.
end

return DataService
