-- LocalScript for a Roblox experience you own.
-- Finds chest Models under configured folders and displays local distance diagnostics.

--// Configuration
local CONFIG = {
	ScanInterval = 1.5,
	YieldEvery = 200,
	MaximumScannedInstances = 5000,
	MaximumDistance = 10000,
	MaximumHighlights = 12,
	MaximumRows = 7,
	TargetFolders = { "ChestModels", "Map", "_WorldOrigin" },
	ChestTag = "Chest",
	MatchChestNames = true,
	MatchChestAttribute = true,
	HighlightsEnabled = true,
}

--// Services and shared state
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local running = true
local monitoring = true
local minimized = false
local activeTab = "Metrics"
local automationEnabled = false
local automationRange = 35
local automationGeneration = 0
local connections = {}
local highlights = {}
local latestChestTargets = {}
local scannedInstanceCount = 0
local missingFolderCount = 0
local latestFps = 0
local fpsFrames = 0
local fpsElapsed = 0
local scanGeneration = 0

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function makeLabel(parent, text, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(234, 237, 245)
	label.TextSize = textSize or 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function tween(instance, duration, properties)
	local animation = TweenService:Create(
		instance,
		TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		properties
	)
	animation:Play()
	return animation
end

local function formatPosition(position)
	return string.format("X %.1f   Y %.1f   Z %.1f", position.X, position.Y, position.Z)
end

--// Chest detection and spatial scan
local COMPONENT_SUFFIXES = {
	"bottom",
	"base",
	"lid",
	"handle",
	"hinge",
	"lock",
	"part",
}

local function isComponentModelName(name)
	local normalized = string.lower(name):gsub("[%W_]+", "")
	for _, suffix in ipairs(COMPONENT_SUFFIXES) do
		if #normalized > #suffix and normalized:sub(-#suffix) == suffix then
			return true
		end
	end
	return false
end

local function isChestModel(model)
	if not model:IsA("Model") then
		return false
	end

	local tagged = CollectionService:HasTag(model, CONFIG.ChestTag)
	local marked = CONFIG.MatchChestAttribute and model:GetAttribute("IsChest") == true
	if tagged or marked then
		return true
	end

	if not CONFIG.MatchChestNames or isComponentModelName(model.Name) then
		return false
	end

	return string.find(string.lower(model.Name), "chest", 1, true) ~= nil
end

local function getModelAnchor(model)
	local primaryPart = model.PrimaryPart
	if primaryPart then
		return primaryPart
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function getCharacterRoot()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function collectChestModels(origin, generation)
	local results = {}
	local seenModels = {}
	local stack = {}
	local visited = 0
	local foundFolders = 0

	for _, folderName in ipairs(CONFIG.TargetFolders) do
		if not running or not monitoring or generation ~= scanGeneration then
			return nil
		end

		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			foundFolders += 1
			table.clear(stack)
			table.insert(stack, folder)

			while #stack > 0 do
				if not running or not monitoring or generation ~= scanGeneration then
					return nil
				end

				local instance = table.remove(stack)
				visited += 1
				local matchedModel = false

				if instance:IsA("Model") and isChestModel(instance) and not seenModels[instance] then
					local anchor = getModelAnchor(instance)
					if anchor then
						seenModels[instance] = true
						matchedModel = true
						local distance = (anchor.Position - origin).Magnitude
						if distance <= CONFIG.MaximumDistance then
							table.insert(results, {
								Model = instance,
								Name = instance.Name,
								Position = anchor.Position,
								Distance = distance,
							})
						end
					end
				end

				-- Once a chest model is accepted, do not treat its nested component
				-- models as separate chests.
				if not matchedModel then
					for _, child in ipairs(instance:GetChildren()) do
						table.insert(stack, child)
					end
				end

				if visited % CONFIG.YieldEvery == 0 then
					task.wait()
				end

				if visited >= CONFIG.MaximumScannedInstances then
					break
				end
			end
		end

		if visited >= CONFIG.MaximumScannedInstances then
			break
		end
	end

	table.sort(results, function(a, b)
		return a.Distance < b.Distance
	end)

	return results, visited, #CONFIG.TargetFolders - foundFolders
end

--// Interface
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChestDiagnostics"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local main = Instance.new("Frame")
main.Name = "MainWindow"
main.Size = UDim2.fromOffset(430, 500)
main.Position = UDim2.new(0, 32, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(19, 21, 29)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = screenGui
makeCorner(main, 13)
makeStroke(main, Color3.fromRGB(57, 62, 78))

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundColor3 = Color3.fromRGB(29, 32, 43)
header.BorderSizePixel = 0
header.Parent = main
makeCorner(header, 13)

local accent = Instance.new("Frame")
accent.Size = UDim2.new(0, 4, 1, -14)
accent.Position = UDim2.fromOffset(0, 7)
accent.BackgroundColor3 = Color3.fromRGB(103, 112, 255)
accent.BorderSizePixel = 0
accent.Parent = header
makeCorner(accent, 3)

local title = makeLabel(
	header,
	"CHEST DIAGNOSTICS",
	UDim2.fromOffset(18, 0),
	UDim2.new(1, -74, 1, 0),
	14,
	Color3.fromRGB(245, 247, 252)
)
title.Font = Enum.Font.GothamBold

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "Minimize"
minimizeButton.Size = UDim2.fromOffset(34, 30)
minimizeButton.Position = UDim2.new(1, -45, 0, 11)
minimizeButton.BackgroundColor3 = Color3.fromRGB(43, 47, 60)
minimizeButton.BorderSizePixel = 0
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.Text = "−"
minimizeButton.TextColor3 = Color3.fromRGB(238, 241, 248)
minimizeButton.TextSize = 18
minimizeButton.Parent = header
makeCorner(minimizeButton, 8)

local tabBar = Instance.new("Frame")
tabBar.Name = "TabBar"
tabBar.Position = UDim2.fromOffset(16, 64)
tabBar.Size = UDim2.new(1, -32, 0, 38)
tabBar.BackgroundColor3 = Color3.fromRGB(29, 32, 43)
tabBar.BorderSizePixel = 0
tabBar.Parent = main
makeCorner(tabBar, 9)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 5)
tabLayout.Parent = tabBar

local pageContainer = Instance.new("Frame")
pageContainer.Name = "PageContainer"
pageContainer.Position = UDim2.fromOffset(16, 114)
pageContainer.Size = UDim2.new(1, -32, 1, -130)
pageContainer.BackgroundTransparency = 1
pageContainer.ClipsDescendants = true
pageContainer.Parent = main

local pages = {}
local tabButtons = {}

local function createPage(name)
	local page = Instance.new("Frame")
	page.Name = name .. "Page"
	page.Size = UDim2.fromScale(1, 1)
	page.Position = UDim2.fromOffset(0, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = pageContainer
	pages[name] = page
	return page
end

local function selectTab(name)
	if name == activeTab then
		return
	end

	local newPage = pages[name]
	if not newPage then
		return
	end

	activeTab = name
	for tabName, button in pairs(tabButtons) do
		local selected = tabName == name
		tween(button, 0.14, {
			BackgroundColor3 = selected
				and Color3.fromRGB(103, 112, 255)
				or Color3.fromRGB(42, 46, 59),
			TextColor3 = selected
				and Color3.fromRGB(255, 255, 255)
				or Color3.fromRGB(161, 168, 184),
		})
	end

	for pageName, page in pairs(pages) do
		if pageName ~= name then
			page.Visible = false
			page.Position = UDim2.fromOffset(0, 0)
		end
	end

	newPage.Position = UDim2.fromOffset(24, 0)
	newPage.Visible = true

	tween(newPage, 0.18, { Position = UDim2.fromOffset(0, 0) })
end

for _, name in ipairs({ "Metrics", "Spatial", "Automation", "Settings" }) do
	local button = Instance.new("TextButton")
	button.Name = name .. "Tab"
	button.Size = UDim2.new(1 / 4, -4, 0, 30)
	button.BackgroundColor3 = Color3.fromRGB(42, 46, 59)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.Text = name
	button.TextColor3 = Color3.fromRGB(161, 168, 184)
	button.TextSize = 12
	button.Parent = tabBar
	makeCorner(button, 7)
	tabButtons[name] = button
	createPage(name)

	connect(button.Activated, function()
		selectTab(name)
	end)
end

local function createMetricCard(parent, headingText, valueText, y)
	local card = Instance.new("Frame")
	card.Position = UDim2.fromOffset(0, y)
	card.Size = UDim2.new(1, 0, 0, 66)
	card.BackgroundColor3 = Color3.fromRGB(29, 32, 43)
	card.BorderSizePixel = 0
	card.Parent = parent
	makeCorner(card, 9)

	makeLabel(
		card,
		headingText,
		UDim2.fromOffset(13, 7),
		UDim2.new(1, -26, 0, 18),
		10,
		Color3.fromRGB(153, 161, 180)
	)

	local value = makeLabel(
		card,
		valueText,
		UDim2.fromOffset(13, 29),
		UDim2.new(1, -26, 0, 27),
		17,
		Color3.fromRGB(245, 247, 252)
	)
	value.Font = Enum.Font.GothamSemibold
	return value
end

local function createToggle(parent, name, titleText, description, initialValue, callback, y)
	local row = Instance.new("Frame")
	row.Name = name .. "Row"
	row.Position = UDim2.fromOffset(0, y)
	row.Size = UDim2.new(1, 0, 0, 62)
	row.BackgroundColor3 = Color3.fromRGB(29, 32, 43)
	row.BorderSizePixel = 0
	row.Parent = parent
	makeCorner(row, 9)

	local label = makeLabel(
		row,
		titleText,
		UDim2.fromOffset(13, 7),
		UDim2.new(1, -78, 0, 20),
		12,
		Color3.fromRGB(239, 241, 247)
	)
	label.Font = Enum.Font.GothamMedium
	makeLabel(
		row,
		description,
		UDim2.fromOffset(13, 31),
		UDim2.new(1, -78, 0, 18),
		10,
		Color3.fromRGB(153, 161, 180)
	)

	local track = Instance.new("TextButton")
	track.Name = name .. "Toggle"
	track.Position = UDim2.new(1, -59, 0.5, -12)
	track.Size = UDim2.fromOffset(44, 24)
	track.BackgroundColor3 = initialValue
		and Color3.fromRGB(103, 112, 255)
		or Color3.fromRGB(68, 72, 86)
	track.BorderSizePixel = 0
	track.Text = ""
	track.AutoButtonColor = false
	track.Parent = row
	makeCorner(track, 12)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = initialValue and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Color3.fromRGB(250, 251, 253)
	knob.BorderSizePixel = 0
	knob.Parent = track
	makeCorner(knob, 9)

	local enabled = initialValue
	local function setEnabled(value)
		if enabled == value then
			return
		end
		enabled = value
		tween(track, 0.15, {
			BackgroundColor3 = enabled
				and Color3.fromRGB(103, 112, 255)
				or Color3.fromRGB(68, 72, 86),
		})
		tween(knob, 0.15, {
			Position = enabled and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
		})
		callback(enabled)
	end

	connect(track.Activated, function()
		setEnabled(not enabled)
	end)
	return setEnabled
end

--// Metrics page
local metricsPage = pages.Metrics
local chestCountValue = createMetricCard(metricsPage, "CHESTS IN RANGE", "0", 0)
local scanCountValue = createMetricCard(metricsPage, "INSTANCES SCANNED", "0", 76)
local fpsValue = createMetricCard(metricsPage, "CLIENT FRAME RATE", "-- FPS", 152)
local metricsHint = makeLabel(
	metricsPage,
	"Models are counted once; loose parts and chest components are ignored.",
	UDim2.fromOffset(2, 234),
	UDim2.new(1, -4, 0, 38),
	10,
	Color3.fromRGB(153, 161, 180)
)
metricsHint.TextWrapped = true

--// Spatial page
local spatialPage = pages.Spatial
local characterPositionValue = createMetricCard(
	spatialPage,
	"CHARACTER POSITION",
	"Waiting for character...",
	0
)
characterPositionValue.TextSize = 12
local nearestChestValue = createMetricCard(spatialPage, "NEAREST CHEST", "No chest found", 76)
nearestChestValue.TextSize = 12
local nearestPositionValue = makeLabel(
	spatialPage,
	"Chest position: --",
	UDim2.fromOffset(3, 151),
	UDim2.new(1, -6, 0, 22),
	10,
	Color3.fromRGB(153, 161, 180)
)

local chestRows = table.create(CONFIG.MaximumRows)
for index = 1, CONFIG.MaximumRows do
	chestRows[index] = makeLabel(
		spatialPage,
		"",
		UDim2.fromOffset(3, 181 + (index - 1) * 24),
		UDim2.new(1, -6, 0, 21),
		11,
		Color3.fromRGB(220, 224, 234)
	)
end

--// Automation tab: passive proximity QA only; it never moves the character
-- or invokes interactions. The worker reports nearby chest candidates.
local automationPage = pages.Automation
local automationStatus = makeLabel(
	automationPage,
	"Monitor is off",
	UDim2.fromOffset(3, 0),
	UDim2.new(1, -6, 0, 24),
	11,
	Color3.fromRGB(153, 161, 180)
)

local automationTarget = createMetricCard(
	automationPage,
	"NEAREST CHEST CANDIDATE",
	"No candidate",
	34
)
automationTarget.TextSize = 13

local automationDistance = makeLabel(
	automationPage,
	"Distance: --",
	UDim2.fromOffset(3, 108),
	UDim2.new(1, -6, 0, 22),
	11,
	Color3.fromRGB(220, 224, 234)
)

local rangeCard = Instance.new("Frame")
rangeCard.Position = UDim2.fromOffset(0, 140)
rangeCard.Size = UDim2.new(1, 0, 0, 62)
rangeCard.BackgroundColor3 = Color3.fromRGB(29, 32, 43)
rangeCard.BorderSizePixel = 0
rangeCard.Parent = automationPage
makeCorner(rangeCard, 9)

makeLabel(
	rangeCard,
	"REPORTING RANGE",
	UDim2.fromOffset(13, 4),
	UDim2.new(1, -26, 0, 17),
	9,
	Color3.fromRGB(153, 161, 180)
)

local rangeValue = makeLabel(
	rangeCard,
	string.format("%d studs", automationRange),
	UDim2.fromOffset(13, 24),
	UDim2.new(1, -100, 0, 25),
	15,
	Color3.fromRGB(245, 247, 252)
)
rangeValue.Font = Enum.Font.GothamSemibold

local function createRangeButton(name, text, xOffset)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.new(1, xOffset, 0, 20)
	button.Size = UDim2.fromOffset(30, 28)
	button.BackgroundColor3 = Color3.fromRGB(48, 53, 68)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(235, 239, 247)
	button.TextSize = 16
	button.Parent = rangeCard
	makeCorner(button, 7)
	return button
end

local decreaseRangeButton = createRangeButton("DecreaseRange", "−", -76)
local increaseRangeButton = createRangeButton("IncreaseRange", "+", -40)

local proximityNote = makeLabel(
	automationPage,
	"Read-only monitor. No movement or interactions are performed.",
	UDim2.fromOffset(3, 211),
	UDim2.new(1, -6, 0, 44),
	10,
	Color3.fromRGB(153, 161, 180)
)
proximityNote.TextWrapped = true

--// Settings page
local settingsPage = pages.Settings
local rangeLabel = makeLabel(
	settingsPage,
	"Search range: 10,000 studs",
	UDim2.fromOffset(3, 0),
	UDim2.new(1, -6, 0, 25),
	11,
	Color3.fromRGB(153, 161, 180)
)

local trackingStatus = makeLabel(
	settingsPage,
	"Tracking is active",
	UDim2.fromOffset(3, 257),
	UDim2.new(1, -6, 0, 22),
	10,
	Color3.fromRGB(153, 161, 180)
)

local setAutomationToggle
local function setAutomationActive(enabled)
	automationEnabled = enabled
	automationGeneration += 1
	local generation = automationGeneration

	if not enabled then
		automationStatus.Text = "Monitor is off"
		automationTarget.Text = "No candidate"
		automationDistance.Text = "Distance: --"
		return
	end

	automationStatus.Text = "Starting passive proximity monitor..."
	task.spawn(function()
		while running and automationEnabled and generation == automationGeneration do
			local ok, err = pcall(function()
				local root = getCharacterRoot()
				if not root or not root.Parent then
					automationStatus.Text = "Paused: character unavailable"
					automationTarget.Text = "No candidate"
					automationDistance.Text = "Distance: --"
					if setAutomationToggle then
						setAutomationToggle(false)
					end
					return
				end

				local nearestModel
				local nearestDistance = math.huge
				for _, target in ipairs(latestChestTargets) do
					local model = target.Model
					if model and model.Parent then
						local anchor = getModelAnchor(model)
						if anchor and anchor.Parent then
							local distance = (anchor.Position - root.Position).Magnitude
							if distance < nearestDistance then
								nearestModel = model
								nearestDistance = distance
							end
						end
					end
				end

				if not nearestModel then
					automationStatus.Text = "Waiting: no chest targets found"
					automationTarget.Text = "No candidate"
					automationDistance.Text = "Distance: --"
				else
					automationTarget.Text = nearestModel.Name
					automationDistance.Text = string.format(
						"Distance: %.1f studs",
						nearestDistance
					)
					if nearestDistance <= automationRange then
						automationStatus.Text = "Candidate is within reporting range"
					else
						automationStatus.Text = "Monitoring nearest candidate"
					end
				end
			end)

			if not ok then
				warn("[ChestDiagnostics] Proximity monitor failed: " .. tostring(err))
				automationStatus.Text = "Monitor error; retrying"
			end
			task.wait(0.25)
		end
	end)
end

setAutomationToggle = createToggle(
	automationPage,
	"AutomationMonitor",
	"Proximity monitor",
	"Report the closest chest without interacting",
	false,
	setAutomationActive,
	220
)

connect(decreaseRangeButton.Activated, function()
	automationRange = math.max(5, automationRange - 5)
	rangeValue.Text = string.format("%d studs", automationRange)
end)

connect(increaseRangeButton.Activated, function()
	automationRange = math.min(250, automationRange + 5)
	rangeValue.Text = string.format("%d studs", automationRange)
end)

connect(player.CharacterRemoving, function()
	latestChestTargets = {}
	if setAutomationToggle then
		setAutomationToggle(false)
	end
	automationStatus.Text = "Paused: character resetting"
	automationTarget.Text = "No candidate"
	automationDistance.Text = "Distance: --"
end)

connect(player.CharacterAdded, function()
	latestChestTargets = {}
	if setAutomationToggle then
		setAutomationToggle(false)
	end
	automationStatus.Text = "Character ready; monitor is off"
end)

createToggle(
	settingsPage,
	"Tracking",
	"Live scanning",
	"Pause or resume distance tracking",
	true,
	function(enabled)
		monitoring = enabled
		scanGeneration += 1
		trackingStatus.Text = enabled and "Tracking is active" or "Tracking is paused"
		if not enabled then
			if setAutomationToggle then
				setAutomationToggle(false)
			end
			latestChestTargets = {}
			clearHighlights()
			chestCountValue.Text = "Paused"
			scanCountValue.Text = "Paused"
			nearestChestValue.Text = "Paused"
			nearestPositionValue.Text = "Chest position: --"
			for _, row in ipairs(chestRows) do
				row.Text = ""
			end
		end
	end,
	35
)

createToggle(
	settingsPage,
	"Highlights",
	"Model highlights",
	"Highlight up to 12 nearest chest models",
	CONFIG.HighlightsEnabled,
	function(enabled)
		CONFIG.HighlightsEnabled = enabled
		if not enabled then
			clearHighlights()
		end
	end,
	107
)

createToggle(
	settingsPage,
	"NameMatching",
	"Match chest names",
	"Find model names containing 'chest'",
	CONFIG.MatchChestNames,
	function(enabled)
		CONFIG.MatchChestNames = enabled
	end,
	179
)

local customRecognition = makeLabel(
	settingsPage,
	"Custom models: add the Chest tag or set IsChest = true.",
	UDim2.fromOffset(3, 253),
	UDim2.new(1, -6, 0, 40),
	10,
	Color3.fromRGB(153, 161, 180)
)
customRecognition.TextWrapped = true

--// Window controls and dragging
local expandedSize = UDim2.fromOffset(430, 500)
local collapsedSize = UDim2.fromOffset(430, 52)

connect(minimizeButton.Activated, function()
	minimized = not minimized
	minimizeButton.Text = minimized and "+" or "−"

	if minimized then
		tabBar.Visible = false
		pageContainer.Visible = false
		tween(main, 0.22, { Size = collapsedSize })
	else
		tween(main, 0.22, { Size = expandedSize })
		task.delay(0.1, function()
			if running and not minimized then
				tabBar.Visible = true
				pageContainer.Visible = true
			end
		end)
	end
end)

local dragging = false
local dragInput
local dragStart
local startPosition

connect(header.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragInput = input
		dragStart = input.Position
		startPosition = main.Position
	end
end)

connect(UserInputService.InputChanged, function(input)
	if not dragging or not dragInput then
		return
	end

	local mouseMovement = dragInput.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseMovement
	local touchMovement = dragInput.UserInputType == Enum.UserInputType.Touch
		and input == dragInput
	if mouseMovement or touchMovement then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end
end)

connect(UserInputService.InputEnded, function(input)
	if input == dragInput then
		dragging = false
		dragInput = nil
	end
end)

--// Rendering and telemetry
local function updateHighlights(results)
	if not CONFIG.HighlightsEnabled then
		clearHighlights()
		return
	end

	local active = {}
	local limit = math.min(#results, CONFIG.MaximumHighlights)
	for index = 1, limit do
		local model = results[index].Model
		if model and model.Parent then
			active[model] = true
			if not highlights[model] then
				local highlight = Instance.new("Highlight")
				highlight.Name = "ChestDiagnosticsHighlight"
				highlight.Adornee = model
				highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				highlight.FillColor = Color3.fromRGB(83, 191, 158)
				highlight.OutlineColor = Color3.fromRGB(225, 255, 245)
				highlight.FillTransparency = 0.78
				highlight.OutlineTransparency = 0.1
				highlight.Parent = Workspace
				highlights[model] = highlight
			end
		end
	end

	for model, highlight in pairs(highlights) do
		if not active[model] or not model.Parent then
			highlight:Destroy()
			highlights[model] = nil
		end
	end
end

local function renderMetrics(origin, results)
	chestCountValue.Text = tostring(#results)
	scanCountValue.Text = string.format("%d visited  |  %d missing folders", scannedInstanceCount, missingFolderCount)
	characterPositionValue.Text = formatPosition(origin)

	local nearest = results[1]
	if nearest then
		nearestChestValue.Text = string.format("%s  |  %.1f studs", nearest.Name, nearest.Distance)
		nearestPositionValue.Text = "Chest position: " .. formatPosition(nearest.Position)
	else
		nearestChestValue.Text = "No chest within range"
		nearestPositionValue.Text = "Chest position: --"
	end

	for index, row in ipairs(chestRows) do
		local result = results[index]
		if result then
			row.Text = string.format("%d. %s  |  %.1f studs", index, result.Name, result.Distance)
		else
			row.Text = ""
		end
	end
end

local function updateInterface(generation)
	if not running or not monitoring or generation ~= scanGeneration then
		return
	end

	local root = getCharacterRoot()
	if not root then
		characterPositionValue.Text = "Waiting for character..."
		nearestChestValue.Text = "No character root"
		nearestPositionValue.Text = "Chest position: --"
		chestCountValue.Text = "0"
		scanCountValue.Text = "0"
		latestChestTargets = {}
		clearHighlights()
		for _, row in ipairs(chestRows) do
			row.Text = ""
		end
		return
	end

	local results, visited, missing =
		collectChestModels(root.Position, generation)
	if not results then
		return
	end

	scannedInstanceCount = visited
	missingFolderCount = missing
	latestChestTargets = results
	updateHighlights(results)
	renderMetrics(root.Position, results)
end

connect(RunService.Heartbeat, function(deltaTime)
	fpsFrames += 1
	fpsElapsed += deltaTime
	if fpsElapsed >= 1 then
		latestFps = math.floor(fpsFrames / fpsElapsed + 0.5)
		fpsFrames = 0
		fpsElapsed = 0
		fpsValue.Text = string.format("%d FPS", latestFps)
	end
end)

--// Cleanup
local function cleanup()
	if not running then
		return
	end

	running = false
	scanGeneration += 1
	automationGeneration += 1
	automationEnabled = false
	clearHighlights()

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)

	if screenGui.Parent then
		screenGui:Destroy()
	end
end

--// Startup
pages.Metrics.Visible = true
tabButtons.Metrics.BackgroundColor3 = Color3.fromRGB(103, 112, 255)
tabButtons.Metrics.TextColor3 = Color3.fromRGB(255, 255, 255)
connect(script.Destroying, cleanup)

task.spawn(function()
	while running and screenGui.Parent do
		if monitoring then
			scanGeneration += 1
			local generation = scanGeneration
			local ok, err = pcall(function()
				updateInterface(generation)
			end)

			if not ok then
				warn("[ChestDiagnostics] Scan failed: " .. tostring(err))
			end
		end

		task.wait(CONFIG.ScanInterval)
	end
end)
