--!strict
-- Posadas Piñateras por fecha UTC (GDD §11). Puro: el servicio pasa el unix y el override.
-- La ventana publicada es 4 dic 2026 00:00 UTC inclusive hasta 7 ene 2027 00:00 UTC exclusive
-- (el 6 de enero todavía juega; los Bastones se convierten al empezar el 7).

local Events = if typeof(script) == "Instance"
	then require(script.Parent.Parent.Config.Events)
	else require("../Config/Events")

local EventCalendar = {}

export type Snapshot = {
	active: boolean,
	phase: string,
	decor: boolean,
	parade: boolean,
	runway: boolean,
	shop: boolean,
	mutation: boolean,
	gift: boolean,
	advent: boolean,
	convert: boolean,
	fiestaVariant: string,
	forced: boolean,
}

export type AdventReward = {
	bastones: number,
	pinataId: string?,
	finale: boolean,
}

export type EventQuest = {
	id: string,
	stat: string,
	goal: number,
	bastones: number,
	titleKey: string,
}

local function config()
	return Events.PosadasPinateras
end

function EventCalendar.isForced(attribute: any): boolean
	if Events.ForceActive == true then
		return true
	end
	return attribute == true
end

-- Día civil UTC. Algoritmo de Howard Hinnant (días desde 1970-01-01).
function EventCalendar.ymd(unix: number): (number, number, number)
	local z = math.floor(unix / 86400) + 719468
	local era = if z >= 0 then z // 146097 else (z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	if m <= 2 then
		y += 1
	end
	return y, m, d
end

local function phaseAt(unix: number): string
	local c = config()
	if unix < c.StartUnix or unix >= c.EndUnix then
		return "off"
	end
	if unix >= c.ReyesUnix then
		return "reyes"
	end
	if unix >= c.NewYearUnix and unix < c.NewYearEndUnix then
		return "newyear"
	end
	if unix >= c.NavidadUnix and unix < c.NavidadEndUnix then
		return "navidad"
	end
	if unix >= c.PosadasUnix then
		return "posadas"
	end
	return "soft"
end

local function sampleUnix(phase: string): number
	local c = config()
	if phase == "soft" then
		return c.StartUnix
	elseif phase == "navidad" then
		return c.NavidadUnix
	elseif phase == "newyear" then
		return c.NewYearUnix
	elseif phase == "reyes" then
		return c.ReyesUnix
	end
	return c.PosadasUnix
end

local function paint(unix: number, forced: boolean): Snapshot
	local c = config()
	local phase = phaseAt(unix)
	local shop = phase == "posadas" or phase == "navidad" or phase == "newyear" or phase == "reyes"
	local variant = "fiesta"
	if phase == "posadas" or phase == "navidad" then
		variant = "posada"
	elseif phase == "newyear" then
		variant = "newyear"
	elseif phase == "reyes" then
		variant = "rosca"
	end
	local active = phase ~= "off"
	return {
		active = active,
		phase = phase,
		decor = active,
		parade = shop,
		runway = active,
		shop = shop,
		mutation = phase == "navidad",
		gift = phase == "navidad",
		advent = active and unix >= c.PosadasUnix and unix < c.AdventEndUnix,
		convert = not forced and unix >= c.EndUnix,
		fiestaVariant = variant,
		forced = forced,
	}
end

function EventCalendar.snapshot(unix: number, force: boolean?, phaseOverride: string?): Snapshot
	local forced = force == true
	local real = phaseAt(unix)
	if forced and real == "off" then
		local phase = if type(phaseOverride) == "string" and phaseOverride ~= ""
			then phaseOverride
			else Events.ForcePhase
		if
			phase ~= "soft"
			and phase ~= "posadas"
			and phase ~= "navidad"
			and phase ~= "newyear"
			and phase ~= "reyes"
		then
			phase = "posadas"
		end
		local snap = paint(sampleUnix(phase), true)
		snap.forced = true
		snap.convert = false
		return snap
	end
	local snap = paint(unix, forced)
	if forced then
		snap.convert = false
	end
	return snap
