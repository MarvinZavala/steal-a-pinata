--!strict
-- Validación pura de payloads de remotes (WP-10a). No tira: el servidor usa validateSafe.
-- Los números de rango salen de Security y el roster de Pinatas, que se pasan por argumento
-- para que este módulo no dependa de `script` y se pueda testear fuera de Studio.
local Payload = {}

export type Direction = "C2S" | "S2C"
export type ArgKind =
	"slot"
	| "userId"
	| "pedestal"
	| "upgrade"
	| "pinataId"
	| "ftueStep"
	| "ftueAction"
	| "locale"
	| "unit"
	| "flag"

export type RemoteSpec = {
	Direction: Direction,
	Honeypot: boolean,
	Args: { ArgKind },
}

local FORBIDDEN: { [string]: boolean } = {
	Dulces = true,
	Bastones = true,
	Inventory = true,
	Cash = true,
	Robux = true,
	Currency = true,
	WalkSpeed = true,
	SchemaVersion = true,
	ProcessedPurchases = true,
	Placed = true,
	Dex = true,
}

local SPECS: { [string]: RemoteSpec } = {
	RequestBuy = { Direction = "C2S", Honeypot = false, Args = { "slot" } },
	RequestSteal = { Direction = "C2S", Honeypot = false, Args = { "userId", "pedestal" } },
	RequestSwing = { Direction = "C2S", Honeypot = false, Args = {} },
	RequestLock = { Direction = "C2S", Honeypot = false, Args = {} },
	RequestUpgrade = { Direction = "C2S", Honeypot = false, Args = { "upgrade" } },
	RequestFuse = { Direction = "C2S", Honeypot = false, Args = { "pinataId" } },
	StateChanged = { Direction = "S2C", Honeypot = false, Args = {} },
	Feedback = { Direction = "S2C", Honeypot = false, Args = {} },
	Announce = { Direction = "S2C", Honeypot = false, Args = {} },
	-- UI (WP-12a / WP-13). Misma carpeta Remotes; el anti-cheat ya los escucha por estar acá.
	RequestCollect = { Direction = "C2S", Honeypot = false, Args = {} },
	RequestSettings = { Direction = "C2S", Honeypot = false, Args = { "locale", "unit", "unit", "flag", "flag" } },
	RequestFTUEStep = { Direction = "C2S", Honeypot = false, Args = { "ftueStep" } },
	RequestFTUEAction = { Direction = "C2S", Honeypot = false, Args = { "ftueAction" } },
	OpenShop = { Direction = "S2C", Honeypot = false, Args = {} },
	-- Señuelos. El cliente legítimo no los dispara (Remotes.fireServer los rechaza).
	RequestGrantCurrency = { Direction = "C2S", Honeypot = true, Args = {} },
	RequestSetWalkSpeed = { Direction = "C2S", Honeypot = true, Args = {} },
	AdminGivePinata = { Direction = "C2S", Honeypot = true, Args = {} },
}

function Payload.spec(name: string): RemoteSpec?
	return SPECS[name]
end

function Payload.names(): { string }
	local list: { string } = {}
	for name in SPECS do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function scan(value: any, depth: number): (boolean, string?)
	if depth > 4 or type(value) ~= "table" then
		return true, nil
	end
	for key, child in value do
		if type(key) == "string" and FORBIDDEN[key] == true then
			return false, "client_currency"
		end
		local ok, reason = scan(child, depth + 1)
		if not ok then
			return false, reason
		end
	end
	return true, nil
end

local function checkInteger(value: any, min: number, max: number): (boolean, string?)
	if type(value) ~= "number" then
		return false, "type"
	end
	if not isFinite(value) then
		return false, "nonfinite"
	end
	if value % 1 ~= 0 then
		return false, "integer"
	end
	if value < min then
		return false, "min"
	end
	if value > max then
		return false, "max"
	end
	return true, nil
end

local function allowList(list: any): { [string]: boolean }
	local allowed: { [string]: boolean } = {}
	if type(list) ~= "table" then
		return allowed
	end
	for _, item in list do
		if type(item) == "string" then
			allowed[item] = true
		end
	end
	return allowed
