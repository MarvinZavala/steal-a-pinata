--!strict
-- Misma forma que DataService.makeDefaults. Si cambian Economy o Security, los tests lo ven.
local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local Security = require("../src/ReplicatedStorage/Shared/Config/Security")

return function()
	return {
		pedestalsOwned = Economy.StartPedestals,
		vaultCapTier = 1,
		maxVaultTier = #Economy.VaultCapSeconds,
		maxPedestalSlots = Economy.MaxPedestalSlots,
		maxInventory = Security.MaxInventory,
		maxCurrency = Security.MaxCurrency,
		maxReFiestas = Security.MaxReFiestas,
	}
end
