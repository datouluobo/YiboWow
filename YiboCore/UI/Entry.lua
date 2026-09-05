local Core = _G.YiboCore

local Entry = {}
Core.Entry = Entry
Entry.businessEntries = Entry.businessEntries or {}
local HidePreview
local CORE_ICON = "Interface\\AddOns\\YiboCore\\Media\\YiboCoreIcon-v13"

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

local function BrokerName(addonName, definition)
    local name = definition and definition.brokerName
    if type(name) == "string" and name ~= "" then return name end
    return addonName
end

local function MinimapFrameName(entryID)
    return "YiboCoreMinimapEntry_" .. string.gsub(entryID, "[^%w_]", "_")
end

function Entry:GetBusinessEntryMode(entryID)
    local saved = EntrySettings().pageModes[entryID]
    return ENTRY_MODE_LABELS[saved] and saved or "none"
end

function Entry:GetBusinessEntryModeLabel(mode)
    return ENTRY_MODE_LABELS[mode] or ENTRY_MODE_LABELS.none
end

function Entry:GetCoreEntryMode()
    local saved = EntrySettings().coreMode
    return ENTRY_MODE_LABELS[saved] and saved or "both"
end

function Entry:SetCoreEntryMode(mode)
    if not ENTRY_MODE_LABELS[mode] then return false end
    local settings = EntrySettings()
    settings.coreMode = mode
    -- Keep the old fields coherent for releases that still read them.
    settings.broker.show = HasBroker(mode)
    settings.minimap.show = HasMinimap(mode)
    self:Refresh()
    return true
end

function Entry:GetBusinessEntryByPageID(pageID)
    for _, entry in pairs(self.businessEntries) do
        if entry.pageID == pageID and not entry.disabled then return entry end
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

local function RaiseBrokerTooltip(tooltip)
    local preview = Core.AccountView and Core.AccountView.frame
    if not (tooltip and preview and preview.preview) then return end

    -- Some Broker displays call OnTooltipShow before showing their tooltip.
    -- Native Broker tooltips belong in TOOLTIP; the interactive preview stays
    -- in DIALOG, so this remains visible above the preview in either order.
    if tooltip.SetFrameStrata then tooltip:SetFrameStrata("TOOLTIP") end
    if tooltip.SetFrameLevel and preview.GetFrameLevel then
        tooltip:SetFrameLevel((preview:GetFrameLevel() or 0) + 50)
    end
    if tooltip.Raise then tooltip:Raise() end
end

function Entry:CreateBusinessBroker(entry)
    if not entry or entry.disabled or not HasBroker(self:GetBusinessEntryMode(entry.id)) then return end
    local library = type(LibStub) == "table" and LibStub.GetLibrary and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not library then return end
    local broker = entry.broker or (library.GetDataObjectByName and library:GetDataObjectByName(entry.brokerName))
    if broker and broker.yiboCoreEntryID ~= entry.id then
        Core:Print("Broker 名称冲突，未接管数据源: " .. entry.brokerName)
        return
    end
    if not broker then broker = library:NewDataObject(entry.brokerName, {}) end
    if not broker then return end
    entry.broker = broker
    broker.yiboCoreEntryID = entry.id
    broker.type = "launcher"
    broker.text = entry.text
    broker.icon = entry.icon
    broker.OnClick = function(_, mouseButton)
        if entry.disabled then return end
        if mouseButton == "RightButton" then
            -- Open the business workbench in one layout pass.  Going through
            -- the account page first can leave the shared settings host at its
            -- previous page's size while an entry hover is being dismissed.
            Core.AccountView:ShowSettings(entry.pageID)
        else
            Toggle(entry.pageID)
        end
    end
    broker.OnEnter = function(first, second)
        if not entry.disabled then ShowPreview(second or first, entry.pageID) end
    end
    broker.OnLeave = function() Entry:SchedulePreviewClose() end
    broker.OnTooltipShow = function(tooltip)
        local owner = tooltip and tooltip.GetOwner and tooltip:GetOwner()
        if not entry.disabled and ShowPreview(owner, entry.pageID) then RaiseBrokerTooltip(tooltip) end
    end
