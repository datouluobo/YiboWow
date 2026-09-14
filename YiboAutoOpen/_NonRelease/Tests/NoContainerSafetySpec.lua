local scheduled = {}
local safetyChecks, warnings = 0, 0

C_Timer = { After = function(delay, callback) scheduled[#scheduled + 1] = { delay = delay, callback = callback } end }
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
GetTime = function() return 10 end

YiboAutoOpen = {
    runtime = { initialized = true, loggedIn = true, queueState = "IDLE", generation = 0, deferredScanGeneration = 0, quarantined = {}, failures = {}, warned = {}, sensitiveFrames = {} },
    LIMITS = { maxRetries = 2, operationTimeout = 2 },
    db = { catalog = { entries = {} } },
    Safety = { CanRun = function() safetyChecks = safetyChecks + 1; return false, "INSUFFICIENT_SPACE" end },
    BagAdapter = { FindNextEligible = function() return nil, nil, nil, nil end },
    NotifyIssue = function() warnings = warnings + 1 end,
}

dofile("YiboAutoOpen/Queue.lua")
YiboAutoOpen.Queue:ProcessNext()

assert(YiboAutoOpen.runtime.queueState == "IDLE", "an empty catalog scan should remain idle")
assert(safetyChecks == 0, "space checks should not run when there is no container to open")
assert(warnings == 0, "space warnings should not appear without a container")

print("No-container safety spec passed")
