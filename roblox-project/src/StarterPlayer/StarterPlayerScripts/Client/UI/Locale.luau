--!strict
-- Textos de UI. Llena LocalizationService.FiestaUI y lee desde ahí.
-- El catálogo Luau solo existe para construir la tabla (listo para exportar en WP-21).

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"):WaitForChild("Catalog")) :: any

type Row = {
	es: string,
	en: string,
	pt: string,
}

local cache: { [string]: Row } = {}
local current = "es"
local mode = "auto"
local binders: { () -> () } = {}
local listeners: { () -> () } = {}
local installed = false

local Locale = {}

local function normalize(localeId: string): string
	local lower = string.lower(localeId)
	if string.sub(lower, 1, 2) == "en" then
		return "en"
	elseif string.sub(lower, 1, 2) == "pt" then
		return "pt"
	elseif string.sub(lower, 1, 2) == "es" then
		return "es"
	end
	return "es"
end

local function fillCacheFromCatalog()
	table.clear(cache)
	for key, row in Catalog.entries do
		if typeof(key) == "string" and typeof(row) == "table" then
			cache[key] = {
				es = tostring(row.es or ""),
				en = tostring(row.en or ""),
				pt = tostring(row.pt or ""),
			}
		end
	end
end

local function fillCacheFromTable(locTable: LocalizationTable)
	local entries = locTable:GetEntries()
	if typeof(entries) ~= "table" then
		return
	end
	for _, entry in entries do
		if typeof(entry) == "table" and typeof(entry.Key) == "string" then
			local values = entry.Values
			local source = if typeof(entry.Source) == "string" then entry.Source else ""
			local es = source
			local en = source
			local pt = source
			if typeof(values) == "table" then
				if typeof(values.es) == "string" then
					es = values.es
				end
				if typeof(values.en) == "string" then
					en = values.en
				elseif typeof(values["en-us"]) == "string" then
					en = values["en-us"]
				end
				if typeof(values.pt) == "string" then
					pt = values.pt
				elseif typeof(values["pt-br"]) == "string" then
					pt = values["pt-br"]
				end
			end
			cache[entry.Key] = { es = es, en = en, pt = pt }
		end
	end
end

function Locale.install()
	if installed then
		return
	end
	installed = true
	fillCacheFromCatalog()
	local locTable = Instance.new("LocalizationTable")
	locTable.Name = "FiestaUI"
	local payload = {}
	for key, row in cache do
		table.insert(payload, {
			Key = key,
			Source = row.es,
			Context = "FiestaUI",
			Example = row.en,
			Values = {
				es = row.es,
				["es-mx"] = row.es,
				["es-es"] = row.es,
				en = row.en,
				["en-us"] = row.en,
				pt = row.pt,
				["pt-br"] = row.pt,
			},
		})
	end
	local wrote = pcall(function()
		locTable:SetEntries(payload)
	end)
	if wrote then
		locTable.Parent = LocalizationService
		local read = pcall(function()
			fillCacheFromTable(locTable)
		end)
		if not read then
			fillCacheFromCatalog()
		end
	else
		locTable:Destroy()
	end
	current = normalize(LocalizationService.RobloxLocaleId)
end

local function refresh()
	for _, fn in binders do
		fn()
	end
	for _, fn in listeners do
		fn()
	end
end

function Locale.setLocale(requested: string)
	mode = if requested == "" then "auto" else requested
	local nextId = current
	if mode == "auto" then
		nextId = normalize(LocalizationService.RobloxLocaleId)
	elseif mode == "en" or mode == "pt" or mode == "es" then
		nextId = mode
	end
	if nextId == current then
		return
	end
	current = nextId
	refresh()
end

function Locale.current(): string
	return current
end

function Locale.mode(): string
	return mode
end

function Locale.has(key: string): boolean
	return cache[key] ~= nil
end

function Locale.t(key: string, args: { [string]: string }?): string
	local row = cache[key]
	if not row then
		return "[" .. key .. "]"
	end
	local template = row.es
	if current == "en" then
		template = row.en
	elseif current == "pt" then
		template = row.pt
	end
	if not args then
		return template
	end
	local filled = string.gsub(template, "{(%w+)}", function(name: string): string
		return args[name] or ("{" .. name .. "}")
	end)
	return filled
end

function Locale.bind(label: TextLabel, key: string)
	label.AutoLocalize = false
	label.RichText = false
	label:SetAttribute("LKey", key)
	local function apply()
		label.Text = Locale.t(key)
	end
	apply()
	table.insert(binders, apply)
end

function Locale.onChange(fn: () -> ())
	table.insert(listeners, fn)
end

function Locale.pinataName(id: string): string
	local key = "pinata." .. id
	if cache[key] then
		return Locale.t(key)
	end
	return id
end

function Locale.mutationName(mutation: string): string
	if mutation == "" or mutation == "None" then
		return ""
	end
	local key = "mutation." .. mutation
	if cache[key] then
		return Locale.t(key)
	end
	return mutation
end

return Locale
