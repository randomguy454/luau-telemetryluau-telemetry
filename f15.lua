-- ════════════════════════════════════════════════════════════
--  BABFT ARCHITECT v4.0 — "BEST EVER" EDITION
--  ────────────────────────────────────────────────────────────
--  • F-15 builder (21 parts, auto-mirrored, batched paint)
--  • OBJ importer: TWO build modes
--      - Voxel cubes    (classic blocky look)
--      - Triangle plates (per-face rotation, smooth shells)
--  • Load models from: URL / pasted text / getgenv().OBJ_DATA
--  • Armored engine: retries, probe gating, rotation verify,
--    staging collision bump, STOP, per-step pcall
--  ────────────────────────────────────────────────────────────
--  Run with:
--  loadstring(game:HttpGet("YOUR_RAW_URL"))()
-- ════════════════════════════════════════════════════════════

local Players = game:GetService("Players")
local P = Players.LocalPlayer

-- ══════════════════════════ CONFIG ══════════════════════════
local CONFIG = {
    BlockIDs = {
        WoodBlock      = 450,     -- verified
        TitaniumBlock  = 12272,   -- verified
    },
    ZoneName     = "Really redZone",
    BuildAt      = Vector3.new(271, -10.4, -72),   -- build center (world)
    Stage        = Vector3.new(251.8, -11.9, -77.2), -- proven placeable spot
    Pace         = 0.35,    -- seconds between engine steps
    PlaceTimeout = 3,       -- seconds waiting for block replication
    MaxVoxels    = 1000,    -- safety cap (voxels OR plates)
}

local C = {
    MID = Color3.fromRGB(114, 118, 112), -- gunship gray
    LTG = Color3.fromRGB(185, 188, 184), -- light belly
    DK  = Color3.fromRGB(52, 54, 52),    -- radome / nozzles
    BLK = Color3.fromRGB(20, 20, 22),    -- inlet faces
    GLD = Color3.fromRGB(170, 134, 54),  -- gold canopy
}

-- ═══════════════════════ F-15 PART DATA ═════════════════════
-- {name, size, localPos(+X right, +Y up, -Z nose), rotDeg, color, mirror?}
local function V(x, y, z) return Vector3.new(x, y, z) end

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

-- ═══════════════════════ BUILD ENGINE ═══════════════════════
-- jobs: array of {name, size(V3), cf(CFrame), color(Color3), lv(LookVector?, optional)}
local STOP, BUILDING = false, false

local function tool(n)
    local ch = P.Character
    return (ch and ch:FindFirstChild(n)) or P.Backpack:FindFirstChild(n)
end

