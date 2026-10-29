local Core = _G.YiboCore

local Entry = {}
Core.Entry = Entry
Entry.businessEntries = Entry.businessEntries or {}
local HidePreview
local CORE_ICON = "Interface\\AddOns\\YiboCore\\Media\\YiboCoreIcon"

local ENTRY_MODES = { "none", "broker", "minimap", "both" }
local ENTRY_MODE_LABELS = Core.Locale:Bind(function() return {
    none = Core:Text("CORE.HIDDEN"),
    broker = Core:Text("CORE.BROKER_ONLY"),
    minimap = Core:Text("CORE.MINIMAP_ONLY"),
    both = Core:Text("CORE.BOTH"),
} end)

local function Toggle(pageID)
    if Core.AccountView then Core.AccountView:Toggle(pageID) end
end

local function ResolveBusinessPageID(entry)
    if not entry then return nil end
    if type(entry.resolvePageID) == "function" then
        local ok, pageID = pcall(entry.resolvePageID)
        local page = ok and type(pageID) == "string" and Core.AccountView and Core.AccountView._pages[pageID]
        if page and page.addonName == entry.addonName then return pageID end
    end
    return entry.pageID
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
    local c = self:GetEntryChannels(entryID)
    return c.broker and c.minimap and "both" or (c.broker and "broker" or (c.minimap and "minimap" or "none"))
end

function Entry:GetBusinessEntryModeLabel(mode)
    return ENTRY_MODE_LABELS[mode] or ENTRY_MODE_LABELS.none
end

function Entry:GetCoreEntryMode()
    return self:GetBusinessEntryMode("YiboCore")
end

function Entry:SetCoreEntryMode(mode)
    if not ENTRY_MODE_LABELS[mode] then return false end
    local c = Core.EntryConfig:FromMode(mode)
    c.builtinBar = self:GetEntryChannels("YiboCore").builtinBar
    EntrySettings().coreChannels = c
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
    local c = Core.EntryConfig:FromMode(ENTRY_MODES[nextIndex])
    c.builtinBar = self:GetEntryChannels(entryID).builtinBar
    EntrySettings().businessChannels[entryID] = c
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
    local mouseFocus = Core.Client:ReadMouseFocus()
    if mouseFocus and type(mouseFocus.GetLeft) == "function" then return mouseFocus end
    if candidate and type(candidate.GetLeft) == "function" then return candidate end
    return nil
end

local function ShowPreview(anchor, pageID)
    if not (Core.AccountView and (pageID or Core.AccountView:GetPreviewPage())) then return false end
    Entry.previewToken = (Entry.previewToken or 0) + 1
    local token = Entry.previewToken
    local resolvedAnchor = ResolveAnchor(anchor)

    local function RenderPreview()
        if Entry.previewToken ~= token then return end
        Entry.lastPreviewRenderAt = GetTime and GetTime() or 0
        GameTooltip:Hide()
        if Core.AccountView:ShowPreview(pageID, resolvedAnchor) then Entry:StartPreviewWatch() end

        -- 某些 Broker 显示插件会在 OnTooltipShow 返回后才完成锚点布局。
        -- 首帧没有进入预览状态时，仅补一次短延迟重试。
        local function RetryPreview()
            if Entry.previewToken ~= token then return end
            local frame = Core.AccountView.frame
            if not (frame and frame.preview) then
                GameTooltip:Hide()
                if Core.AccountView:ShowPreview(pageID, resolvedAnchor) then Entry:StartPreviewWatch() end
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.05, RetryPreview) end
    end

    -- The first hover remains immediate.  During rapid movement across
    -- multiple entries, coalesce requests arriving within one short frame
    -- window so only the final page builds its preview context and controls.
    local now = GetTime and GetTime() or 0
    local last = Entry.lastPreviewRenderAt
    local delay = last and math.max(0, 0.08 - (now - last)) or 0
    if delay > 0 and C_Timer and C_Timer.After then
        C_Timer.After(delay, RenderPreview)
    else
        RenderPreview()
    end
    return true
end

