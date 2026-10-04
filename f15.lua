-- ════════════════════════════════════════════════════════════
--  BABFT OBJ ARCHITECT v7.5 — FINAL TUNED EDITION
--  ────────────────────────────────────────────────────────────
--  • CLOSED-LOOP budget solver: builds, measures, re-solves
--    until the real count fits (<= 4 passes)
--  • Decimator Tier 2 with TUNABLE tightness (cluster slider)
--  • Lower rasterization threshold: more true-angle plates,
--    less averaged clustering = smoother builds
--  • Exact rasterization (barycentric cull) + dual-axis verify
--  • Burst engine, chunked paint, STOP, DeleteTool cleanup
-- ════════════════════════════════════════════════════════════

local RUN_OK, RUN_ERR = pcall(function()

local Players = game:GetService("Players")
local P = Players.LocalPlayer

print("[v7.5] loading...")

local CONFIG = {
    BlockIDs   = { WoodBlock = 450, TitaniumBlock = 12272 },
    ZoneName   = "Really redZone",
    BuildAt    = Vector3.new(271, -10.4, -72),
    Stage      = Vector3.new(251.8, -11.9, -77.2),
    PaintChunk = 1000,
    ToolFloor  = 0.1,
    ZeroStreakAbort = 3,
}

local function firstOf(v) return typeof(v) == "table" and v[1] or v end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function fmtTime(sec)
    return string.format("%dm %02ds", math.floor(sec / 60), math.floor(sec % 60))
end

local STOP, BUILDING = false, false

local function tool(n)
    local ch = P.Character
    return (ch and ch:FindFirstChild(n)) or P.Backpack:FindFirstChild(n)
end

local function snapSet()
    local s = {}
    local f = workspace.Blocks:FindFirstChild(P.Name)
    if f then for _, c in ipairs(f:GetChildren()) do s[c] = true end end
    return s
end

local function alive(b) return typeof(b) == "Instance" and b.Parent ~= nil end

-- ═══════════════════════ BUILD ENGINE ═══════════════════════
local function runBuild(jobs, opts, ui)
    ui = ui or { log = print, status = function() end }
    opts = opts or {}
    STOP = false
    BUILDING = true
    local ok, err = pcall(function()
        assert(#jobs > 0, "no jobs to build")
        local zone = workspace:FindFirstChild(CONFIG.ZoneName)
        assert(zone, "zone not found - stand on your plot")
        local material = opts.material or "TitaniumBlock"
        local ID = assert(CONFIG.BlockIDs[material], "unknown material: " .. tostring(material))
        local BURST = opts.burst or 20
        local BURST_WAIT = opts.burstWait or 0.1
        local SCALE_WAIT = 0.08
        local verify = opts.verify ~= false

        for _, n in ipairs({ "BuildingTool", "PaintingTool", "ScalingTool", "PropertiesTool" }) do
            assert(tool(n), "missing tool: " .. n .. " - step off plot and back on")
        end
        ui.log("[engine] preflight ok - " .. #jobs .. " parts | burst " .. BURST .. " per " .. BURST_WAIT .. "s")

        local function firePlace(S)
            pcall(function()
                local t = tool("BuildingTool")
                if t and t:FindFirstChild("RF") then
                    t.RF:InvokeServer(material, ID, zone,
                        CFrame.new(S.Z - zone.Position.Z, S.Y - zone.Position.Y, -(S.X - zone.Position.X)),
                        true, CFrame.new(S) * CFrame.Angles(0, -math.pi / 2, 0), false, true)
                end
            end)
        end

        local bump = 0
        local zeroStreak = 0
        local built, fail = {}, {}
        local i = 1

        while i <= #jobs and not STOP do
            local batch = math.min(BURST, #jobs - i + 1)
            local before = snapSet()

            for k = 1, batch do
                firePlace(CONFIG.Stage + Vector3.new((k - 1) * 4, bump, 0))
            end
            task.wait(BURST_WAIT)

            local got = {}
            for c in pairs(snapSet()) do
                if not before[c] then got[#got + 1] = c end
            end
            local n = math.min(#got, batch)

            for k = 1, n do
                local j = jobs[i + k - 1]
                local b = got[k]
                pcall(function()
                    local t = tool("ScalingTool")
                    if t and t:FindFirstChild("RF") then
                        t.RF:InvokeServer(b, j.size, j.cf)
                    end
                end)
                if k % 5 == 0 then task.wait(SCALE_WAIT) end
            end
            task.wait(BURST_WAIT)

            local okCount = 0
            for k = 1, n do
                local j = jobs[i + k - 1]
                local b = got[k]
                if alive(b) then
                    local posErr = (b:GetPivot().Position - j.cf.Position).Magnitude
                    local rotOK = true
                    if verify and j.lv then
                        local lvA = math.abs(b:GetPivot().LookVector:Dot(j.cf.LookVector))
                        local upA = math.abs(b:GetPivot().UpVector:Dot(j.cf.UpVector))
                        rotOK = (lvA > 0.98) and (upA > 0.98)
                        if not rotOK then
                            pcall(function()
                                local t = tool("TrowelTool")
                                if t and t:FindFirstChild("OperationRF") then
                                    t.OperationRF:InvokeServer({ b }, b:GetPivot(), j.cf, "Rotate")
                                end
                            end)
                            task.wait(SCALE_WAIT)
                            if alive(b) then
                                lvA = math.abs(b:GetPivot().LookVector:Dot(j.cf.LookVector))
                                rotOK = lvA > 0.98
                            end
                        end
                    end
                    if posErr < 1 and rotOK then
                        built[i + k - 1] = b
                        okCount = okCount + 1
                    else
                        fail[#fail + 1] = j.name
                    end
                else
                    fail[#fail + 1] = j.name
                end
            end

            if okCount < n then
                ui.log("[engine] batch issues: " .. (n - okCount) .. " failed verify")
            end
            ui.status(string.format("BUILD %d/%d", math.min(i + n - 1, #jobs), #jobs))

            if n == 0 then
                zeroStreak = zeroStreak + 1
                ui.log("[engine] batch harvested 0 - cooldown " .. zeroStreak .. "/" .. CONFIG.ZeroStreakAbort)
                task.wait(1)
                if zeroStreak >= CONFIG.ZeroStreakAbort then
                    error("server stopped accepting placements - wait a minute and retry")
                end
            else
                zeroStreak = 0
                if n < batch then ui.log("[engine] partial batch " .. n .. "/" .. batch) end
                i = i + n
            end
            task.wait(0.1)
        end

        ui.status("PAINT")
        local pl = {}
        for idx, j in ipairs(jobs) do
            local b = built[idx]
            if b and b.Parent then pl[#pl + 1] = { b, j.color } end
        end
        for s = 1, #pl, CONFIG.PaintChunk do
            local pb = {}
            for x = s, math.min(s + CONFIG.PaintChunk - 1, #pl) do
                pb[#pb + 1] = pl[x]
            end
            pcall(function()
                local t = tool("PaintingTool")
                if t and t:FindFirstChild("RF") then
                    t.RF:InvokeServer({ pb })
                end
            end)
            task.wait(0.2)
        end

        local msg = string.format("DONE %d/%d | fails: %s", #pl, #jobs,
            (#fail == 0 and "none" or table.concat(fail, ",")))
        ui.log("[engine] " .. msg)
        ui.status(msg)
        return msg
    end)
    BUILDING = false
    return ok, err
end

-- ═══════════════════════ CLEANUP ════════════════════════════
local function cleanupAll()
    local t = tool("DeleteTool")
    assert(t, "DeleteTool missing - step off/on your plot")
    local f = workspace.Blocks:FindFirstChild(P.Name)
    if not f then return 0 end
    local n = 0
    for _, b in ipairs(f:GetChildren()) do
        pcall(function() t.RF:InvokeServer(b) end)
        n = n + 1
        task.wait(0.03)
    end
    return n
end

-- ═══════════════════════ OBJ PARSER ═════════════════════════
local function parseOBJ(text)
    assert(type(text) == "string" and #text > 10, "no OBJ text loaded")
    local verts, faces = {}, {}
    for line in text:gmatch("[^\r\n]+") do
        local pfx = line:sub(1, 2)
        if pfx == "v " or pfx == "v\t" then
            local x, y, z = line:match("^v%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)%s+([%-%+%.%deE]+)")
            if x then verts[#verts + 1] = Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
        elseif pfx == "f " or pfx == "f\t" then
            local f = {}
            for tok in line:gmatch("%S+") do
                if tok ~= "f" then
                    local vi = tonumber(tok:match("^(%-?%d+)"))
                    if vi then
                        if vi < 0 then vi = #verts + vi + 1 end
                        f[#f + 1] = vi
                    end
                end
            end
            if #f >= 3 then faces[#faces + 1] = f end
        end
    end
    assert(#verts >= 3, "no vertices parsed - invalid OBJ?")
    assert(#faces >= 1, "no faces parsed - OBJ needs f lines")
    return verts, faces
end

local function normalize(verts, fit)
    local mn = Vector3.new(math.huge, math.huge, math.huge)
    local mx = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, v in ipairs(verts) do
        mn = Vector3.new(math.min(mn.X, v.X), math.min(mn.Y, v.Y), math.min(mn.Z, v.Z))
        mx = Vector3.new(math.max(mx.X, v.X), math.max(mx.Y, v.Y), math.max(mx.Z, v.Z))
    end
    local s = fit / math.max(mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z)
    local nv = {}
    for i, v in ipairs(verts) do nv[i] = (v - (mn + mx) / 2) * s end
    return nv
end

-- ═══ CLOSED-LOOP BUDGET SOLVER + TUNED DECIMATOR (v7.5) ═════
-- Tier 1 threshold: cell^2 * 0.15 (3x wider door than v7.4)
-- Cluster neighborhood: cell * clusterAggr (default 0.9, tunable)
local function triPlates(verts, faces, opts)
    local nv = normalize(verts, opts.fit)
    local budget = opts.budget or 10000
    local clusterAggr = opts.clusterAggr or 0.9

    local totalArea = 0
    local triCount = 0
    local triList = {}
    for _, f in ipairs(faces) do
        for k = 2, #f - 1 do
            local A, B, Cp = nv[f[1]], nv[f[k]], nv[f[k + 1]]
            local e1, e2 = B - A, Cp - A
            local cr = e1:Cross(e2)
            if cr.Magnitude > 1e-9 then
                triCount = triCount + 1
                totalArea = totalArea + cr.Magnitude / 2
                triList[#triList + 1] = { A = A, B = B, C = Cp, e1 = e1, e2 = e2, cr = cr }
            end
        end
    end
    assert(triCount > 0, "no valid triangles")

    math.randomseed(7)
    local cell = clamp(math.sqrt(totalArea / budget), CONFIG.ToolFloor, 4)
    local plates, clusterCount = {}, 0

    for pass = 1, 4 do
        plates = {}
        clusterCount = 0
        local CLUSTER_CELL = cell * clusterAggr
        local grid = {}

        for _, t in ipairs(triList) do
            local triArea = t.cr.Magnitude / 2
            if triArea >= cell * cell * 0.15 then
                local n = t.cr.Unit
                local right = t.e1.Unit
                local up = n:Cross(right).Unit
                up = up - right * up:Dot(right)
                up = up.Unit
                local e1u = t.e1.Magnitude
                local cu, cv = t.e2:Dot(right), t.e2:Dot(up)
                if math.abs(cv) > 1e-9 then
                    local minU = math.min(0, e1u, cu)
                    local maxU = math.max(0, e1u, cu)
                    local minV = math.min(0, cv)
                    local maxV = math.max(0, cv)
                    local nu = math.max(1, math.ceil((maxU - minU) / cell))
                    local nv2 = math.max(1, math.ceil((maxV - minV) / cell))
                    local cw = (maxU - minU) / nu
                    local ch = (maxV - minV) / nv2
                    for iu = 1, nu do
                        for iv = 1, nv2 do
                            local u0 = minU + (iu - 1) * cw + cw / 2
                            local v0 = minV + (iv - 1) * ch + ch / 2
                            local c2 = v0 / cv
                            local b2 = (u0 - c2 * cu) / e1u
                            local a2 = 1 - b2 - c2
                            if a2 >= -0.02 and b2 >= -0.02 and c2 >= -0.02 then
                                plates[#plates + 1] = {
                                    pos = t.A + right * u0 + up * v0,
                                    right = right, up = up, n = n,
                                    w = cw + 0.08, h = ch + 0.08,
                                    t = opts.thick * (0.9 + math.random() * 0.2),
                                }
                            end
                        end
                    end
                end
            else
                local c = (t.A + t.B + t.C) / 3
                local key = math.floor(c.X / CLUSTER_CELL) .. "," ..
                    math.floor(c.Y / CLUSTER_CELL) .. "," ..
                    math.floor(c.Z / CLUSTER_CELL)
                local bucket = grid[key]
                if not bucket then
                    bucket = { pts = {}, n = Vector3.new(0, 0, 0) }
                    grid[key] = bucket
                end
                bucket.pts[#bucket.pts + 1] = t.A
                bucket.pts[#bucket.pts + 1] = t.B
                bucket.pts[#bucket.pts + 1] = t.C
                bucket.n = bucket.n + t.cr
                clusterCount = clusterCount + 1
            end
        end

        for _, bucket in pairs(grid) do
            if bucket.n.Magnitude > 1e-9 then
                local n = bucket.n.Unit
                local sx, sy, sz, cnt = 0, 0, 0, 0
                for _, p in ipairs(bucket.pts) do
                    sx = sx + p.X
                    sy = sy + p.Y
                    sz = sz + p.Z
                    cnt = cnt + 1
                end
                local center = Vector3.new(sx / cnt, sy / cnt, sz / cnt)
                local right = nil
                for _, p in ipairs(bucket.pts) do
                    local d = p - center
                    if d.Magnitude > 1e-6 and not right then
                        right = d.Unit
                    end
                end
                if not right then right = Vector3.new(1, 0, 0) end
                right = right - n * right:Dot(n)
                if right.Magnitude < 1e-6 then
                    right = n:Cross(Vector3.new(0, 1, 0))
                    if right.Magnitude < 1e-6 then right = n:Cross(Vector3.new(1, 0, 0)) end
                    right = right.Unit
                else
                    right = right.Unit
                end
                local up = n:Cross(right).Unit
                local minU, maxU = math.huge, -math.huge
                local minV, maxV = math.huge, -math.huge
                for _, p in ipairs(bucket.pts) do
                    local d = p - center
                    local u, v = d:Dot(right), d:Dot(up)
                    minU = math.min(minU, u)
                    maxU = math.max(maxU, u)
                    minV = math.min(minV, v)
                    maxV = math.max(maxV, v)
                end
                plates[#plates + 1] = {
                    pos = center + right * ((minU + maxU) / 2) + up * ((minV + maxV) / 2),
                    right = right, up = up, n = n,
                    w = (maxU - minU) + 0.15, h = (maxV - minV) + 0.15,
                    t = opts.thick * (0.9 + math.random() * 0.2),
                }
            end
        end

        if #plates <= budget then break end
        if pass < 4 then
            cell = clamp(cell * math.sqrt(#plates / budget) * 1.03, CONFIG.ToolFloor, 4)
        end
    end

    table.sort(plates, function(a, b) return a.pos.Y < b.pos.Y end)
    return plates, cell, totalArea, triCount, clusterCount
end

local function triJobs(plates, offsetY, colorMode)
    local base = CONFIG.BuildAt + Vector3.new(0, offsetY or 0, 0)
    local LIGHT = Vector3.new(0.4, 0.85, -0.3).Unit
    local minY, maxY = math.huge, -math.huge
    for _, p in ipairs(plates) do
        minY = math.min(minY, p.pos.Y)
        maxY = math.max(maxY, p.pos.Y)
    end
    local jobs = {}
    for i, p in ipairs(plates) do
        local col
        if colorMode == "Shaded" then
            local l = clamp(0.5 + 0.5 * p.n:Dot(LIGHT), 0, 1)
            col = Color3.fromRGB(90 + 110 * l, 95 + 110 * l, 100 + 110 * l)
        elseif colorMode == "Height Fade" then
            local a = (maxY > minY) and (p.pos.Y - minY) / (maxY - minY) or 0.5
            col = Color3.fromRGB(65, 70, 80):Lerp(Color3.fromRGB(205, 210, 215), a)
        elseif colorMode == "White" then
            col = Color3.fromRGB(240, 240, 240)
        else
            col = Color3.fromRGB(114, 118, 112)
        end
        jobs[#jobs + 1] = {
            name = "tri" .. i,
            size = Vector3.new(p.w, p.h, p.t),
            cf = CFrame.fromMatrix(base + p.pos, p.right, p.up),
            lv = p.n,
            color = col,
        }
    end
    return jobs
end

-- ═══════════════════════ JOB FACTORY ════════════════════════
local function genJobs(text, o)
    local vv, ff = parseOBJ(text)
    local plates, cellUsed, area, tris, clusters = triPlates(vv, ff, {
        fit = o.fit or 60,
        budget = o.budget or 10000,
        thick = o.thick or 0.6,
        clusterAggr = o.clusterAggr or 0.9,
    })
    local jobs = triJobs(plates, o.offsetY or 0, o.colorMode or "Shaded")
    return jobs, {
        cellUsed = math.floor(cellUsed * 1000) / 1000,
        area = math.floor(area),
        tris = tris,
        clusters = clusters,
    }
end

-- ═══════════════════════ EXPORTS ════════════════════════════
getgenv().BABFT_CLEAN = cleanupAll
getgenv().OBJ_BUILD = function(text, o)
    o = o or {}
    local jobs = genJobs(text, o)
    return runBuild(jobs, { material = o.material, burst = o.burst, burstWait = o.burstWait })
end

-- ═══════════════════════ RAYFIELD UI ════════════════════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Win = Rayfield:CreateWindow({
    Name = "BABFT OBJ Architect",
    LoadingTitle = "BABFT OBJ Architect",
    LoadingSubtitle = "v7.5 FINAL | tuned clusters, closed loop",
    ConfigurationSaving = { Enabled = false },
})

local function notify(t, c, d)
    Rayfield:Notify({ Title = t, Content = c, Duration = d or 5 })
end

local T = Win:CreateTab("OBJ Builder", 4483345998)

T:CreateSection("1. Load model")
local objText, urlInput, pasteInput = "", "", ""
T:CreateInput({ Name = "Model URL (raw.githubusercontent)",
    PlaceholderText = "https://raw.githubusercontent.com/.../model.obj",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) urlInput = t end })
T:CreateInput({ Name = "...or paste OBJ text (small)",
    PlaceholderText = "v 0 1 0 ... f 1 2 3",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) pasteInput = t end })
T:CreateButton({ Name = "LOAD MODEL", Callback = function()
    if #urlInput > 10 then
        local ok, data = pcall(function() return game:HttpGet(urlInput) end)
        if not ok or type(data) ~= "string" or #data < 10 then
            notify("Fetch failed", "Check URL - repo must be public", 6) return
        end
        if data:find("<!DOCTYPE html>") or data:find("<html") then
            notify("That's a webpage", "Use the RAW url", 6) return
        end
        objText = data
        notify("Model loaded", "From URL - " .. #data .. " chars", 4) return
    end
    if getgenv().OBJ_DATA and #getgenv().OBJ_DATA > 10 then
        objText = getgenv().OBJ_DATA
        notify("Model loaded", "OBJ_DATA - " .. #objText .. " chars", 4) return
    end
    if #pasteInput > 10 then
        objText = pasteInput
        notify("Model loaded", "Pasted - " .. #objText .. " chars", 4) return
    end
    notify("Nothing to load", "URL, OBJ_DATA, or paste text", 5)
end })

T:CreateSection("2. Budget & shape")
local budget, fit, thick, colorMode = 10000, 60, 0.6, "Shaded"
local material, burst, burstWait, verifyOn = "TitaniumBlock", 20, 0.1, true
local offsetY, clusterAggr = 0, 0.9
T:CreateSlider({ Name = "BLOCK BUDGET (solver target)", Range = { 500, 12000 }, Increment = 500,
    CurrentValue = 10000, Callback = function(v) budget = v end })
T:CreateSlider({ Name = "Fit size", Range = { 8, 120 }, Increment = 2,
    CurrentValue = 60, Callback = function(v) fit = v end })
T:CreateSlider({ Name = "Cluster tightness (lower = smoother)", Range = { 0.4, 1.5 }, Increment = 0.1,
    CurrentValue = 0.9, Callback = function(v) clusterAggr = v end })
T:CreateSlider({ Name = "Plate thickness", Range = { 0.1, 1 }, Increment = 0.05,
    CurrentValue = 0.6, Callback = function(v) thick = v end })
T:CreateSlider({ Name = "Height offset", Range = { -20, 20 }, Increment = 1,
    CurrentValue = 0, Callback = function(v) offsetY = v end })
T:CreateDropdown({ Name = "Color mode", Options = { "Shaded", "Height Fade", "Gray", "White" },
    CurrentOption = "Shaded", Callback = function(v) colorMode = firstOf(v) end })
T:CreateDropdown({ Name = "Material", Options = { "TitaniumBlock", "WoodBlock" },
    CurrentOption = "TitaniumBlock", Callback = function(v) material = firstOf(v) end })
T:CreateSlider({ Name = "Burst size", Range = { 1, 40 }, Increment = 1,
    CurrentValue = 20, Callback = function(v) burst = v end })
T:CreateSlider({ Name = "Burst wait", Range = { 0.05, 1 }, Increment = 0.05,
    CurrentValue = 0.1, Callback = function(v) burstWait = v end })
T:CreateToggle({ Name = "Verify rotation (recommended)", CurrentValue = true,
    Callback = function(v) verifyOn = v end })

T:CreateSection("3. Actions")
T:CreateButton({ Name = "ANALYZE (solver plan)", Callback = function()
    if #objText < 10 then notify("OBJ", "Load a model first", 4) return end
    local ok, jobs, info = pcall(function()
        local j, meta = genJobs(objText, { fit = fit, budget = budget,
            thick = thick, offsetY = offsetY, colorMode = colorMode,
            clusterAggr = clusterAggr })
        return j, meta
    end)
    if not ok then notify("Blocked", tostring(jobs), 8) return end
    notify("Solver plan", string.format(
        "%d blocks (budget %d) | cell %.3f | %d tris | %d clustered | %s",
        #jobs, budget, info.cellUsed, info.tris, info.clusters, fmtTime(#jobs * 0.12)), 10)
end })

T:CreateButton({ Name = "BUILD FROM OBJ", Callback = function()
    if BUILDING then notify("Busy", "A build is already running", 3) return end
    if #objText < 10 then notify("OBJ", "Load a model first", 4) return end
    local ok, jobs = pcall(function()
        return (genJobs(objText, { fit = fit, budget = budget,
            thick = thick, offsetY = offsetY, colorMode = colorMode,
            clusterAggr = clusterAggr }))
    end)
    if not ok then notify("Blocked", tostring(jobs), 8) return end
    notify("OBJ build", #jobs .. " blocks | " .. fmtTime(#jobs * 0.12) .. " - stay on plot!", 8)
    task.spawn(function()
        local ok2, msg = runBuild(jobs, { material = material, burst = burst,
            burstWait = burstWait, verify = verifyOn })
        notify("OBJ build", ok2 and tostring(msg) or ("Error: " .. tostring(msg)), 8)
    end)
end })

T:CreateButton({ Name = "STOP build", Callback = function() STOP = true end })

T:CreateSection("Cleanup")
T:CreateButton({ Name = "DELETE ALL MY BLOCKS", Callback = function()
    notify("Cleanup", "Deleting every block you own...", 4)
    task.spawn(function()
        local ok, n = pcall(cleanupAll)
        notify("Cleanup", ok and ("Deleted " .. tostring(n) .. " blocks")
            or ("Error: " .. tostring(n)), 6)
    end)
end })

T:CreateSection("Info")
T:CreateParagraph({ Title = "The contract", Content =
"Budget is law: the solver builds, measures, re-solves until the real count fits. Rasterization threshold lowered 3x - most facets now build at true angles. Cluster tightness slider: lower = smoother curves. Use a decimated mesh (10-16k tris) for best results." })

print("[Architect] v7.5 FINAL loaded - clusters tamed")

end)

if not RUN_OK then
    warn("[Architect FATAL] " .. tostring(RUN_ERR))
end
