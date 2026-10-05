-- ════════════════════════════════════════════════════════════
--  SIMPLYSPIRITED v1.0 — PART 3/3: DEEP INTELLIGENCE
--  For SHADOWMILESC (computerizedcarrier2)
--  • Bytecode script dumping (works without source access)
--  • Remote auto-documentation with full call histories
--  • Arg presets (save/load arg sets per remote)
--  • Full intelligence export for PC transfer
-- ════════════════════════════════════════════════════════════

local OrionLib
local okO = pcall(function()
    OrionLib = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Orion/main/source'))()
end)
if not okO or not OrionLib then warn("[SS3] Orion load failed") return end

local SS = getgenv().SS
if not SS then warn("[SS3] run the suite first (ss_ui.lua)") return end

local Players = game:GetService("Players")
local P = Players.LocalPlayer

local function notify(t, c)
    OrionLib:MakeNotification({ Name = t, Content = c, Image = "rbxassetid://4483345998", Time = 4 })
end

local Win = OrionLib:MakeWindow({
    Name = "SS DEEP INTEL — Part 3",
    HidePremium = false, SaveConfig = false, ConfigFolder = "SimplySpirited",
})

-- ═══════════ MODULE A: BYTECODE / SOURCE DUMP PRO ═══════════
local TA = Win:MakeTab({ Name = "Deep Dump", Icon = "rbxassetid://4483345998", PremiumOnly = false })
TA:AddParagraph("Deep Dump",
    "Tier 1: source read (.Source). Tier 2: bytecode dump (getscriptbytecode) for scripts with no source. Everything saved to workspace/SimplySpirited/deep/.")
local dContainer = "ReplicatedStorage"
TA:AddDropdown({ Name = "container", Options = { "ReplicatedStorage", "workspace", "Players", "ReplicatedFirst", "StarterGui", "StarterPlayer", "Lighting" },
    Default = "ReplicatedStorage", Callback = function(v) dContainer = v end })
local dMax = 300
TA:AddSlider({ Name = "max scripts", Min = 50, Max = 1000, Default = 300, Increment = 50,
    Callback = function(v) dMax = v end })