local function HideBrokerTooltip(tooltip)
    local preview = Core.AccountView and Core.AccountView.frame
    if not (tooltip and preview and preview.preview) then return end

    -- The account preview contains real buttons.  A Broker host's native
    -- tooltip otherwise occupies the top-most hit-test layer and makes those
    -- visible controls inert.  The preview already supplies the same summary,
    -- so dismiss the redundant tooltip as soon as its interactive projection
    -- is available.
    if tooltip.Hide then tooltip:Hide() end
end

function Entry:CreateBusinessBroker(entry)
    if not entry or entry.disabled or not self:GetEntryAvailability(entry.id) or not HasBroker(self:GetBusinessEntryMode(entry.id)) then return end
    local library = type(LibStub) == "table" and LibStub.GetLibrary and LibStub:GetLibrary("LibDataBroker-1.1", true)
    if not library then return end
    local broker = entry.broker or (library.GetDataObjectByName and library:GetDataObjectByName(entry.brokerName))
    if broker and broker.yiboCoreEntryID ~= entry.id then
        Core:Print(Core:Text("CORE.BROKER_NAME_CONFLICT_DATA_SOURCE_LEFT_UNCHANGED") .. entry.brokerName)
        return
    end
    if not broker then broker = library:NewDataObject(entry.brokerName, {}) end
    if not broker then return end
    entry.broker = broker
    broker.yiboCoreEntryID = entry.id
    broker.type = "launcher"
    broker.text = entry.text
    broker.icon = entry.icon
    broker.yiboCoreEntryDisabled = nil
    broker.yiboCoreEntryID = entry.id
    broker.OnClick = function(_, button) Entry:HandleEntryClick(entry.id, button) end
    broker.OnEnter = function(first, second) Entry:ShowEntryPreview(entry.id, second or first, "broker") end
    broker.OnLeave = function() Entry:SchedulePreviewClose() end
    broker.OnTooltipShow = function(tooltip)
        local anchor = tooltip and tooltip.GetOwner and tooltip:GetOwner()
        if Entry:ShowEntryPreview(entry.id, anchor, "broker") then HideBrokerTooltip(tooltip) end
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
    broker.text = Core:Text("CORE.YIBO_ACCOUNT_OVERVIEW")
    broker.icon = CORE_ICON
    broker.yiboCoreEntryDisabled = nil
    broker.yiboCoreEntryID = "YiboCore"
    broker.OnClick = function(_, button) Entry:HandleEntryClick("YiboCore", button) end
    broker.OnEnter = function(first, second) Entry:ShowEntryPreview("YiboCore", second or first, "broker") end
    broker.OnLeave = function() Entry:SchedulePreviewClose() end
    broker.OnTooltipShow = function(tooltip)
        local anchor = tooltip and tooltip.GetOwner and tooltip:GetOwner()
        if Entry:ShowEntryPreview("YiboCore", anchor, "broker") then HideBrokerTooltip(tooltip) end
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
    button:SetScript("OnClick", function(_, button) Entry:HandleEntryClick(entry.id, button) end)
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
    button:SetScript("OnEnter", function(self) Entry:ShowEntryPreview(entry.id, self, "minimap") end)
    button:SetScript("OnLeave", function() Entry:SchedulePreviewClose() end)
    entry.button = button
end

