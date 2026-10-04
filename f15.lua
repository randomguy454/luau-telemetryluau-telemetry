-- ============================================================
--  F-15 BUILDER — Build A Boat For Treasure
--  Pipeline: place (BuildingTool) -> anchor (PropertiesTool)
--            -> scale+teleport (ScalingTool) -> batch paint
--  Run with:
--  loadstring(game:HttpGet("YOUR_RAW_URL_HERE"))()
-- ============================================================

local Players = game:GetService("Players")
local P = Players.LocalPlayer

-- ====================== CONFIG ==============================
local CONFIG = {
    BlockType = "TitaniumBlock",
    BlockID   = 12272, -- TitaniumBlock=12272, WoodBlock=450
    ZoneName  = "Really redZone",
    BuildAt   = Vector3.new(271, -10.4, -72), -- plane center
    Stage     = Vector3.new(251.8, -11.9, -77.2), -- staging spot
    Pace      = 0.35,
}

local C = {
    MID = Color3.fromRGB(114,118,112), -- gunship gray
    LTG = Color3.fromRGB(185,188,184), -- light belly
    DK  = Color3.fromRGB(52,54,52),    -- radome/nozzles
    BLK = Color3.fromRGB(20,20,22),    -- inlet faces
    GLD = Color3.fromRGB(170,134,54),  -- gold canopy
}

