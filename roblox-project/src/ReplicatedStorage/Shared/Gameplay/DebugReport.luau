--!strict
-- Texto de la vista de admin. Vive en el server (ServerStorage): el cliente no lo recibe.
-- No incluye posiciones, inventario ni el perfil. Solo liga, puntaje y el último motivo.

local DebugReport = {}

export type Row = {
	userId: number,
	name: string,
	score: number,
	response: string,
	league: string,
	power: number,
	carryLocked: boolean,
	lastReason: string,
}

export type Recent = {
	userId: number,
	playerName: string,
	reason: string,
	count: number,
}

function DebugReport.format(rows: { Row }, recent: { Recent }): string
	local ordered: { Row } = {}
	for _, row in rows do
		table.insert(ordered, row)
	end
	table.sort(ordered, function(a: Row, b: Row): boolean
		return a.userId < b.userId
	end)
	local lines = { "FairPlay (solo servidor, no se replica)" }
	if #ordered == 0 then
		table.insert(lines, "(sin jugadores con puntaje)")
	end
	for _, row in ordered do
		local lock = if row.carryLocked then "si" else "no"
		local reason = if row.lastReason ~= "" then row.lastReason else "-"
		table.insert(
			lines,
			string.format(
				"%d %s liga=%s poder=%.1f score=%.1f resp=%s lock=%s last=%s",
				row.userId,
				row.name,
				row.league,
				row.power,
				row.score,
				row.response,
				lock,
				reason
			)
		)
	end
	table.insert(lines, "-- flags --")
	local tail = #recent
	local startAt = math.max(1, tail - 11)
	for index = startAt, tail do
		local flag = recent[index]
		table.insert(lines, string.format("%d %s #%d %s", flag.userId, flag.reason, flag.count, flag.playerName))
	end
	return table.concat(lines, "\n")
end

return DebugReport