function Entry:RegisterBusinessEntry(addonName, definition)
    if type(addonName) ~= "string" or type(definition) ~= "table" or type(definition.id) ~= "string" or definition.id == "" or definition.id == "YiboCore" or type(definition.pageID) ~= "string" then
        return nil, Core:Text("CORE.BUSINESS_ENTRIES_REQUIRE_ADDON_NAME_ID_AND")
    end
    if not (Core.Registry and Core.Registry:Get(addonName)) then return nil, Core:Text("CORE.ENTRY_S_ADDON_IS_NOT_REGISTERED") .. addonName end
    if definition.brokerName ~= nil and (type(definition.brokerName) ~= "string" or definition.brokerName == "") then
        return nil, Core:Text("CORE.BUSINESS_ENTRY_BROKERNAME_MUST_BE_A_NON")
    end
    if definition.resolvePageID ~= nil and type(definition.resolvePageID) ~= "function" then
        return nil, Core:Text("CORE.BUSINESS_ENTRY_RESOLVEPAGEID_MUST_BE_A_FUNCTION")
    end
    if definition.defaultMode ~= nil and not ENTRY_MODE_LABELS[definition.defaultMode] then
        return nil, Core:Text("CORE.INVALID_BUSINESS_ENTRY_DEFAULTMODE")
    end
    if definition.defaultChannels ~= nil then
        if type(definition.defaultChannels) ~= "table" then return nil, Core:Text("ENTRY.INVALID_CHANNELS") end
        for key, value in pairs(definition.defaultChannels) do
            if (key ~= "broker" and key ~= "minimap" and key ~= "builtinBar") or type(value) ~= "boolean" then return nil, Core:Text("ENTRY.INVALID_CHANNELS") end
        end
    end
    local page = Core.AccountView and Core.AccountView._pages[definition.pageID]
    if not page then return nil, Core:Text("CORE.ENTRY_TARGET_PAGE_DOES_NOT_EXIST") .. definition.pageID end
    if page.addonName ~= addonName then return nil, Core:Text("CORE.ENTRIES_MAY_ONLY_BIND_TO_PAGES_OWNED") end
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
    entry.resolvePageID = definition.resolvePageID
    entry.text = definition.text or ("[Yibo] " .. definition.pageID)
    entry.icon = definition.icon or "Interface\\Icons\\INV_Misc_GroupLooking"
    entry.brokerName = brokerName
    entry.frameName = frameName
    entry.disabled = false
    local settings = EntrySettings()
    if settings.businessChannels[entry.id] == nil then
        for _, legacyID in ipairs(definition.legacyIDs or {}) do
            if settings.businessChannels[legacyID] ~= nil then
                settings.businessChannels[entry.id] = Core.Defaults:Copy(settings.businessChannels[legacyID]); break
            end
        end
        if settings.businessChannels[entry.id] == nil then
            settings.businessChannels[entry.id] = definition.defaultChannels and Core.Defaults:Copy(definition.defaultChannels) or Core.EntryConfig:FromMode(definition.defaultMode)
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
    table.sort(entries, function(left, right)
        if left.addonName ~= right.addonName then return left.addonName < right.addonName end
        return left.id < right.id
    end)
    return entries
end

HidePreview = function(navigating)
    Entry.previewToken = (Entry.previewToken or 0) + 1
    Entry:StopPreviewWatch()
    Entry.previewOwner = nil
    GameTooltip:Hide()
    if Core.AccountView then
        local close = navigating and Core._private and Core._private.HidePreviewForNavigation
        if close then close() else Core.AccountView:HidePreview() end
    end
end

function Entry:CancelPreviewClose()
    self.previewToken = (self.previewToken or 0) + 1
end

function Entry:SuppressPreviewClose(seconds)
    local now = GetTime and GetTime() or 0
    local suppressedUntil = now + math.max(0, tonumber(seconds) or 0)
    self.previewCloseSuppressedUntil = suppressedUntil
    -- The polling watcher is independent from the delayed OnLeave callback.
    -- Extend its grace window as well, otherwise it can hide a preview on the
    -- next 0.1 s tick while an in-preview tab click is rebuilding controls.
    self.previewWatchGraceUntil = math.max(self.previewWatchGraceUntil or 0, suppressedUntil)
    self:CancelPreviewClose()
end

function Entry:IsMouseOverFrame(frame)
    if not (frame and frame.IsShown and frame:IsShown()) then return false end
    -- Do not infer this from GetMouseFocus or Frame:IsMouseOver().  A scroll
    -- child may retain mouse hit-testing outside its clipped viewport; Boss
    -- weekly has interactive matrix cells, so that made an invisible overflow
    -- cell keep the preview alive after the pointer had visibly left it.
    -- Cursor coordinates provide every business page the same close boundary.
    if not (UIParent and UIParent.GetEffectiveScale) then return false end
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return false end
    local cursorX, cursorY = Core.Client:ReadCursorPosition()
    local left, right, bottom, top = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    if not (cursorX and cursorY and left and right and bottom and top) then return false end
    cursorX, cursorY = cursorX / scale, cursorY / scale
    return cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top
end

function Entry:IsMouseOverPreview()
    local preview = Core.AccountView and Core.AccountView.frame
    return preview and preview.preview and self:IsMouseOverFrame(preview) or false
