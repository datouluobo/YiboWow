local Addon = _G.YiboAutoOpen
local Queue = {}; Addon.Queue = Queue
local function ReasonText(reason)
    return ({ DISABLED="已关闭", IN_COMBAT="战斗中", PLAYER_UNAVAILABLE="角色当前不可操作", CASTING="正在施法", LOOT_OPEN="拾取窗口已打开", SENSITIVE_UI="敏感界面已打开", BAG_DATA_PENDING="背包数据尚未就绪", INSUFFICIENT_SPACE="通用背包空位不足" })[reason] or reason
end
function Queue:GetStatus() local ok, reason = Addon.Safety:CanRun(); return Addon.runtime.queueState, ok and nil or reason end
function Queue:RequestScan(reason)
    if not Addon.runtime.initialized then return end
    -- A scan request is only a request to inspect the latest bag state.  It
    -- must not invalidate an in-flight use operation: bag and spell events
    -- are expected while a container is opening.
    Addon.runtime.lastScanReason = reason
    if Addon.runtime.scanQueued then return end
    Addon.runtime.scanQueued = true
    local function Run()
        Addon.runtime.scanQueued = nil
        if Addon.runtime.initialized then self:ProcessNext() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end
function Queue:ScheduleDeferredScan(delay, reason)
    if not (C_Timer and C_Timer.After) then return end
    Addon.runtime.deferredScanGeneration = (Addon.runtime.deferredScanGeneration or 0) + 1
    local token = Addon.runtime.deferredScanGeneration
    C_Timer.After(math.max(0.1, math.min(5, tonumber(delay) or 0.5)), function()
        if token == Addon.runtime.deferredScanGeneration and Addon.runtime.initialized then self:RequestScan(reason or "deferred") end
    end)
end
function Queue:CancelItem(itemID)
    if Addon.runtime.pending and Addon.runtime.pending.itemID == itemID then Addon.runtime.generation = Addon.runtime.generation + 1; Addon.runtime.pending = nil; Addon.runtime.queueState = "IDLE" end
end
function Queue:Clear()
    Addon.runtime.generation = Addon.runtime.generation + 1
    Addon.runtime.deferredScanGeneration = (Addon.runtime.deferredScanGeneration or 0) + 1
    Addon.runtime.pending = nil; Addon.runtime.scanQueued = nil; Addon.runtime.lastScanReason = nil; Addon.runtime.queueState = "IDLE"
end
function Queue:ProcessNext()
    if Addon.runtime.pending then return end
    local bag, slot, item, retryAfter = Addon.BagAdapter:FindNextEligible(Addon.db.catalog.entries, Addon.runtime.quarantined)
    if not item and not retryAfter then
        Addon.runtime.queueState = "IDLE"
        Addon.runtime.warned.space = nil
        return
    end
    local ok, reason = Addon.Safety:CanRun()
    if not ok then
        if reason == "BAG_DATA_PENDING" then
            Addon.runtime.queueState = "WAITING_READY"
            Addon.runtime.warned.space = nil
            self:ScheduleDeferredScan(0.5, "bag-data-ready")
        else
            Addon.runtime.queueState = "PAUSED"
            if reason == "INSUFFICIENT_SPACE" then Addon:NotifyIssue("space", "通用背包空位不足，已暂停自动开包。") else Addon.runtime.warned.space = nil end
        end
        return
    end
    Addon.runtime.warned.space = nil
    if not item then
        Addon.runtime.queueState = retryAfter and "WAITING_READY" or "IDLE"
        if retryAfter then self:ScheduleDeferredScan(retryAfter, "item-ready") end
        return
    end
    Addon.runtime.queueState = "USING"
    local pending = { itemID = item.itemID, bag = bag, slot = slot, before = Addon.BagAdapter:GetTotalItemCount(item.itemID), retries = Addon.runtime.failures[item.itemID] or 0, startedAt = GetTime and GetTime() or 0, token = Addon.runtime.generation }
    Addon.runtime.pending = pending; Addon.BagAdapter:UseItem(bag, slot); Addon.runtime.queueState = "WAITING_RESULT"
    local function Timeout()
        if Addon.runtime.pending ~= pending or pending.token ~= Addon.runtime.generation then return end
        self:ResolvePending(false)
    end
    if C_Timer and C_Timer.After then C_Timer.After(Addon.LIMITS.operationTimeout, Timeout) end