end

local function checkUnit(value: any): (boolean, string?)
	if type(value) ~= "number" then
		return false, "type"
	end
	if not isFinite(value) then
		return false, "nonfinite"
	end
	if value < 0 or value > 1 then
		return false, "range"
	end
	return true, nil
end

local function checkString(value: any, maxLen: number, allowed: { [string]: boolean }?): (boolean, string?)
	if type(value) ~= "string" then
		return false, "type"
	end
	if #value == 0 or #value > maxLen then
		return false, "length"
	end
	if string.find(value, "%c") ~= nil then
		return false, "control"
	end
	if allowed ~= nil and allowed[value] ~= true then
		return false, "enum"
	end
	return true, nil
end

function Payload.validate(name: string, args: any, security: any, pinatas: any): (boolean, string?)
	local spec = SPECS[name]
	if spec == nil then
		return false, "unknown"
	end
	if spec.Honeypot then
		return false, "honeypot"
	end
	if spec.Direction ~= "C2S" then
		return false, "direction"
	end
	if type(args) ~= "table" then
		return false, "args"
	end
	local scanOk, scanReason = scan(args, 0)
	if not scanOk then
		return false, scanReason
	end

	local expected = #spec.Args
	local numeric = 0
	for key in args do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > expected then
			return false, "shape"
		end
		numeric += 1
	end
	if numeric ~= expected then
		return false, "arity"
	end

	local bounds = security.Bounds
	for index, kind in spec.Args do
		local value = args[index]
		if kind == "slot" then
			local ok, reason = checkInteger(value, bounds.Slot.Min, bounds.Slot.Max)
			if not ok then
				return false, reason
			end
		elseif kind == "userId" then
			local ok, reason = checkInteger(value, bounds.UserId.Min, bounds.UserId.Max)
			if not ok then
				return false, reason
			end
			if value == 0 then
				return false, "user"
			end
		elseif kind == "pedestal" then
			local ok, reason = checkInteger(value, bounds.Pedestal.Min, bounds.Pedestal.Max)
			if not ok then
				return false, reason
			end
		elseif kind == "upgrade" then
			local allowed: { [string]: boolean } = {}
			for _, upgradeId in security.Upgrades do
				allowed[upgradeId] = true
			end
			local ok, reason = checkString(value, bounds.String.MaxLen, allowed)
			if not ok then
				return false, reason
			end
		elseif kind == "pinataId" then
			local allowed: { [string]: boolean } = {}
			if type(pinatas) == "table" then
				for pinataId in pinatas do
					allowed[pinataId] = true
				end
			end
			local ok, reason = checkString(value, bounds.String.MaxLen, allowed)
			if not ok then
				return false, reason
			end
		elseif kind == "ftueStep" then
			local ok, reason = checkString(value, bounds.String.MaxLen, allowList(security.FtueSteps))
			if not ok then
				return false, reason
			end
		elseif kind == "ftueAction" then
			local ok, reason = checkString(value, bounds.String.MaxLen, allowList(security.FtueActions))
			if not ok then
				return false, reason
			end
		elseif kind == "locale" then
			local ok, reason = checkString(value, bounds.String.MaxLen, allowList(security.Locales))
			if not ok then
				return false, reason
			end
		elseif kind == "unit" then
			local ok, reason = checkUnit(value)
			if not ok then
				return false, reason
			end
		elseif kind == "flag" then
			if type(value) ~= "boolean" then
				return false, "type"
			end
		else
			return false, "spec"
		end
	end
	return true, nil
end

function Payload.validateSafe(name: any, args: any, security: any, pinatas: any): (boolean, string?)
	local ok, success, reason = pcall(function(): (boolean, string?)
		if type(name) ~= "string" then
			return false, "unknown"
		end
		return Payload.validate(name, args, security, pinatas)
	end)
	if not ok then
		return false, "threw"
	end
	return success, reason
end

return Payload
