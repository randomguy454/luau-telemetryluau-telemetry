-- LocalScript for your Roblox experience.
-- Tracks chest Models by name, the "Chest" CollectionService tag, or IsChest=true.
-- Each chest is one target; its BaseParts are never listed as separate targets.

--// Configuration
local CONFIG = {
	Enabled = true,
	HighlightsEnabled = true,
	ScanInterval = 1,
	YieldEvery = 150,
	MaximumScannedInstances = 5000,
	MaximumRows = 8,
	MaximumHighlights = 8,
	MaximumDistance = 10000,
	HighlightFillColor = Color3.fromRGB(60, 190, 145),
	HighlightOutlineColor = Color3.fromRGB(225, 255, 245),
	TargetFolders = { "ChestModels", "Map", "_WorldOrigin" },
	ChestTag = "Chest",
}

--// Services and state
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local running = true
local connections = {}
local highlights = {}
local activeHighlightTargets = {}

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
panel.Size = UDim2.fromOffset(320, 350)
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
header.Text = "  Chest Diagnostics"
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

local highlightButton = Instance.new("TextButton")
highlightButton.Name = "HighlightToggle"
highlightButton.Position = UDim2.fromOffset(12, 88)
highlightButton.Size = UDim2.new(1, -24, 0, 32)
highlightButton.BorderSizePixel = 0
highlightButton.Font = Enum.Font.GothamMedium
highlightButton.TextColor3 = Color3.fromRGB(240, 243, 248)
highlightButton.TextSize = 12
highlightButton.Parent = panel

local highlightButtonCorner = Instance.new("UICorner")
highlightButtonCorner.CornerRadius = UDim.new(0, 6)
highlightButtonCorner.Parent = highlightButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Position = UDim2.fromOffset(12, 128)
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
	row.Position = UDim2.fromOffset(12, 156 + (index - 1) * 22)
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

local function clearHighlights()
	for part, highlight in pairs(highlights) do
		highlight:Destroy()
		highlights[part] = nil
	end
	table.clear(activeHighlightTargets)
end

local function updateHighlightButton()
	highlightButton.Text = CONFIG.HighlightsEnabled and "Highlights: ON" or "Highlights: OFF"
	highlightButton.BackgroundColor3 = CONFIG.HighlightsEnabled
		and Color3.fromRGB(45, 130, 100)
		or Color3.fromRGB(65, 69, 80)
end

local function syncHighlights(results)
	table.clear(activeHighlightTargets)

	if not CONFIG.HighlightsEnabled then
		clearHighlights()
		return
	end

	local count = math.min(#results, CONFIG.MaximumHighlights)
	for index = 1, count do
		local model = results[index].Model
		if model and model.Parent then
			activeHighlightTargets[model] = true

			if not highlights[model] then
				local highlight = Instance.new("Highlight")
				highlight.Name = "DistanceDiagnosticsHighlight"
				highlight.Adornee = model
				highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				highlight.FillColor = CONFIG.HighlightFillColor
				highlight.OutlineColor = CONFIG.HighlightOutlineColor
				highlight.FillTransparency = 0.78
				highlight.OutlineTransparency = 0.1
				highlight.Parent = Workspace
				highlights[model] = highlight
			end
		end
	end

	for model, highlight in pairs(highlights) do
		if not activeHighlightTargets[model] or not model.Parent then
			highlight:Destroy()
			highlights[model] = nil
		end
	end
end

connect(toggleButton.Activated, function()
	CONFIG.Enabled = not CONFIG.Enabled
	updateToggleButton()
	if not CONFIG.Enabled then
		clearHighlights()
	end
end)

connect(highlightButton.Activated, function()
	CONFIG.HighlightsEnabled = not CONFIG.HighlightsEnabled
	updateHighlightButton()
	if not CONFIG.HighlightsEnabled then
		clearHighlights()
	end
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

local COMPONENT_NAME_PATTERNS = {
	"bottom",
	"base",
	"lid",
	"handle",
	"hinge",
	"lock",
	"part",
}

local function isComponentModelName(name)
	local normalized = string.lower(name):gsub("[%s_%-]+", "")
	for _, componentName in ipairs(COMPONENT_NAME_PATTERNS) do
		if normalized:match(componentName .. "$") then
			return true
		end
	end
	return false
end

local function isChestModel(model)
	if not model:IsA("Model") or isComponentModelName(model.Name) then
		return false
	end

	local taggedAsChest = CollectionService:HasTag(model, CONFIG.ChestTag)
	local markedAsChest = model:GetAttribute("IsChest") == true
	local namedAsChest = string.find(string.lower(model.Name), "chest", 1, true) ~= nil
	return taggedAsChest or markedAsChest or namedAsChest
end

local function getModelAnchor(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function collectDistances(origin)
	local results = {}
	local visitedModels = {}
	local stack = {}
	local visitedInstances = 0
	local scannedInstances = 0

	for _, folderName in ipairs(CONFIG.TargetFolders) do
		local folder = Workspace:FindFirstChild(folderName)

		if folder then
			table.clear(stack)
			table.insert(stack, folder)

			while #stack > 0 do
				local instance = table.remove(stack)
				visitedInstances += 1
				scannedInstances += 1

				if instance:IsA("Model") and isChestModel(instance) and not visitedModels[instance] then
					visitedModels[instance] = true
					local anchor = getModelAnchor(instance)
					if anchor then
						local distance = (anchor.Position - origin).Magnitude
						if distance <= CONFIG.MaximumDistance then
							table.insert(results, {
								Model = instance,
								Name = instance.Name,
								Distance = distance,
							})
						end
					end
				else
					for _, child in ipairs(instance:GetChildren()) do
						table.insert(stack, child)
					end
				end

				if scannedInstances >= CONFIG.MaximumScannedInstances then
					break
				end

				if visitedInstances % CONFIG.YieldEvery == 0 then
					task.wait()
				end
			end
		end

		if scannedInstances >= CONFIG.MaximumScannedInstances then
			break
		end
	end

	table.sort(results, function(a, b)
		return a.Distance < b.Distance
	end)

	return results, scannedInstances
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
		clearHighlights()
		return
	end

	local root = getCharacterRoot()
	if not root then
		statusLabel.Text = "Character root not available"
		clearRows()
		clearHighlights()
		return
	end

	local results, scannedInstances = collectDistances(root.Position)
	syncHighlights(results)
	statusLabel.Text = string.format(
		"%d chests in range  |  %d instances scanned",
		#results,
		scannedInstances
	)

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
	clearHighlights()

	if screenGui.Parent then
		screenGui:Destroy()
	end
end

--// Startup
updateToggleButton()
updateHighlightButton()
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
