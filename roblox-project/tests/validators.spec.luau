--!strict
local H = require("./harness")
local Validators = require("../src/ServerScriptService/Server/Services/AntiCheat/Validators")
local Economy = require("../src/ReplicatedStorage/Shared/Config/Economy")
local Security = require("../src/ReplicatedStorage/Shared/Config/Security")

H.begin()

H.check("números finitos", function()
	H.truthy(Validators.isFiniteNumber(1))
	H.eq(Validators.isFiniteNumber(0 / 0), false)
	H.eq(Validators.isFiniteNumber(math.huge), false)
	H.eq(Validators.isFiniteNumber("1"), false)
end)

H.check("robo a 200 studs se rechaza y a 8 pasa", function()
	local maxDist = Economy.Steal.MaxDistance
	H.eq(Validators.withinPoints(0, 0, 0, 0, 0, 200, maxDist, 0), false)
	H.eq(Validators.withinPoints(0, 0, 0, 0, 0, maxDist, maxDist, 0), true)
	H.eq(Validators.withinPoints(0, 0, 0, 0, 0, maxDist + 2, maxDist, 3), true)
	H.eq(Validators.withinPoints(0, 0, 0, 12, 0, 0, Economy.Buy.MaxDistance, 0), true)
	H.eq(Validators.withinPoints(0, 0, 0, 0, 0, 30, Economy.Bat.MaxDistance, 0), false)
end)

H.check("ángulo frontal del bate", function()
	local maxAngle = Economy.Bat.MaxAngleDeg
	H.eq(Validators.inFrontPoints(0, 0, -1, 0, 0, 0, 0, 0, -5, maxAngle), true)
	local edge = math.rad(maxAngle)
	H.eq(Validators.inFrontPoints(0, 0, -1, 0, 0, 0, math.sin(edge), 0, -math.cos(edge), maxAngle), true)
	local outside = math.rad(maxAngle + 10)
	H.eq(Validators.inFrontPoints(0, 0, -1, 0, 0, 0, math.sin(outside), 0, -math.cos(outside), maxAngle), false)
	H.eq(Validators.inFrontPoints(0, 0, -1, 0, 0, 0, 0, 0, 5, maxAngle), false)
end)

H.check("ping, mapa y velocidad", function()
	H.near(Validators.pingSlack(0.1, Economy.Walk.Normal), Economy.Walk.Normal * 0.1)
	H.near(Validators.pingSlack(5, Economy.Walk.Normal), Economy.Walk.Normal * 0.3)
	H.eq(Validators.positionSane(0, 10, 0, Security.MapHalfExtent), true)
	H.eq(Validators.positionSane(1e9, 0, 0, Security.MapHalfExtent), false)
	H.eq(Validators.positionSane(0 / 0, 0, 0, Security.MapHalfExtent), false)
	local maxSpeed = Economy.Walk.Normal * Security.SpeedMultiplier
	H.eq(Validators.speedSane(maxSpeed, 1, maxSpeed, Security.TeleportSlackStuds), true)
	H.eq(Validators.speedSane(500, 1, maxSpeed, Security.TeleportSlackStuds), false)
end)

H.check("multiplicador aditivo", function()
	H.eq(Economy.totalMultiplier(0, false, false, 0), 1)
	H.eq(Economy.totalMultiplier(2, true, true, 1), 1 + 1 + 1 + 0.5 + 0.05)
end)

H.finish()
