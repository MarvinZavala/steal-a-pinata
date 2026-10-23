--!strict
-- WP-21. Falla si falta un idioma, si los placeholders no coinciden,
-- si una piñata o liga no tiene clave, o si el juego vuelve a hardcodear
-- un kick o un prompt.

local fs = require("@lune/fs")
local H = require("./harness")
local Catalog = require("../src/ReplicatedStorage/Shared/Locale/Catalog")
local DailyRules = require("../src/ReplicatedStorage/Shared/Gameplay/DailyRules")
local EventCalendar = require("../src/ReplicatedStorage/Shared/Gameplay/EventCalendar")
local FairPlay = require("../src/ReplicatedStorage/Shared/Config/FairPlay")
local Pinatas = require("../src/ReplicatedStorage/Shared/Config/Pinatas")

H.begin()

local function holes(text: string): { [string]: boolean }
	local found: { [string]: boolean } = {}
	for name in string.gmatch(text, "{(%w+)}") do
		found[name] = true
	end
	return found
end

local function sameHoles(left: { [string]: boolean }, right: { [string]: boolean }): boolean
	for name in left do
		if right[name] ~= true then
			return false
		end
	end
	for name in right do
		if left[name] ~= true then
			return false
		end
	end
	return true
end

H.check("es, en y pt tienen el mismo texto de relleno", function()
	local missing = Catalog.missing()
	H.eq(#missing, 0, table.concat(missing, ", "))
	for key, row in Catalog.entries do
		local es = holes(row.es)
		H.truthy(sameHoles(es, holes(row.en)), key .. " en")
		H.truthy(sameHoles(es, holes(row.pt)), key .. " pt")
	end
end)

H.check("cada piñata, liga y misión tiene clave", function()
	for id in Pinatas do
		H.truthy(Catalog.entries["pinata." .. id] ~= nil, "pinata." .. id)
	end
	for _, band in FairPlay.Bands do
		H.truthy(Catalog.entries["league." .. band.id] ~= nil, "league." .. band.id)
	end
	H.truthy(Catalog.entries["league.Mixto"] ~= nil, "league.Mixto")
	for _, quest in DailyRules.board(0) do
		H.truthy(Catalog.entries[quest.titleKey] ~= nil, quest.titleKey)
	end
	for _, quest in EventCalendar.quests() do
		H.truthy(Catalog.entries[quest.titleKey] ~= nil, quest.titleKey)
	end
	for _, key in { "kick.load", "kick.migration", "kick.stolen", "kick.anticheat" } do
		H.truthy(Catalog.entries[key] ~= nil, key)
	end
end)

local FORBIDDEN = {
	':Kick%("',
	'ActionText = "',
	'ObjectText = "',
}

local function collect(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			collect(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end

H.check("los kicks y los prompts salen del catálogo", function()
	local files = {}
	collect("src", files)
	local hits = {}
	for _, path in files do
		local lineNo = 0
		for line in string.gmatch(fs.readFile(path) .. "\n", "(.-)\n") do
			lineNo += 1
			local trimmed = string.gsub(line, "^%s+", "")
			if string.sub(trimmed, 1, 2) ~= "--" then
				for _, pattern in FORBIDDEN do
					if string.find(line, pattern) ~= nil then
						table.insert(hits, string.format("%s:%d %s", path, lineNo, pattern))
					end
				end
			end
		end
	end
	H.eq(#hits, 0, table.concat(hits, "\n"))
end)

H.finish()
