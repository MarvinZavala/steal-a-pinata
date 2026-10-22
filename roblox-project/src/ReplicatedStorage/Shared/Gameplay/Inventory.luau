--!strict
-- Mover una piñata de un inventario a otro sin duplicarla ni perderla.

local Inventory = {}

export type Row = { uid: string }

function Inventory.uids(rows: { Row }): { string }
	local out: { string } = {}
	for _, row in rows do
		table.insert(out, row.uid)
	end
	return out
end

function Inventory.contains(rows: { Row }, uid: string): boolean
	for _, row in rows do
		if row.uid == uid then
			return true
		end
	end
	return false
end

function Inventory.move(fromRows: { Row }, toRows: { Row }, uid: string): boolean
	if Inventory.contains(toRows, uid) then
		return false
	end
	local found: Row? = nil
	local keep: { Row } = {}
	for _, row in fromRows do
		if row.uid == uid and found == nil then
			found = row
		else
			table.insert(keep, row)
		end
	end
	if found == nil then
		return false
	end
	table.clear(fromRows)
	for _, row in keep do
		table.insert(fromRows, row)
	end
	table.insert(toRows, found)
	return true
end

function Inventory.sameUids(a: { string }, b: { string }): boolean
	if #a ~= #b then
		return false
	end
	for index, uid in a do
		if b[index] ~= uid then
			return false
		end
	end
	return true
end

return Inventory
