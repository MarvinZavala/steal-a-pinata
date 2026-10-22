--!strict
-- WP-10b. Distancia, teleport y vuelo contra Tuning. Puro: el server pasa el sample.
-- El golpe (knockback) abre una ventana. El ping suma studs a la velocidad de caminar.
-- Un fallo es un flag. Quién responde (log, rubber-band, kick) lo decide Suspicion.

local MovementSanity = {}

export type MoveConfig = {
	walkSpeed: number,
	carrySpeed: number,
	speedMultiplier: number,
	teleportSlack: number,
	pingCapSec: number,
	knockbackHorizontal: number,
	knockbackVertical: number,
	knockbackGraceSec: number,
	jumpHeight: number,
	groundY: number,
	flySlack: number,
	teleportExtra: number,
}

export type Verdict = "ok" | "speed" | "teleport" | "fly"

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function MovementSanity.fromTuning(tuning: any, security: any, fair: any): MoveConfig
	return {
		walkSpeed = tuning.WalkSpeed,
		carrySpeed = tuning.CarrySpeed,
		speedMultiplier = security.SpeedMultiplier,
		teleportSlack = security.TeleportSlackStuds,
		pingCapSec = fair.PingCapSec,
		knockbackHorizontal = tuning.KnockbackHorizontal,
		knockbackVertical = tuning.KnockbackVertical,
		knockbackGraceSec = fair.KnockbackGraceSec,
		jumpHeight = tuning.JumpHeight,
		groundY = fair.GroundY,
		flySlack = fair.FlySlack,
		teleportExtra = fair.TeleportExtra,
	}
end

function MovementSanity.modeSpeed(cfg: MoveConfig, mode: string): number
	if mode == "carry" then
		return cfg.carrySpeed
	end
	if mode == "stun" then
		return 0
	end
	return cfg.walkSpeed
end

function MovementSanity.knockbackActive(cfg: MoveConfig, knockAge: number?): boolean
	if knockAge == nil or not finite(knockAge) then
		return false
	end
	return knockAge >= 0 and knockAge <= cfg.knockbackGraceSec
end

function MovementSanity.allowedDistance(
	cfg: MoveConfig,
	dt: number,
	mode: string,
	pingSec: number,
	knockAge: number?
): number
	if not finite(dt) or dt <= 0 then
		return 0
	end
	local ping = pingSec
	if not finite(ping) or ping < 0 then
		ping = 0
	elseif ping > cfg.pingCapSec then
		ping = cfg.pingCapSec
	end
	local allowed = MovementSanity.modeSpeed(cfg, mode) * cfg.speedMultiplier * dt + cfg.teleportSlack
	allowed += cfg.walkSpeed * ping
	if MovementSanity.knockbackActive(cfg, knockAge) then
		local window = math.min(dt, cfg.knockbackGraceSec)
		allowed += (cfg.knockbackHorizontal + cfg.knockbackVertical) * window
	end
	return allowed
end

function MovementSanity.maxHeight(cfg: MoveConfig, dt: number, knockAge: number?): number
	local extra = 0
	if MovementSanity.knockbackActive(cfg, knockAge) and finite(dt) and dt > 0 then
		extra = cfg.knockbackVertical * math.min(dt, cfg.knockbackGraceSec)
	end
	return cfg.groundY + cfg.jumpHeight + cfg.flySlack + extra
end

function MovementSanity.classify(
	cfg: MoveConfig,
	distance: number,
	dt: number,
	mode: string,
	pingSec: number,
	knockAge: number?,
	y: number
): Verdict
	if not finite(distance) or not finite(y) or distance < 0 then
		return "teleport"
	end
	if y > MovementSanity.maxHeight(cfg, dt, knockAge) then
		return "fly"
	end
	local allowed = MovementSanity.allowedDistance(cfg, dt, mode, pingSec, knockAge)
	if distance <= allowed then
		return "ok"
	end
	if distance > allowed + cfg.teleportExtra then
		return "teleport"
	end
	return "speed"
end

return MovementSanity
