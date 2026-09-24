local Addon = _G.YiboAutoOpen
local Assist = {}
Addon.BindConfirmAssist = Assist

local POPUP_KIND = "LOOT_BIND"
local POPUP_COUNT = 4
local EDGE_PADDING = 16

local function IsPositionAssistEnabled()
    return not (Addon.db and Addon.db.bindConfirmFollowCursor == false)
end

local function GetVisibleBindPopup()
    for index = 1, POPUP_COUNT do
        local popup = _G["StaticPopup" .. index]
        if popup and popup.which == POPUP_KIND and popup.IsShown and popup:IsShown() then return popup end
    end
end

local function GetPopupButton(popup, index)
    local field = popup["button" .. index]
    if field then return field end
    local name = popup.GetName and popup:GetName()
    return name and _G[name .. "Button" .. index]
end

local function GetCursorCenter(popup)
    local rawX, rawY = GetCursorPosition()
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    local screenWidth = GetScreenWidth and GetScreenWidth() or 0
    local screenHeight = GetScreenHeight and GetScreenHeight() or 0
    local x, y = rawX, rawY
    local cursorSource = "api-ui-parent-scale"
    -- The confirmation is independent of the loot window.  Fast-loot addons
    -- may hide or rebuild LootFrame, so always convert from UIParent only.
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 0
    -- GetCursorPosition returns physical pixels.  UI anchors use UIParent
    -- coordinates, so this must be converted through the UI owner's effective
    -- scale.
    if rawX and rawY and scale and scale > 0 then
        x, y = rawX / scale, rawY / scale
    else
        x, y = width / 2, height / 2
        cursorSource = "ui-center-fallback"
    end
    local popupX, popupY = popup:GetCenter()
    local button = GetPopupButton(popup, 1)
    local buttonOffsetX, buttonOffsetY = 0, 0
    if button and button.GetCenter and popupX and popupY then
        local buttonX, buttonY = button:GetCenter()
        if buttonX and buttonY then
            buttonOffsetX, buttonOffsetY = buttonX - popupX, buttonY - popupY
            x, y = x - buttonOffsetX, y - buttonOffsetY
        end
    end
    local halfWidth = (popup:GetWidth() or 0) / 2
    local halfHeight = (popup:GetHeight() or 0) / 2
    if width > 0 then x = math.max(EDGE_PADDING + halfWidth, math.min(width - EDGE_PADDING - halfWidth, x)) end
    if height > 0 then y = math.max(EDGE_PADDING + halfHeight, math.min(height - EDGE_PADDING - halfHeight, y)) end
    return x, y, { rawX = rawX or 0, rawY = rawY or 0, screenWidth = screenWidth, screenHeight = screenHeight, parentWidth = width, parentHeight = height, effectiveScale = scale, buttonOffsetX = buttonOffsetX, buttonOffsetY = buttonOffsetY, cursorSource = cursorSource }
end

function Assist:Arm(pending)
    if not IsPositionAssistEnabled() then return end
    if Addon.Database and Addon.Database.IsConfirmSourceEnabled
        and not Addon.Database:IsConfirmSourceEnabled("auto-open-catalog") then return end
    Addon.runtime.bindConfirmCandidate = pending
end

function Assist:Disarm(pending)
    if Addon.runtime.bindConfirmCandidate == pending then Addon.runtime.bindConfirmCandidate = nil end
end

function Assist:AwaitPossibleBind(pending)
    if Addon.runtime.bindConfirmCandidate ~= pending then return end
    pending.awaitingBindEvent = true
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            if Addon.runtime.bindConfirmCandidate == pending and pending.awaitingBindEvent then Assist:Disarm(pending) end
        end)
    end
end

function Assist:Cancel(pending)
    self:Disarm(pending)
    pending.awaitingBindConfirmation, pending.awaitingBindEvent = nil, nil
    if Addon.runtime.pending == pending then
        if Addon.Queue and Addon.Queue.QuarantineItem then
            Addon.Queue:QuarantineItem(pending.itemID, "bind-cancelled")
        else
            Addon.runtime.quarantined[pending.itemID] = true
            Addon.runtime.quarantineReasons = Addon.runtime.quarantineReasons or {}
            Addon.runtime.quarantineReasons[pending.itemID] = "bind-cancelled"
        end
        Addon.runtime.pending = nil
        Addon.runtime.queueState = "READY"
        Addon.runtime.pauseReason = nil
        Addon:NotifyIssue("bind-cancelled:" .. pending.itemID, "已取消拾取后绑定确认；物品 #" .. pending.itemID .. " 将在本次登录跳过。")
        if Addon.Queue then Addon.Queue:RequestScan() end
    end
