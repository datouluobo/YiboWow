local scheduled = {}
local eligible = false

C_Timer = { After = function(delay, callback) scheduled[#scheduled + 1] = { delay = delay, callback = callback } end }
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
GetTime = function() return 10 end

YiboAutoOpen = {
    runtime = { initialized = true, loggedIn = true, queueState = "IDLE", generation = 0, deferredScanGeneration = 0, quarantined = {}, failures = {}, warned = {}, sensitiveFrames = {} },
    LIMITS = { maxRetries = 2, operationTimeout = 2 },
    db = { catalog = { entries = { [90735] = true } } },
    Safety = { CanRun = function() return true end },
    BagAdapter = {
        FindNextEligible = function()
            if eligible then return 0, 1, { itemID = 90735 } end
            return nil, nil, nil, 0.5
        end,
        GetTotalItemCount = function() return 1 end,
        UseItem = function() end,
    },
    NotifyIssue = function() end,
}

dofile("YiboAutoOpen/Queue.lua")

local function RunNextTimer()
    assert(#scheduled > 0, "expected a scheduled callback")
    local nextIndex = 1
    for index = 2, #scheduled do
        if scheduled[index].delay < scheduled[nextIndex].delay then nextIndex = index end
    end
    local timer = table.remove(scheduled, nextIndex)
    timer.callback()
end

YiboAutoOpen.Queue:RequestScan()
RunNextTimer()
assert(YiboAutoOpen.runtime.queueState == "WAITING_READY", "temporarily blocked items should wait instead of becoming idle")
assert(#scheduled == 1 and scheduled[1].delay == 0.5, "the queue should schedule an eligibility retry")

eligible = true
RunNextTimer()
RunNextTimer()
assert(YiboAutoOpen.runtime.pending and YiboAutoOpen.runtime.pending.itemID == 90735, "the item should open after becoming eligible")

print("Deferred eligibility spec passed")
