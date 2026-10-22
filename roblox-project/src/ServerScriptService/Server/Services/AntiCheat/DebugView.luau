--!strict
-- Vista de admin en ServerStorage. El cliente no replica ServerStorage.
-- KickEnabled se puede apagar desde la command bar del servidor sin publicar de nuevo.

local ServerStorage = game:GetService("ServerStorage")

local DebugView = {}

local function folder(): Folder
	local found = ServerStorage:FindFirstChild("FairPlayDebug")
	if found ~= nil and found:IsA("Folder") then
		return found
	end
	local created = Instance.new("Folder")
	created.Name = "FairPlayDebug"
	created.Parent = ServerStorage
	return created
end

function DebugView.install()
	local root = folder()
	if root:FindFirstChild("Report") == nil then
		local report = Instance.new("StringValue")
		report.Name = "Report"
		report.Value = "FairPlay (solo servidor, no se replica)"
		report.Parent = root
	end
	if root:FindFirstChild("KickEnabled") == nil then
		local kick = Instance.new("BoolValue")
		kick.Name = "KickEnabled"
		kick.Value = true
		kick.Parent = root
	end
end

function DebugView.kickEnabled(): boolean
	local root = ServerStorage:FindFirstChild("FairPlayDebug")
	if root == nil then
		return true
	end
	local flag = root:FindFirstChild("KickEnabled")
	if flag ~= nil and flag:IsA("BoolValue") then
		return flag.Value
	end
	return true
end

function DebugView.write(text: string)
	local root = folder()
	local report = root:FindFirstChild("Report")
	if report == nil or not report:IsA("StringValue") then
		local created = Instance.new("StringValue")
		created.Name = "Report"
		created.Parent = root
		report = created
	end
	if report:IsA("StringValue") then
		report.Value = text
	end
end

return DebugView
