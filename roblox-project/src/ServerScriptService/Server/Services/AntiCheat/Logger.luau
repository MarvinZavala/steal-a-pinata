--!strict
-- Log silencioso de sospechas (primer peldaño de la escalera, GDD §7).
-- El conteo vive en memoria de este servidor. No se escribe al perfil (un falso positivo no se arrastra).
local Logger = {}

export type Flag = {
	userId: number,
	playerName: string,
	reason: string,
	count: number,
	at: number,
}

local counts: { [number]: number } = {}
local recent: { Flag } = {}
local MAX_RECENT = 50

function Logger.levelFor(count: number, restrictAt: number): string
	if count >= restrictAt then
		return "restrict"
	end
	return "log"
end

function Logger.count(userId: number): number
	return counts[userId] or 0
end

function Logger.clear(userId: number)
	counts[userId] = nil
end

function Logger.recent(): { Flag }
	return recent
end

function Logger.flag(player: Player, reason: string, data: { [string]: any }?, countStrike: boolean?)
	local userId = player.UserId
	if countStrike ~= false then
		counts[userId] = (counts[userId] or 0) + 1
	end
	local count = counts[userId] or 0
	local entry: Flag = {
		userId = userId,
		playerName = player.Name,
		reason = reason,
		count = count,
		at = os.clock(),
	}
	table.insert(recent, entry)
	if #recent > MAX_RECENT then
		table.remove(recent, 1)
	end
	warn(string.format("[AC] %s (%d) %s #%d", player.Name, userId, reason, count), data)
end

return Logger
