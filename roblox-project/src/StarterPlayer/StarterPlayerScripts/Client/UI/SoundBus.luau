--!strict
-- Sonidos del motor de Roblox (no assets de terceros). El volumen sale de Ajustes.
-- La música de fondo la conecta WP-17 leyendo settings.music; acá solo guardamos el valor.

local SoundService = game:GetService("SoundService")

local IDS: { [string]: string } = {
	click = "rbxasset://sounds/switch.wav",
	pop = "rbxasset://sounds/electronicpingshort.wav",
	bonk = "rbxasset://sounds/collide.wav",
	candy = "rbxasset://sounds/impact_water.mp3",
}

local sounds: { [string]: Sound } = {}
local sfx = 0.8
local music = 0.8

local SoundBus = {}

local function get(name: string): Sound?
	local id = IDS[name]
	if not id then
		return nil
	end
	local existing = sounds[name]
	if existing then
		return existing
	end
	local sound = Instance.new("Sound")
	sound.Name = "Fiesta" .. name
	sound.SoundId = id
	sound.Volume = 0.45
	sound.Parent = SoundService
	sounds[name] = sound
	return sound
end

function SoundBus.setVolumes(nextMusic: number, nextSfx: number)
	music = math.clamp(nextMusic, 0, 1)
	sfx = math.clamp(nextSfx, 0, 1)
end

function SoundBus.musicVolume(): number
	return music
end

function SoundBus.play(name: string)
	if sfx <= 0 then
		return
	end
	local sound = get(name)
	if not sound then
		return
	end
	sound.Volume = 0.35 + sfx * 0.4
	sound.TimePosition = 0
	local ok = pcall(function()
		sound:Play()
	end)
	if not ok then
		return
	end
end

return SoundBus