end

function Entry:IsMouseOverPreviewAnchor()
    local anchor = Core.AccountView and Core.AccountView.previewAnchor
    return self:IsMouseOverFrame(anchor)
end

function Entry:StopPreviewWatch()
    if self.previewWatchFrame then self.previewWatchFrame:Hide() end
    self.previewWatchActive = nil
    self.previewWatchGraceUntil = nil
end

function Entry:StartPreviewWatch()
    -- Entry and preview OnLeave are normally enough.  This watcher is a
    -- common fallback for controls rebuilt by business pages after they have
    -- been registered for hover callbacks, where WoW may not deliver a final
    -- leave event from the replaced child.
    local frame = self.previewWatchFrame
    local wasActive = self.previewWatchActive == true and frame and frame:IsShown()
    if not frame then
        frame = CreateFrame("Frame")
        frame.elapsed = 0
        frame:SetScript("OnUpdate", function(watcher, elapsed)
            watcher.elapsed = (watcher.elapsed or 0) + elapsed
            if watcher.elapsed < 0.10 then return end
            watcher.elapsed = 0
            local preview = Core.AccountView and Core.AccountView.frame
            if not (preview and preview.preview and preview:IsShown()) then
                Entry:StopPreviewWatch()
                return
            end
            local now = GetTime and GetTime() or 0
            if now < (Entry.previewWatchGraceUntil or 0) then return end
            if not Entry:IsMouseOverPreview() and not Entry:IsMouseOverPreviewAnchor() then HidePreview() end
        end)
        self.previewWatchFrame = frame
    end
    frame.elapsed = 0
    -- Preserve the direct path from entry to preview only when the watcher is
    -- first activated. Broker hosts may call OnTooltipShow repeatedly while
    -- the same preview is visible; resetting this deadline on every callback
    -- can keep an interactive preview alive forever after the pointer leaves.
    if not wasActive then
        self.previewWatchGraceUntil = (GetTime and GetTime() or 0) + 0.20
    end
    self.previewWatchActive = true
    frame:Show()
end

function Entry:SchedulePreviewClose()
    local now = GetTime and GetTime() or 0
    self.previewToken = (self.previewToken or 0) + 1
    local token = self.previewToken
    local function CloseIfStillPending()
        -- A checkbox, scope button, or row inside the preview becomes the mouse
        -- focus itself.  Treat every descendant as part of the hover surface.
        if Entry.previewToken == token and not Entry:IsMouseOverPreview() and not Entry:IsMouseOverPreviewAnchor() then HidePreview() end
    end
    if C_Timer and C_Timer.After then
        -- A preview can be rebuilt after an in-preview click.  If its leave
        -- event lands during that short protected interval, still queue one
        -- close for after it expires; returning early here stranded the Boss
        -- weekly preview until another hover event happened.
        local suppressedFor = math.max(0, (self.previewCloseSuppressedUntil or 0) - now)
        C_Timer.After(math.max(0.20, suppressedFor + 0.05), CloseIfStillPending)
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
        button:SetScript("OnClick", function(_, button) Entry:HandleEntryClick("YiboCore", button) end)
        button:SetScript("OnDragStart", button.StartMoving)
        button:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local centerX, centerY = Minimap:GetCenter()
            local buttonX, buttonY = self:GetCenter()
            if centerX and buttonX then EntrySettings().minimap.angle = math.deg(AngleFromOffset(buttonY - centerY, buttonX - centerX)) end
            Entry:Refresh()
        end)
        button:SetScript("OnEnter", function(self)
            if Entry:ShowEntryPreview("YiboCore", self, "minimap") then return end
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(Core:Text("CORE.YIBO_ACCOUNT_OVERVIEW"), 0.125, 0.88, 0.44)
            GameTooltip:AddLine(Core:Text("CORE.LEFT_CLICK_TO_OPEN_CHARACTER_STATUS"), 0.75, 0.85, 0.87)
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
        if not broker then broker = library:NewDataObject("YiboCore", {yiboCoreEntryID="YiboCore"}) end
        if broker.yiboCoreEntryID == "YiboCore" then self.broker = broker; ConfigureCoreBroker(broker) end
    end
    for _, entry in pairs(self.businessEntries) do self:CreateBusinessBroker(entry) end
    self:Refresh()
end

function Entry:Refresh()
    local coreMode = self:GetCoreEntryMode()
    local library = self.library or (LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true))
    self.library = library
    if library and HasBroker(coreMode) and not self.broker then
        local broker = library:GetDataObjectByName("YiboCore")
        if not broker then broker = library:NewDataObject("YiboCore", {yiboCoreEntryID="YiboCore"}) end
        if broker.yiboCoreEntryID == "YiboCore" then self.broker = broker end
    end
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
        local available = self:GetEntryAvailability(entry.id)
        if HasBroker(mode) and available then
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
            entry.button:SetShown(available and HasMinimap(mode))
        end
    end
    if self.previewOwner and not self:GetEntryAvailability(self.previewOwner.id) then HidePreview() end
    if Core.EntryBar then Core.EntryBar:Refresh() end
