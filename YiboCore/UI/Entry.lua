local Core = _G.YiboCore

local Entry = {}
Core.Entry = Entry
Entry.businessEntries = Entry.businessEntries or {}
local HidePreview

local ENTRY_MODES = { "none", "broker", "minimap", "both" }
local ENTRY_MODE_LABELS = {
    none = "不显示",
    broker = "仅 Broker",
    minimap = "仅小地图",
    both = "两者都显示",
}

local function Toggle(pageID)
    if Core.AccountView then Core.AccountView:Toggle(pageID) end
end

local function EntrySettings()
    local view = Core.AccountView:GetSettings()
    return view.entry
end

local function HasBroker(mode)
    return mode == "broker" or mode == "both"
end

local function HasMinimap(mode)
    return mode == "minimap" or mode == "both"
end

function Entry:GetBusinessEntryMode(entryID)
    local saved = EntrySettings().pageModes[entryID]
    return ENTRY_MODE_LABELS[saved] and saved or "none"
end

function Entry:GetBusinessEntryModeLabel(mode)
    return ENTRY_MODE_LABELS[mode] or ENTRY_MODE_LABELS.none
end

function Entry:GetBusinessEntryByPageID(pageID)
    for _, entry in pairs(self.businessEntries) do
        if entry.pageID == pageID then return entry end
    end
end

function Entry:CycleBusinessEntryMode(entryID)
    local current = self:GetBusinessEntryMode(entryID)
    local nextIndex = 1
    for index, mode in ipairs(ENTRY_MODES) do
        if mode == current then nextIndex = (index % #ENTRY_MODES) + 1; break end
    end
    EntrySettings().pageModes[entryID] = ENTRY_MODES[nextIndex]
    self:Refresh()
end

local function AngleFromOffset(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x == 0 then return y >= 0 and (math.pi / 2) or -(math.pi / 2) end
    local angle = math.atan(y / x)
    if x < 0 then angle = angle + (y >= 0 and math.pi or -math.pi) end
    return angle
end

local function ResolveAnchor(candidate)
    local mouseFocus = GetMouseFocus and GetMouseFocus()
    if mouseFocus and type(mouseFocus.GetLeft) == "function" then return mouseFocus end
    if candidate and type(candidate.GetLeft) == "function" then return candidate end
    return nil
end

local function ShowPreview(anchor, pageID)
    if not (Core.AccountView and (pageID or Core.AccountView:GetPreviewPage())) then return false end
    Entry.previewToken = (Entry.previewToken or 0) + 1
    local token = Entry.previewToken
    GameTooltip:Hide()
    local resolvedAnchor = ResolveAnchor(anchor)
    Core.AccountView:ShowPreview(pageID, resolvedAnchor)

    -- 某些 Broker 显示插件会在 OnTooltipShow 返回后才完成锚点布局。
    -- 首帧没有进入预览状态时，仅补一次短延迟重试。
    local function RetryPreview()
        if Entry.previewToken ~= token then return end
        local frame = Core.AccountView.frame
        if not (frame and frame.preview) then
            GameTooltip:Hide()
            Core.AccountView:ShowPreview(pageID, resolvedAnchor)
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, RetryPreview)
    end
    return true
end

function Entry:CreateBusinessBroker(entry)
    if not entry or entry.broker or EntrySettings().broker.show == false or not HasBroker(self:GetBusinessEntryMode(entry.id)) then return end
    local library = type(LibStub) == "table" and LibStub.GetLibrary and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not library then return end
    local broker = library.GetDataObjectByName and library:GetDataObjectByName(entry.id)
    if not broker then broker = library:NewDataObject(entry.id, {}) end
    if not broker then return end
    entry.broker = broker
    broker.type = "launcher"
    broker.text = entry.text
    broker.icon = entry.icon
    broker.OnClick = function(_, mouseButton)
        if mouseButton == "RightButton" then
            Toggle(entry.pageID)
            Core.AccountView:ShowSettings()
        else
            Toggle(entry.pageID)
        end
    end
    broker.OnEnter = function(first, second) ShowPreview(second or first, entry.pageID) end
    broker.OnLeave = function() Entry:SchedulePreviewClose() end
    broker.OnTooltipShow = function(tooltip)
        local owner = tooltip and tooltip.GetOwner and tooltip:GetOwner()
        if ShowPreview(owner, entry.pageID) and tooltip and tooltip.Hide then tooltip:Hide() end
    end
end

function Entry:CreateBusinessMinimap(entry)
    if not entry or entry.button then return end
    local button = CreateFrame("Button", "YiboCoreMinimap" .. entry.id, Minimap)
    button:SetSize(31, 31); button:SetFrameStrata("MEDIUM"); button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetMovable(true); button:EnableMouse(true); button:RegisterForDrag("LeftButton")
    button.icon = button:CreateTexture(nil, "BACKGROUND"); button.icon:SetTexture(entry.icon); button.icon:SetAllPoints()
    button.border = button:CreateTexture(nil, "OVERLAY"); button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); button.border:SetSize(53, 53); button.border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then Toggle(entry.pageID); Core.AccountView:ShowSettings() else Toggle(entry.pageID) end
    end)
    button:SetScript("OnDragStart", button.StartMoving)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local centerX, centerY = Minimap:GetCenter()
        local buttonX, buttonY = self:GetCenter()
        if centerX and buttonX then
            EntrySettings().pagePositions[entry.id] = math.deg(AngleFromOffset(buttonY - centerY, buttonX - centerX))
        end
        Entry:Refresh()
    end)
    button:SetScript("OnEnter", function(self) ShowPreview(self, entry.pageID) end)
    button:SetScript("OnLeave", function() Entry:SchedulePreviewClose() end)
    entry.button = button
