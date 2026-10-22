--!strict
-- WP-10b. Heurística de autoclick. El cooldown de 0.8 s lo aplica CombatService;
-- acá se cuentan los intentos, también los que el cooldown tira.
-- Clics al ritmo del cooldown no son spam. Una ráfaga por debajo de MinInterval sí.

local BatSpam = {}

export type State = { times: { number } }

export type Config = {
	WindowSec: number,
	MaxAttempts: number,
	MinIntervalSec: number,
	BurstCount: number,
}

function BatSpam.empty(): State
	return { times = {} }
end

local function trim(times: { number }, now: number, windowSec: number): { number }
	local kept: { number } = {}
	for _, at in times do
		if now - at <= windowSec then
			table.insert(kept, at)
		end
	end
	table.insert(kept, now)
	return kept
end

function BatSpam.judge(times: { number }, cfg: Config): "ok" | "spam"
	if #times >= cfg.MaxAttempts then
		return "spam"
	end
	local burst = 0
	for index = 2, #times do
		if times[index] - times[index - 1] < cfg.MinIntervalSec then
			burst += 1
		end
	end
	if burst >= cfg.BurstCount then
		return "spam"
	end
	return "ok"
end

function BatSpam.observe(state: State, now: number, cfg: Config): (State, "ok" | "spam")
	local times = trim(state.times, now, cfg.WindowSec)
	return { times = times }, BatSpam.judge(times, cfg)
end

return BatSpam
