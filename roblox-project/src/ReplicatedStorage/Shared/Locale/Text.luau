--!strict
-- Lectura del catálogo sin LocalizationService. El servidor la usa para kicks
-- y para el texto de respaldo de los rótulos del mundo.

local Catalog = if typeof(script) == "Instance" then require(script.Parent.Catalog) else require("./Catalog")

local Text = {}

function Text.normalize(localeId: string): string
	local lower = string.lower(localeId)
	if string.sub(lower, 1, 2) == "en" then
		return "en"
	elseif string.sub(lower, 1, 2) == "pt" then
		return "pt"
	end
	return "es"
end

function Text.line(key: string, locale: string?, args: { [string]: string }?): string
	local row = Catalog.entries[key]
	if type(row) ~= "table" then
		return "[" .. key .. "]"
	end
	local lang = if type(locale) == "string" then Text.normalize(locale) else "es"
	local template = row.es
	if lang == "en" then
		template = row.en
	elseif lang == "pt" then
		template = row.pt
	end
	if type(template) ~= "string" then
		return "[" .. key .. "]"
	end
	if args == nil then
		return template
	end
	return (
		string.gsub(template, "{(%w+)}", function(name: string): string
			local value = args[name]
			if value == nil then
				return "{" .. name .. "}"
			end
			return value
		end)
	)
end

return Text
