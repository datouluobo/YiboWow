local addonName, ns = ...
if not ns.YBP_TARGET_OK then return end
local YBP = _G.YiboBeastPaths
local T = ns.Text

-- Shared Retail/Mists adapter. BeastPaths stays independently loadable: this file
-- merely registers optional Core UI when the required host is present.
local ADDON_ID = "YiboBeastPaths"
local PAGE_ID = "yibo-beastpaths-route-maintenance"
local function ActivePageID()
    return ns.OfflinePetPage and "yibo-beastpaths-offline-pets" or PAGE_ID
end
local SETTINGS_ID = "yibo-beastpaths"
local registered, pageRegistered, unavailableReason = false, false, nil
local notifiedReasons = {}
local waitingCore, OnCoreReady

local function IsSupportedClient()
    return ns and (ns.IS_MISTS == true or ns.IS_RETAIL == true)
end

local function GetCore()
    local core = _G.YiboCore
    if not (core and core.CheckAPIVersion and core:CheckAPIVersion(13)
        and core.HasCapability) then return nil, T("CORE_REQUIRED") end
    for name, version in pairs({ localization = 1, ["basic-input"] = 1,
        ["account-view"] = 2, ["account-surface-budget"] = 1 }) do
        if not core:HasCapability(name, version) then return nil, T("CORE_REQUIRED") end
    end
    if not (core.IsInitialized and core:IsInitialized()) then return nil, T("CORE_NOT_READY") end
    if not (core.Registry and core.SettingsRegistry and core.AccountView
        and core.RegisterAddon and core.RegisterSettingsPanel and core.Events
        and core.Events.Register and core.Events.Unregister
        and core.AccountView.RegisterPage and core.AccountView.UnregisterPage
        and core.AccountView.ShowPage and core.AccountView.Toggle and core.AccountView.ShowSettings
        and core.AccountView.RefreshPage and core.AccountView.NotifyPageChanged
        and core.UITheme and core.UITheme.CreateInput and core.UITheme.CreateScrollFrame
        and core.UITheme.CreateButton and core.UITheme.CreateText
        and ns.RegisterLocale(core)) then return nil, T("CORE_REQUIRED") end
    return core
end

local function PrintUnavailable(reason)
    reason = reason or unavailableReason or T("MAINTENANCE_UNAVAILABLE")
    if notifiedReasons[reason] then return end
    notifiedReasons[reason] = true
    print(reason)
end

local function RefreshCorePage()
    local core = _G.YiboCore
    if core and core.AccountView and core.AccountView.NotifyPageChanged then
        core.AccountView:NotifyPageChanged(ActivePageID())
    end
end

local function GetStableDebugWidth(parent, viewportWidth, fallbackWidth)
    local pageWidth = parent:GetWidth() or 0
    local stableViewportWidth = pageWidth - 32 -- 8px sides + Core's 16px gutter
    if stableViewportWidth >= 580 then
        return viewportWidth and viewportWidth >= 580
            and math.min(viewportWidth, stableViewportWidth) or stableViewportWidth
    end
    if viewportWidth and viewportWidth >= 580 then return viewportWidth end
    return math.max(620, fallbackWidth or 620)
end

function YBP:NotifyCoreDebugPage()
    RefreshCorePage()
end

local function CreateDebugPage(parent)
    local core = _G.YiboCore
    local theme = core.UITheme
    parent.scroll = theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -8)
    parent.scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
    parent.content = CreateFrame("Frame", nil, parent.scroll)
    parent.content:SetSize(math.max(620, parent:GetWidth() or 620), 1160)
    parent.scroll:SetScrollChild(parent.content)
    parent.scroll:BindScrollbarGutter(parent.content)
    parent.debugPanel = YBP.CreateCoreDebugPanel and YBP:CreateCoreDebugPanel(parent.content) or nil
    parent:HookScript("OnHide", function() YBP:CancelCoreDebugInteraction() end)
    -- Core releases/reserves its scrollbar gutter asynchronously.  The
    -- business panel has an explicit width, so keep it tied to the actual
    -- viewport rather than the pre-gutter surface metric.
    parent.scroll:HookScript("OnSizeChanged", function(scroll, width)
        if not parent.debugPanel or not width or width < 580 then return end
        local stableWidth = GetStableDebugWidth(parent, width)
        if math.abs((parent.debugPanel:GetWidth() or 0) - stableWidth) < 1 then return end
        parent.content:SetWidth(stableWidth)
        parent.debugPanel:SetWidth(stableWidth)
        YBP:RefreshDebugPanel()
    end)
end

local function RefreshDebugPage(parent, context)
    local viewportWidth = parent.scroll:GetWidth() or 0
    local width = GetStableDebugWidth(parent, viewportWidth,
        (context and context.surfaceAvailableWidth) or parent:GetWidth() or 620)
    parent.content:SetWidth(width)
    if parent.debugPanel then
        parent.debugPanel:SetWidth(width)
        parent.debugPanel:Show()
        YBP:RefreshDebugPanel()
        local height = math.max(360, parent.debugPanel:GetHeight() or 360)
        parent.content:SetHeight(height)
        parent.scroll:SetContentHeight(height)
    end
