--!strict
local Menus = {}

local openName: string? = nil
local closers: { [string]: () -> () } = {}

function Menus.register(name: string, closeFn: () -> ())
	closers[name] = closeFn
end

function Menus.opening(name: string)
	if openName and openName ~= name then
		local previous = openName
		openName = name
		local closeFn = closers[previous]
		if closeFn then
			closeFn()
		end
	else
		openName = name
	end
end

function Menus.closed(name: string)
	if openName == name then
		openName = nil
	end
end

function Menus.current(): string?
	return openName
end

function Menus.closeAll()
	if openName then
		local closeFn = closers[openName]
		if closeFn then
			closeFn()
		end
	end
end

return Menus
