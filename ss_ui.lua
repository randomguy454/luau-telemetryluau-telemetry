-- ════════════════════════════════════════════════════════════
--  SIMPLYSPIRITED v1.0 — ORION UI (Part 2/3)
--  For SHADOWMILESC (computerizedcarrier2)
--  Auto-boots the engine. Universal. Every game.
-- ════════════════════════════════════════════════════════════

local ENGINE_URL = "https://raw.githubusercontent.com/randomguy454/luau-telemetryluau-telemetry/refs/heads/main/simplyspirited.lua"

print("[SS-UI] loading Orion...")
local OrionLib
local okOrion = pcall(function()
    OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()
end)
if not okOrion or not OrionLib then
    warn("[SS-UI] Orion failed to load — check internet/executor")
    return
end

if not (getgenv().SS and getgenv().SS_READY) then
    print("[SS-UI] booting engine...")
    pcall(function()
        loadstring(game:HttpGet(ENGINE_URL .. "?nocache=" .. os.time()))()
    end)
    local t0 = os.clock()
    while not getgenv().SS_READY and os.clock() - t0 < 10 do task.wait(0.1) end
end
local SS = getgenv().SS
if not SS then warn("[SS-UI] engine failed to boot") return end

local Players = game:GetService("Players")
local P = Players.LocalPlayer

local function notify(title, text)
    OrionLib:MakeNotification({ Name = title, Content = text, Image = "rbxassetid://4483345998", Time = 4 })
end

-- ═══ TEXT -> TYPED VALUE PARSER ═══
local function parseArg(s)
    s = s:match("^%s*(.-)%s*$")
    if s == "true" then return true end
    if s == "false" then return false end
    if s == "nil" then return nil end
    local n = tonumber(s)
    if n then return n end
    local x, y, z = s:match("^V3%(([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)%)$")
    if x then return Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
    local r, g, b = s:match("^C3%((%d+),(%d+),(%d+)%)$")
    if r then return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)) end
    x, y, z = s:match("^CF%(([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)%)$")
    if x then return CFrame.new(tonumber(x), tonumber(y), tonumber(z)) end
    local str = s:match('^"(.*)"$')
    if str then return str end
    return s
end

-- ═══ WINDOW ═══
local Window = OrionLib:MakeWindow({
    Name = "SIMPLYSPIRITED — " .. SS.game,
    HidePremium = false, SaveConfig = false, ConfigFolder = "SimplySpirited",
})

-- ═══ TAB: DASHBOARD ═══
local T1 = Window:MakeTab({ Name = "Dashboard", Icon = "rbxassetid://4483345998", PremiumOnly = false })
T1:AddParagraph("SIMPLYSPIRITED v1.0",
    "Universal intelligence suite\nbuilt for SHADOWMILESC\n(display: computerizedcarrier2)")
