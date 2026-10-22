--!strict
-- Definición ÚNICA de remotes. El cliente solo manda INTENCIONES; el servidor valida todo (GDD §7).
-- El servidor crea las instancias en ReplicatedStorage/Remotes al arrancar; el cliente las espera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	-- Cliente -> Servidor (intenciones)
	"RequestBuy", -- (conveyorSlotId: number)
	"RequestSteal", -- (ownerUserId: number, pedestalIndex: number)
	"RequestSwing", -- ()
	"RequestLock", -- ()
	"RequestUpgrade", -- (upgradeId: string)
	"RequestFuse", -- (pinataId: string)
	-- Servidor -> Cliente (estado / feedback)
	"StateChanged", -- (patch: table)
	"Feedback", -- (kind: string, payload: table)  -- BONK, ROBBED, PURCHASE, etc.
	"Announce", -- (text: string, rarity: string)
}

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	local folder: Instance
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		local r = folder:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		return r :: RemoteEvent
	end
	folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.init()
	for _, n in NAMES do
		Remotes.get(n)
	end
end

return Remotes
