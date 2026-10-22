--!strict
-- Esquema v1 que el gameplay lee y escribe. WP-02 (ProfileStore) puede persistir
-- esta misma tabla; ver roblox-project/INTEGRATION.md. Sin dependencias de Roblox.

export type OwnedPinata = {
	uid: string,
	pinataId: string,
	mutation: string?,
	pedestal: number?,
	inTransit: boolean?,
}

export type StealStamp = { victim: number, at: number }

export type ProfileData = {
	schemaVersion: number,
	candy: number,
	bastones: number,
	reFiestas: number,
	has2x: boolean,
	hasVip: boolean,
	setsDone: number,
	pedestalCount: number,
	vaultTier: number,
	vaultCandy: number,
	pinatas: { OwnedPinata },
	totalPlaySeconds: number,
	lastLogoutUnix: number?,
	lastStealUnix: number,
	stealTimes: { StealStamp },
	-- Unix de cada robo sufrido (tope: 2 cada 5 min, GDD §4.3 / §7).
	robbedAt: { number },
	-- Unix hasta el que no se puede activar el candado manual.
	lockCooldownUntil: number,
}

local Profile = {}

local function finiteNonNeg(x: any, fallback: number): number
	if type(x) ~= "number" or x ~= x or x == math.huge or x < 0 then
		return fallback
	end
	return x
end

function Profile.default(pedestalCount: number): ProfileData
	return {
		schemaVersion = 1,
		candy = 0,
		bastones = 0,
		reFiestas = 0,
		has2x = false,
		hasVip = false,
		setsDone = 0,
		pedestalCount = pedestalCount,
		vaultTier = 1,
		vaultCandy = 0,
		pinatas = {},
		totalPlaySeconds = 0,
		lastLogoutUnix = nil,
		lastStealUnix = 0,
		stealTimes = {},
		robbedAt = {},
		lockCooldownUntil = 0,
	}
end

function Profile.hydrate(raw: any, pedestalCount: number): ProfileData
	local data = Profile.default(pedestalCount)
	if type(raw) ~= "table" then
		return data
	end
	data.candy = finiteNonNeg(raw.candy, 0)
	data.bastones = finiteNonNeg(raw.bastones, 0)
	data.reFiestas = math.floor(finiteNonNeg(raw.reFiestas, 0))
	data.has2x = raw.has2x == true
	data.hasVip = raw.hasVip == true
	data.setsDone = math.floor(finiteNonNeg(raw.setsDone, 0))
	local ped = math.floor(finiteNonNeg(raw.pedestalCount, pedestalCount))
	data.pedestalCount = math.clamp(ped, 1, 12)
	data.vaultTier = math.clamp(math.floor(finiteNonNeg(raw.vaultTier, 1)), 1, 4)
	data.vaultCandy = finiteNonNeg(raw.vaultCandy, 0)
	data.totalPlaySeconds = finiteNonNeg(raw.totalPlaySeconds, 0)
	if type(raw.lastLogoutUnix) == "number" and raw.lastLogoutUnix > 0 then
		data.lastLogoutUnix = raw.lastLogoutUnix
	end
	data.lastStealUnix = finiteNonNeg(raw.lastStealUnix, 0)
	data.lockCooldownUntil = finiteNonNeg(raw.lockCooldownUntil, 0)
	if type(raw.pinatas) == "table" then
		for _, item in raw.pinatas do
			if type(item) == "table" and type(item.uid) == "string" and type(item.pinataId) == "string" then
				local owned: OwnedPinata = {
					uid = item.uid,
					pinataId = item.pinataId,
					mutation = if type(item.mutation) == "string" then item.mutation else nil,
					pedestal = if type(item.pedestal) == "number" then item.pedestal else nil,
					inTransit = if item.inTransit == true then true else nil,
				}
				table.insert(data.pinatas, owned)
			end
		end
	end
	if type(raw.stealTimes) == "table" then
		for _, stamp in raw.stealTimes do
			if type(stamp) == "table" and type(stamp.victim) == "number" and type(stamp.at) == "number" then
				table.insert(data.stealTimes, { victim = stamp.victim, at = stamp.at })
			end
		end
	end
	if type(raw.robbedAt) == "table" then
		for _, at in raw.robbedAt do
			if type(at) == "number" and at > 0 then
				table.insert(data.robbedAt, at)
			end
		end
	end
	return data
end

return Profile
