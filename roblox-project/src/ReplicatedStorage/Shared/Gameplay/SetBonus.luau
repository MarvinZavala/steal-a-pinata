--!strict
-- Un set completo (todas las piñatas de ese Set en el Dex) suma +0.05 al multiplicador.

local SetBonus = {}

function SetBonus.count(dex: { [string]: boolean }, pinatas: { [string]: any }): number
	local need: { [string]: number } = {}
	local have: { [string]: number } = {}
	for id, def in pinatas do
		if type(def) == "table" and type(def.Set) == "string" then
			local setName = def.Set
			need[setName] = (need[setName] or 0) + 1
			if dex[id] == true then
				have[setName] = (have[setName] or 0) + 1
			end
		end
	end
	local done = 0
	for setName, total in need do
		if total > 0 and (have[setName] or 0) >= total then
			done += 1
		end
	end
	return done
end

return SetBonus
