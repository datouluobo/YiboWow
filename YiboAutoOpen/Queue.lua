local Addon = _G.YiboAutoOpen
local Queue = {}; Addon.Queue = Queue
local SENSITIVE_OPEN_EVENTS = { MERCHANT_SHOW = true, BANKFRAME_OPENED = true, MAIL_SHOW = true, TRADE_SHOW = true, AUCTION_HOUSE_SHOW = true, GUILDBANKFRAME_OPENED = true, VOID_STORAGE_OPEN = true }
local SENSITIVE_CLOSE_EVENTS = { MERCHANT_CLOSED = true, BANKFRAME_CLOSED = true, MAIL_CLOSED = true, TRADE_CLOSED = true, AUCTION_HOUSE_CLOSED = true, GUILDBANKFRAME_CLOSED = true, VOID_STORAGE_CLOSE = true }
local MAX_UNKNOWN_OUTCOME_CHECKS = 3
local UNKNOWN_OUTCOME_RECHECK_DELAY = 0.5
local function EnsureCandidateQueue()
    Addon.runtime.candidateQueue = Addon.runtime.candidateQueue or {}
    Addon.runtime.candidateSet = Addon.runtime.candidateSet or {}
end
function Queue:RefreshCandidates()
    EnsureCandidateQueue()
    local runtime = Addon.runtime
    local eligible, retryAfter
    if Addon.BagAdapter.FindEligibleItems then
        eligible, retryAfter = Addon.BagAdapter:FindEligibleItems(Addon.db.catalog.entries, runtime.quarantined)
    else
        local bag, slot, item
        bag, slot, item, retryAfter = Addon.BagAdapter:FindNextEligible(Addon.db.catalog.entries, runtime.quarantined)
        eligible = item and { { bag = bag, slot = slot, item = item } } or {}
    end
    local present = {}
    for _, candidate in ipairs(eligible or {}) do present[candidate.item.itemID] = true end
    for index = #runtime.candidateQueue, 1, -1 do
        local itemID = runtime.candidateQueue[index]
        if not present[itemID] then
            table.remove(runtime.candidateQueue, index)
            runtime.candidateSet[itemID] = nil
        end
    end
    for _, candidate in ipairs(eligible or {}) do
        local itemID = candidate.item.itemID
        if not runtime.candidateSet[itemID] then
            runtime.candidateQueue[#runtime.candidateQueue + 1] = itemID
            runtime.candidateSet[itemID] = true
        end
    end
    return retryAfter
end
function Queue:PopCandidate()
    EnsureCandidateQueue()
    local runtime = Addon.runtime
    while #runtime.candidateQueue > 0 do
        local itemID = table.remove(runtime.candidateQueue, 1)
        runtime.candidateSet[itemID] = nil
        if not runtime.quarantined[itemID] then
            local bag, slot, item
            if Addon.BagAdapter.FindItemByID then
                bag, slot, item = Addon.BagAdapter:FindItemByID(itemID, Addon.db.catalog.entries, runtime.quarantined)
            else
                bag, slot, item = Addon.BagAdapter:FindNextEligible(Addon.db.catalog.entries, runtime.quarantined)
                if item and item.itemID ~= itemID then
                    runtime.candidateQueue[#runtime.candidateQueue + 1] = itemID
                    runtime.candidateSet[itemID] = true
                    item = nil
                end
            end
            if item then return bag, slot, item end
        end
    end
end
function Queue:RequeueCandidate(itemID)
    EnsureCandidateQueue()
    if Addon.runtime.quarantined[itemID] or Addon.runtime.candidateSet[itemID] then return end
    Addon.runtime.candidateQueue[#Addon.runtime.candidateQueue + 1] = itemID
    Addon.runtime.candidateSet[itemID] = true
end
function Queue:GetStatus()
    if Addon.db and not Addon.db.enabled then return "PAUSED", "DISABLED" end
    if not Addon.runtime.loggedIn then return "PAUSED", "PLAYER_UNAVAILABLE" end
    return Addon.runtime.queueState, Addon.runtime.pauseReason
end
function Queue:RequestScan()
    if not Addon.runtime.initialized then return end
    -- A scan request is only a request to inspect the latest bag state.  It
    -- must not invalidate an in-flight use operation: bag and spell events
    -- are expected while a container is opening.
    if Addon.runtime.scanQueued then return end
    Addon.runtime.scanQueued = true
    local function Run()
        Addon.runtime.scanQueued = nil
        if Addon.runtime.initialized then self:ProcessNext() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end
function Queue:ScheduleDeferredScan(delay)
    if not (C_Timer and C_Timer.After) then return end
    Addon.runtime.deferredScanGeneration = (Addon.runtime.deferredScanGeneration or 0) + 1
    local token = Addon.runtime.deferredScanGeneration
    C_Timer.After(math.max(0.1, math.min(5, tonumber(delay) or 0.5)), function()
        if token == Addon.runtime.deferredScanGeneration and Addon.runtime.initialized then self:RequestScan() end
    end)
end
function Queue:BeginRecoveryWindow(duration)
    local now = GetTime and GetTime() or 0
    local untilAt = now + math.max(0.5, tonumber(duration) or 5)
    Addon.runtime.recoveryUntil = math.max(Addon.runtime.recoveryUntil or 0, untilAt)
end
function Queue:RequestRecoveryScan(duration)
    self:BeginRecoveryWindow(duration)
    self:RequestScan()
end
function Queue:QuarantineItem(itemID, reason, delay)
    itemID = tonumber(itemID)
    if not itemID then return end
    Addon.runtime.quarantineTokens = Addon.runtime.quarantineTokens or {}
    Addon.runtime.quarantined = Addon.runtime.quarantined or {}
    Addon.runtime.quarantineReasons = Addon.runtime.quarantineReasons or {}
    Addon.runtime.quarantineTokens[itemID] = (Addon.runtime.quarantineTokens[itemID] or 0) + 1
    local token = Addon.runtime.quarantineTokens[itemID]
    Addon.runtime.quarantined[itemID] = true
    Addon.runtime.quarantineReasons[itemID] = reason or "retry-backoff"
    if delay then
        if C_Timer and C_Timer.After then
            C_Timer.After(math.max(1, tonumber(delay) or 15), function()
                if not Addon.runtime.initialized or Addon.runtime.quarantineTokens[itemID] ~= token then return end
                self:ReleaseQuarantine(itemID, token)
            end)
        else
            self:ReleaseQuarantine(itemID, token)
        end
    end
end
function Queue:ReleaseQuarantine(itemID, token)
    if token and Addon.runtime.quarantineTokens[itemID] ~= token then return end
    Addon.runtime.quarantineReasons = Addon.runtime.quarantineReasons or {}
    Addon.runtime.quarantined = Addon.runtime.quarantined or {}
    Addon.runtime.quarantined[itemID] = nil
    Addon.runtime.quarantineReasons[itemID] = nil
    Addon.runtime.failures[itemID] = nil
    Addon.runtime.warned["quarantine:" .. itemID] = nil
    if Addon.runtime.quarantineTokens[itemID] then Addon.runtime.quarantineTokens[itemID] = Addon.runtime.quarantineTokens[itemID] + 1 end
    self:RequestScan()
end
function Queue:ClearQuarantineForTrigger(itemID, trigger)
    itemID = tonumber(itemID)
    if not itemID then return false end
    local reason = Addon.runtime.quarantineReasons[itemID]
    if reason == "bind-cancelled" and trigger ~= "manual" then return false end
    if reason and reason ~= "retry-backoff" and trigger ~= "manual" then return false end
    if Addon.runtime.quarantined[itemID] then
        self:ReleaseQuarantine(itemID, Addon.runtime.quarantineTokens[itemID])
    else
        Addon.runtime.failures[itemID] = nil
        Addon.runtime.warned["quarantine:" .. itemID] = nil
    end
    return true
end
function Queue:ReleaseQuarantineAfter(itemID, delay)
    self:QuarantineItem(itemID, "retry-backoff", delay)
end
function Queue:ReleaseTransientWorldQuarantine()
    for itemID in pairs(Addon.runtime.quarantined) do
        self:ClearQuarantineForTrigger(itemID, "world-ready")
    end
end
function Queue:CancelItem(itemID)
    if Addon.runtime.pending and Addon.runtime.pending.itemID == itemID then
        if Addon.BindConfirmAssist then Addon.BindConfirmAssist:Disarm(Addon.runtime.pending) end
        Addon.runtime.generation = Addon.runtime.generation + 1; Addon.runtime.pending = nil; Addon.runtime.queueState = "IDLE"; Addon.runtime.pauseReason = nil
    end
end
function Queue:Clear()
    if Addon.runtime.pending and Addon.BindConfirmAssist then Addon.BindConfirmAssist:Disarm(Addon.runtime.pending) end
    Addon.runtime.generation = Addon.runtime.generation + 1
    Addon.runtime.deferredScanGeneration = (Addon.runtime.deferredScanGeneration or 0) + 1
    Addon.runtime.pending = nil; Addon.runtime.scanQueued = nil; Addon.runtime.candidateQueue = {}; Addon.runtime.candidateSet = {}; Addon.runtime.queueState = "IDLE"; Addon.runtime.pauseReason = nil
end
function Queue:ProcessNext()
    if Addon.runtime.pending then return end
    local retryAfter = self:RefreshCandidates()
    local bag, slot, item = self:PopCandidate()
    if not item and not retryAfter then
        Addon.runtime.queueState = "IDLE"
        Addon.runtime.pauseReason = nil
        Addon.runtime.warned.space = nil
        return
    end
    local ok, reason = Addon.Safety:CanRun()
    if not ok then
        Addon.runtime.pauseReason = reason
        local now = GetTime and GetTime() or 0
        local worldRetryActive = Addon.runtime.recoveryUntil and now < Addon.runtime.recoveryUntil
        if reason == "BAG_DATA_PENDING" or (worldRetryActive and (reason == "WORLD_LOADING" or reason == "PLAYER_UNAVAILABLE" or reason == "CASTING" or reason == "IN_COMBAT")) then
            Addon.runtime.queueState = "WAITING_READY"
            Addon.runtime.warned.space = nil
            self:ScheduleDeferredScan(0.5)
        else
            Addon.runtime.queueState = "PAUSED"
            if reason == "INSUFFICIENT_SPACE" then Addon:NotifyIssue("space", "通用背包空位不足，已暂停自动开包。") else Addon.runtime.warned.space = nil end
        end
        return
    end
    Addon.runtime.pauseReason = nil
    Addon.runtime.warned.space = nil
    if not item then
        Addon.runtime.queueState = retryAfter and "WAITING_READY" or "IDLE"
        if retryAfter then self:ScheduleDeferredScan(retryAfter) end
        return
    end
    local queued = Addon.runtime.candidateQueue or {}
    local maxRetries = Addon.LIMITS.maxRetries or 2
    local exhausted = (Addon.runtime.failures[item.itemID] or 0) >= maxRetries
    local othersExhausted = #queued > 0
    for _, otherID in ipairs(queued) do
        if (Addon.runtime.failures[otherID] or 0) < maxRetries then othersExhausted = false; break end
    end
    if exhausted and (#queued == 0 or othersExhausted) then
        local delay = Addon.LIMITS.retryBackoff or 15
        self:QuarantineItem(item.itemID, "retry-backoff", delay)
        Addon.runtime.queueState = #queued > 0 and "READY" or "WAITING_READY"
        Addon.runtime.pauseReason = #queued > 0 and nil or "RETRY_BACKOFF"
        if #queued > 0 then self:RequestScan() end
        return
    end
    Addon.runtime.queueState = "USING"
    local pending = { itemID = item.itemID, bag = bag, slot = slot, slotItemID = item.itemID, slotCount = item.count, beforeTotal = Addon.BagAdapter:GetTotalItemCount(item.itemID), retries = Addon.runtime.failures[item.itemID] or 0, startedAt = GetTime and GetTime() or 0, token = Addon.runtime.generation }
    Addon.runtime.pending = pending
    if Addon.BindConfirmAssist then Addon.BindConfirmAssist:Arm(pending) end
    local useOK, useError = pcall(function() Addon.BagAdapter:UseItem(bag, slot) end)
    pending.useCallFailed = not useOK
    Addon.runtime.queueState = "WAITING_RESULT"
    if not useOK then Addon:NotifyIssue("use-call:" .. item.itemID, "调用容器开启接口失败，稍后会按失败重试：" .. tostring(useError)) end
    local function Timeout()
        if Addon.runtime.pending ~= pending or pending.token ~= Addon.runtime.generation then return end
        if pending.awaitingBindConfirmation then
            if C_Timer and C_Timer.After then C_Timer.After(Addon.LIMITS.operationTimeout, Timeout) end
            return
        end
        self:ResolvePending(false)
    end
    if C_Timer and C_Timer.After then C_Timer.After(Addon.LIMITS.operationTimeout, Timeout) end
end
function Queue:ResolvePending(fromBagEvent)
    local pending = Addon.runtime.pending; if not pending then return end
    if pending.token ~= Addon.runtime.generation then
        if Addon.BindConfirmAssist then Addon.BindConfirmAssist:Disarm(pending) end
        Addon.runtime.pending = nil; Addon.runtime.queueState = "READY"; Addon.runtime.pauseReason = nil; self:RequestScan(); return
    end
    local safe, safetyReason = Addon.Safety:CanRun()
    if not safe and safetyReason ~= "DISABLED" then
        Addon.runtime.queueState = "WAITING_READY"
        Addon.runtime.pauseReason = safetyReason
        if C_Timer and C_Timer.After and not pending.safetyRecheckScheduled then
            pending.safetyRecheckScheduled = true
            C_Timer.After(0.5, function()
                if Addon.runtime.pending ~= pending or pending.token ~= Addon.runtime.generation then return end
                pending.safetyRecheckScheduled = nil
                self:ResolvePending(false)
            end)
        end
        return
    end
    local used
    if pending.useCallFailed then
        used = false
    elseif type(Addon.BagAdapter.DidUseItem) == "function" then
        used = Addon.BagAdapter:DidUseItem(pending)
    else
        used = Addon.BagAdapter:GetTotalItemCount(pending.itemID) < pending.beforeTotal
    end
    if used == true then
        if Addon.BindConfirmAssist then Addon.BindConfirmAssist:AwaitPossibleBind(pending) end
        Addon.runtime.failures[pending.itemID] = nil; Addon.runtime.pending = nil; Addon.runtime.queueState = "READY"; Addon.runtime.pauseReason = nil; self:RequestScan(); return
    end
    if fromBagEvent then return end
    if used == nil then
        pending.unknownOutcomeChecks = (pending.unknownOutcomeChecks or 0) + 1
        if pending.unknownOutcomeChecks <= MAX_UNKNOWN_OUTCOME_CHECKS and C_Timer and C_Timer.After and not pending.outcomeRecheckScheduled then
            pending.outcomeRecheckScheduled = true
            C_Timer.After(UNKNOWN_OUTCOME_RECHECK_DELAY, function()
                if Addon.runtime.pending ~= pending or pending.token ~= Addon.runtime.generation then return end
                pending.outcomeRecheckScheduled = nil
                self:ResolvePending(false)
            end)
            return
        end
        -- Never leave the queue holding an unresolved pending item forever.
        -- After bounded observation, account for this as a failed attempt so
        -- retry/backoff can quarantine it and allow other items to proceed.
    end
    pending.retries = pending.retries + 1; Addon.runtime.failures[pending.itemID] = pending.retries
    local otherCandidates = Addon.runtime.candidateQueue or {}
    local allOthersExhausted = #otherCandidates > 0
    for _, itemID in ipairs(otherCandidates) do
        if (Addon.runtime.failures[itemID] or 0) < Addon.LIMITS.maxRetries then allOthersExhausted = false; break end
    end
    local shouldQuarantine = pending.retries >= Addon.LIMITS.maxRetries and (#otherCandidates == 0 or allOthersExhausted)
    if shouldQuarantine then
        local retryDelay = Addon.LIMITS.retryBackoff or 15
        if Addon.BindConfirmAssist then Addon.BindConfirmAssist:Disarm(pending) end
        self:QuarantineItem(pending.itemID, "retry-backoff", retryDelay)
        Addon.runtime.pending = nil
        Addon.runtime.queueState = #otherCandidates > 0 and "READY" or "WAITING_READY"
        Addon.runtime.pauseReason = #otherCandidates > 0 and nil or "RETRY_BACKOFF"
        Addon:NotifyIssue("quarantine:" .. pending.itemID, "物品 #" .. pending.itemID .. " 连续失败，将在 " .. tostring(retryDelay) .. " 秒后重试。")
        if #otherCandidates > 0 then self:RequestScan() end
    else
        if Addon.BindConfirmAssist then Addon.BindConfirmAssist:Disarm(pending) end
        self:RequeueCandidate(pending.itemID)
        Addon.runtime.pending = nil; Addon.runtime.queueState = "READY"; Addon.runtime.pauseReason = nil; self:RequestScan()
    end
end
function Queue:ScheduleBagRefresh()
    self:ResolvePending(true)
    if not (C_Timer and C_Timer.After) then return end
    Addon.runtime.bagScanGeneration = (Addon.runtime.bagScanGeneration or 0) + 1
    local token = Addon.runtime.bagScanGeneration
    C_Timer.After(0.2, function()
        if token == Addon.runtime.bagScanGeneration and Addon.runtime.initialized then
            self:ResolvePending(true)
            self:RequestScan()
        end
    end)
end
function Queue:OnEvent(event, ...)
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then self:ScheduleBagRefresh()
    elseif event == "ITEM_PUSH" then
        -- ITEM_PUSH identifies a newly received item more precisely than a
        -- generic bag update.  A previous transient failure for the same ID
        -- must not suppress this fresh acquisition.
        self:ClearQuarantineForTrigger((...), "item-push")
        self:BeginRecoveryWindow(10)
        self:ScheduleBagRefresh()
    elseif event == "LOOT_BIND_CONFIRM" then
        if Addon.BindConfirmAssist then Addon.BindConfirmAssist:HandleLootBindConfirm() end
    elseif event == "LOOT_OPENED" then
        if Addon.BindConfirmAssist then Addon.BindConfirmAssist:CaptureLootSource() end
        Addon.runtime.queueState = "PAUSED"; Addon.runtime.pauseReason = "LOOT_OPEN"
    elseif event == "LOOT_CLOSED" then
        if Addon.BindConfirmAssist then Addon.BindConfirmAssist:ClearLootSource() end
        self:RequestRecoveryScan(5)
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then self:RequestRecoveryScan(5)
    elseif event == "PLAYER_DEAD" then Addon.runtime.queueState = "PAUSED"; Addon.runtime.pauseReason = "PLAYER_UNAVAILABLE"
    elseif SENSITIVE_OPEN_EVENTS[event] then Addon.Safety:SetSensitive(event, true); Addon.runtime.queueState = "PAUSED"; Addon.runtime.pauseReason = "SENSITIVE_UI"
    elseif SENSITIVE_CLOSE_EVENTS[event] then
        local openEvent = { MERCHANT_CLOSED="MERCHANT_SHOW", BANKFRAME_CLOSED="BANKFRAME_OPENED", MAIL_CLOSED="MAIL_SHOW", TRADE_CLOSED="TRADE_SHOW", AUCTION_HOUSE_CLOSED="AUCTION_HOUSE_SHOW", GUILDBANKFRAME_CLOSED="GUILDBANKFRAME_OPENED", VOID_STORAGE_CLOSE="VOID_STORAGE_OPEN" }
        Addon.Safety:SetSensitive(openEvent[event], false); self:RequestRecoveryScan(5)
    elseif event:find("^UNIT_SPELLCAST_") then local unit = ...; if unit == "player" and event ~= "UNIT_SPELLCAST_START" and (not InCombatLockdown or not InCombatLockdown()) then self:RequestRecoveryScan(5) end end
end
function Queue:ScheduleWorldReadyScans()
    if Addon.Safety and Addon.Safety.ReconcileSensitiveFrames then Addon.Safety:ReconcileSensitiveFrames() end
    self:ReleaseTransientWorldQuarantine()
    self:BeginRecoveryWindow(Addon.LIMITS.worldRetryWindow or 20)
    self:RequestScan()
    if not (C_Timer and C_Timer.After) then self:RequestScan(); return end
    Addon.runtime.worldScanGeneration = (Addon.runtime.worldScanGeneration or 0) + 1
    local token = Addon.runtime.worldScanGeneration
    for _, delay in ipairs(Addon.LIMITS.worldReadyRetryDelays or { 0.5, 2.0, 5.0, 10.0 }) do
        C_Timer.After(delay, function()
            if token == Addon.runtime.worldScanGeneration and Addon.runtime.initialized then
                Addon:Refresh()
            end
        end)
    end
end
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then if ... == Addon.NAME then Addon:Initialize() end; return end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Addon:Initialize()
        if not Addon.runtime.loggedIn then Addon:StartPostLogin() end
        if event == "PLAYER_ENTERING_WORLD" then
            Addon.runtime.worldLoading = false
            Addon.runtime.startupScansStarted = true
            Queue:ScheduleWorldReadyScans()
        end
        return
    end
    if not Addon.runtime.initialized then Addon:Initialize() end
    if Addon.runtime.initialized then
        if event == "LOADING_SCREEN_ENABLED" then
            Addon.runtime.worldLoading = true
            Addon.runtime.worldScanGeneration = (Addon.runtime.worldScanGeneration or 0) + 1
            Addon.runtime.queueState = "PAUSED"
            Addon.runtime.pauseReason = "WORLD_LOADING"
        elseif event == "LOADING_SCREEN_DISABLED" then
            Addon.runtime.worldLoading = false
            Queue:ScheduleWorldReadyScans()
        elseif event == "INSTANCE_CHANGED" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
            -- Some clients do not deliver LOADING_SCREEN_DISABLED or deliver
            -- PLAYER_ENTERING_WORLD before the final instance/zone event.
            -- Treat this event as the world-ready fallback so a stale loading
            -- flag cannot suppress every subsequent scan.
            Addon.runtime.worldLoading = false
            Queue:ScheduleWorldReadyScans()
        else
            Queue:OnEvent(event, ...)
        end
    end
end)

-- Event availability differs between WoW branches.  Register each event in
-- isolation so one unsupported optional event cannot prevent PLAYER_LOGIN,
-- PLAYER_ENTERING_WORLD and bag events from receiving an OnEvent handler.
local events = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED", "INSTANCE_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_PUSH", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "LOOT_OPENED", "LOOT_CLOSED", "LOOT_BIND_CONFIRM", "MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED", "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "VOID_STORAGE_OPEN", "VOID_STORAGE_CLOSE", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }
for _, event in ipairs(events) do
    pcall(frame.RegisterEvent, frame, event)
end