end

function Entry:RegisterBusinessEntry(addonName, definition)
    if type(addonName) ~= "string" or type(definition) ~= "table" or type(definition.id) ~= "string" or type(definition.pageID) ~= "string" then
        return nil, "业务入口必须提供插件名、id 与 pageID。"
    end
    local entry = self.businessEntries[definition.id] or {}
    entry.id = definition.id
    entry.addonName = addonName
    entry.pageID = definition.pageID
    entry.text = definition.text or ("[Yibo] " .. definition.pageID)
    entry.icon = definition.icon or "Interface\\Icons\\INV_Misc_GroupLooking"
    self.businessEntries[entry.id] = entry
    if HasBroker(self:GetBusinessEntryMode(entry.id)) then self:CreateBusinessBroker(entry) end
    if HasMinimap(self:GetBusinessEntryMode(entry.id)) then self:CreateBusinessMinimap(entry) end
    self:Refresh()
    return entry
end

HidePreview = function()
    Entry.previewToken = (Entry.previewToken or 0) + 1
    GameTooltip:Hide()
    if Core.AccountView then Core.AccountView:HidePreview() end
end

function Entry:CancelPreviewClose()
    self.previewToken = (self.previewToken or 0) + 1
end

function Entry:SchedulePreviewClose()
    self.previewToken = (self.previewToken or 0) + 1
    local token = self.previewToken
    local function CloseIfStillPending()
        if Entry.previewToken == token then HidePreview() end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.35, CloseIfStillPending)
    else
        CloseIfStillPending()
    end
end

