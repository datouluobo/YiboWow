local function Scenario(event, owner, throws)
    local scheduled, registered, messages, uses = {}, {}, {}, {}
    local handler
    C_Timer = { After = function(delay, callback)
        scheduled[#scheduled + 1] = { delay = delay, callback = callback }
    end }
    CreateFrame = function() return {
        RegisterEvent = function(_, name) registered[name] = true end,
        SetScript = function(_, _, callback) handler = callback end,
    } end
    GetTime = function() return 10 end
    GetLocale = function() return "enUS" end
    local savedCore = YiboCore
    YiboCore = nil
    dofile("YiboAutoOpen/Bootstrap.lua")
    dofile("YiboAutoOpen/Locale.lua")
    YiboCore = savedCore
    local Addon = YiboAutoOpen
    -- Keep the test independent of any Core fixture left by earlier specs.
    Addon.T = function(_, key, id)
        assert(key == "QUEUE.MANUAL_REQUIRED")
        return string.format("Item #%d: please open manually", id)
    end
    Addon.runtime.initialized, Addon.runtime.loggedIn = true, true
    Addon.db = { catalog = { entries = { [24476] = true, [90735] = true } } }
    Addon.LIMITS = { maxRetries = 2, operationTimeout = 2, retryBackoff = 15 }
    Addon.Safety = { CanRun = function() return true end }
    Addon.NotifyIssue = function(_, key, message) messages[#messages + 1] = message end
    Addon.BindConfirmAssist = { Arm = function() end, Disarm = function(_, pending) pending.disarmed = true end }
    Addon.BagAdapter = {
        FindEligibleItems = function(_, _, quarantined)
            local result = {}
            for _, id in ipairs({24476, 90735}) do
                if not quarantined[id] then result[#result + 1] = { item = {itemID = id} } end
            end
            return result
        end,
        FindItemByID = function(_, id) return 0, id, { itemID = id, count = 1 } end,
        GetTotalItemCount = function() return 1 end,
        UseItem = function(_, _, slot)
            uses[#uses + 1] = slot
            if slot == 24476 and event then
                handler(nil, event, owner, "UNKNOWN()")
                if throws then error("protected call failed") end
            end
        end,
    }
    dofile("YiboAutoOpen/Queue.lua")
    assert(registered.ADDON_ACTION_FORBIDDEN and registered.ADDON_ACTION_BLOCKED)
    Addon.Queue:ProcessNext()
    return Addon, scheduled, messages, uses, handler
end

for _, event in ipairs({"ADDON_ACTION_FORBIDDEN", "ADDON_ACTION_BLOCKED"}) do
    for _, throws in ipairs({false, true}) do
        local Addon, timers, messages, uses = Scenario(event, "YiboAutoOpen", throws)
        assert(Addon.runtime.quarantineReasons[24476] == "protected-action")
        assert(not Addon.runtime.pending and Addon.runtime.queueState == "IDLE")
        assert(#messages == 1 and messages[1]:find("24476") and messages[1]:find("manually"))
        for _, timer in ipairs(timers) do
            assert(timer.delay ~= 15 and timer.delay ~= 2, "blocked use must not schedule retry or timeout")
        end
        Addon.Queue:ReleaseTransientWorldQuarantine()
        assert(not Addon.Queue:ClearQuarantineForTrigger(24476, "item-push"))
        Addon.Queue:OnEvent("BAG_UPDATE_DELAYED")
        Addon.Queue:Clear()
        Addon.Queue:ProcessNext()
        assert(#uses == 2 and uses[2] == 90735, "other items must continue")
        Addon.Queue:ResolvePending(false)
        for _, timer in ipairs(timers) do if timer.delay == 0 then timer.callback() end end
        for _, id in ipairs(uses) do
            if id == 24476 then assert(_ == 1, "blocked item must not be retried") end
        end
        assert(#messages == 1, "automatic recovery must not repeat the manual warning")
        assert(Addon.Queue:ClearQuarantineForTrigger(24476, "manual"))
        assert(not Addon.runtime.quarantined[24476], "explicit manual retry may release isolation")
    end
end

local Addon, _, messages, _, handler = Scenario("ADDON_ACTION_FORBIDDEN", "OtherAddon")
assert(Addon.runtime.pending and not Addon.runtime.quarantined[24476] and #messages == 0)
handler(nil, "ADDON_ACTION_FORBIDDEN", "YiboAutoOpen", "UNKNOWN()")
assert(not Addon.runtime.quarantined[24476], "a later UI action must not quarantine the pending item")
Addon.Queue:ResolvePending(false)
assert(Addon.runtime.failures[24476] == 1, "ordinary failures must retain normal retry behavior")

-- Verify real language resources in standalone mode.
local savedCore, savedLocale = YiboCore, GetLocale
YiboCore = nil
dofile("YiboAutoOpen/Locale.lua")
GetLocale = function() return "enUS" end
assert(Addon:T("QUEUE.MANUAL_REQUIRED", 24476):find("24476"))
assert(Addon:T("QUEUE.MANUAL_REQUIRED", 24476):find("manually"))
assert(Addon:T("CATALOG.MANUAL_ONLY_REJECTED", "Jaggal Clam"):find("not added"))
GetLocale = function() return "zhCN" end
assert(Addon:T("QUEUE.MANUAL_REQUIRED", 24476):find("手动开启"))
assert(Addon:T("CATALOG.MANUAL_ONLY_REJECTED", "裂纹的蚌壳"):find("未加入自动开包目录"))
YiboCore, GetLocale = savedCore, savedLocale
print("Protected action spec passed")
