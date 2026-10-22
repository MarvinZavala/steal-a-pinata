--!strict
-- Nombres de los remotes de UI. Las specs viven en Payload (WP-10a):
-- Remotes.init() crea las instancias y el anti-cheat escucha los C2S.
-- Este módulo no crea RemoteEvents y no se llama desde el servidor.
-- Contrato: roblox-project/UI_INTEGRATION.md
-- No duplicar LogFunnelStepEvent en el servidor para el mismo paso.

local Payload = require(script.Parent.Payload)

local NAMES = {
	"RequestCollect",
	"RequestSettings",
	"RequestFTUEStep",
	"RequestFTUEAction",
	"RequestClaimDaily",
	"RequestClaimQuest",
	"RequestRewarded",
	"OpenShop",
}

local UIRemotes = {}

function UIRemotes.names(): { string }
	return table.clone(NAMES)
end

function UIRemotes.wired(): boolean
	for _, name in NAMES do
		if Payload.spec(name) == nil then
			return false
		end
	end
	return true
end

return UIRemotes
