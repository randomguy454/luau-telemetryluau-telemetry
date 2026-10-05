-- ════════════════════════════════════════════════════════════
--  SIMPLYSPIRITIZED v1.0 — UNIVERSAL GAME INTELLIGENCE SUITE
--  For SHADOWMILESC (computerizedcarrier2)
--  ────────────────────────────────────────────────────────────
--  Universal by design: discovers everything, assumes nothing.
--  PART 1/3: Core engine — interceptor, deconstructor, monitor
-- ════════════════════════════════════════════════════════════

print("[SS] SimplySpirited v1.0 booting...")

local Players = game:GetService("Players")
local P = Players.LocalPlayer

-- ═══════════ GLOBAL STATE ═══════════
getgenv().SS = {
    version = "1.0",
    game = game.Name,
    placeId = game.PlaceId,
    remotes = {},      -- [remote] = info table
    log = {},          -- captured calls
    scripts = {},      -- decompiled scripts cache
    values = {},       -- tracked value objects
    players = {},      -- player snapshots
    filters = {
        heartbeat = true, stepped = true, renderstepped = true,
        input = true, mouse = true, camera = true, touch = true,
        keyframe = true, animation = true,
    },
    maxLog = 1000,
    capture = true,
}
local SS = getgenv().SS

-- ════════════════════════════════════════════════════════════
--  MODULE: DECONSTRUCTOR — anything to readable string
-- ════════════════════════════════════════════════════════════
local function describe(v, depth)
    depth = depth or 0
    local t = typeof(v)
    if t == "string" then
        return #v <= 80 and ('"' .. v .. '"')
            or ('str(' .. #v .. '):"' .. v:sub(1, 40) .. '..."')
    elseif t == "Vector3" then
        return ("V3(%.2f,%.2f,%.2f)"):format(v.X, v.Y, v.Z)
    elseif t == "Vector2" then
        return ("V2(%.1f,%.1f)"):format(v.X, v.Y)
    elseif t == "CFrame" then
        local p = v.Position
        return ("CF(%.1f,%.1f,%.1f)"):format(p.X, p.Y, p.Z)
    elseif t == "Instance" then
        return v.ClassName .. ":" .. v.Name
    elseif t == "number" then
        return (v == math.floor(v) and math.abs(v) < 1e10) and tostring(v)
            or ("%.4f"):format(v)
    elseif t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "Color3" then
        return ("C3(%d,%d,%d)"):format(v.R*255, v.G*255, v.B*255)
    elseif t == "EnumItem" then
        return tostring(v)
    elseif t == "table" then
        if depth >= 2 then return "tbl#" .. #v end
        local parts, n = {}, 0
        for k, vv in pairs(v) do
            n = n + 1
            if n > 6 then parts[#parts+1] = "…+" .. (n - 6) break end
            local key = typeof(k) == "string" and k or "[" .. tostring(k) .. "]"
            parts[#parts+1] = key .. "=" .. describe(vv, depth + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "RBXScriptSignal" then
        return "signal"
    elseif t == "function" then
        return "function"
    elseif t == "thread" then
        return "thread"
    else
        return t
    end
end
SS.describe = describe

-- ════════════════════════════════════════════════════════════
--  MODULE: CALL RECORDER
-- ════════════════════════════════════════════════════════════
local callId = 0

local function recordCall(remote, args, direction)
    if not SS.capture then return end
    local lname = remote.Name:lower()
    for bad in pairs(SS.filters) do
        if lname:find(bad) then return end
    end
    callId = callId + 1

    local path = remote.Name
    pcall(function()
        path = remote:GetFullName():gsub("Game:", ""):gsub("Players%." .. P.Name .. ".", "ME.")
    end)

    local rec = {
        id = callId,
        name = remote.Name,
        path = path,
        class = remote.ClassName,
        dir = direction,
        t = os.clock(),
        args = {},
        raw = args,
    }
    for i, v in ipairs(args) do
        rec.args[i] = describe(v)
    end
    table.insert(SS.log, rec)
    if #SS.log > SS.maxLog then table.remove(SS.log, 1) end

    local tag = direction == "OUT" and ">>>" or "<<<"
    print(("[%s #%d] %s %s\n    %s"):format(
        tag, rec.id, rec.class, rec.path, table.concat(rec.args, " | ")))

    if SS.onCall then pcall(SS.onCall, rec) end
end
SS.recordCall = recordCall

-- ════════════════════════════════════════════════════════════
--  MODULE: REMOTE HOOKING (in + out, universal)
-- ════════════════════════════════════════════════════════════
local function infoFor(r)
    local info = SS.remotes[r]
    if not info then
        info = { calls = 0, out = 0, inn = 0, hooked = false }
        pcall(function()
            info.path = r:GetFullName():gsub("Players%." .. P.Name .. ".", "ME.")
        end)
        SS.remotes[r] = info
    end
    return info
end

local function hookRemote(r)
    local info = infoFor(r)
    if info.hooked then return end
    info.hooked = true

    if r:IsA("RemoteEvent") then
        r.OnClientEvent:Connect(function(...)
            info.calls = info.calls + 1
            info.inn = info.inn + 1
            recordCall(r, { ... }, "IN")
        end)
        pcall(function()
            local old = hookfunction(r.FireServer, function(self, ...)
                info.calls = info.calls + 1
                info.out = info.out + 1
                recordCall(r, { ... }, "OUT")
                return old(self, ...)
            end)
            info.fireHooked = ok ~= nil
        end)
    elseif r:IsA("RemoteFunction") then
        pcall(function()
            local old = hookfunction(r.InvokeServer, function(self, ...)
                info.calls = info.calls + 1
                info.out = info.out + 1
                recordCall(r, { ... }, "OUT")
                return old(self, ...)
            end)
        end)
    end
end

local function scanAllRemotes()
    local n = 0
    for _, d in ipairs(game:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
            pcall(hookRemote, d)
            n = n + 1
        end
    end
    print("[SS] discovered " .. n .. " remotes")
    return n
end

game.DescendantAdded:Connect(function(d)
    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
        pcall(hookRemote, d)
    end
end)

-- ════════════════════════════════════════════════════════════
--  MODULE: VALUE/CURRENCY MONITOR
-- ════════════════════════════════════════════════════════════
local function watchValue(obj)
    if SS.values[obj] then return end
    SS.values[obj] = obj.Value
    local function onChange(v)
        local old = SS.values[obj]
        local path = obj.Name
        pcall(function() path = obj:GetFullName():gsub("Players%." .. P.Name .. ".", "ME.") end)
        print(("[VALUE] %s = %s -> %s (%s%s)"):format(
            path, tostring(old), tostring(v),
            (tonumber(v) and tonumber(old)) and ((v - old) >= 0 and "+" or "") or "",
            (tonumber(v) and tonumber(old)) and tostring(v - old) or ""))
        SS.values[obj] = v
        if SS.onValue then pcall(SS.onValue, obj, old, v) end
    end
    pcall(function() obj.Changed:Connect(onChange) end)
    if obj:IsA("IntValue") or obj:IsA("NumberValue") then
        pcall(function() obj:GetPropertyChangedSignal("Value"):Connect(function() onChange(obj.Value) end) end)
    end
end

task.spawn(function()
    local ls = P:WaitForChild("leaderstats", 20)
    if ls then
        for _, d in ipairs(ls:GetChildren()) do
            if d:IsA("ValueBase") then watchValue(d) end
        end
        ls.ChildAdded:Connect(function(d)
            if d:IsA("ValueBase") then watchValue(d) end
        end)
        print("[SS] leaderstats monitoring live")
    else
        print("[SS] no leaderstats — scanning for hidden value containers")
        -- universal fallback: watch Player for ANY ValueBase children
        for _, d in ipairs(P:GetDescendants()) do
            if d:IsA("ValueBase") then watchValue(d) end
        end
        P.DescendantAdded:Connect(function(d)
            if d:IsA("ValueBase") then
                pcall(watchValue, d)
            end
        end)
    end
end)

-- ════════════════════════════════════════════════════════════
--  MODULE: PLAYER CENSUS
-- ════════════════════════════════════════════════════════════
local function playerSnapshot(pl)
    local snap = { name = pl.Name, display = pl.DisplayName, stats = {} }
    pcall(function()
        local ls = pl:FindFirstChild("leaderstats")
        if ls then
            for _, d in ipairs(ls:GetChildren()) do
                if d:IsA("ValueBase") then
                    snap.stats[d.Name] = d.Value
                end
            end
        end
    end)
    return snap
end

task.spawn(function()
    task.wait(5)
    print("═══ [SS] PLAYER CENSUS ═══")
    for _, pl in ipairs(Players:GetPlayers()) do
        local s = playerSnapshot(pl)
        SS.players[pl] = s
        local st = ""
        for k, v in pairs(s.stats) do st = st .. k .. ":" .. tostring(v) .. " " end
        print(("%s (%s) %s"):format(s.name, s.display, st))
    end
end)

Players.PlayerAdded:Connect(function(pl)
    print("[SS] player joined: " .. pl.Name)
end)

-- ════════════════════════════════════════════════════════════
--  BOOT
-- ════════════════════════════════════════════════════════════
scanAllRemotes()

print("[SS] Part 1/3 LIVE — " .. SS.game .. " | place " .. SS.placeId)
print("[SS] interceptor: OUT + IN armed | currency watch | census done")
print("[SS] " .. #P.Name == "" and "" or "for SHADOWMILESC — the suite is yours")
getgenv().SS_READY = true
