--!strict
-- Rótulos del mundo. El texto de respaldo es español; el cliente lo reemplaza
-- con el idioma elegido leyendo LKey / LKeyAction / LKeyObject.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Locale"):WaitForChild("Text"))

local Labels = {}

function Labels.line(label: TextLabel, key: string, args: { [string]: string }?)
	label.AutoLocalize = false
	label:SetAttribute("LKey", key)
	if args ~= nil then
		for name, value in args do
			label:SetAttribute("LArg_" .. name, value)
		end
	end
	label.Text = Text.line(key, "es", args)
end

function Labels.clear(label: TextLabel)
	label:SetAttribute("LKey", nil)
end

function Labels.prompt(prompt: ProximityPrompt, actionKey: string, objectKey: string)
	prompt.AutoLocalize = false
	prompt:SetAttribute("LKeyAction", actionKey)
	prompt:SetAttribute("LKeyObject", objectKey)
	prompt.ActionText = Text.line(actionKey, "es")
	prompt.ObjectText = Text.line(objectKey, "es")
end

return Labels