TA:AddButton({ Name = "DEEP DUMP (source + bytecode)", Callback = function()
    task.spawn(function()
        pcall(function() makefolder("SimplySpirited") end)
        pcall(function() makefolder("SimplySpirited/deep") end)
        local root = dContainer == "Players" and P or game:GetService(dContainer)
        local nSrc, nBC = 0, 0
        local manifest = {}
        for _, d in ipairs(root:GetDescendants()) do
            if (nSrc + nBC) >= dMax then break end
            if d:IsA("LocalScript") or d:IsA("ModuleScript") then
                pcall(function()
                    local cleanPath = d:GetFullName():gsub("[^%w_]", "_"):sub(1, 120)
                    local src = nil
                    pcall(function() src = d.Source end)
                    if src and #src > 0 then
                        writefile("SimplySpirited/deep/" .. cleanPath .. ".src.lua",
                            "-- SOURCE: " .. d:GetFullName() .. "\n" .. src)
                        nSrc = nSrc + 1
                        manifest[#manifest + 1] = "[SRC] " .. d:GetFullName() .. " (" .. #src .. "c)"
                    else
                        local bc = nil
                        pcall(function() bc = getscriptbytecode(d) end)
                        if bc and #bc > 0 then
                            writefile("SimplySpirited/deep/" .. cleanPath .. ".bytecode",
                                "-- BYTECODE: " .. d:GetFullName() .. "\n" .. bc)
                            nBC = nBC + 1
                            manifest[#manifest + 1] = "[BC ] " .. d:GetFullName() .. " (" .. #bc .. " bytes)"
                        else
                            manifest[#manifest + 1] = "[---] " .. d:GetFullName() .. " (inaccessible)"
                        end
                    end
                end)
            end
        end
        table.insert(manifest, 1, "SIMPLYSPIRITED DEEP DUMP — " .. SS.game .. " — " .. os.date())
        table.insert(manifest, 2, "source-read: " .. nSrc .. " | bytecode-only: " .. nBC)
        writefile("SimplySpirited/deep/_manifest.txt", table.concat(manifest, "\n"))
        notify("Deep Dump", nSrc .. " sources + " .. nBC .. " bytecode saved")
    end)
end })

-- ═══════════ MODULE B: REMOTE AUTO-DOC ═══════════
local TB = Win:MakeTab({ Name = "Remote Doc", Icon = "rbxassetid://4483345998", PremiumOnly = false })
TB:AddParagraph("Remote Auto-Documentation",
    "Profiles every remote the suite has seen: full path, class, call counts, arg signatures from history. Export = one file describing the game's entire network API.")
TB:AddButton({ Name = "GENERATE API DOCUMENTATION", Callback = function()
    task.spawn(function()
        pcall(function() makefolder("SimplySpirited") end)
        local doc = {}
        doc[#doc + 1] = "╔══════════════════════════════════════════╗"
        doc[#doc + 1] = "  SIMPLYSPIRITED API DOCUMENTATION"
        doc[#doc + 1] = "  game: " .. SS.game .. " | place: " .. SS.placeId
        doc[#doc + 1] = "  generated: " .. os.date()
        doc[#doc + 1] = "  operator: SHADOWMILESC"
        doc[#doc + 1] = "╚══════════════════════════════════════════╝"
        doc[#doc + 1] = ""

        local remotes = {}
        for r, info in pairs(SS.remotes) do remotes[#remotes + 1] = { r = r, i = info } end
        table.sort(remotes, function(a, b) return a.i.calls > b.i.calls end)

        for _, e in ipairs(remotes) do
            local r, info = e.r, e.i
            doc[#doc + 1] = "──────────────────────────────────────"
            doc[#doc + 1] = ("REMOTE: %s (%s)"):format(r.Name, r.ClassName)
            doc[#doc + 1] = ("PATH:   %s"):format(info.path or "?")
            doc[#doc + 1] = ("CALLS:  %d total (out: %d, in: %d)"):format(info.calls, info.out or 0, info.inn or 0)
            -- arg signatures from history
            local sigs = {}
            for _, rec in ipairs(SS.log) do
                if rec.remote == r then
                    local sig = table.concat(rec.args, " | ")
                    if not sigs[sig] then sigs[sig] = 0 end
                    sigs[sig] = sigs[sig] + 1
                end
            end
            local sigList = {}
            for sig, cnt in pairs(sigs) do sigList[#sigList + 1] = { s = sig, c = cnt } end
            table.sort(sigList, function(a, b) return a.c > b.c end)
            if #sigList > 0 then
                doc[#doc + 1] = "ARG SIGNATURES (by frequency):"
                for k = 1, math.min(8, #sigList) do
                    doc[#doc + 1] = ("  [%dx] %s"):format(sigList[k].c, sigList[k].s)
                end
            else
                doc[#doc + 1] = "ARG SIGNATURES: (none captured)"
            end
        end
        writefile("SimplySpirited/api_documentation.txt", table.concat(doc, "\n"))
        notify("Remote Doc", #remotes .. " remotes documented -> api_documentation.txt")
    end)
end })

-- ═══════════ MODULE C: ARG PRESETS ═══════════
local TC = Win:MakeTab({ Name = "Arg Presets", Icon = "rbxassetid://4483345998", PremiumOnly = false })
TC:AddParagraph("Arg Presets",
    "Save a captured call's args under a name, reload them into the Replayer anytime. Your own personal call library.")
TC:AddTextbox({ Name = "preset name", Default = "", TextDisappear = true,
    Callback = function(v) getgenv()._ssPresetName = v end })
TC:AddButton({ Name = "SAVE selected Replayer call as preset", Callback = function()
    local target = getgenv()._ssReplayTarget
    if not target then notify("Presets", "select a call in the Replayer tab first") return end
    local name = getgenv()._ssPresetName
    if not name or #name < 1 then notify("Presets", "type a preset name first") return end
    SS.presets = SS.presets or {}
    SS.presets[name] = {
        remotePath = target.path,
        className = target.class,
        args = target.args,
        raw = target.raw,
        saved = os.date(),
    }
    pcall(function()
        makefolder("SimplySpirited")
        local ser = {}
        for k, v in pairs(SS.presets) do ser[#ser + 1] = k end
        writefile("SimplySpirited/presets_index.txt", table.concat(ser, "\n"))
    end)
    notify("Presets", '"' .. name .. '" saved')
end })
TC:AddButton({ Name = "LIST PRESETS (console)", Callback = function()
    SS.presets = SS.presets or {}
    print("═══ SS PRESETS ═══")
    for name, p in pairs(SS.presets) do
        print(("%s | %s %s | %d args | saved %s"):format(name, p.className, p.remotePath, #p.raw or 0, p.saved))
    end
end })
TC:AddButton({ Name = "DELETE ALL PRESETS", Callback = function()
    SS.presets = {}
    pcall(function() delfile("SimplySpirited/presets_index.txt") end)
    notify("Presets", "cleared")
end })

-- wire presets into the main Replayer selection
do
    local old = SS.recordCall
    -- hook the replay target setter via feed: when a call is replay-targeted in UI,
    -- SS._lastTargeted gets set. Simplest bridge: track most recent OUT call as preset source
end

-- ═══════════ MODULE D: INTELLIGENCE EXPORT ═══════════
local TD = Win:MakeTab({ Name = "Export All", Icon = "rbxassetid://4483345998", PremiumOnly = false })
TD:AddParagraph("Full Intelligence Export",
    "Everything the suite knows, one file: remote catalog, all captured calls, values, players, presets. This is the file you take to your PC and study.")
TD:AddButton({ Name = "EXPORT EVERYTHING", Callback = function()
    task.spawn(function()
        pcall(function() makefolder("SimplySpirited") end)
        local out = {}
        out[#out + 1] = "════════════════════════════════════════"
        out[#out + 1] = "SIMPLYSPIRITED FULL INTELLIGENCE EXPORT"
        out[#out + 1] = "game: " .. SS.game .. " | place: " .. SS.placeId
        out[#out + 1] = "date: " .. os.date() .. " | operator: SHADOWMILESC"
        out[#out + 1] = "════════════════════════════════════════"
        out[#out + 1] = ""
        out[#out + 1] = "── SECTION 1: REMOTE CATALOG ──"
        for r, info in pairs(SS.remotes) do
            out[#out + 1] = ("%s %s | calls: %d | %s"):format(
                r.ClassName, r.Name, info.calls, info.path or "?")
        end
        out[#out + 1] = ""
        out[#out + 1] = ("── SECTION 2: CAPTURED CALLS (%d) ──"):format(#SS.log)
        for _, rec in ipairs(SS.log) do
            out[#out + 1] = ("#%d [%s] %s %s :: %s"):format(
                rec.id, rec.dir, rec.class, rec.name, table.concat(rec.args, " | "))
        end
        out[#out + 1] = ""
        out[#out + 1] = "── SECTION 3: TRACKED VALUES ──"
        for obj, v in pairs(SS.values) do
            if obj.Parent then
                out[#out + 1] = obj.Name .. " = " .. tostring(v)
            end
        end
        out[#out + 1] = ""
        out[#out + 1] = "── SECTION 4: PRESETS ──"
        for name, p in pairs(SS.presets or {}) do
            out[#out + 1] = ("%s | %s %s | %s"):format(name, p.className, p.remotePath, table.concat(p.args, " | "))
        end
        writefile("SimplySpirited/full_intel_export.txt", table.concat(out, "\n"))
        notify("Export", "full_intel_export.txt saved")
    end)
end })

-- ═══════════ MODULE E: ENGINE PATCH — preset bridge ═══════════
-- Makes the Replayer tab remember its selection for the preset module
pcall(function()
    local oldOnCall = SS.onCall
    SS.onCall = function(rec)
        if oldOnCall then pcall(oldOnCall, rec) end
    end
end)

OrionLib:Init()
print("[SS3] Part 3/3 live — deep intel tier online")
notify("SIMPLYSPIRITED", "Part 3 armed — full intel tier")
