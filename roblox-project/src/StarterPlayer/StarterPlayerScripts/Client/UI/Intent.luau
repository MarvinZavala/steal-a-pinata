--!strict
-- La intro puede "atrapar" un botón del HUD (batear, juntar) sin que el HUD conozca al FTUE.

local handler: ((string) -> boolean)? = nil

local Intent = {}

function Intent.bind(fn: ((string) -> boolean)?)
	handler = fn
end

function Intent.try(name: string): boolean
	if handler then
		return handler(name)
	end
	return false
end

return Intent