end

function Assist:OnChoice(popup, accepted)
    local pending = popup.yiboAutoOpenBindPending
    if not pending then return end
    if accepted then
        pending.awaitingBindConfirmation = nil
    else
        self:Cancel(pending)
    end
end

function Assist:RestorePopup(popup)
    local point = popup.yiboAutoOpenOriginalPoint
    if not point then return end
    local currentX, currentY = popup:GetCenter()
    local record = Addon.runtime.lastBindPlacement
    if record then record.finalPopupX, record.finalPopupY = currentX, currentY end
    popup.yiboAutoOpenOriginalPoint = nil
    popup:ClearAllPoints()
    popup:SetPoint(unpack(point))
end

function Assist:HandlePopupHidden(popup)
    local pending = popup.yiboAutoOpenBindPending
    if not pending then return end
    local function FinishHide()
        -- StaticPopup can briefly hide while it is being rebuilt or relaid out
        -- after a reload.  Treat it as a dismissal only if it is still hidden
        -- on the following frame; otherwise retain the original placement.
        if popup.yiboAutoOpenBindPending ~= pending or (popup.IsShown and popup:IsShown()) then return end
        popup.yiboAutoOpenBindPending = nil
        Assist:RestorePopup(popup)
        if pending.awaitingBindConfirmation then Assist:Cancel(pending) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, FinishHide) else FinishHide() end
end

function Assist:PlacePopup(popup, pending)
    if popup.yiboAutoOpenBindPending ~= pending then return end
    local currentX, currentY = popup:GetCenter()
    if currentX and currentY and math.abs(currentX - popup.yiboAutoOpenCursorX) < 0.5 and math.abs(currentY - popup.yiboAutoOpenCursorY) < 0.5 then return end
    popup.yiboAutoOpenPlacing = true
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", UIParent, "BOTTOMLEFT", popup.yiboAutoOpenCursorX, popup.yiboAutoOpenCursorY)
    popup.yiboAutoOpenPlacing = nil
    local appliedX, appliedY = popup:GetCenter()
    local record = Addon.runtime.lastBindPlacement
    if record then record.appliedPopupX, record.appliedPopupY = appliedX, appliedY end
end

function Assist:RefreshPopupTarget(popup, pending)
    local cursorX, cursorY, cursor = GetCursorCenter(popup)
    popup.yiboAutoOpenCursorX, popup.yiboAutoOpenCursorY = cursorX, cursorY
    cursor.targetPopupX, cursor.targetPopupY = cursorX, cursorY
    Addon.runtime.lastBindPlacement = cursor
end

function Assist:ScheduleLayoutConfirmation(popup, pending)
    if not (C_Timer and C_Timer.After) then return end
    -- A final next-frame check catches layouts deferred by the popup itself.
    -- Further changes are handled by the StaticPopup_Show post-hook instead.
    C_Timer.After(0, function()
        if popup.IsShown and popup:IsShown() then
            Assist:RefreshPopupTarget(popup, pending)
            Assist:PlacePopup(popup, pending)
        end
    end)
end

function Assist:InstallLayoutHook(popup)
    if popup.yiboAutoOpenLayoutHooked or not hooksecurefunc then return end
    popup.yiboAutoOpenLayoutHooked = true
    hooksecurefunc(popup, "SetPoint", function(frame)
        local pending = frame.yiboAutoOpenBindPending
        if pending and not frame.yiboAutoOpenPlacing then
            -- This is event-driven: repair only an actual later SetPoint from
            -- another layout owner, rather than repeatedly polling the frame.
            Assist:ScheduleLayoutConfirmation(frame, pending)
        end
    end)
end

