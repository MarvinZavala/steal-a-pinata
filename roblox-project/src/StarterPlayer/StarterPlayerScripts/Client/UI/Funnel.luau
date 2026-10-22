--!strict
-- Embudo FTUE. El cliente llama AnalyticsService (funnel + custom).
-- Si Studio rechaza la llamada, igual queda en el panel de preview.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")

local history: { string } = {}
local listeners: { (string) -> () } = {}
local sessionId = ""
local warned = false

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

function Funnel.log(step: number, stepName: string, preview: boolean)
	local line = tostring(step) .. " " .. stepName
	if preview then
		line ..= " (preview)"
	end
	table.insert(history, line)
	if #history > 12 then
		table.remove(history, 1)
	end
	for _, fn in listeners do
		fn(line)
	end

	local session = Funnel.session()
	local fields = { source = if preview then "preview" else "client" }
	local ok, err = pcall(function()
		AnalyticsService:LogFunnelStepEvent("ftue_first_60", session, step, stepName, fields)
		AnalyticsService:LogCustomEvent("ftue_" .. stepName, step, fields)
	end)
	if not ok and not warned then
		warned = true
		warn("[FTUE] AnalyticsService no aceptó el evento (" .. tostring(err) .. "). Sigue en el preview.")
	end
end

function Funnel.skip(step: number)
	local ok = pcall(function()
		AnalyticsService:LogCustomEvent("ftue_skip", step, { source = "client" })
	end)
	if not ok then
		return
	end
end

return Funnel