-- ====================== PART DATA ===========================
-- {name, size, pos(+X right,+Y up,-Z nose), rotDeg, color, mirror?}
local function V(x,y,z) return Vector3.new(x,y,z) end
local BASE = {
    {"radomeA",V(1.2,1.2,5),  V(0,.1,-10.5),  {0,0,45}, C.DK},
    {"radomeB",V(2.6,2.4,4),  V(0,.05,-6.2),  {0,0,0},  C.DK},
    {"noseFus",V(3.2,3,4),    V(0,0,-1.8),    {0,0,0},  C.MID},
    {"canopyM",V(1.8,1.8,4.2),V(0,2.2,-5.6),  {0,0,0},  C.GLD},
    {"canopyR",V(1.3,1.3,2.8),V(0,1.85,-2.4), {0,0,45}, C.GLD},
    {"midFus", V(3.4,3.2,6),  V(0,0,3.4),     {0,0,0},  C.MID},
    {"aftFus", V(3.6,3,6.5),  V(0,.15,9.9),   {0,0,0},  C.MID},
    {"bellyF", V(2.6,1.1,7),  V(0,-1.85,.5),  {0,0,0},  C.LTG},
    {"bellyA", V(2.8,1.3,7),  V(0,-1.8,7.5),  {0,0,0},  C.LTG},
    {"spine",  V(1.6,1.2,8),  V(0,1.85,3.8),  {0,0,0},  C.MID},
    {"intL", V(2.2,2.8,9.5), V(-2.8,-.15,.9), {0,0,0},  C.MID, true},
    {"inlL", V(1.5,2.1,.6),  V(-3,-.25,-4.1), {0,0,0},  C.BLK, true},
    {"wingL",V(6.5,.6,7),    V(-5.1,.4,.6),   {0,26,0}, C.MID, true},
    {"railL",V(.45,1.1,3),   V(-8.2,1.1,2.1), {0,26,0}, C.DK,  true},
    {"aim9L",V(.55,.55,4.6), V(-8.2,2,2.1),   {0,26,0}, C.LTG, true},
    {"mslL", V(.6,.6,5),     V(-4.7,-.35,.8), {0,26,0}, C.LTG, true},
    {"mslL2",V(.6,.6,5),     V(-6.4,-.35,1.3),{0,26,0}, C.LTG, true},
    {"fairL",V(.8,1.6,6),    V(-1.72,2.55,3.4),{0,0,0}, C.MID, true},
    {"vtL",  V(.7,5.5,5.5),  V(-1.75,4.5,8.9),{0,0,6},  C.MID, true},
    {"hstL", V(4.5,.5,3.5),  V(-3.3,.55,11.3),{0,30,0}, C.MID, true},
    {"nozL", V(1.7,1.7,3),   V(-.95,.1,12.7), {0,0,0},  C.DK,  true},
}
local PARTS = {}
for _,d in ipairs(BASE) do PARTS[#PARTS+1]=d end
for _,d in ipairs(BASE) do
    if d[6] then
        PARTS[#PARTS+1] = {d[1].."R", d[2], V(-d[3].X,d[3].Y,d[3].Z),
            {d[4][1],-d[4][2],-d[4][3]}, d[5]}
    end
end

-- ====================== BUILD ENGINE ========================
local STOP = false

local function tool(n)
    local ch = P.Character
    return (ch and ch:FindFirstChild(n)) or P.Backpack:FindFirstChild(n)
end

local function build(offsetY)
    STOP = false
    local ok, err = pcall(function()
        local zone = workspace:FindFirstChild(CONFIG.ZoneName)
        assert(zone, "zone not found - stand on your plot")
        local AT = Vector3.new(CONFIG.BuildAt.X, CONFIG.BuildAt.Y + (offsetY or 0), CONFIG.BuildAt.Z)
        local ST, PC, T, ID = CONFIG.Stage, CONFIG.Pace, CONFIG.BlockType, CONFIG.BlockID

        for _,n in ipairs({"BuildingTool","PaintingTool","ScalingTool","PropertiesTool"}) do
            assert(tool(n), "missing tool: "..n)
        end
        print("[F15] preflight ok")

        local function snap()
            local s = {}
            local f = workspace.Blocks:FindFirstChild(P.Name)
            if f then for _,c in ipairs(f:GetChildren()) do s[c] = true end end
            return s
        end
        local function waitNew(before)
            local t = os.clock()
            while os.clock() - t < 3 do
                for c in pairs(snap()) do if not before[c] then return c end end
                task.wait(0.1)
            end
        end
        local function alive(b) return typeof(b)=="Instance" and b.Parent ~= nil end
        local function anchor(b)
            pcall(function() tool("PropertiesTool").SetPropertieRF:InvokeServer("Anchored",{b}) end)
        end

        local bump = 0
        local function place()
            for a = 1, 2 do
                local before = snap()
                local S = ST + Vector3.new(0, bump, 0)
                pcall(function()
                    tool("BuildingTool").RF:InvokeServer(T, ID, zone,
                        CFrame.new(S.Z-zone.Position.Z, S.Y-zone.Position.Y, -(S.X-zone.Position.X)),
                        true, CFrame.new(S)*CFrame.Angles(0,-math.pi/2,0), false, true)
                end)
                local b = waitNew(before)
                if b then return b end
                bump = bump + 5
                warn("[F15] place retry "..a)
                task.wait(0.5)
            end
        end

        local O = CFrame.new(AT)
        local built, fail = {}, {}
        local function R(a) return CFrame.Angles(math.rad(a[1]),math.rad(a[2]),math.rad(a[3])) end

        local function buildPart(d)
            if STOP then return end
            local b = place()
            if not b then fail[#fail+1]=d[1] warn("[F15] place fail "..d[1]) return end
            anchor(b) task.wait(PC)
            local w = O * CFrame.new(d[3]) * R(d[4])
            pcall(function() tool("ScalingTool").RF:InvokeServer(b, d[2], w) end)
            task.wait(PC)
            if not alive(b) then fail[#fail+1]=d[1] warn("[F15] "..d[1].." vanished") return end
            if (b:GetPivot().Position - ST).Magnitude < 3 then bump = bump + 5 end
            local pe = (b:GetPivot().Position - w.Position).Magnitude
            print(string.format("[F15] %-8s posErr=%.2f %s", d[1], pe, pe < 1 and "OK" or "CHECK"))
            if pe < 1 then built[d[1]] = b else fail[#fail+1] = d[1] end
        end

        buildPart(PARTS[1])
        if not built[PARTS[1][1]] then error("probe failed") end
        print("[F15] probe ok")

        for i = 2, #PARTS do
            if STOP then warn("[F15] stopped by user") break end
            pcall(buildPart, PARTS[i])
            task.wait(PC)
        end

        local pl = {}
        for _,d in ipairs(PARTS) do
            local bb = built[d[1]]
            if bb and bb.Parent then pl[#pl+1] = {bb, d[5]} end
        end
        if #pl > 0 then
            pcall(function() tool("PaintingTool").RF:InvokeServer({pl}) end)
        end

        local msg = string.format("done %d/%d | fails: %s", #pl, #PARTS,
            (#fail == 0 and "none" or table.concat(fail, ",")))
        print("[F15] "..msg)
        return msg
    end)
    return ok, err
end
getgenv().F15_BUILD = build -- escape hatch if GUI ever fails

-- ====================== RAYFIELD UI =========================
local guiOK, guiErr = pcall(function()
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    local Win = Rayfield:CreateWindow({Name = "F-15 Builder", LoadingEnabled = false})
    local Tab = Win:CreateTab("Build")

    local offsetY = 0
    Tab:CreateSlider({Name = "Height offset", Range = {-10,10}, Increment = 1,
        CurrentValue = 0, Callback = function(v) offsetY = v end})

    Tab:CreateButton({Name = "BUILD F-15", Callback = function()
        Rayfield:Notify({Title="F-15", Content="Building "..#PARTS.." parts - stay on your plot!", Duration=5})
        task.spawn(function()
            local ok, msg = build(offsetY)
            Rayfield:Notify({Title="F-15",
                Content = ok and tostring(msg) or ("Error: "..tostring(msg)), Duration=6})
        end)
    end})

    Tab:CreateButton({Name = "STOP build", Callback = function() STOP = true end})

    Tab:CreateParagraph({Title = "Notes", Content =
        "Delete old jets manually first (no delete remote yet).\nThin parts (rail/aim9/msl) may print CHECK - server clamps min thickness.\nSlider nudges the whole jet up/down."})
    print("[F15] GUI ready")
end)

if not guiOK then
    warn("[F15] Rayfield failed: "..tostring(guiErr))
    warn("[F15] fallback: run getgenv().F15_BUILD(0)")
end
