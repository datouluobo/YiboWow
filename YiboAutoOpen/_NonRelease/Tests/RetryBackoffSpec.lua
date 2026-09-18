local scheduled = {}
local itemCount = 1

C_Timer = { After = function(delay, callback) scheduled[#scheduled + 1] = { delay = delay, callback = callback } end }
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
GetTime = function() return 10 end

YiboAutoOpen = {
    runtime = { initialized = true, loggedIn = true, queueState = "IDLE", generation = 0, quarantined = {}, failures = {}, warned = {}, sensitiveFrames = {} },
    LIMITS = { maxRetries = 2, operationTimeout = 2, retryBackoff = 15 },
    db = { catalog = { entries = { [90735] = true } } },
    Safety = { CanRun = function() return true end },
    BagAdapter = {
        FindNextEligible = function(_, _, quarantined)
            if quarantined[90735] then return nil end
            return 0, 1, { itemID = 90735 }
        end,
        GetTotalItemCount = function() return itemCount end,
        UseItem = function() end,
    },
    NotifyIssue = function() end,
}

dofile("YiboAutoOpen/Queue.lua")

local function RunTimer(delay)
    for index, timer in ipairs(scheduled) do
        if timer.delay == delay then
            table.remove(scheduled, index)
            timer.callback()
            return
        end
    end
    error("missing timer with delay " .. tostring(delay))
end

YiboAutoOpen.Queue:RequestScan()
RunTimer(0)
YiboAutoOpen.Queue:ResolvePending(false)
RunTimer(0)
YiboAutoOpen.Queue:ResolvePending(false)

assert(YiboAutoOpen.runtime.quarantined[90735], "failed item should enter the bounded retry backoff")
assert(YiboAutoOpen.runtime.pauseReason == "RETRY_BACKOFF", "retry backoff should be visible in queue status")
RunTimer(15)
assert(not YiboAutoOpen.runtime.quarantined[90735], "backoff completion must release the item during the same login")
assert(YiboAutoOpen.runtime.failures[90735] == nil, "backoff completion must reset the failure count")

print("Retry backoff spec passed")