end

ns.CreateMaintenancePage = CreateDebugPage
ns.RefreshMaintenancePage = RefreshDebugPage

local function RegisterPage(core)
    if pageRegistered then return true end
    -- The 1.9 offline page owns the shared Core page and hosts this view.
    if ns.OfflinePetPage then return true end
    local page, err = core.AccountView:RegisterPage(ADDON_ID, {
        id = PAGE_ID,
        title = T("TITLE"),
        hideFromSettings = true,
        compactWidth = true,
        defaultEnabled = true,
        Create = CreateDebugPage,
        Refresh = RefreshDebugPage,
        GetSurfaceMetrics = function(context)
            local budget = context and context.surfaceAvailableHeight or 720
            return { minContentWidth = 620, naturalContentWidth = 760,
                minContentHeight = math.min(460, budget), naturalContentHeight = math.min(720, budget) }
        end,
    })
    if not page then
        unavailableReason = err
        PrintUnavailable(err)
        return false
    end
    pageRegistered = true
    return true
end

local function CreateSettingsPanel(row, host)
    local core, theme = _G.YiboCore, _G.YiboCore.UITheme
    if row.yiboBeastPathsSettings then row.yiboBeastPathsSettings:Hide() end
    local section = host.createSection(row, T("BUSINESS_SETTINGS"), row:GetWidth() or 560, 178)
    section:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.yiboBeastPathsSettings = section
    local status = theme:CreateText(section, theme.Font.assist, theme.Colors.muted, "LEFT")
    status:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -42)
    status:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -42)
    status:SetWordWrap(true)
    local open = theme:CreateButton(section, 190, T("MAINTENANCE_OPEN"), "secondary")
    open:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -92)
    local ready = ns.OfflinePetPage and type(ns.IsUnifiedPageReady) == "function"
        and ns.IsUnifiedPageReady() or pageRegistered
    open:SetEnabled(ready or ns.OfflinePetPage ~= nil)
    open:SetScript("OnClick", function()
        YBP:OpenCoreRouteMaintenance()
    end)
    local pageState = ready and T("ON") or T("OFF")
    status:SetText(T("MAINTENANCE_STATUS", pageState))
    row:SetHeight(178)
    return 178
end
ns.CreateMaintenanceSettingsPanel = CreateSettingsPanel

local function TryRegister()
    if not IsSupportedClient() then return false end
    if registered then return RegisterPage(_G.YiboCore) end
    local core, reason = GetCore()
    if not core then unavailableReason = reason; return false end
    -- Initialize defaults before the early ADDON_LOADED registration so a new
    -- profile's visible page does not depend on PLAYER_LOGIN event ordering.
    if YBP.InitDebugDB then YBP:InitDebugDB() end
    local addon, err = core:RegisterAddon(ADDON_ID, { requiredAPI = 13, version = "1.9.0" })
    if not addon then unavailableReason = err; return false end
    if not ns.OfflinePetPage then
        local settings, settingsErr = core:RegisterSettingsPanel(ADDON_ID, {
            id = SETTINGS_ID,
            title = T("TITLE"),
            CreateSettingsPanel = CreateSettingsPanel,
        })
        if not settings then unavailableReason = settingsErr; return false end
    end
    registered = true
    if waitingCore then waitingCore.Events:Unregister("CORE_READY", ADDON_ID, OnCoreReady) end
    waitingCore = nil
    unavailableReason = nil
    local pageReady = RegisterPage(core)
    YBP:RefreshWorldMapButton()
    return pageReady
end

function YBP:OpenCoreRouteMaintenance()
    if not TryRegister() then PrintUnavailable(); return false end
    if ns.OfflinePetPage then
        if type(self.OpenOfflinePets) == "function" then return self:OpenOfflinePets("maintenance") end
        PrintUnavailable(); return false
    end
    if RegisterPage(_G.YiboCore) then
        if _G.YiboCore.AccountView:Toggle(PAGE_ID) == false then return false end
        return true
    end
    return false
end

local init = CreateFrame("Frame")
OnCoreReady = function()
    if waitingCore then waitingCore.Events:Unregister("CORE_READY", ADDON_ID, OnCoreReady) end
    waitingCore = nil
    TryRegister()
end
local function WaitForCore()
    local core = _G.YiboCore
    if not IsSupportedClient() or registered or waitingCore == core then return end
    if core and core.Events and core.Events.Register and core.Events.Unregister then
        if waitingCore then waitingCore.Events:Unregister("CORE_READY", ADDON_ID, OnCoreReady) end
        waitingCore = core
        core.Events:Register("CORE_READY", ADDON_ID, OnCoreReady)
    end
end
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == addonName or name == "YiboCore" then
        if not TryRegister() then
            WaitForCore()
            if event == "PLAYER_LOGIN" and IsSupportedClient() and _G.YiboCore then PrintUnavailable() end
        end
    end
end)
