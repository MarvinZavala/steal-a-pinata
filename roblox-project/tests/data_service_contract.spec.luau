--!strict
local H = require("./harness")
local fs = require("@lune/fs")

H.begin()

local function read(path: string): string?
	if fs.isFile(path) then
		return fs.readFile(path)
	end
	return nil
end

H.check("DataService usa ProfileStore con lock, autosave y EndSession", function()
	local src = read("src/ServerScriptService/Server/Services/DataService.luau")
		or read("roblox-project/src/ServerScriptService/Server/Services/DataService.luau")
	H.truthy(src, "DataService.luau")
	local text = src :: string
	H.truthy(string.find(text, "StartSessionAsync", 1, true))
	H.truthy(string.find(text, "EndSession", 1, true))
	H.truthy(string.find(text, "OnSessionEnd", 1, true))
	H.truthy(string.find(text, "AUTO_SAVE_PERIOD", 1, true))
	H.truthy(string.find(text, "ProfileStore.Mock", 1, true) or string.find(text, "store.Mock", 1, true))
	H.truthy(string.find(text, "UseLiveProfiles", 1, true))
	H.truthy(string.find(text, "Economy.StartPedestals", 1, true))
	H.truthy(string.find(text, "Migrations.migrate", 1, true))
	H.eq(string.find(text, "Steal", 1, true), nil)
end)

H.check("ProfileStore vendorizado está en el repo", function()
	local src = read("src/ServerScriptService/Server/Vendor/ProfileStore.luau")
		or read("roblox-project/src/ServerScriptService/Server/Vendor/ProfileStore.luau")
	H.truthy(src, "ProfileStore.luau")
	H.truthy(string.find(src :: string, "session locking", 1, true))
end)

H.finish()
