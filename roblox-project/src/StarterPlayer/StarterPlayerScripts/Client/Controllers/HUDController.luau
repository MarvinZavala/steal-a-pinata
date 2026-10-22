--!strict
-- HUD mínimo para probar el loop: Dulces, anuncio, bate y candado.
-- La tienda completa es WP-12. Los botones miden más de 44 px.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Net"):WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local HUDController = {}

local INK = Color3.fromHex("#1B1430")
local WHITE = Color3.fromHex("#FFF7EC")
local PINK = Color3.fromHex("#FF3E9A")
local YELLOW = Color3.fromHex("#FFE14D")
local TURQ = Color3.fromHex("#16D3E8")

local function num(payload: any, key: string): number
	if type(payload) ~= "table" then
		return 0
	end
	local value = payload[key]
	if type(value) ~= "number" then
		return 0
	end
	return value
end

local function flag(payload: any, key: string): boolean
	return type(payload) == "table" and payload[key] == true
end

local function button(parent: Instance, text: string, color: Color3, yOffset: number, onClick: () -> ())
	local click = Instance.new("TextButton")
	click.Name = text
	click.AnchorPoint = Vector2.new(1, 1)
	click.Position = UDim2.new(1, -28, 1, yOffset)
	click.Size = UDim2.fromOffset(84, 84)
	click.BackgroundColor3 = color
	click.Text = text
	click.TextColor3 = INK
	click.Font = Enum.Font.FredokaOne
	click.TextSize = 22
	click.AutoButtonColor = true
	click.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = click
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = WHITE
	stroke.Parent = click
	click.Activated:Connect(onClick)
end

local function hookTool(tool: Instance)
	if tool:IsA("Tool") and tool.Name == "Bate" and tool:GetAttribute("Hooked") ~= true then
		tool:SetAttribute("Hooked", true)
		tool.Activated:Connect(function()
			Remotes.fireServer("RequestSwing")
		end)
	end
end

local function watchTools(player: Player)
	local function watch(container: Instance)
		container.ChildAdded:Connect(hookTool)
		for _, child in container:GetChildren() do
			hookTool(child)
		end
	end
	local backpack = player:WaitForChild("Backpack")
	watch(backpack)
	player.CharacterAdded:Connect(function(character)
		watch(character)
	end)
	if player.Character ~= nil then
		watch(player.Character)
	end
end

function HUDController.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "PinataHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Candy"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 16)
	panel.Size = UDim2.fromOffset(280, 92)
	panel.BackgroundColor3 = INK
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 20)
	panelCorner.Parent = panel
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = PINK
	panelStroke.Thickness = 3
	panelStroke.Parent = panel

	local candy = Instance.new("TextLabel")
	candy.BackgroundTransparency = 1
	candy.Position = UDim2.fromOffset(12, 6)
	candy.Size = UDim2.new(1, -24, 0, 40)
	candy.Font = Enum.Font.FredokaOne
	candy.TextScaled = true
	candy.TextColor3 = YELLOW
	candy.TextXAlignment = Enum.TextXAlignment.Left
	candy.Text = "0 dulces"
	candy.Parent = panel

	local detail = Instance.new("TextLabel")
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(12, 48)
	detail.Size = UDim2.new(1, -24, 0, 36)
	detail.Font = Enum.Font.GothamBold
	detail.TextScaled = true
	detail.TextColor3 = WHITE
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.Text = "Dulcería 0"
	detail.Parent = panel

	local banner = Instance.new("TextLabel")
	banner.Name = "Announce"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 120)
	banner.Size = UDim2.fromOffset(460, 48)
	banner.BackgroundColor3 = PINK
	banner.BackgroundTransparency = 0.1
	banner.Font = Enum.Font.FredokaOne
	banner.TextScaled = true
	banner.TextColor3 = WHITE
	banner.Text = ""
	banner.Visible = false
	banner.Parent = gui
	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 16)
	bannerCorner.Parent = banner

	button(gui, "BATE", YELLOW, -150, function()
		Remotes.fireServer("RequestSwing")
	end)
	button(gui, "CANDADO", TURQ, -246, function()
		Remotes.fireServer("RequestLock")
	end)

	Remotes.get("StateChanged").OnClientEvent:Connect(function(payload)
		candy.Text = Format(num(payload, "candy")) .. " dulces"
		local carry = if flag(payload, "carrying") then "  ·  cargando" else ""
		local rookieLeft = num(payload, "rookieLeft")
		local shield = if flag(payload, "rookie")
			then string.format("  ·  protegido %ds", math.ceil(rookieLeft))
			else ""
		detail.Text = string.format(
			"Dulcería %s   +%s/s%s%s",
			Format(num(payload, "vault")),
			Format(num(payload, "perSec")),
			carry,
			shield
		)
	end)

	local bannerToken = 0
	Remotes.get("Announce").OnClientEvent:Connect(function(text)
		if type(text) ~= "string" then
			return
		end
		bannerToken += 1
		local token = bannerToken
		banner.Text = text
		banner.Visible = true
		task.delay(4.5, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	end)

	watchTools(player)
end

return HUDController
