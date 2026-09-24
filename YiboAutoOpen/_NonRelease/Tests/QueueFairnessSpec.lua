local scheduled = {}
local attempts = {}
local counts = { [1001] = 1, [1002] = 1 }
C_Timer = { After = function(delay, callback) scheduled[#scheduled + 1] = { delay = delay, callback = callback } end }
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
GetTime = function() return 10 end
YiboAutoOpen = {
    runtime = { initialized = true, loggedIn = true, queueState = "IDLE", generation = 0, quarantined = {}, failures = {}, warned = {}, sensitiveFrames = {} },
    LIMITS = { maxRetries = 2, operationTimeout = 2, retryBackoff = 15 },
    db = { catalog = { entries = { [1001] = true, [1002] = true } } },
    Safety = { CanRun = function() return true end },
    BagAdapter = {
        FindEligibleItems = function(_, _, quarantined)
            local list = {}
            for _, id in ipairs({ 1001, 1002 }) do if counts[id] and not quarantined[id] then list[#list + 1] = { bag = 0, slot = id, item = { itemID = id, count = 1 } } end end
            return list
        end,
        FindItemByID = function(_, id, _, quarantined) if counts[id] and not quarantined[id] then return 0, id, { itemID = id, count = 1 } end end,
        GetTotalItemCount = function(_, id) return counts[id] or 0 end,
        UseItem = function(_, bag, slot) attempts[#attempts + 1] = slot end,
    },
    NotifyIssue = function() end,
}
dofile("YiboAutoOpen/Queue.lua")
local function RunDelay(delay)
    for index, timer in ipairs(scheduled) do
        if timer.delay == delay then table.remove(scheduled, index); timer.callback(); return end
    end
    error("missing timer: " .. tostring(delay))
end
local function FailPending()
    YiboAutoOpen.Queue:ResolvePending(false)
    RunDelay(0)
end
YiboAutoOpen.Queue:RequestScan()
RunDelay(0)
assert(attempts[1] == 1001, "first catalog item should start the queue")
FailPending()
assert(attempts[2] == 1002, "a failed item must move behind its peer")
FailPending()
assert(attempts[3] == 1001, "queue should rotate back to the first item")
FailPending()
assert(attempts[4] == 1002, "isolating one exhausted item must continue with the remaining queue")
FailPending()
assert(YiboAutoOpen.runtime.quarantined[1001] and YiboAutoOpen.runtime.quarantined[1002], "exhausted peers should be isolated instead of rotating forever")
print("Queue fairness spec passed")
