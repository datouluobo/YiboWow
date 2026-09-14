local scheduled = {}
local itemCount = 1
local eventHandler

C_Timer = { After = function(delay, callback) scheduled[#scheduled + 1] = { delay = delay, callback = callback } end }
CreateFrame = function()
    return {
        RegisterEvent = function(_, event) if event == "PLAYER_UNGHOST" then error("unsupported event") end end,
        SetScript = function(_, script, handler) if script == "OnEvent" then eventHandler = handler end end,
    }
end
GetTime = function() return 10 end

YiboAutoOpen = {
    runtime = { initialized = true, loggedIn = true, queueState = "IDLE", generation = 0, quarantined = {}, failures = {}, warned = {}, sensitiveFrames = {} },
    LIMITS = { maxRetries = 2, operationTimeout = 2 },
    db = { catalog = { entries = { [90735] = true } } },
    Safety = { CanRun = function() return true end },
    BagAdapter = {
        FindNextEligible = function() return 0, 1, { itemID = 90735 } end,
        GetTotalItemCount = function() return itemCount end,
        UseItem = function() end,
    },
    NotifyIssue = function() end,
}

dofile("YiboAutoOpen/Queue.lua")
assert(eventHandler, "the OnEvent handler must be installed even when an optional event is unsupported")
assert(YiboAutoOpen.runtime.eventRegistration.registered > 0, "supported events should continue registering")
assert(YiboAutoOpen.runtime.eventRegistration.unsupported[1] == "PLAYER_UNGHOST", "unsupported events should be recorded")

local function RunNextTimer()
    assert(#scheduled > 0, "expected a scheduled callback")
    local nextIndex = 1
    for index = 2, #scheduled do
        if scheduled[index].delay < scheduled[nextIndex].delay then nextIndex = index end
    end
    local timer = table.remove(scheduled, nextIndex)
    timer.callback()
end

YiboAutoOpen.Queue:RequestScan("initial")
YiboAutoOpen.Queue:RequestScan("coalesced-bag-event")
assert(YiboAutoOpen.runtime.generation == 0, "scan requests must not cancel operations")
RunNextTimer()

local pending = YiboAutoOpen.runtime.pending
assert(pending and pending.itemID == 90735, "the item should be pending after use")
YiboAutoOpen.Queue:RequestScan("spell-event-during-use")
RunNextTimer()
assert(YiboAutoOpen.runtime.pending == pending, "a scan event must preserve the pending operation")
assert(not YiboAutoOpen.runtime.quarantined[90735], "normal events must not quarantine the item")

itemCount = 0
YiboAutoOpen.Queue:ResolvePending(true)
assert(YiboAutoOpen.runtime.pending == nil, "the count decrease should resolve the operation")
assert(YiboAutoOpen.runtime.failures[90735] == nil, "a successful operation should clear failures")
assert(not YiboAutoOpen.runtime.quarantined[90735], "a successful operation must not be quarantined")

print("Queue scan isolation spec passed")