function Entry:Initialize()
    if not self.button then
        local button = CreateFrame("Button", "YiboCoreMinimapButton", Minimap)
        button:SetSize(31, 31); button:SetFrameStrata("MEDIUM"); button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetMovable(true); button:EnableMouse(true); button:RegisterForDrag("LeftButton")
        button.icon = button:CreateTexture(nil, "BACKGROUND"); button.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking"); button.icon:SetAllPoints()
        button.border = button:CreateTexture(nil, "OVERLAY"); button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); button.border:SetSize(53, 53); button.border:SetPoint("TOPLEFT")
        button:SetScript("OnClick", function(_, mouseButton)
            if mouseButton == "RightButton" then Core.AccountView:ShowSettings() else Toggle() end
        end)
        button:SetScript("OnDragStart", button.StartMoving)
        button:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local centerX, centerY = Minimap:GetCenter()
            local buttonX, buttonY = self:GetCenter()
            if centerX and buttonX then EntrySettings().minimap.angle = math.deg(AngleFromOffset(buttonY - centerY, buttonX - centerX)) end
            Entry:Refresh()
        end)
        button:SetScript("OnEnter", function(self)
            if ShowPreview(self) then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("[Yibo] 账号总览", 0.125, 0.88, 0.44)
            GameTooltip:AddLine("左键打开多角色状态视图", 0.75, 0.85, 0.87)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() Entry:SchedulePreviewClose() end)
        self.button = button
    end

    Core.AccountView:SetPreviewHoverCallbacks(function() Entry:CancelPreviewClose() end, function() Entry:SchedulePreviewClose() end)
    if self.broker then
        for _, entry in pairs(self.businessEntries) do self:CreateBusinessBroker(entry) end
        self:Refresh()
        return
    end
    -- LibDataBroker 没有可靠的注销协议；关闭后仅在下次载入时不注册数据源。
    local library = EntrySettings().broker.show ~= false and type(LibStub) == "table" and LibStub.GetLibrary and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if library then
        local broker = library.GetDataObjectByName and library:GetDataObjectByName("YiboCore")
        if not broker then broker = library:NewDataObject("YiboCore", {}) end
        self.broker = broker
        -- 复用同名对象时也覆盖回调，避免热重载后仍保留旧的悬停处理函数。
        broker.type = "launcher"
        broker.text = "[Yibo] 账号总览"
        broker.icon = "Interface\\Icons\\INV_Misc_GroupLooking"
        broker.OnClick = function(_, mouseButton)
            if mouseButton == "RightButton" then Core.AccountView:ShowSettings() else Toggle() end
        end
        broker.OnEnter = function(first, second)
            local owner = second or first
            Entry.lastBrokerAnchor = owner
            ShowPreview(owner)
        end
        broker.OnLeave = function() Entry:SchedulePreviewClose() end
        broker.OnTooltipShow = function(tooltip)
            local owner = tooltip and tooltip.GetOwner and tooltip:GetOwner() or Entry.lastBrokerAnchor
            if ShowPreview(owner) and tooltip and tooltip.Hide then tooltip:Hide() end
        end
    end
    for _, entry in pairs(self.businessEntries) do self:CreateBusinessBroker(entry) end
    self:Refresh()
end

function Entry:Refresh()
    if self.button then
        local minimap = EntrySettings().minimap
        local angle = math.rad(tonumber(minimap.angle) or 225)
        self.button:ClearAllPoints()
        self.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
        self.button:SetShown(minimap.show ~= false)
    end
    if self.broker then self.broker.text = "[Yibo] 账号总览" end
    for _, entry in pairs(self.businessEntries) do
        local mode = self:GetBusinessEntryMode(entry.id)
        if HasBroker(mode) then self:CreateBusinessBroker(entry) end
        if HasMinimap(mode) then self:CreateBusinessMinimap(entry) end
        if entry.button then
            local angle = math.rad(tonumber(EntrySettings().pagePositions[entry.id]) or 225)
            entry.button:ClearAllPoints()
            entry.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
            entry.button:SetShown(HasMinimap(mode))
        end
    end
end

Core.Events:Register("CORE_READY", Entry, function(owner) owner:Initialize() end)
Core.Events:Register("PLAYER_LOGIN", Entry, function(owner) owner:Initialize() end)
Core.Capabilities:Register("account-entry", 1)