local dRemotes = T1:AddLabel("remotes: —")
local dCalls = T1:AddLabel("calls captured: —")
local dValues = T1:AddLabel("values tracked: —")
T1:AddButton({ Name = "REFRESH STATS", Callback = function()
    local rc = 0
    for _ in pairs(SS.remotes) do rc = rc + 1 end
    local vn = 0
    for _ in pairs(SS.values) do vn = vn + 1 end
    pcall(function() dRemotes:Set("remotes: " .. rc) end)
    pcall(function() dCalls:Set("calls captured: " .. #SS.log) end)
    pcall(function() dValues:Set("values tracked: " .. vn) end)
end })
T1:AddToggle({ Name = "CAPTURE (master switch)", Default = SS.capture,
    Callback = function(v) SS.capture = v end })
T1:AddButton({ Name = "QUICK INTEL REPORT (print to console)", Callback = function()
    print("═══ SS QUICK INTEL ═══")
    print("game:", SS.game, "| place:", SS.placeId)
    local sorted = {}
    for r, info in pairs(SS.remotes) do
        if info.calls > 0 then sorted[#sorted + 1] = { r = r, i = info } end
    end
    table.sort(sorted, function(a, b) return a.i.calls > b.i.calls end)
    print("── top remotes by activity ──")
    for k = 1, math.min(15, #sorted) do
        print(("%4d calls | %s %s"):format(sorted[k].i.calls, sorted[k].r.ClassName, sorted[k].i.path))
    end
    print("── last 10 calls ──")
    for i = #SS.log, math.max(1, #SS.log - 9), -1 do
        local rec = SS.log[i]
        print(("#%d %s %s :: %s"):format(rec.id, rec.dir, rec.name, table.concat(rec.args, " | ")))
    end
    print("═══ end report ═══")
    notify("Intel", "report printed to console")
end })
T1:AddButton({ Name = "UNLOAD SUITE", Callback = function()
    SS.capture = false
    pcall(function() OrionLib:Destroy() end)
end })

-- ═══ TAB: REMOTE FEED ═══
local T2 = Window:MakeTab({ Name = "Remote Feed", Icon = "rbxassetid://4483345998", PremiumOnly = false })
T2:AddSection({ Name = "Live call feed (last 14)" })
local feedLines = {}
local feedLabels = {}
for i = 1, 14 do feedLabels[i] = T2:AddLabel("") end
SS.onCall = function(rec)
    local line = ("#%d %s%s %s | %s"):format(
        rec.id, rec.dir == "OUT" and ">" or "<", rec.name,
        rec.args[1] and rec.args[1]:sub(1, 50) or "")
    table.insert(feedLines, 1, line)
    if #feedLines > 14 then table.remove(feedLines) end
    for i = 1, 14 do
        pcall(function() feedLabels[i]:Set(feedLines[i] or "") end)
    end
end
T2:AddSection({ Name = "Noise filters" })
for key, val in pairs(SS.filters) do
    T2:AddToggle({ Name = "filter: " .. key, Default = val,
        Callback = function(v) SS.filters[key] = v end })
end
T2:AddTextbox({ Name = "add filter word", Default = "", TextDisappear = true,
    Callback = function(v)
        if v and #v > 1 then
            SS.filters[v:lower()] = true
            notify("Filter", v .. " added")
        end
    end })

-- ═══ TAB: REPLAYER ═══
local T3 = Window:MakeTab({ Name = "Replayer", Icon = "rbxassetid://4483345998", PremiumOnly = false })
T3:AddSection({ Name = "Re-fire any captured call" })
T3:AddParagraph("How it works", "Pick a captured call, edit args if you dare, fire again. Instance args stay original. Replaying purchases/combat can flag anti-cheat — start with count 1.")
local replayMap = {}
local replayTarget = nil
local replayText = ""
local infoLabel = T3:AddLabel("no call selected")
local argBox = T3:AddTextbox({ Name = "args (edit between |)", Default = "", TextDisappear = false,
    Callback = function(v) replayText = v end })
local replayDrop = T3:AddDropdown({ Name = "recent calls", Options = { "(refresh first)" },
    Default = "(refresh first)", Callback = function(v)
        local rec = replayMap[v]
        if rec then
            replayTarget = rec
            pcall(function() infoLabel:Set(rec.class .. " " .. rec.path) end)
            pcall(function() argBox:Set(table.concat(rec.args, " | ")) end)
        end
    end })
local rCount, rDelay = 1, 0.1
T3:AddSlider({ Name = "replay count", Min = 1, Max = 10, Default = 1, Increment = 1,
    Callback = function(v) rCount = v end })
T3:AddSlider({ Name = "delay between (s)", Min = 0.05, Max = 2, Default = 0.1, Increment = 0.05,
    Callback = function(v) rDelay = v end })
T3:AddButton({ Name = "REFRESH CALL LIST", Callback = function()
    local opts = {}
    replayMap = {}
    for i = #SS.log, math.max(1, #SS.log - 99), -1 do
        local rec = SS.log[i]
        local opt = ("#%d %s %s"):format(rec.id, rec.dir, rec.name)
        opts[#opts + 1] = opt
        replayMap[opt] = rec
    end
    pcall(function() replayDrop:Refresh(opts) end)
    notify("Replayer", #opts .. " calls listed")
end })
T3:AddButton({ Name = "REPLAY SELECTED", Callback = function()
    if not replayTarget then notify("Replayer", "select a call first") return end
    local r = replayTarget.remote
    if not r or not r.Parent then notify("Replayer", "remote no longer exists") return end
    local raw = replayTarget.raw or {}
    local textParts = {}
    for part in (replayText or ""):gmatch("[^|]+") do
        textParts[#textParts + 1] = part
    end
    local finalArgs = {}
    for i = 1, math.max(#raw, #textParts) do
        if textParts[i] then
            local v = parseArg(textParts[i])
            if typeof(v) == "string" and typeof(raw[i]) ~= "string" and typeof(raw[i]) ~= "nil" then
                finalArgs[i] = raw[i]
            else
                finalArgs[i] = v
            end
        else
            finalArgs[i] = raw[i]
        end
    end
    notify("Replayer", ("firing %s x%d"):format(replayTarget.name, rCount))
    task.spawn(function()
        for k = 1, rCount do
            if replayTarget.class == "RemoteEvent" then
                pcall(function() r:FireServer(unpack(finalArgs)) end)
            else
                pcall(function() r:InvokeServer(unpack(finalArgs)) end)
            end
            if k < rCount then task.wait(rDelay) end
        end
        notify("Replayer", "done")
    end)
end })

-- ═══ TAB: VALUES ═══
local T4 = Window:MakeTab({ Name = "Values", Icon = "rbxassetid://4483345998", PremiumOnly = false })
T4:AddSection({ Name = "Tracked values / currencies" })
local valLabels = {}
for i = 1, 10 do valLabels[i] = T4:AddLabel("") end
T4:AddButton({ Name = "REFRESH VALUES", Callback = function()
    local lines = {}
    for obj, v in pairs(SS.values) do
        if obj.Parent then
            lines[#lines + 1] = obj.Name .. " = " .. tostring(v)
        end
    end
    for i = 1, 10 do
        pcall(function() valLabels[i]:Set(lines[i] or "") end)
    end
    notify("Values", #lines .. " tracked")
end })

-- ═══ TAB: PLAYERS ═══
local T5 = Window:MakeTab({ Name = "Players", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local plLabels = {}
for i = 1, 10 do plLabels[i] = T5:AddLabel("") end
T5:AddButton({ Name = "REFRESH PLAYER CENSUS", Callback = function()
    local lines = {}
    for _, pl in ipairs(Players:GetPlayers()) do
        local st = ""
        pcall(function()
            local ls = pl:FindFirstChild("leaderstats")
            if ls then
                local bits = {}
                for _, d in ipairs(ls:GetChildren()) do
                    if d:IsA("ValueBase") then bits[#bits + 1] = d.Name .. ":" .. tostring(d.Value) end
                end
                st = " | " .. table.concat(bits, " ")
            end
        end)
        lines[#lines + 1] = pl.Name .. " (" .. pl.DisplayName .. ")" .. st
    end
    for i = 1, 10 do
        pcall(function() plLabels[i]:Set(lines[i] or "") end)
    end
    notify("Census", #lines .. " players")
end })

-- ═══ TAB: SCRIPT DUMPER ═══
local T6 = Window:MakeTab({ Name = "Script Dumper", Icon = "rbxassetid://4483345998", PremiumOnly = false })
T6:AddParagraph("Script Dumper",
    "Reads LocalScript/ModuleScript sources and saves them to Delta's workspace folder 'SimplySpirited'. Pull them onto your PC from there. Manifest included.")
local dumpContainer = "ReplicatedStorage"
T6:AddDropdown({ Name = "container", Options = { "ReplicatedStorage", "workspace", "Players", "ReplicatedFirst", "StarterGui", "StarterPlayer" },
    Default = "ReplicatedStorage", Callback = function(v) dumpContainer = v end })
local dumpMax = 500
T6:AddSlider({ Name = "max scripts", Min = 50, Max = 2000, Default = 500, Increment = 50,
    Callback = function(v) dumpMax = v end })
T6:AddButton({ Name = "DUMP SCRIPTS", Callback = function()
    task.spawn(function()
        pcall(function() makefolder("SimplySpirited") end)
        local root = dumpContainer == "Players" and P or game:GetService(dumpContainer)
        local n = 0
        local manifest = {}
        for _, d in ipairs(root:GetDescendants()) do
            if n >= dumpMax then break end
            if (d:IsA("LocalScript") or d:IsA("ModuleScript")) then
                pcall(function()
                    local src = d.Source
                    if src and #src > 0 then
                        local path = d:GetFullName():gsub("[^%w_]", "_"):sub(1, 120)
                        writefile("SimplySpirited/" .. path .. ".lua",
                            "-- " .. d:GetFullName() .. "\n" .. src)
                        manifest[#manifest + 1] = d:GetFullName() .. " (" .. #src .. " chars)"
                        n = n + 1
                    end
                end)
            end
        end
        writefile("SimplySpirited/_manifest.txt", table.concat(manifest, "\n"))
        notify("Dumper", n .. " scripts saved to workspace/SimplySpirited")
    end)
end })

-- ═══ BOOT ═══
OrionLib:Init()
print("[SS-UI] Orion interface live — suite complete for SHADOWMILESC")
notify("SIMPLYSPIRITED", "suite live in " .. SS.game)