end
function Queue:ResolvePending(fromBagEvent)
    local pending = Addon.runtime.pending; if not pending then return end
    if pending.token ~= Addon.runtime.generation then
        Addon.runtime.pending = nil; Addon.runtime.queueState = "READY"; self:RequestScan("operation-cancelled"); return
    end
    if Addon.BagAdapter:GetTotalItemCount(pending.itemID) < pending.before then
        Addon.runtime.failures[pending.itemID] = nil; Addon.runtime.pending = nil; Addon.runtime.queueState = "READY"; self:RequestScan("success"); return
    end
    if fromBagEvent then return end
    pending.retries = pending.retries + 1; Addon.runtime.failures[pending.itemID] = pending.retries
    if pending.retries >= Addon.LIMITS.maxRetries then
        Addon.runtime.quarantined[pending.itemID] = true; Addon.runtime.pending = nil; Addon.runtime.queueState = "READY"; Addon:NotifyIssue("quarantine:" .. pending.itemID, "物品 #" .. pending.itemID .. " 连续失败，已在本次登录跳过。"); self:RequestScan("quarantined")
    else
        Addon.runtime.pending = nil; Addon.runtime.queueState = "READY"; self:RequestScan("retry")
    end
end
function Queue:ScheduleBagRefresh(event)
    self:ResolvePending(true)
    self:RequestScan(event)
    if not (C_Timer and C_Timer.After) then return end
    Addon.runtime.bagScanGeneration = (Addon.runtime.bagScanGeneration or 0) + 1
    local token = Addon.runtime.bagScanGeneration
    C_Timer.After(0.2, function()
        if token == Addon.runtime.bagScanGeneration and Addon.runtime.initialized then
            self:ResolvePending(true)
            self:RequestScan(event .. "-settled")
        end
    end)
end
function Queue:OnEvent(event, ...)
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "ITEM_PUSH" then self:ScheduleBagRefresh(event)
    elseif event == "LOOT_OPENED" then Addon.runtime.queueState = "PAUSED"
    elseif event == "LOOT_CLOSED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then self:RequestScan(event)
    elseif event == "PLAYER_DEAD" then Addon.runtime.queueState = "PAUSED"
    elseif event:find("_SHOW$") or event:find("_OPENED$") or event == "VOID_STORAGE_OPEN" then Addon.Safety:SetSensitive(event, true); self:RequestScan(event)
    elseif event:find("_CLOSED$") or event == "VOID_STORAGE_CLOSE" then
        local openEvent = { MERCHANT_CLOSED="MERCHANT_SHOW", BANKFRAME_CLOSED="BANKFRAME_OPENED", MAIL_CLOSED="MAIL_SHOW", TRADE_CLOSED="TRADE_SHOW", AUCTION_HOUSE_CLOSED="AUCTION_HOUSE_SHOW", GUILDBANKFRAME_CLOSED="GUILDBANKFRAME_OPENED", VOID_STORAGE_CLOSE="VOID_STORAGE_OPEN" }
        Addon.Safety:SetSensitive(openEvent[event], false); self:RequestScan(event)
    elseif event:find("UNIT_SPELLCAST") then local unit = ...; if unit == "player" then self:RequestScan(event) end end
end
local frame = CreateFrame("Frame")
local function ScheduleWorldReadyScans()
    if not (C_Timer and C_Timer.After) then return end
    Addon.runtime.worldScanGeneration = (Addon.runtime.worldScanGeneration or 0) + 1
    local token = Addon.runtime.worldScanGeneration
    for _, delay in ipairs({ 0.5, 2.0, 5.0, 10.0 }) do
        C_Timer.After(delay, function()
            if token == Addon.runtime.worldScanGeneration and Addon.runtime.initialized then
                Addon:Refresh("world-ready-" .. delay)
            end
        end)
    end
end
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then if ... == Addon.NAME then Addon:Initialize() end; return end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Addon:Initialize()
        Addon:StartPostLogin(event)
        if event == "PLAYER_ENTERING_WORLD" and not Addon.runtime.startupScansStarted then
            Addon.runtime.startupScansStarted = true
            ScheduleWorldReadyScans()
        end
        return
    end
    if not Addon.runtime.initialized then Addon:Initialize() end
    if Addon.runtime.initialized then Queue:OnEvent(event, ...) end
end)

-- Event availability differs between WoW branches.  Register each event in
-- isolation so one unsupported optional event cannot prevent PLAYER_LOGIN,
-- PLAYER_ENTERING_WORLD and bag events from receiving an OnEvent handler.
local events = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_PUSH", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "LOOT_OPENED", "LOOT_CLOSED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "VOID_STORAGE_OPEN", "VOID_STORAGE_CLOSE", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }
local registration = { registered = 0, unsupported = {} }
for _, event in ipairs(events) do
    local ok, result = pcall(frame.RegisterEvent, frame, event)
    if ok and result ~= false then registration.registered = registration.registered + 1 else registration.unsupported[#registration.unsupported + 1] = event end
end
Addon.runtime.eventRegistration = registration