local function runBuild(jobs, opts, ui)
    ui = ui or { log = print, status = function() end }
    opts = opts or {}
    STOP = false
    BUILDING = true
    local ok, err = pcall(function()
        local zone = workspace:FindFirstChild(CONFIG.ZoneName)
        assert(zone, "zone not found - stand on your plot")
        local material = opts.material or "TitaniumBlock"
        local ID = assert(CONFIG.BlockIDs[material], "unknown material: " .. material)
        local pace = opts.pace or CONFIG.Pace

        for _, n in ipairs({ "BuildingTool", "PaintingTool", "ScalingTool", "PropertiesTool" }) do
            assert(tool(n), "missing tool: " .. n)
        end
        ui.log("[engine] preflight ok - " .. #jobs .. " parts, " .. material)

        -- -- block tracking -- --
        local function snap()
            local s = {}
            local f = workspace.Blocks:FindFirstChild(P.Name)
            if f then for _, c in ipairs(f:GetChildren()) do s[c] = true end end
            return s
        end
        local function waitNew(before)
            local t = os.clock()
            while os.clock() - t < CONFIG.PlaceTimeout do
                for c in pairs(snap()) do if not before[c] then return c end end
                task.wait(0.1)
            end
            return nil
        end
        local function alive(b) return typeof(b) == "Instance" and b.Parent ~= nil end
        local function anchor(b) -- fresh blocks spawn unanchored: one toggle = anchored
            pcall(function() tool("PropertiesTool").SetPropertieRF:InvokeServer("Anchored", { b }) end)
        end

        -- -- placement: retry + staging collision bump -- --
        local bump = 0
        local function place()
            for attempt = 1, 2 do
                local before = snap()
                local S = CONFIG.Stage + Vector3.new(0, bump, 0)
                pcall(function()
                    tool("BuildingTool").RF:InvokeServer(material, ID, zone,
                        CFrame.new(S.Z - zone.Position.Z, S.Y - zone.Position.Y, -(S.X - zone.Position.X)),
                        true, CFrame.new(S) * CFrame.Angles(0, -math.pi / 2, 0), false, true)
                end)
                local b = waitNew(before)
                if b then return b end
                bump = bump + 5
                ui.log("[engine] place retry " .. attempt .. " (staging bumped)")
                task.wait(0.5)
            end
            return nil
        end

        -- -- main loop -- --
        local built, fail = {}, {}
        for i, j in ipairs(jobs) do
            if STOP then ui.log("[engine] STOPPED by user at " .. i) break end
            ui.status(string.format("BUILD %d/%d", i, #jobs))
            pcall(function()
                local b = place()
                if not b then fail[#fail + 1] = j.name ui.log("[FAIL] place " .. j.name) return end
                anchor(b) task.wait(pace)
                pcall(function() tool("ScalingTool").RF:InvokeServer(b, j.size, j.cf) end)
                task.wait(pace)
                if not alive(b) then fail[#fail + 1] = j.name ui.log("[FAIL] " .. j.name .. " vanished") return end
                if (b:GetPivot().Position - CONFIG.Stage).Magnitude < 3 then bump = bump + 5 end
                local posErr = (b:GetPivot().Position - j.cf.Position).Magnitude
                local rotOK = true
                if j.lv then rotOK = math.abs(b:GetPivot().LookVector:Dot(j.lv)) > 0.98 end
                ui.log(string.format("%-8s posErr=%.2f rot=%s",
                    j.name, posErr, rotOK and "ok" or "BAD"))
                if posErr < 1 and rotOK then built[i] = b else fail[#fail + 1] = j.name end
            end)
            task.wait(pace)
        end

        -- -- batched paint: ONE invoke -- --
        ui.status("PAINT")
        local pl = {}
        for i, j in ipairs(jobs) do
            local b = built[i]
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

-- ══════════════════════ F-15 JOB BUILDER ════════════════════
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
    return verts, faces
end

-- ════════════════════════ VOXELIZER ═════════════════════════
local function voxelize(verts, faces, cell, fitSize)
    local mn = Vector3.new(math.huge, math.huge, math.huge)
    local mx = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, v in ipairs(verts) do
        mn = Vector3.new(math.min(mn.X, v.X), math.min(mn.Y, v.Y), math.min(mn.Z, v.Z))
        mx = Vector3.new(math.max(mx.X, v.X), math.max(mx.Y, v.Y), math.max(mx.Z, v.Z))
    end
    local s = fitSize / math.max(mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z)
    local nv = {}
    for i, v in ipairs(verts) do nv[i] = (v - (mn + mx) / 2) * s end

    math.randomseed(42) -- deterministic
    local seen, voxels = {}, {}
    for _, f in ipairs(faces) do
        for k = 2, #f - 1 do
            local A, B, Cp = nv[f[1]], nv[f[k]], nv[f[k + 1]]
            local area = (B - A):Cross(Cp - A).Magnitude / 2
            local n = math.clamp(math.floor(area / (cell * cell)) + 1, 1, 512)
            for _ = 1, n do
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
        minY = math.min(minY, v.Y) maxY = math.max(maxY, v.Y)
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
        jobs[#jobs + 1] = { name = "vx" .. i,
            size = Vector3.new(cell, cell, cell),
            cf = CFrame.new(base + v), color = col }
    end
    return jobs
end

-- ═══════════════════ TRIANGLE PLATE BUILDER ═════════════════
-- One thin plate per triangle: positioned at the face, rotated
-- to its plane, scaled to its bounds. Smooth, blocky-free shell.
local function triPlates(verts, faces, opts)
    local mn = Vector3.new(math.huge, math.huge, math.huge)
    local mx = Vector3.new(-math.huge, -math.huge, -math.huge)
    for _, v in ipairs(verts) do
        mn = Vector3.new(math.min(mn.X, v.X), math.min(mn.Y, v.Y), math.min(mn.Z, v.Z))
        mx = Vector3.new(math.max(mx.X, v.X), math.max(mx.Y, v.Y), math.max(mx.Z, v.Z))
    end
    local s = opts.fit / math.max(mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z)
    local nv = {}
    for i, v in ipairs(verts) do nv[i] = (v - (mn + mx) / 2) * s end

    math.randomseed(7) -- deterministic jitter (anti z-fight)
    local plates = {}
    for _, f in ipairs(faces) do
        for k = 2, #f - 1 do -- fan-triangulate n-gons
            local A, B, Cp = nv[f[1]], nv[f[k]], nv[f[k + 1]]
            local e1, e2 = B - A, Cp - A
            local cr = e1:Cross(e2)
            if cr.Magnitude > opts.minArea * 2 then
                local n = cr.Unit
                local right = e1.Unit
                local up = n:Cross(right).Unit
                local cu, cv = e2:Dot(right), e2:Dot(up)
                local minU = math.min(0, e1.Magnitude, cu)
                local maxU = math.max(0, e1.Magnitude, cu)
                local minV = math.min(0, 0, cv)
                local maxV = math.max(0, 0, cv)
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
    local LIGHT = Vector3.new(0.4, 0.85, -0.3).Unit -- fake sun
    local minY, maxY = math.huge, -math.huge
    for _, p in ipairs(plates) do
        minY = math.min(minY, p.pos.Y) maxY = math.max(maxY, p.pos.Y)
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
        else
            col = C.MID
        end
        jobs[#jobs + 1] = {
            name = "tri" .. i,
            size = Vector3.new(p.w, p.h, p.t),
            cf = CFrame.fromMatrix(base + p.pos, p.right, p.up),
            lv = p.n, -- engine verifies rotation against this
            color = col,
        }
    end
    return jobs
end

-- ═══════════════════════ HELPERS ════════════════════════════
local function firstOf(v) return typeof(v) == "table" and v[1] or v end
local function fmtTime(sec)
    return string.format("%dm %02ds", math.floor(sec / 60), math.floor(sec % 60))
end
local function genJobs(text, o)
    local vv, ff = parseOBJ(text)
    if (o.mode or "Triangle plates") == "Triangle plates" then
        local plates = triPlates(vv, ff, o)
        return plates, triJobs(plates, o.offsetY, o.colorMode), "plates"
    else
        local vox = voxelize(vv, ff, o.cell, o.fit)
        return vox, objJobs(vox, o.cell, o.offsetY, o.colorMode), "voxels"
    end
end

-- ═════════════════════ ESCAPE HATCHES ═══════════════════════
getgenv().F15_BUILD = function(offsetY, ui)
    return runBuild(f15Jobs(offsetY), {}, ui)
end
getgenv().OBJ_BUILD = function(text, opts, ui)
    opts = opts or {}
    local _, jobs, kind = genJobs(text, opts)
    assert(#jobs <= CONFIG.MaxVoxels, #jobs .. " " .. kind .. " > cap " .. CONFIG.MaxVoxels)
    return runBuild(jobs, { material = opts.material }, ui)
end

-- ═══════════════════════ RAYFIELD UI ════════════════════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Win = Rayfield:CreateWindow({
    Name = "BABFT Architect",
    LoadingTitle = "BABFT Architect",
    LoadingSubtitle = "v4.0 | F-15 + Voxel + Triangle Plates",
    ConfigurationSaving = { Enabled = false },
})

-- ------------------------ TAB: F-15 -------------------------
local T1 = Win:CreateTab("F-15", 4483345998)
T1:CreateSection("Build")
local f15Y = 0
T1:CreateSlider({ Name = "Height offset", Range = { -10, 10 }, Increment = 1,
    CurrentValue = 0, Callback = function(v) f15Y = v end })
T1:CreateButton({ Name = "BUILD F-15 (" .. #PARTS .. " parts)", Callback = function()
    if BUILDING then Rayfield:Notify({ Title = "Busy", Content = "A build is already running", Duration = 3 }) return end
    Rayfield:Notify({ Title = "F-15", Content = "Stay on your plot!", Duration = 4 })
    task.spawn(function()
        local ok, msg = getgenv().F15_BUILD(f15Y)
        Rayfield:Notify({ Title = "F-15",
            Content = ok and tostring(msg) or ("Error: " .. tostring(msg)), Duration = 6 })
    end)
end })
T1:CreateButton({ Name = "STOP build", Callback = function() STOP = true end })

-- --------------------- TAB: CUSTOM OBJ ----------------------
local T2 = Win:CreateTab("Custom OBJ", 4483345998)
T2:CreateSection("1. Load a model")
local objText, urlInput, pasteInput = "", "", ""
T2:CreateInput({ Name = "Model URL (raw.githubusercontent link)",
    PlaceholderText = "https://raw.githubusercontent.com/.../model.obj",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) urlInput = t end })
T2:CreateInput({ Name = "...or paste OBJ text (small models)",
    PlaceholderText = "v 0 1 0 ... f 1 2 3",
    RemoveTextAfterFocusLost = false,
    Callback = function(t) pasteInput = t end })
T2:CreateButton({ Name = "LOAD MODEL", Callback = function()
    if #urlInput > 10 then
        local ok, data = pcall(function() return game:HttpGet(urlInput) end)
        if not ok or type(data) ~= "string" or #data < 10 then
            Rayfield:Notify({ Title = "Fetch failed", Content = "Check URL - repo must be public", Duration = 6 }) return
        end
        if data:find("<!DOCTYPE html>") or data:find("<html") then
            Rayfield:Notify({ Title = "That's a webpage", Content = "Use the RAW url", Duration = 6 }) return
        end
        objText = data
        Rayfield:Notify({ Title = "Model loaded", Content = "From URL - " .. #data .. " chars", Duration = 4 }) return
    end
    if getgenv().OBJ_DATA and #getgenv().OBJ_DATA > 10 then
        objText = getgenv().OBJ_DATA
        Rayfield:Notify({ Title = "Model loaded", Content = "OBJ_DATA - " .. #objText .. " chars", Duration = 4 }) return
    end
    if #pasteInput > 10 then
        objText = pasteInput
        Rayfield:Notify({ Title = "Model loaded", Content = "Pasted - " .. #objText .. " chars", Duration = 4 }) return
    end
    Rayfield:Notify({ Title = "Nothing to load", Content = "URL, OBJ_DATA, or paste text", Duration = 5 })
end })

T2:CreateSection("2. Shape settings")
local cell, fit, objY, colorMode, mode, minArea, thick = 2, 30, 0, "Shaded", "Triangle plates", 0.5, 0.6
T2:CreateDropdown({ Name = "Build mode", Options = { "Triangle plates", "Voxel cubes" },
    CurrentOption = "Triangle plates", Callback = function(v) mode = firstOf(v) end })
T2:CreateSlider({ Name = "Fit size (max dimension)", Range = { 8, 60 }, Increment = 2,
    CurrentValue = 30, Callback = function(v) fit = v end })
T2:CreateSlider({ Name = "Block size (voxels only)", Range = { 1, 4 }, Increment = 0.5,
    CurrentValue = 2, Callback = function(v) cell = v end })
T2:CreateSlider({ Name = "Min triangle area (plates only)", Range = { 0, 3 }, Increment = 0.1,
    CurrentValue = 0.5, Callback = function(v) minArea = v end })
T2:CreateSlider({ Name = "Plate thickness (plates only)", Range = { 0.4, 1 }, Increment = 0.1,
    CurrentValue = 0.6, Callback = function(v) thick = v end })
T2:CreateSlider({ Name = "Height offset", Range = { -10, 10 }, Increment = 1,
    CurrentValue = 0, Callback = function(v) objY = v end })
T2:CreateDropdown({ Name = "Color mode", Options = { "Shaded", "Height Fade", "Gray", "White" },
    CurrentOption = "Shaded", Callback = function(v) colorMode = firstOf(v) end })
T2:CreateDropdown({ Name = "Material", Options = { "TitaniumBlock", "WoodBlock" },
    CurrentOption = "TitaniumBlock", Callback = function(v) getgenv()._objMat = firstOf(v) end })

T2:CreateSection("3. Actions")
T2:CreateButton({ Name = "PARSE & PREVIEW (always check first!)", Callback = function()
    if #objText < 10 then
        Rayfield:Notify({ Title = "OBJ", Content = "Load a model first", Duration = 4 }) return
    end
    local ok, count, jobs, kind = pcall(function()
        local _, j, k = genJobs(objText, { mode = mode, cell = cell, fit = fit,
            minArea = minArea, thick = thick, overlap = 0.15,
            offsetY = objY, colorMode = colorMode })
        return #j, j, k
    end)
    if not ok then
        Rayfield:Notify({ Title = "Parse error", Content = tostring(count), Duration = 6 }) return
    end
    local est = fmtTime(count * 1.15)
    if count > CONFIG.MaxVoxels then
        Rayfield:Notify({ Title = "TOO MANY " .. kind:upper(),
            Content = count .. " > cap " .. CONFIG.MaxVoxels .. (mode == "Triangle plates"
                and " - raise Min area" or " - raise Block size"), Duration = 8 })
    else
        Rayfield:Notify({ Title = "Preview (" .. kind .. ")",
            Content = count .. " blocks | est " .. est, Duration = 8 })
    end
end })
T2:CreateButton({ Name = "BUILD FROM OBJ", Callback = function()
    if BUILDING then Rayfield:Notify({ Title = "Busy", Content = "A build is already running", Duration = 3 }) return end
    if #objText < 10 then
        Rayfield:Notify({ Title = "OBJ", Content = "Load a model first", Duration = 4 }) return
    end
    local ok, jobsOrErr = pcall(function()
        local _, j, k = genJobs(objText, { mode = mode, cell = cell, fit = fit,
            minArea = minArea, thick = thick, overlap = 0.15,
            offsetY = objY, colorMode = colorMode })
        assert(#j <= CONFIG.MaxVoxels, #j .. " " .. k .. " > cap " .. CONFIG.MaxVoxels)
        return j
    end)
    if not ok then
        Rayfield:Notify({ Title = "OBJ error", Content = tostring(jobsOrErr), Duration = 6 }) return
    end
    Rayfield:Notify({ Title = "OBJ build", Content = #jobsOrErr .. " blocks - stay on plot!", Duration = 6 })
    task.spawn(function()
        local ok2, msg = runBuild(jobsOrErr, { material = getgenv()._objMat or "TitaniumBlock" })
        Rayfield:Notify({ Title = "OBJ build",
            Content = ok2 and tostring(msg) or ("Error: " .. tostring(msg)), Duration = 8 })
    end)
end })
T2:CreateButton({ Name = "STOP build", Callback = function() STOP = true end })

-- ------------------------- TAB: INFO ------------------------
local T3 = Win:CreateTab("Info", 4483345998)
T3:CreateParagraph({ Title = "Quick start", Content =
"1. Stand on your plot with all 4 tools.\n2. F-15 tab: BUILD (works every time).\n3. OBJ tab: LOAD MODEL -> PREVIEW -> BUILD.\n4. Always preview first: it shows block count + estimated time." })
T3:CreateParagraph({ Title = "Build modes", Content =
"Triangle plates: one rotated plate per triangle - smooth, realistic shell. Use Min area to control count.\nVoxel cubes: classic blocky look. Use Block size to control count.\nPlate thickness below ~0.5 may clamp on the server." })
T3:CreateParagraph({ Title = "Big models", Content =
"Upload .obj to your GitHub repo, paste the raw URL in the Load section.\nCache tip: after updating a file, rename it (model_v2.obj) - raw URLs cache ~5 min.\nEst time = blocks x ~1.2s. Cap is " .. CONFIG.MaxVoxels .. " for a reason." })
T3:CreateParagraph({ Title = "Console", Content =
"getgenv().F15_BUILD(0) - build jet from executor\ngetgenv().OBJ_BUILD(text, {mode='Triangle plates', fit=40, minArea=0.5, thick=0.6, colorMode='Shaded'})" })

print("[Architect] v4.0 loaded - F-15 | Voxel | Triangle Plates")
