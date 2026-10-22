--!strict
-- Racha y misiones por día UTC (GDD §10). El día 7 del ciclo da una Épica.
-- Reclamar dos veces el mismo día no avanza la racha. Un día salteado la vuelve a 1.

local DailyRules = {}

local DAY = 86400

export type Reward = {
	Candy: number,
	PinataId: string?,
}

export type Quest = {
	id: string,
	stat: string,
	goal: number,
	candy: number,
	titleKey: string,
}

local REWARDS: { Reward } = {
	{ Candy = 800, PinataId = "estrellita" },
	{ Candy = 2000, PinataId = nil },
	{ Candy = 5000, PinataId = "michi" },
	{ Candy = 9000, PinataId = nil },
	{ Candy = 15000, PinataId = nil },
	{ Candy = 25000, PinataId = nil },
	{ Candy = 40000, PinataId = "pulpo" },
}

local POOL: { Quest } = {
	{ id = "buy", stat = "Buys", goal = 5, candy = 5000, titleKey = "daily.quest_buy" },
	{ id = "bonk", stat = "Bonks", goal = 3, candy = 3000, titleKey = "daily.quest_bonk" },
	{ id = "fiesta", stat = "FiestaCandy", goal = 10000, candy = 8000, titleKey = "daily.quest_fiesta" },
	{ id = "steal", stat = "Steals", goal = 1, candy = 6000, titleKey = "daily.quest_steal" },
	{ id = "collect", stat = "Collects", goal = 3, candy = 2500, titleKey = "daily.quest_collect" },
}

function DailyRules.dayIndex(unix: number): number
	if unix ~= unix or unix < 0 then
		return 0
	end
	return math.floor(unix / DAY)
end

function DailyRules.weekIndex(unix: number): number
	return math.floor(DailyRules.dayIndex(unix) / 7)
end

-- "already" si ese día UTC ya se reclamó. "clock" si el reloj del server fue para atrás.
function DailyRules.nextStreak(lastDay: number, streak: number, today: number): (number, string)
	if lastDay > 0 and today == lastDay then
		return streak, "already"
	end
	if today < lastDay then
		return streak, "clock"
	end
	if lastDay <= 0 then
		return 1, "start"
	end
	if today == lastDay + 1 then
		return math.max(0, streak) + 1, "continue"
	end
	return 1, "reset"
end

function DailyRules.cycleDay(streak: number): number
	if streak <= 0 then
		return 1
	end
	local index = (streak - 1) % #REWARDS
	return index + 1
end

function DailyRules.rewardForStreak(streak: number): Reward
	local index = DailyRules.cycleDay(streak)
	return REWARDS[index]
end

function DailyRules.isEpicDay(streak: number): boolean
	return DailyRules.cycleDay(streak) == #REWARDS
end

function DailyRules.board(day: number): { Quest }
	local picks: { Quest } = {}
	local used: { [number]: boolean } = {}
	local cursor = math.floor(math.abs(day) * 3) % #POOL
	local guard = 0
	while #picks < 3 and guard < 12 do
		guard += 1
		cursor = (cursor % #POOL) + 1
		if used[cursor] ~= true then
			used[cursor] = true
			table.insert(picks, POOL[cursor])
		end
	end
	return picks
end

function DailyRules.questByIndex(day: number, index: number): Quest?
	local board = DailyRules.board(day)
	return board[index]
end

return DailyRules
