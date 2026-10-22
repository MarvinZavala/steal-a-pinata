--!strict
-- WP-16. Ligas por Poder de base, escudo y servers.
-- Un jugador de Fuego no entra a un server Confeti. El server privado no redirige.
-- Si la liga está vacía, el fallback es un server Mixto (GDD §4.10).

local LeagueRules = {}

export type Band = { id: string, min: number, max: number }

export type Listing = {
	league: string,
	jobId: string,
	players: number,
	accessCode: string,
	updatedAt: number,
}

export type DecideInput = {
	studio: boolean,
	vip: boolean,
	serverLeague: string,
	playerLeague: string,
	openLeagues: { string },
	lockedMixed: boolean,
}

export type Decision = { action: "stay" | "claim" | "redirect", league: string }

export type Placement = {
	kind: "join" | "reserve",
	league: string,
	jobId: string?,
	accessCode: string?,
}

function LeagueRules.rank(id: string): number
	if id == "Confeti" then
		return 1
	end
	if id == "Serpentina" then
		return 2
	end
	if id == "Fuego" then
		return 3
	end
	return 0
end

function LeagueRules.isLeague(id: string): boolean
	return LeagueRules.rank(id) > 0
end

function LeagueRules.leagueOf(power: number, bands: { Band }): string
	local value = power
	if value ~= value or value < 0 then
		value = 0
	end
	local fallback = if bands[1] ~= nil then bands[1].id else "Confeti"
	for _, band in bands do
		if value >= band.min and value < band.max then
			return band.id
		end
	end
	return fallback
end

function LeagueRules.shieldLeft(playedSec: number, durationSec: number): number
	if durationSec <= 0 or playedSec ~= playedSec then
		return 0
	end
	return math.max(0, durationSec - math.max(0, playedSec))
end

function LeagueRules.shielded(playedSec: number, durationSec: number): boolean
	return LeagueRules.shieldLeft(playedSec, durationSec) > 0
end

local function contains(list: { string }, id: string): boolean
	for _, item in list do
		if item == id then
			return true
		end
	end
	return false
end

-- La liga abierta más alta a la que puede ir sin bajar más de un escalón.
-- Fuego con solo Confeti abierta cae a Mixto, no a Confeti.
function LeagueRules.destination(playerLeague: string, openLeagues: { string }): string
	if contains(openLeagues, playerLeague) then
		return playerLeague
	end
	local playerRank = LeagueRules.rank(playerLeague)
	local best: string? = nil
	local bestRank = 0
	for _, id in openLeagues do
		local rank = LeagueRules.rank(id)
		if rank > 0 and rank < playerRank and rank > bestRank then
			best = id
			bestRank = rank
		end
	end
	if best == nil or playerRank - bestRank > 1 then
		return "Mixto"
	end
	return best
end

function LeagueRules.decide(input: DecideInput): Decision
	if input.studio or input.vip or input.serverLeague == "Privado" then
		local league = if input.vip or input.serverLeague == "Privado" then "Privado" else input.serverLeague
		return { action = "stay", league = league }
	end
	local dest = LeagueRules.destination(input.playerLeague, input.openLeagues)
	if input.serverLeague == dest then
		return { action = "stay", league = dest }
	end
	if input.serverLeague == "Mixto" and input.lockedMixed then
		return { action = "stay", league = "Mixto" }
	end
	if input.serverLeague == "Mixto" then
		return { action = "claim", league = dest }
	end
	return { action = "redirect", league = dest }
end

-- El veterano no le roba al que va atrás. Al revés sí, si el escudo ya no aplica.
function LeagueRules.canSteal(thiefLeague: string, victimLeague: string): boolean
	local thiefRank = LeagueRules.rank(thiefLeague)
	local victimRank = LeagueRules.rank(victimLeague)
	if thiefRank == 0 or victimRank == 0 then
		return true
	end
	return thiefRank <= victimRank
end

function LeagueRules.serverKind(privateServerId: string, ownerId: number): "vip" | "reserved" | "public"
	if ownerId ~= 0 then
		return "vip"
	end
	if privateServerId ~= "" then
		return "reserved"
	end
	return "public"
end

function LeagueRules.shouldPublish(kind: "vip" | "reserved" | "public", accessCode: string?): boolean
	return kind == "reserved" and type(accessCode) == "string" and accessCode ~= ""
end

function LeagueRules.pick(
	listings: { Listing },
	league: string,
	now: number,
	staleSec: number,
	maxPlayers: number,
	ownJobId: string
): Listing?
	local best: Listing? = nil
	for _, item in listings do
		local fresh = now - item.updatedAt <= staleSec
		local room = item.players < maxPlayers
		local code = item.accessCode ~= ""
		if item.league == league and item.jobId ~= ownJobId and fresh and room and code then
			if best == nil or item.players > best.players then
				best = item
			end
		end
	end
	return best
end

function LeagueRules.whereTo(
	dest: string,
	destListings: { Listing },
	mixtoListings: { Listing },
	now: number,
	staleSec: number,
	maxPlayers: number,
	ownJobId: string,
	preferMixed: boolean
): Placement
	local chosen = LeagueRules.pick(destListings, dest, now, staleSec, maxPlayers, ownJobId)
	if chosen ~= nil then
		return { kind = "join", league = dest, jobId = chosen.jobId, accessCode = chosen.accessCode }
	end
	if preferMixed then
		local mixed = LeagueRules.pick(mixtoListings, "Mixto", now, staleSec, maxPlayers, ownJobId)
		if mixed ~= nil then
			return { kind = "join", league = "Mixto", jobId = mixed.jobId, accessCode = mixed.accessCode }
		end
	end
	return { kind = "reserve", league = dest, jobId = nil, accessCode = nil }
end

return LeagueRules
