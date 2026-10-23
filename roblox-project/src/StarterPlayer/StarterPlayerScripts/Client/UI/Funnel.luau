--!strict
-- Historial del embudo FTUE para el panel de preview. El evento de analytics lo
-- registra el servidor al recibir RequestFTUEStep (UiIntentService): AnalyticsService
-- pide el Player y no funciona desde el cliente.

local HttpService = game:GetService("HttpService")

local history: { string } = {}
local listeners: { (string) -> () } = {}
local sessionId = ""

local Funnel = {}

function Funnel.session(): string
	if sessionId == "" then
		sessionId = HttpService:GenerateGUID(false)
	end
	return sessionId
end

function Funnel.resetSession()
	sessionId = HttpService:GenerateGUID(false)
end

function Funnel.history(): { string }
	return history
end

function Funnel.onLogged(fn: (string) -> ())
	table.insert(listeners, fn)
end

local function push(line: string)
	table.insert(history, line)
	if #history > 12 then
		table.remove(history, 1)
	end
	for _, fn in listeners do
		fn(line)
	end
end

function Funnel.log(step: number, stepName: string, preview: boolean)
	local line = tostring(step) .. " " .. stepName
	if preview then
		line ..= " (preview)"
	end
	push(line)
end

function Funnel.skip(step: number)
	push(tostring(step) .. " skip")
end

return Funnel