end

Core.Events:Register("CORE_READY", Entry, function(owner) owner:Initialize() end)
Core.Events:Register("PLAYER_LOGIN", Entry, function(owner) owner:Initialize() end)
local function Settings() return EntrySettings() end
function Entry:GetEntryChannels(id)
    local s = Settings()
    return Core.Defaults:Copy(id == "YiboCore" and s.coreChannels or s.businessChannels[id] or Core.EntryConfig:FromMode("none"))
end
function Entry:SetEntryChannel(id, channel, enabled)
    if channel ~= "minimap" and channel ~= "broker" and channel ~= "builtinBar" then return false end
    if type(id) ~= "string" or id == "" or type(enabled) ~= "boolean" then return false end
    local c = self:GetEntryChannels(id); c[channel] = enabled
    local s = Settings()
    if id == "YiboCore" then s.coreChannels = c else s.businessChannels[id] = c end
    if not enabled then self:CloseEntryPreview(id,channel) end
    self:Refresh(); return true
end
function Entry:GetBuiltinBarSettings() return Core.Defaults:Copy(Settings().bar) end
function Entry:SetBuiltinBarEnabled(enabled)
    if type(enabled) ~= "boolean" then return false end
    Settings().bar.enabled = enabled
    if not enabled then self:CloseEntryPreview(nil, "builtinBar") end
    self:Refresh(); return true
end
function Entry:SetBuiltinBarOption(key, value)
    local allowed = {locked="boolean",showNames="boolean",showBorder="boolean",background="string",backgroundAlpha="number",iconSize="number",spacing="number"}
    if not allowed[key] or type(value) ~= allowed[key] then return false end
    if key == "background" and not ({theme=true,black=true,charcoal=true,navy=true,forest=true})[value] then return false end
    Settings().bar[key] = value
    Core.EntryConfig:Normalize(Settings()); self:Refresh(); return true
end
function Entry:SetBuiltinBarPosition(point, relativePoint, x, y)
    local s = Settings().bar
    s.point,s.relativePoint,s.x,s.y = point,relativePoint,x,y
    Core.EntryConfig:Normalize(Settings()); self:Refresh()
end
function Entry:GetEntryAvailability(id)
    if id == "YiboCore" then return Core.AccountView ~= nil end
    local entry = self.businessEntries[id]
    if not entry or entry.disabled then return false end
    local page = Core.AccountView._pages[ResolveBusinessPageID(entry)]
    return page ~= nil and Core.AccountView._internal.PageEnabled(page)
end
function Entry:HandleEntryClick(id, button)
    if not self:GetEntryAvailability(id) then return false end
    HidePreview(true)
    if button == "RightButton" then
        if id == "YiboCore" then
            Core.AccountView:ShowSettings("display")
        else
            local entry = self.businessEntries[id]
            Core.AccountView:ShowSettings(ResolveBusinessPageID(entry))
        end
    else
        Core.AccountView:Toggle(id ~= "YiboCore" and ResolveBusinessPageID(self.businessEntries[id]) or nil)
    end
    return true
end
local function BarName(text)
    text=tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
    return (text:gsub("^%s*%[Yibo%]%s*",""):gsub("^Yibo[%w_]*%s*%-%s*",""):gsub("^%s+",""):gsub("%s+$",""))
