-- ════════════════════════════════════════════════════════════
--  SIMPLYSPIRITED MAIN LAUNCHER
--  For SHADOWMILESC (computerizedcarrier2)
--  One loadstring. Full suite. Any game.
--
--  Usage:
--  loadstring(game:HttpGet("https://raw.githubusercontent.com/randomguy454/luau-telemetryluau-telemetry/refs/heads/main/main.lua?nocache=" .. os.time()))()
-- ════════════════════════════════════════════════════════════

local BASE = "https://raw.githubusercontent.com/randomguy454/luau-telemetryluau-telemetry/refs/heads/main/"
local FILES = {
    "simplyspirited.lua",  -- engine: hooks, recorder, monitors
    "ss_ui.lua",           -- Orion interface: dashboard, feed, replayer
    "ss_part3.lua",        -- deep intel: bytecode dump, API doc, presets
}

print("╔══════════════════════════════════════════╗")
print("║  SIMPLYSPIRITED LAUNCHER v1.0            ║")
print("║  operator: SHADOWMILESC                  ║")
print("╚══════════════════════════════════════════╝")

-- wipe previous session state for a clean boot
getgenv().SS = nil
getgenv().SS_READY = nil

local loaded, failed = 0, {}
for i, file in ipairs(FILES) do
    local url = BASE .. file .. "?nocache=" .. os.time() .. i
    local fn, err = loadstring(game:HttpGet(url))
    if fn then
        local ok, runErr = pcall(fn)
        if ok then
            loaded = loaded + 1
            print(("[main] %d/3 loaded: %s"):format(loaded, file))
        else
            failed[#failed + 1] = file .. " (runtime: " .. tostring(runErr) .. ")"
            warn("[main] runtime error in " .. file .. ": " .. tostring(runErr))
        end
    else
        failed[#failed + 1] = file .. " (compile: " .. tostring(err) .. ")"
        warn("[main] compile error in " .. file .. ": " .. tostring(err))
    end
end

if loaded == #FILES then
    print("[main] ALL SYSTEMS LIVE — " .. loaded .. "/" .. #FILES)
elseif loaded > 0 then
    warn("[main] partial boot: " .. loaded .. "/" .. #FILES .. " | failed: " .. table.concat(failed, "; "))
else
    warn("[main] TOTAL BOOT FAILURE — check internet / repo public / file names")
end

-- keep the launcher's fingerprint on the session
getgenv().SIMPLYSPIRITED_VERSION = "1.0"
getgenv().SIMPLYSPIRITED_BY = "SHADOWMILESC"