end

function Entry:DisableBusinessBroker(entry)
    if not entry or not entry.broker then return end

    -- LibDataBroker has no portable unregister API. Keep the object alive, but
    -- make it completely inert until the entry mode is enabled again.
    entry.broker.OnClick = function() end
    entry.broker.OnEnter = function() end
    entry.broker.OnLeave = function() end
    entry.broker.OnTooltipShow = function() end
    entry.broker.yiboCoreEntryDisabled = true
end

local function ConfigureCoreBroker(broker)
    broker.yiboCoreEntryDisabled = nil
    broker.type = "launcher"
    broker.text = "[Yibo] 账号总览"
    broker.icon = CORE_ICON
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
        if ShowPreview(owner) then RaiseBrokerTooltip(tooltip) end
    end
end

local function DisableCoreBroker(broker)
    if not broker then return end
    -- LibDataBroker cannot be portably unregistered.  Keep an existing source
    -- inert until it is enabled again; a reload removes a source that was not
    -- registered during initialization.
    broker.OnClick = function() end
    broker.OnEnter = function() end
    broker.OnLeave = function() end
    broker.OnTooltipShow = function() end
    broker.yiboCoreEntryDisabled = true
end

function Entry:CreateBusinessMinimap(entry)
    if not entry or entry.disabled or entry.button then return end
    local button = CreateFrame("Button", entry.frameName, Minimap)
    button:SetSize(31, 31); button:SetFrameStrata("MEDIUM"); button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetMovable(true); button:EnableMouse(true); button:RegisterForDrag("LeftButton")
    button.icon = button:CreateTexture(nil, "BACKGROUND"); button.icon:SetTexture(entry.icon); button.icon:SetAllPoints()
    button.border = button:CreateTexture(nil, "OVERLAY"); button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); button.border:SetSize(53, 53); button.border:SetPoint("TOPLEFT")
    button:SetScript("OnClick", function(_, mouseButton)
        if entry.disabled then return end
        if mouseButton == "RightButton" then Core.AccountView:ShowSettings(entry.pageID) else Toggle(entry.pageID) end
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
    button:SetScript("OnEnter", function(self) if not entry.disabled then ShowPreview(self, entry.pageID) end end)
    button:SetScript("OnLeave", function() Entry:SchedulePreviewClose() end)
    entry.button = button
end

function Entry:RegisterBusinessEntry(addonName, definition)
    if type(addonName) ~= "string" or type(definition) ~= "table" or type(definition.id) ~= "string" or type(definition.pageID) ~= "string" then
        return nil, "业务入口必须提供插件名、id 与 pageID。"
    end
    if not (Core.Registry and Core.Registry:Get(addonName)) then return nil, "入口所属插件尚未注册: " .. addonName end
    if definition.brokerName ~= nil and (type(definition.brokerName) ~= "string" or definition.brokerName == "") then
        return nil, "业务入口 brokerName 必须是非空 string。"
    end
    if definition.defaultMode ~= nil and not ENTRY_MODE_LABELS[definition.defaultMode] then
        return nil, "业务入口 defaultMode 无效。"
    end
    local page = Core.AccountView and Core.AccountView._pages[definition.pageID]
    if not page then return nil, "入口目标页面不存在: " .. definition.pageID end
    if page.addonName ~= addonName then return nil, "入口只能绑定所属插件自己的页面。" end
    local entryClaim, claimError = Core:ClaimResource("entry", definition.id, addonName)
    if not entryClaim then return nil, claimError end
    local brokerName = BrokerName(addonName, definition)
    local brokerClaim, brokerClaimError = Core:ClaimResource("broker", brokerName, addonName)
    if not brokerClaim then
        Core.Registry:ReleaseResource("entry", definition.id, addonName)
        return nil, brokerClaimError
    end
    local frameName = MinimapFrameName(definition.id)
    local frameClaim, frameClaimError = Core:ClaimResource("minimap-frame", frameName, addonName)
    if not frameClaim then
        Core.Registry:ReleaseResource("entry", definition.id, addonName)
        Core.Registry:ReleaseResource("broker", brokerName, addonName)
        return nil, frameClaimError
    end
    local entry = self.businessEntries[definition.id] or {}
    entry.id = definition.id
    entry.addonName = addonName
    entry.pageID = definition.pageID
    entry.text = definition.text or ("[Yibo] " .. definition.pageID)
    entry.icon = definition.icon or "Interface\\Icons\\INV_Misc_GroupLooking"
    entry.brokerName = brokerName
    entry.frameName = frameName
    entry.disabled = false
    local settings = EntrySettings()
    if settings.pageModes[entry.id] == nil then
        for _, legacyID in ipairs(definition.legacyIDs or {}) do
            if settings.pageModes[legacyID] ~= nil then
                settings.pageModes[entry.id] = settings.pageModes[legacyID]
                break
            end
        end
        if settings.pageModes[entry.id] == nil and definition.defaultMode then
            settings.pageModes[entry.id] = definition.defaultMode
        end
    end
    if settings.pagePositions[entry.id] == nil then
        for _, legacyID in ipairs(definition.legacyIDs or {}) do
            if settings.pagePositions[legacyID] ~= nil then
                settings.pagePositions[entry.id] = settings.pagePositions[legacyID]
                break
            end
        end
    end
    self.businessEntries[entry.id] = entry
    if HasBroker(self:GetBusinessEntryMode(entry.id)) then self:CreateBusinessBroker(entry) end
    if HasMinimap(self:GetBusinessEntryMode(entry.id)) then self:CreateBusinessMinimap(entry) end
    self:Refresh()
    return entry
end

function Entry:UnregisterEntriesForPage(pageID)
    for entryID, entry in pairs(self.businessEntries) do
        if entry.pageID == pageID then
            entry.disabled = true
            if entry.button then entry.button:Hide() end
            -- LibDataBroker 没有可靠注销协议；保留对象但禁用其交互，防止其它插件抢占同名数据源。
            if Core.Registry then
                Core.Registry:ReleaseResource("entry", entryID, entry.addonName)
                Core.Registry:ReleaseResource("minimap-frame", entry.frameName, entry.addonName)
            end
        end
    end
    self:Refresh()
end

function Entry:GetRegisteredBusinessEntries()
    local entries = {}
    for _, entry in pairs(self.businessEntries) do
        if not entry.disabled then entries[#entries + 1] = entry end
    end
    table.sort(entries, function(left, right) return left.id < right.id end)
    return entries
end

HidePreview = function()
    Entry.previewToken = (Entry.previewToken or 0) + 1
    GameTooltip:Hide()
    if Core.AccountView then Core.AccountView:HidePreview() end
end

function Entry:CancelPreviewClose()
    self.previewToken = (self.previewToken or 0) + 1
end

function Entry:SuppressPreviewClose(seconds)
    local now = GetTime and GetTime() or 0
    self.previewCloseSuppressedUntil = now + math.max(0, tonumber(seconds) or 0)
    self:CancelPreviewClose()
end

function Entry:IsMouseOverPreview()
    local preview = Core.AccountView and Core.AccountView.frame
    if not (preview and preview.preview and preview:IsShown()) then return false end

    -- Do not infer this from GetMouseFocus or Frame:IsMouseOver().  A scroll
    -- child may retain mouse hit-testing outside its clipped viewport; Boss
    -- weekly has interactive matrix cells, so that made an invisible overflow
    -- cell keep the preview alive after the pointer had visibly left it.
    -- Cursor coordinates against the shared preview shell give every business
    -- page exactly the same close boundary.
    if not (GetCursorPosition and UIParent and UIParent.GetEffectiveScale) then return false end
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return false end
    local cursorX, cursorY = GetCursorPosition()
    local left, right, bottom, top = preview:GetLeft(), preview:GetRight(), preview:GetBottom(), preview:GetTop()
    if not (cursorX and cursorY and left and right and bottom and top) then return false end
    cursorX, cursorY = cursorX / scale, cursorY / scale
    return cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top
end

function Entry:SchedulePreviewClose()
    local now = GetTime and GetTime() or 0
    self.previewToken = (self.previewToken or 0) + 1
    local token = self.previewToken
    local function CloseIfStillPending()
        -- A checkbox, scope button, or row inside the preview becomes the mouse
        -- focus itself.  Treat every descendant as part of the hover surface.
        if Entry.previewToken == token and not Entry:IsMouseOverPreview() then HidePreview() end
    end
    if C_Timer and C_Timer.After then
        -- A preview can be rebuilt after an in-preview click.  If its leave
        -- event lands during that short protected interval, still queue one
        -- close for after it expires; returning early here stranded the Boss
        -- weekly preview until another hover event happened.
        local suppressedFor = math.max(0, (self.previewCloseSuppressedUntil or 0) - now)
        C_Timer.After(math.max(0.5, suppressedFor + 0.05), CloseIfStillPending)
    else
        if (self.previewCloseSuppressedUntil or 0) <= now then CloseIfStillPending() end
    end
end

function Entry:Initialize()
    if not self.button then
        local button = CreateFrame("Button", "YiboCoreMinimapButton", Minimap)
        button:SetSize(31, 31); button:SetFrameStrata("MEDIUM"); button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetMovable(true); button:EnableMouse(true); button:RegisterForDrag("LeftButton")
        button.icon = button:CreateTexture(nil, "BACKGROUND"); button.icon:SetTexture(CORE_ICON); button.icon:SetAllPoints()
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
    -- Business Broker entries remain available even when Core's own Broker
    -- entry is hidden, so load the library independently from coreMode.
    local library = type(LibStub) == "table" and LibStub.GetLibrary and LibStub:GetLibrary("LibDataBroker-1.1", true)
    self.library = library
    if library and HasBroker(self:GetCoreEntryMode()) then
        local broker = library.GetDataObjectByName and library:GetDataObjectByName("YiboCore")
        if not broker then broker = library:NewDataObject("YiboCore", {}) end
        self.broker = broker
        ConfigureCoreBroker(broker)
    end
    for _, entry in pairs(self.businessEntries) do self:CreateBusinessBroker(entry) end
    self:Refresh()
end

function Entry:Refresh()
    local coreMode = self:GetCoreEntryMode()
    if self.button then
        local minimap = EntrySettings().minimap
        local angle = math.rad(tonumber(minimap.angle) or 225)
        self.button:ClearAllPoints()
        self.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
        self.button:SetShown(HasMinimap(coreMode))
    end
    if self.broker then
        if HasBroker(coreMode) then ConfigureCoreBroker(self.broker) else DisableCoreBroker(self.broker) end
    end
    for _, entry in pairs(self.businessEntries) do
        local mode = self:GetBusinessEntryMode(entry.id)
        if HasBroker(mode) then
            self:CreateBusinessBroker(entry)
            if entry.broker then entry.broker.yiboCoreEntryDisabled = nil end
        else
            self:DisableBusinessBroker(entry)
        end
        if HasMinimap(mode) then self:CreateBusinessMinimap(entry) end
        if entry.button then
            local angle = math.rad(tonumber(EntrySettings().pagePositions[entry.id]) or 225)
            entry.button:ClearAllPoints()
            entry.button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
            entry.button:SetShown(not entry.disabled and HasMinimap(mode))
        end
    end
end

Core.Events:Register("CORE_READY", Entry, function(owner) owner:Initialize() end)
Core.Events:Register("PLAYER_LOGIN", Entry, function(owner) owner:Initialize() end)
Core.Capabilities:Register("account-entry", 1)
