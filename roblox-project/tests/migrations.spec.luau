--!strict
local H = require("./harness")
local Migrations = require("../src/ReplicatedStorage/Shared/Data/Migrations")
local defaults = require("./defaults")

H.begin()

local function profile(data: any, err: string?): any
	H.eq(err, nil, "migrate error")
	H.truthy(data, "migrate returned nil")
	return data
end

H.check("perfil vacío llega a v2", function()
	local data = profile(Migrations.migrate({}, defaults()))
	H.eq(data.SchemaVersion, Migrations.VERSION)
	H.eq(data.Dulces, 0)
	H.eq(data.Bastones, 0)
	H.eq(data.PedestalsOwned, defaults().pedestalsOwned)
	H.eq(data.VaultCapTier, 1)
	H.eq(#data.Inventory, 0)
	H.eq(data.Stats.Bonks, 0)
	H.eq(data.Daily.LastResetUnix, 0)
	H.eq(data.Daily.Streak, 0)
	H.eq(data.FtueCompleted, false)
	H.eq(data.Passes.DoubleCandy, false)
	H.eq(data.Passes.Vip, false)
	H.eq(data.Stats.Buys, 0)
	H.eq(data.Stats.Collects, 0)
	H.eq(data.Daily.ClaimedDay, 0)
	H.eq(data.EmergencyCharges, 0)
	H.eq(data.AdventMask, 0)
	H.eq(data.EventQuestMask, 0)
	H.eq(data.EventQuestDay, 0)
	H.eq(data.GiftDay, 0)
	H.eq(data.BastonesSettled, false)
	H.eq(Migrations.VERSION, 4)
end)

H.check("FtueCompleted ausente queda en false y true se conserva", function()
	local missing = profile(Migrations.migrate({ SchemaVersion = 2, Dulces = 1 }, defaults()))
	H.eq(missing.FtueCompleted, false)
	local done = profile(Migrations.migrate({ SchemaVersion = 2, FtueCompleted = true, Dulces = 1 }, defaults()))
	H.eq(done.FtueCompleted, true)
	H.eq(done.Dulces, 1)
	local junk = profile(Migrations.migrate({ SchemaVersion = 2, FtueCompleted = "yes" }, defaults()))
	H.eq(junk.FtueCompleted, false)
end)

H.check("v1 suma Bonks, reset diario y compras sin perder Dulces", function()
	local raw = {
		SchemaVersion = 1,
		Dulces = 50,
		Bastones = 3,
		ReFiestas = 2,
		PedestalsOwned = 6,
		VaultCapTier = 2,
		Inventory = {
			{ InstanceId = "a", PinataId = "michi", Mutation = "Golden", ObtainedAt = 10 },
		},
		Placed = { ["1"] = "a", ["2"] = "fantasma" },
		Dex = { michi = true },
		Stats = {
			PlayTimeSec = 10,
			FirstJoinUnix = 1,
			LastJoinUnix = 2,
			LastLeaveUnix = 3,
			Steals = 4,
			TimesRobbed = 5,
		},
		Daily = { LastClaimUnix = 9, Streak = 2 },
		RookieSeconds = 8,
		Hacks = 1,
	}
	local data = profile(Migrations.migrate(raw, defaults()))
	H.eq(data.SchemaVersion, Migrations.VERSION)
	H.eq(data.Dulces, 50)
	H.eq(data.Bastones, 3)
	H.eq(data.ReFiestas, 2)
	H.eq(data.PedestalsOwned, 6)
	H.eq(data.Inventory[1].PinataId, "michi")
	H.eq(data.Inventory[1].Mutation, "Golden")
	H.eq(data.Placed["1"], "a")
	H.eq(data.Placed["2"], nil)
	H.eq(data.Stats.Bonks, 0)
	H.eq(data.Stats.Steals, 4)
	H.eq(data.Daily.LastResetUnix, 0)
	H.eq(data.Daily.Streak, 2)
	H.eq(data.Hacks, nil)
	H.eq(raw.SchemaVersion, 1)
	H.eq(raw.Stats.Bonks, nil)
	H.eq(raw.Hacks, 1)
end)

H.check("migrar dos veces es estable", function()
	local once = profile(Migrations.migrate({ SchemaVersion = 1, Dulces = 20 }, defaults()))
	local twice = profile(Migrations.migrate(once, defaults()))
	H.eq(twice.Dulces, 20)
	H.eq(twice.SchemaVersion, Migrations.VERSION)
	H.eq(twice.Stats.Bonks, 0)
	H.eq(#twice.Inventory, 0)
end)

H.check("rechaza basura sin mutar el original", function()
	local cases = {
		{ SchemaVersion = 99, Dulces = 5 },
		{ SchemaVersion = 1, Dulces = "100" },
		{ SchemaVersion = 1, Dulces = -1 },
		{ SchemaVersion = 1, Dulces = 1.5 },
		{ SchemaVersion = 1, Dulces = 0 / 0 },
		{ SchemaVersion = "2", Dulces = 1 },
	}
	for _, raw in cases do
		local before = raw.Dulces
		local data, err = Migrations.migrate(raw, defaults())
		H.eq(data, nil)
		H.truthy(err)
		-- NaN no es igual a sí mismo; si el original era NaN, tiene que seguir siéndolo.
		if before ~= before then
			H.truthy(raw.Dulces ~= raw.Dulces, "nan mutated")
		else
			H.eq(raw.Dulces, before)
		end
	end
	local data, err = Migrations.migrate("nope", defaults())
	H.eq(data, nil)
	H.eq(err, "not_table")
end)

H.check("instancia duplicada no pasa", function()
	local raw = {
		SchemaVersion = 2,
		Inventory = {
			{ InstanceId = "a", PinataId = "toro", Mutation = "None", ObtainedAt = 1 },
			{ InstanceId = "a", PinataId = "toro", Mutation = "None", ObtainedAt = 1 },
		},
	}
	local data, err = Migrations.migrate(raw, defaults())
	H.eq(data, nil)
	H.eq(err, "duplicate_instance")
end)

H.finish()
