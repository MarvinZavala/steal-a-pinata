--!strict
-- MonetizationService (WP-11) — UserOwnsGamePassAsync cacheado, ProcessReceipt idempotente (guardar PurchaseId en el perfil ANTES de conceder).
-- Criterios de aceptación: plan/GDD.md §13.2 (WP-11).
local MonetizationService = {}

function MonetizationService.init(_services: { [string]: any })
	-- TODO(WP-11): obtener referencias a otros servicios y crear estado.
end

function MonetizationService.start()
	-- TODO(WP-11): conectar eventos/remotes y loops.
end

return MonetizationService