end
function Entry:GetBuiltinBarEntries()
    local result = {}
    if self:GetEntryChannels("YiboCore").builtinBar then result[1] = {id="YiboCore",addonName="",text=BarName(Core:Text("CORE.YIBO_ACCOUNT_OVERVIEW")),icon="Interface\\AddOns\\YiboCore\\Media\\YiboCoreIcon"} end
    for _, entry in pairs(self.businessEntries) do
        if self:GetEntryChannels(entry.id).builtinBar and self:GetEntryAvailability(entry.id) then result[#result+1] = {id=entry.id,addonName=entry.addonName,text=BarName((Core.AccountView._pages[ResolveBusinessPageID(entry)] or {}).title or entry.text),icon=entry.icon} end
    end
    local ranks = {}
    for index,id in ipairs(Settings().bar.order) do ranks[id]=index end
    table.sort(result,function(a,b)
        if ranks[a.id] ~= ranks[b.id] then
            if ranks[a.id] == nil then return false end
            if ranks[b.id] == nil then return true end
            return ranks[a.id] < ranks[b.id]
        end
        if a.addonName ~= b.addonName then return a.addonName < b.addonName end
        return a.id < b.id
    end)
    return result
end
Core.Events:Register("ACCOUNT_VIEW_PAGE_REGISTERED", Entry, function(owner) owner:Refresh() end)
Core.Events:Register("ACCOUNT_VIEW_PAGE_UNREGISTERED", Entry, function(owner) owner:Refresh() end)
Core.Capabilities:Register("account-entry", 2)
Core.Capabilities:Register("builtin-entry-bar", 3)

function Entry:ShowEntryPreview(id, anchor, source)
    if not self:GetEntryAvailability(id) then return false end
    local pageID = id ~= "YiboCore" and ResolveBusinessPageID(self.businessEntries[id]) or nil
    local page = pageID and Core.AccountView._pages[pageID] or Core.AccountView:GetPreviewPage()
    local frame = Core.AccountView.frame
    if not page or not page.previewEnabled or (frame and frame:IsShown() and not frame.preview and not EntrySettings().showPreviewWhileMainWindowOpen) then
        self:CloseEntryPreview();return false
    end
    self.previewOwner = {id=id,source=source}
    return ShowPreview(anchor, pageID)
end
function Entry:CloseEntryPreview(id, source)
    local owner = self.previewOwner
    if id == nil and source == nil or owner and (not id or owner.id == id) and (not source or owner.source == source) then HidePreview() end
end

function Entry:MoveBuiltinBarEntry(id, direction)
    if direction ~= -1 and direction ~= 1 then return false end
    local entries = self:GetBuiltinBarEntries()
    local current
    for index,entry in ipairs(entries) do if entry.id == id then current=index;break end end
    local neighbor = current and entries[current+direction]
    if not neighbor then return false end
    local order = Settings().bar.order
    local positions = {}
    for index,key in ipairs(order) do positions[key]=index end
    for _,entry in ipairs(entries) do
        if not positions[entry.id] then order[#order+1]=entry.id;positions[entry.id]=#order end
    end
    local a,b = positions[id],positions[neighbor.id]
    order[a],order[b] = order[b],order[a]
    self:Refresh();return true
end
function Entry:ResetBuiltinBarOrder()
    Settings().bar.order = {};self:Refresh()
end

function Entry:ReorderBuiltinBarEntry(id,targetID)
    local entries=self:GetBuiltinBarEntries()
    local source,target
    for i,entry in ipairs(entries) do
        if entry.id==id then source=i end
        if entry.id==targetID then target=i end
    end
    if not source or not target or source==target then return false end
    local moved=table.remove(entries,source);table.insert(entries,target,moved)
    local visible={};for _,entry in ipairs(entries) do visible[entry.id]=true end
    local order,nextIndex={},1
    for _,key in ipairs(Settings().bar.order) do
        if visible[key] then order[#order+1]=entries[nextIndex].id;nextIndex=nextIndex+1
        else order[#order+1]=key end
    end
    while nextIndex<=#entries do order[#order+1]=entries[nextIndex].id;nextIndex=nextIndex+1 end
    Settings().bar.order=order;self:Refresh();return true
end