end

function EventCalendar.runwayHit(snap: Snapshot, roll01: number): boolean
	if not snap.runway then
		return false
	end
	return roll01 < config().RunwayChance
end

function EventCalendar.mutationHit(snap: Snapshot, roll01: number): boolean
	if not snap.mutation then
		return false
	end
	return roll01 < config().ChristmasMutationChance
end

function EventCalendar.adventBit(day: number): number
	local c = config()
	local shift = day - c.AdventFirstDay
	if shift < 0 or shift > 30 then
		return 0
	end
	return bit32.lshift(1, shift)
end

function EventCalendar.missesBefore(mask: number, day: number): number
	local c = config()
	local prior = day - c.AdventFirstDay
	if prior <= 0 then
		return 0
	end
	local claimed = 0
	for index = 0, prior - 1 do
		if bit32.band(mask, bit32.lshift(1, index)) ~= 0 then
			claimed += 1
		end
	end
	return prior - claimed
end

function EventCalendar.adventDay(unix: number, snap: Snapshot): number?
	if not snap.advent then
		return nil
	end
	local real = EventCalendar.snapshot(unix, false)
	if snap.forced and not real.active then
		if snap.phase == "navidad" then
			return config().AdventFinaleDay
		end
		return config().AdventFirstDay
	end
	local year, month, day = EventCalendar.ymd(unix)
	local c = config()
	if year == 2026 and month == 12 and day >= c.AdventFirstDay and day <= c.AdventFinaleDay then
		return day
	end
	return nil
end

function EventCalendar.adventReward(day: number, misses: number): AdventReward
	local c = config()
	if day == c.AdventFinaleDay and misses <= c.AdventMaxMisses then
		return { bastones = c.AdventFinaleBonus, pinataId = c.AdventFinalePinata, finale = true }
	end
	if day == c.AdventFinaleDay then
		return { bastones = c.AdventFinaleBastones, pinataId = nil, finale = true }
	end
	local step = day - c.AdventFirstDay
	if step < 0 then
		step = 0
	end
	return { bastones = c.AdventBastonesBase + step * c.AdventBastonesStep, pinataId = nil, finale = false }
end

function EventCalendar.quests(): { EventQuest }
	local list: { EventQuest } = {}
	for _, row in config().Quests do
		table.insert(list, {
			id = row.id,
			stat = row.stat,
			goal = row.goal,
			bastones = row.bastones,
			titleKey = row.titleKey,
		})
	end
	return list
end

function EventCalendar.questById(id: string): EventQuest?
	for _, quest in EventCalendar.quests() do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

function EventCalendar.questBit(index: number): number
	if index < 1 or index > 8 then
		return 0
	end
	return bit32.lshift(1, index - 1)
end

function EventCalendar.applySettle(
	data: any,
	unix: number,
	force: boolean,
	maxCurrency: number,
	phaseOverride: string?
): (boolean, number)
	if type(data) ~= "table" then
		return false, 0
	end
	if data.BastonesSettled == true then
		return false, 0
	end
	local snap = EventCalendar.snapshot(unix, force, phaseOverride)
	if not snap.convert then
		return false, 0
	end
	local bastones = if type(data.Bastones) == "number" then math.max(0, math.floor(data.Bastones)) else 0
	local per = config().DulcesPerBaston
	local gain = bastones * per
	local dulces = if type(data.Dulces) == "number" then data.Dulces else 0
	if gain > 0 then
		local room = maxCurrency - dulces
		if room < 0 then
			room = 0
		end
		if gain > room then
			gain = math.floor(room)
		end
		data.Dulces = dulces + gain
	else
		gain = 0
	end
	data.Bastones = 0
	data.BastonesSettled = true
	return true, gain
end

return EventCalendar
