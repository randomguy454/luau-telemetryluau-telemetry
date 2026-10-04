-- ════════════════════════════════════════════════════════════
--  BABFT ARCHITECT v5.0 — FINAL
--  Burst engine | Precision rotation | Self-cleanup
--  F-15 + OBJ voxel cubes + OBJ triangle plates
-- ════════════════════════════════════════════════════════════

local RUN_OK, RUN_ERR = pcall(function()

local Players = game:GetService("Players")
local P = Players.LocalPlayer

local CONFIG = {
    BlockIDs = { WoodBlock = 450, TitaniumBlock = 12272 },
    ZoneName = "Really redZone",
    BuildAt  = Vector3.new(271, -10.4, -72),
    Stage    = Vector3.new(251.8, -11.9, -77.2),
    MaxVoxels = 7000,
}

local C = {
    MID = Color3.fromRGB(114, 118, 112),
    LTG = Color3.fromRGB(185, 188, 184),
    DK  = Color3.fromRGB(52, 54, 52),
    BLK = Color3.fromRGB(20, 20, 22),
    GLD = Color3.fromRGB(170, 134, 54),
}

local function V(x, y, z) return Vector3.new(x, y, z) end
local function firstOf(v) return typeof(v) == "table" and v[1] or v end
local function fmtTime(sec)
    return string.format("%dm %02ds", math.floor(sec / 60), math.floor(sec % 60))
end

local BASE = {
    {"radomeA", V(1.2, 1.2, 5),   V(0, 0.1, -10.5),  {0, 0, 45}, C.DK},
    {"radomeB", V(2.6, 2.4, 4),   V(0, 0.05, -6.2),  {0, 0, 0},  C.DK},
    {"noseFus", V(3.2, 3, 4),     V(0, 0, -1.8),     {0, 0, 0},  C.MID},
    {"canopyM", V(1.8, 1.8, 4.2), V(0, 2.2, -5.6),   {0, 0, 0},  C.GLD},
    {"canopyR", V(1.3, 1.3, 2.8), V(0, 1.85, -2.4),  {0, 0, 45}, C.GLD},
    {"midFus",  V(3.4, 3.2, 6),   V(0, 0, 3.4),      {0, 0, 0},  C.MID},
    {"aftFus",  V(3.6, 3, 6.5),   V(0, 0.15, 9.9),   {0, 0, 0},  C.MID},
    {"bellyF",  V(2.6, 1.1, 7),   V(0, -1.85, 0.5),  {0, 0, 0},  C.LTG},
    {"bellyA",  V(2.8, 1.3, 7),   V(0, -1.8, 7.5),   {0, 0, 0},  C.LTG},
    {"spine",   V(1.6, 1.2, 8),   V(0, 1.85, 3.8),   {0, 0, 0},  C.MID},
    {"intL",  V(2.2, 2.8, 9.5),   V(-2.8, -0.15, 0.9), {0, 0, 0},  C.MID, true},
    {"inlL",  V(1.5, 2.1, 0.6),   V(-3, -0.25, -4.1),  {0, 0, 0},  C.BLK, true},
    {"wingL", V(6.5, 0.6, 7),     V(-5.1, 0.4, 0.6),   {0, 26, 0}, C.MID, true},
    {"railL", V(0.45, 1.1, 3),    V(-8.2, 1.1, 2.1),   {0, 26, 0}, C.DK,  true},
    {"aim9L", V(0.55, 0.55, 4.6), V(-8.2, 2, 2.1),     {0, 26, 0}, C.LTG, true},
    {"mslL",  V(0.6, 0.6, 5),     V(-4.7, -0.35, 0.8), {0, 26, 0}, C.LTG, true},
    {"mslL2", V(0.6, 0.6, 5),     V(-6.4, -0.35, 1.3), {0, 26, 0}, C.LTG, true},
    {"fairL", V(0.8, 1.6, 6),     V(-1.72, 2.55, 3.4), {0, 0, 0},  C.MID, true},
    {"vtL",   V(0.7, 5.5, 5.5),   V(-1.75, 4.5, 8.9),  {0, 0, 6},  C.MID, true},
    {"hstL",  V(4.5, 0.5, 3.5),   V(-3.3, 0.55, 11.3), {0, 30, 0}, C.MID, true},
    {"nozL",  V(1.7, 1.7, 3),     V(-0.95, 0.1, 12.7), {0, 0, 0},  C.DK,  true},
}
local PARTS = {}
for _, d in ipairs(BASE) do PARTS[#PARTS + 1] = d end
for _, d in ipairs(BASE) do
    if d[6] then
        PARTS[#PARTS + 1] = { d[1] .. "R", d[2],
            V(-d[3].X, d[3].Y, d[3].Z),
            { d[4][1], -d[4][2], -d[4][3] }, d[5] }
    end
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
-- jobs: {name, size, cf, color, lv?}
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
        local SCALE_WAIT = opts.scaleWait or 0.08
        local POST = opts.postBatch or 0.1
        local verify = opts.verify ~= false
        local fixRot = opts.fixRot ~= false

        for _, n in ipairs({ "BuildingTool", "PaintingTool", "ScalingTool", "PropertiesTool" }) do
            assert(tool(n), "missing tool: " .. n)
        end
        ui.log("[engine] preflight ok - " .. #jobs .. " parts | burst " .. BURST .. " per " .. BURST_WAIT .. "s")

        local function firePlace(S)
            pcall(function()
                tool("BuildingTool").RF:InvokeServer(material, ID, zone,
                    CFrame.new(S.Z - zone.Position.Z, S.Y - zone.Position.Y, -(S.X - zone.Position.X)),
                    true, CFrame.new(S) * CFrame.Angles(0, -math.pi / 2, 0), false, true)
            end)
        end

        local function stageDirty()
            local f = workspace.Blocks:FindFirstChild(P.Name)
            if not f then return 0 end
            local cnt = 0
            for _, c in ipairs(f:GetChildren()) do
                pcall(function()
                    if (c:GetPivot().Position - CONFIG.Stage).Magnitude < 8 then cnt = cnt + 1 end
                end)
            end
            return cnt
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
                    tool("ScalingTool").RF:InvokeServer(b, j.size, j.cf)
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
                        if (not rotOK) and fixRot then
                            pcall(function()
                                tool("TrowelTool").OperationRF:InvokeServer({ b }, b:GetPivot(), j.cf, "Rotate")
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

            ui.status(string.format("BUILD %d/%d", math.min(i + n - 1, #jobs), #jobs))

            if n == 0 then
                zeroStreak = zeroStreak + 1
                ui.log("[engine] batch harvested 0 - cooldown " .. zeroStreak .. "/3")
                task.wait(1)
                if zeroStreak >= 3 then error("server stopped accepting placements") end
            else
                zeroStreak = 0
                if n < batch then ui.log("[engine] partial batch " .. n .. "/" .. batch) end
                i = i + n
            end

            if (i % (BURST * 10)) == 0 and stageDirty() > 3 then
                bump = bump + 10
                ui.log("[engine] staging dirty - bumped")
            end
            task.wait(POST)
        end

        ui.status("PAINT")
        local pl = {}
        for idx, j in ipairs(jobs) do
            local b = built[idx]
            if b and b.Parent then pl[#pl + 1] = { b, j.color } end
        end
        if #pl > 0 then
            pcall(function() tool("PaintingTool").RF:InvokeServer({ pl }) end)
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
    assert(tool("DeleteTool"), "DeleteTool missing - step off/on your plot")
    local f = workspace.Blocks:FindFirstChild(P.Name)
    if not f then return 0 end
    local n = 0
    for _, b in ipairs(f:GetChildren()) do
        pcall(function() tool("DeleteTool").RF:InvokeServer(b) end)
        n = n + 1
        task.wait(0.03)
    end
    return n
end

-- ══════════════════════ F-15 JOBS ═══════════════════════════
local function f15Jobs(offsetY)
    local O = CFrame.new(CONFIG.BuildAt + Vector3.new(0, offsetY or 0, 0))
    local jobs = {}
    for _, d in ipairs(PARTS) do
        jobs[#jobs + 1] = {
            name = d[1], size = d[2],
            cf = O * CFrame.new(d[3]) * CFrame.Angles(
                math.rad(d[4][1]), math.rad(d[4][2]), math.rad(d[4][3])),
            color = d[5],
        }
    end
    return jobs
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

-- ════════════════════════ VOXELIZER ═════════════════════════
local function voxelize(verts, faces, cell, fit)
    local nv = normalize(verts, fit)
    math.randomseed(42)
    local seen, voxels = {}, {}
    for _, f in ipairs(faces) do
        for k = 2, #f - 1 do
            local A, B, Cp = nv[f[1]], nv[f[k]], nv[f[k + 1]]
            local area = (B - A):Cross(Cp - A).Magnitude / 2
            local samples = math.clamp(math.floor(area / (cell * cell)) + 1, 1, 512)
            for _ = 1, samples do
                local r1, r2 = math.random(), math.random()
                local s1 = math.sqrt(r1)
                local p = A * (1 - s1) + B * (s1 * (1 - r2)) + Cp * (s1 * r2)
                local g = Vector3.new(
                    math.floor(p.X / cell + 0.5) * cell,
                    math.floor(p.Y / cell + 0.5) * cell,
                    math.floor(p.Z / cell + 0.5) * cell)
                local key = g.X .. "," .. g.Y .. "," .. g.Z
                if not seen[key] then
                    seen[key] = true
                    voxels[#voxels + 1] = g
                end
            end
        end
    end
    table.sort(voxels, function(a, b)
        if a.Y ~= b.Y then return a.Y < b.Y end
        if a.X ~= b.X then return a.X < b.X end
        return a.Z < b.Z
    end)
    return voxels
end

local function objJobs(voxels, cell, offsetY, colorMode)
    local base = CONFIG.BuildAt + Vector3.new(0, offsetY or 0, 0)
    local minY, maxY = math.huge, -math.huge
    for _, v in ipairs(voxels) do
        minY = math.min(minY, v.Y)
        maxY = math.max(maxY, v.Y)
    end
    local jobs = {}
    for i, v in ipairs(voxels) do
        local col
        if colorMode == "Height Fade" then
            local a = (maxY > minY) and (v.Y - minY) / (maxY - minY) or 0.5
            col = Color3.fromRGB(65, 70, 80):Lerp(Color3.fromRGB(205, 210, 215), a)
        elseif colorMode == "White" then
            col = Color3.fromRGB(240, 240, 240)
        else
            col = C.MID
        end
        jobs[#jobs + 1] = {
            name = "vx" .. i,
            size = Vector3.new(cell, cell, cell),
            cf = CFrame.new(base + v),
            color = col,
        }
    end
    return jobs
end

-- ══════════════════ TRIANGLE PLATE BUILDER ══════════════════
local function triPlates(verts, faces, opts)
    local nv = normalize(verts, opts.fit)
    math.randomseed(7)
    local plates = {}
    for _, f in ipairs(faces) do
        for k = 2, #f - 1 do
            local A, B, Cp = nv[f[1]], nv[f[k]], nv[f[k + 1]]
            local e1, e2 = B - A, Cp - A
            local cr = e1:Cross(e2)
            if cr.Magnitude > opts.minArea * 2 then
                local n = cr.Unit
                local right = e1.Unit
                local up = n:Cross(right).Unit
                up = up - right * up:Dot(right)
                up = up.Unit
                local cu, cv = e2:Dot(right), e2:Dot(up)
                local minU = math.min(0, e1.Magnitude, cu)
                local maxU = math.max(0, e1.Magnitude, cu)
                local minV = math.min(0, cv)
                local maxV = math.max(0, cv)
                plates[#plates + 1] = {
                    pos = A + right * ((minU + maxU) / 2) + up * ((minV + maxV) / 2),
                    right = right, up = up, n = n,
                    w = (maxU - minU) + opts.overlap,
                    h = (maxV - minV) + opts.overlap,
                    t = opts.thick * (0.9 + math.random() * 0.2),
                }
            end
        end
    end
    table.sort(plates, function(a, b) return a.pos.Y < b.pos.Y end)
    return plates
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
            local l = math.clamp(0.5 + 0.5 * p.n:Dot(LIGHT), 0, 1)
            col = Color3.fromRGB(90 + 110 * l, 95 + 110 * l, 100 + 110 * l)
        elseif colorMode == "Height Fade" then
            local a = (maxY > minY) and (p.pos.Y - minY) / (maxY - minY) or 0.5
            col = Color3.fromRGB(65, 70, 80):Lerp(Color3.fromRGB(205, 210, 215), a)
        elseif colorMode == "White" then
            col = Color3.fromRGB(240, 240, 240)
        else
            col = C.MID
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
    if (o.mode or "Triangle plates") == "Triangle plates" then
        local plates = triPlates(vv, ff, {
            fit = o.fit or 40, minArea = o.minArea or 0.5,
            thick = o.thick or 0.6, overlap = 0.15 })
        return triJobs(plates, o.offsetY or 0, o.colorMode or "Shaded"), "plates"
    else
        local vox = voxelize(vv, ff, o.cell or 2, o.fit or 40)
        return objJobs(vox, o.cell or 2, o.offsetY or 0, o.colorMode or "Gray"), "voxels"
    end
end

-- ═════════════════════ ESCAPE HATCHES ═══════════════════════
getgenv().F15_BUILD = function(offsetY)
    return runBuild(f15Jobs(offsetY), { burst = 10 })
end
getgenv().OBJ_BUILD = function(text, o)
    o = o or {}
    local jobs = genJobs(text, o)
    assert(#jobs <= CONFIG.MaxVoxels, #jobs .. " > cap " .. CONFIG.MaxVoxels)
    return runBuild(jobs, { material = o.material, burst = o.burst, burstWait = o.burstWait })
end
getgenv().BABFT_CLEAN = cleanupAll

-- ═══════════════════════ RAYFIELD UI ════════════════════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Win = Rayfield:CreateWindow({
    Name = "BABFT Architect",
    LoadingTitle = "BABFT Architect",
    LoadingSubtitle = "v5.0 FINAL | Burst + Plates + Cleanup",
    ConfigurationSaving = { Enabled = false },
})

local function notify(title, content, dur)
    Rayfield:Notify({ Title = title, Content = content, Duration = dur or 5 })
end

local function startBuild(jobs, opts, label)
    task.spawn(function()
        local ok, msg = runBuild(jobs, opts)
        notify(label, ok and tostring(msg) or ("Error: " .. tostring(msg)), 8)
    end)
end

-- ------------------------ TAB: F-15 -------------------------
local T1 = Win:CreateTab("F-15", 4483345998)
T1:CreateSection("Build")
local f15Y = 0
T1:CreateSlider({ Name = "Height offset", Range = { -10, 10 }, Increment = 1,
    CurrentValue = 0, Callback = function(v) f15Y = v end })
T1:CreateButton({ Name = "BUILD F-15 (" .. #PARTS .. " parts)", Callback = function()
    if BUILDING then notify("Busy", "A build is already running", 3) return end
    notify("F-15", "Stay on your plot!", 4)
    startBuild(f15Jobs(f15Y), { burst = 10 }, "F-15")
end })

-- --------------------- TAB: CUSTOM OBJ ----------------------
local T2 = Win:CreateTab("Custom OBJ", 4483345998)
T2:CreateSection("1. Load a model")
local objText, urlInput, pasteInput = "", "", ""
T2:CreateInput({ Name = "Model URL (raw.githubusercontent)",
    PlaceholderText = "https://raw.githubusercontent.com/.../model.obj",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) urlInput = t end })
T2:CreateInput({ Name = "...or paste OBJ text (small)",
    PlaceholderText = "v 0 1 0 ... f 1 2 3",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) pasteInput = t end })
T2:CreateButton({ Name = "LOAD MODEL", Callback = function()
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
    notify("Nothing to load", "Give a URL, set OBJ_DATA, or paste text", 5)
end })

T2:CreateSection("2. Shape settings")
local mode, cell, fit, objY = "Triangle plates", 2, 40, 0
local minArea, thick, colorMode = 0.5, 0.6, "Shaded"
local material, burst, burstWait, verifyOn = "TitaniumBlock", 20, 0.1, true
T2:CreateDropdown({ Name = "Build mode", Options = { "Triangle plates", "Voxel cubes" },
    CurrentOption = "Triangle plates", Callback = function(v) mode = firstOf(v) end })
T2:CreateSlider({ Name = "Fit size (max dimension)", Range = { 8, 120 }, Increment = 2,
    CurrentValue = 40, Callback = function(v) fit = v end })
T2:CreateSlider({ Name = "Min triangle area (plates)", Range = { 0, 3 }, Increment = 0.1,
    CurrentValue = 0.5, Callback = function(v) minArea = v end })
T2:CreateSlider({ Name = "Plate thickness (plates)", Range = { 0.4, 1 }, Increment = 0.1,
    CurrentValue = 0.6, Callback = function(v) thick = v end })
T2:CreateSlider({ Name = "Block size (voxels)", Range = { 1, 4 }, Increment = 0.5,
    CurrentValue = 2, Callback = function(v) cell = v end })
T2:CreateSlider({ Name = "Height offset", Range = { -10, 10 }, Increment = 1,
    CurrentValue = 0, Callback = function(v) objY = v end })
T2:CreateDropdown({ Name = "Color mode", Options = { "Shaded", "Height Fade", "Gray", "White" },
    CurrentOption = "Shaded", Callback = function(v) colorMode = firstOf(v) end })
T2:CreateDropdown({ Name = "Material", Options = { "TitaniumBlock", "WoodBlock" },
    CurrentOption = "TitaniumBlock", Callback = function(v) material = firstOf(v) end })

T2:CreateSection("3. Speed")
T2:CreateSlider({ Name = "Burst size (plates per wave)", Range = { 1, 40 }, Increment = 1,
    CurrentValue = 20, Callback = function(v) burst = v end })
T2:CreateSlider({ Name = "Burst wait (seconds)", Range = { 0.05, 1 }, Increment = 0.05,
    CurrentValue = 0.1, Callback = function(v) burstWait = v end })
T2:CreateToggle({ Name = "Verify rotation (accurate, slightly slower)",
    CurrentValue = true, Callback = function(v) verifyOn = v end })

T2:CreateSection("4. Actions")
T2:CreateButton({ Name = "PARSE & PREVIEW (always first!)", Callback = function()
    if #objText < 10 then notify("OBJ", "Load a model first", 4) return end
    local ok, count, kind = pcall(function()
        local j = genJobs(objText, { mode = mode, cell = cell, fit = fit,
            minArea = minArea, thick = thick, offsetY = objY, colorMode = colorMode })
        return #j, select(2, genJobs(objText, { mode = mode, cell = cell, fit = fit,
            minArea = minArea, thick = thick, offsetY = objY, colorMode = colorMode }))
    end)
    if not ok then notify("Parse error", tostring(count), 6) return end
    if count > CONFIG.MaxVoxels then
        notify("TOO MANY " .. kind:upper(),
            count .. " > cap " .. CONFIG.MaxVoxels
            .. (mode == "Triangle plates" and " - raise Min area" or " - raise Block size"), 8)
    else
        notify("Preview (" .. kind .. ")",
            count .. " blocks | est " .. fmtTime(count * 0.12), 8)
    end
end })
T2:CreateButton({ Name = "BUILD FROM OBJ", Callback = function()
    if BUILDING then notify("Busy", "A build is already running", 3) return end
    if #objText < 10 then notify("OBJ", "Load a model first", 4) return end
    local ok, jobs = pcall(function()
        return genJobs(objText, { mode = mode, cell = cell, fit = fit,
            minArea = minArea, thick = thick, offsetY = objY, colorMode = colorMode })
    end)
    if not ok then notify("OBJ error", tostring(jobs), 6) return end
    jobs = jobs[1]
    if #jobs > CONFIG.MaxVoxels then
        notify("Too many", #jobs .. " > cap " .. CONFIG.MaxVoxels, 6) return
    end
    notify("OBJ build", #jobs .. " blocks - stay on plot!", 6)
    startBuild(jobs, { material = material, burst = burst, burstWait = burstWait,
        verify = verifyOn }, "OBJ build")
end })
T2:CreateButton({ Name = "STOP build", Callback = function() STOP = true end })

-- ---------------------- TAB: CLEANUP ------------------------
local T3 = Win:CreateTab("Cleanup", 4483345998)
T3:CreateSection("Delete blocks")
T3:CreateButton({ Name = "DELETE ALL MY BLOCKS", Callback = function()
    notify("Cleanup", "Deleting every block you own...", 4)
    task.spawn(function()
        local ok, n = pcall(cleanupAll)
        notify("Cleanup", ok and ("Deleted " .. tostring(n) .. " blocks")
            or ("Error: " .. tostring(n)), 6)
    end)
end })

-- ------------------------- TAB: INFO ------------------------
local T4 = Win:CreateTab("Info", 4483345998)
T4:CreateParagraph({ Title = "Quick start", Content =
"1. Stand on your plot with all tools.\n2. F-15 tab: BUILD.\n3. OBJ tab: LOAD -> PREVIEW -> BUILD.\n4. Cleanup tab: delete everything you built." })
T4:CreateParagraph({ Title = "Speed", Content =
"Burst 20 / 0.1s = ~200 plates/sec if the server keeps up. If batches come back partial, raise Burst wait. Estimated time shown in preview assumes ~0.12s per block." })
T4:CreateParagraph({ Title = "Console escapes", Content =
"getgenv().F15_BUILD(0)\ngetgenv().OBJ_BUILD(text, {mode='Triangle plates', fit=60, minArea=0.2, colorMode='Shaded', burst=20})\ngetgenv().BABFT_CLEAN()" })

print("[Architect] v5.0 FINAL loaded")

end)

if not RUN_OK then
    warn("[Architect FATAL] " .. tostring(RUN_ERR))
end
