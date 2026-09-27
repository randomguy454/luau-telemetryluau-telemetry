-- LocalScript for a Roblox experience you own.
-- Displays distances to BaseParts inside the configured Workspace folders.

--// Configuration
local CONFIG = {
	Enabled = true,
	ScanInterval = 1,
	YieldEvery = 150,
	MaximumScannedParts = 2000,
	MaximumRows = 8,
	TargetFolders = { "ChestModels", "Map", "_WorldOrigin" },
}

--// Services and state
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local running = true
local connections = {}

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

--// UI construction
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DistanceDiagnostics"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(320, 310)
panel.Position = UDim2.fromOffset(40, 70)
panel.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(70, 78, 94)
panelStroke.Thickness = 1
panelStroke.Parent = panel

local header = Instance.new("TextButton")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 38)
header.BackgroundColor3 = Color3.fromRGB(36, 41, 52)
header.BorderSizePixel = 0
header.AutoButtonColor = false
header.Font = Enum.Font.GothamBold
header.Text = "  Distance Diagnostics"
header.TextColor3 = Color3.fromRGB(240, 243, 248)
header.TextSize = 14
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = panel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 8)
headerCorner.Parent = header

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "Toggle"
toggleButton.Position = UDim2.fromOffset(12, 48)
toggleButton.Size = UDim2.new(1, -24, 0, 32)
toggleButton.BorderSizePixel = 0
toggleButton.Font = Enum.Font.GothamMedium
toggleButton.TextColor3 = Color3.fromRGB(240, 243, 248)
toggleButton.TextSize = 12
toggleButton.Parent = panel

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = toggleButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Position = UDim2.fromOffset(12, 88)
statusLabel.Size = UDim2.new(1, -24, 0, 24)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextColor3 = Color3.fromRGB(171, 180, 197)
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = panel

local rows = table.create(CONFIG.MaximumRows)

for index = 1, CONFIG.MaximumRows do
	local row = Instance.new("TextLabel")
	row.Name = "DistanceRow" .. index
	row.Position = UDim2.fromOffset(12, 116 + (index - 1) * 22)
	row.Size = UDim2.new(1, -24, 0, 20)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.Gotham
	row.TextColor3 = Color3.fromRGB(215, 221, 233)
	row.TextSize = 11
	row.TextTruncate = Enum.TextTruncate.AtEnd
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = ""
	row.Parent = panel
	rows[index] = row
end

local function updateToggleButton()
	if CONFIG.Enabled then
		toggleButton.Text = "Tracking: ON"
		toggleButton.BackgroundColor3 = Color3.fromRGB(45, 130, 100)
	else
		toggleButton.Text = "Tracking: OFF"
		toggleButton.BackgroundColor3 = Color3.fromRGB(65, 69, 80)
	end
end

connect(toggleButton.Activated, function()
	CONFIG.Enabled = not CONFIG.Enabled
	updateToggleButton()
end)

--// Drag handling
local dragging = false
local dragInput
local dragStart
local panelStartPosition

connect(header.InputBegan, function(input)
	local inputType = input.UserInputType
	if inputType ~= Enum.UserInputType.MouseButton1
		and inputType ~= Enum.UserInputType.Touch then
		return
	end

	dragging = true
	dragInput = input
	dragStart = input.Position
	panelStartPosition = panel.Position
end)

connect(UserInputService.InputChanged, function(input)
	if not dragging or not dragInput then
		return
	end

	local isMouseMovement =
		dragInput.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseMovement

	local isTouchMovement =
		dragInput.UserInputType == Enum.UserInputType.Touch
		and input == dragInput

	if not isMouseMovement and not isTouchMovement then
		return
	end

	local delta = input.Position - dragStart
	panel.Position = UDim2.new(
		panelStartPosition.X.Scale,
		panelStartPosition.X.Offset + delta.X,
		panelStartPosition.Y.Scale,
		panelStartPosition.Y.Offset + delta.Y
	)
end)

connect(UserInputService.InputEnded, function(input)
	if input == dragInput then
		dragging = false
		dragInput = nil
	end
end)

--// Distance collection
local function getCharacterRoot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function collectDistances(origin)
	local results = {}
	local visitedParts = {}
	local stack = {}
	local scannedParts = 0
	local visitedInstances = 0

	for _, folderName in ipairs(CONFIG.TargetFolders) do
		local folder = Workspace:FindFirstChild(folderName)

		if folder then
			table.clear(stack)
			table.insert(stack, folder)

			while #stack > 0 do
				local instance = table.remove(stack)
				visitedInstances += 1

				if instance:IsA("BasePart") and not visitedParts[instance] then
					visitedParts[instance] = true
					scannedParts += 1

					table.insert(results, {
						Name = instance:GetFullName(),
						Distance = (instance.Position - origin).Magnitude,
					})
				end

				if scannedParts >= CONFIG.MaximumScannedParts then
					break
				end

				for _, child in ipairs(instance:GetChildren()) do
					table.insert(stack, child)
				end

				if visitedInstances % CONFIG.YieldEvery == 0 then
					task.wait()
				end
			end
		end

		if scannedParts >= CONFIG.MaximumScannedParts then
			break
		end
	end

	table.sort(results, function(a, b)
		return a.Distance < b.Distance
	end)

	return results, scannedParts
end

local function clearRows()
	for _, row in ipairs(rows) do
		row.Text = ""
	end
end

local function updateDisplay()
	if not CONFIG.Enabled then
		statusLabel.Text = "Tracking paused"
		clearRows()
		return
	end

	local root = getCharacterRoot()
	if not root then
		statusLabel.Text = "Character root not available"
		clearRows()
		return
	end

	local results, scannedParts = collectDistances(root.Position)
	statusLabel.Text = string.format("%d parts checked", scannedParts)

	for index, row in ipairs(rows) do
		local result = results[index]

		if result then
			row.Text = string.format("%s  |  %.1f studs", result.Name, result.Distance)
		else
			row.Text = ""
		end
	end
end

--// Cleanup
local function cleanup()
	if not running then
		return
	end

	running = false

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)

	if screenGui.Parent then
		screenGui:Destroy()
	end
end

--// Startup
updateToggleButton()
connect(script.Destroying, cleanup)

task.spawn(function()
	while running and screenGui.Parent do
		local ok, err = pcall(updateDisplay)

		if not ok then
			warn("[DistanceDiagnostics] Update failed: " .. tostring(err))
		end

		task.wait(CONFIG.ScanInterval)
	end
end)
