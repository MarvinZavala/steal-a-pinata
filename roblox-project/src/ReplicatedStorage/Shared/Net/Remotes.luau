--!strict
-- Definición ÚNICA de remotes. El cliente solo manda INTENCIONES; el servidor valida todo (GDD §7).
-- El servidor crea las instancias en ReplicatedStorage/Remotes al arrancar; el cliente las espera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Payload = require(script.Parent.Payload)

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	local folder: Instance
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		return remote :: RemoteEvent
	end
	folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.init()
	for _, name in Payload.names() do
		Remotes.get(name)
	end
end

-- Única puerta del cliente. Rechaza señuelos y remotes de servidor → cliente.
function Remotes.fireServer(name: string, ...: any)
	local spec = Payload.spec(name)
	if spec == nil or spec.Honeypot or spec.Direction ~= "C2S" then
		error(`[Remotes] {name} no es una intención del cliente`, 2)
	end
	Remotes.get(name):FireServer(...)
end

return Remotes
