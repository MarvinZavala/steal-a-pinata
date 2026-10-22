--!strict
local failures: { string } = {}

local H = {}

function H.begin()
	for index = #failures, 1, -1 do
		table.remove(failures, index)
	end
end

function H.check(name: string, fn: () -> ())
	local ok, err = xpcall(fn, function(message: any): string
		return debug.traceback(tostring(message), 2)
	end)
	if not ok then
		table.insert(failures, name .. "\n" .. err)
	end
end

function H.eq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(string.format("%s expected %s got %s", message or "eq", tostring(expected), tostring(actual)), 2)
	end
end

function H.near(actual: number, expected: number, eps: number?)
	local tolerance = if eps ~= nil then eps else 1e-6
	if math.abs(actual - expected) > tolerance then
		error(string.format("expected ~%s got %s", tostring(expected), tostring(actual)), 2)
	end
end

function H.truthy(value: any, message: string?)
	if not value then
		error(message or "expected truthy", 2)
	end
end

function H.finish()
	if #failures > 0 then
		error(table.concat(failures, "\n\n"), 0)
	end
end

return H