function Assist:PreparePopup(popup, pending)
    if not IsPositionAssistEnabled() then return end
    if popup.yiboAutoOpenBindPending == pending then return true end
    local point, relativeTo, relativePoint, x, y = popup:GetPoint(1)
    if point then popup.yiboAutoOpenOriginalPoint = { point, relativeTo, relativePoint, x, y } end
    self:RefreshPopupTarget(popup, pending)
    popup.yiboAutoOpenBindPending = pending
    pending.awaitingBindConfirmation, pending.awaitingBindEvent = true, nil
    self:Disarm(pending)
    self:PlacePopup(popup, pending)
    self:InstallLayoutHook(popup)
    self:ScheduleLayoutConfirmation(popup, pending)

    if not popup.yiboAutoOpenBindHooks then
        popup.yiboAutoOpenBindHooks = true
        popup:HookScript("OnShow", function(frame)
            local active = frame.yiboAutoOpenBindPending
            if active then Assist:ScheduleLayoutConfirmation(frame, active) end
        end)
        popup:HookScript("OnHide", function(frame) Assist:HandlePopupHidden(frame) end)
        local button1, button2 = GetPopupButton(popup, 1), GetPopupButton(popup, 2)
        if button1 then button1:HookScript("OnClick", function() Assist:OnChoice(popup, true) end) end
        if button2 then button2:HookScript("OnClick", function() Assist:OnChoice(popup, false) end) end
    end
    return true
end

function Assist:HandleStaticPopupShow(which)
    if which ~= POPUP_KIND then return end
    local pending = Addon.runtime.bindConfirmCandidate
    if not pending then return end
    local popup = GetVisibleBindPopup()
    if popup then self:PreparePopup(popup, pending) end
end

function Assist:HandleLootBindConfirm()
    local pending = Addon.runtime.bindConfirmCandidate
    if not pending and Addon.runtime.confirmLootSourceKey then
        pending = { source = Addon.runtime.confirmLootSourceKey, lootSlot = Addon.runtime.pandariaDarkSoilLoot }
        Addon.runtime.bindConfirmCandidate = pending
    end
    if not pending then return end
    local function Attach()
        if Addon.runtime.bindConfirmCandidate ~= pending then return end
        local popup = GetVisibleBindPopup()
        if popup then Assist:PreparePopup(popup, pending) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Attach) else Attach() end
end

function Assist:CaptureLootSource()
    Addon.runtime.pandariaDarkSoilLoot = nil
    Addon.runtime.confirmLootSourceKey = nil
    Addon.runtime.recentConfirmObjects = Addon.runtime.recentConfirmObjects or {}
    Addon.runtime.recentConfirmObjectOrder = Addon.runtime.recentConfirmObjectOrder or {}
    if not GetLootSourceInfo or not GetNumLootItems then return end
    local count = GetNumLootItems() or 0
    for lootSlot = 1, count do
        local sourceGUID, sourceName = GetLootSourceInfo(lootSlot)
        local objectID = Addon.Catalog and Addon.Catalog.GetGameObjectID
            and Addon.Catalog:GetGameObjectID(sourceGUID)
        local sourceKey = objectID and ("object:" .. objectID) or nil
        if objectID then
            local recent = Addon.runtime.recentConfirmObjects[objectID]
            if not recent then
                recent = { objectID = objectID, label = sourceName or ("拾取来源对象 #" .. objectID) }
                Addon.runtime.recentConfirmObjects[objectID] = recent
                table.insert(Addon.runtime.recentConfirmObjectOrder, 1, objectID)
                while #Addon.runtime.recentConfirmObjectOrder > 10 do
                    local removed = table.remove(Addon.runtime.recentConfirmObjectOrder)
                    Addon.runtime.recentConfirmObjects[removed] = nil
                end
            elseif sourceName and sourceName ~= "" then
                recent.label = sourceName
            end
            if IsPositionAssistEnabled() and sourceKey and Addon.Database and Addon.Database:IsConfirmSourceEnabled(sourceKey) then
                Addon.runtime.pandariaDarkSoilLoot = lootSlot
                Addon.runtime.confirmLootSourceKey = sourceKey
                return
            end
        end
    end
end

function Assist:GetRecentConfirmObjects()
    local result = {}
    local order = Addon.runtime.recentConfirmObjectOrder or {}
    local objects = Addon.runtime.recentConfirmObjects or {}
    for _, objectID in ipairs(order) do
        if objects[objectID] then result[#result + 1] = objects[objectID] end
    end
    return result
end

function Assist:ClearLootSource()
    Addon.runtime.pandariaDarkSoilLoot = nil
    Addon.runtime.confirmLootSourceKey = nil
end

if hooksecurefunc then
    -- This runs after Blizzard (and earlier-loaded UI addons) finish showing
    -- and anchoring the LOOT_BIND popup, rather than racing their event work.
    hooksecurefunc("StaticPopup_Show", function(which) Assist:HandleStaticPopupShow(which) end)
end
