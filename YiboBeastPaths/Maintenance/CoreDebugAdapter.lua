local addonName, ns = ...
if not ns.YBP_TARGET_OK then return end
local YBP = _G.YiboBeastPaths
local T = ns.Text

-- Shared Retail/Mists adapter. BeastPaths stays independently loadable: this file
-- merely registers optional Core UI when the required host is present.
local ADDON_ID = "YiboBeastPaths"
local SETTINGS_ID = "yibo-beastpaths"
local registered, unavailableReason = false, nil
local notifiedReasons = {}
local waitingCore, OnCoreReady

local function IsSupportedClient()
    return ns and (ns.IS_MISTS == true or ns.IS_RETAIL == true)
end

local function GetCore()
    local core = _G.YiboCore
    if not (core and core.CheckAPIVersion and core:CheckAPIVersion(14)
        and core.HasCapability) then return nil, T("CORE_REQUIRED") end
    for name, version in pairs({ localization = 1, ["basic-input"] = 1,
        ["account-view"] = 2, ["account-surface-budget"] = 1, ["pixel-line"] = 1 }) do
        if not core:HasCapability(name, version) then return nil, T("CORE_REQUIRED") end
    end
    if not (core.IsInitialized and core:IsInitialized()) then return nil, T("CORE_NOT_READY") end
    if not (core.Registry and core.SettingsRegistry and core.AccountView
        and core.RegisterAddon and core.RegisterSettingsPanel and core.Events
        and core.Events.Register and core.Events.Unregister
        and core.AccountView.ShowSettings
        and core.UITheme and core.UITheme.CreateInput
        and core.UITheme.CreateButton and core.UITheme.CreateText
        and type(core.UITheme.ApplyPixelBackdrop) == "function"
        and type(core.UITheme.ApplyPixelRule) == "function"
        and ns.RegisterLocale(core)) then return nil, T("CORE_REQUIRED") end
    return core
end

local function PrintUnavailable(reason)
    reason = reason or unavailableReason or T("MAINTENANCE_UNAVAILABLE")
    if notifiedReasons[reason] then return end
    notifiedReasons[reason] = true
    print(reason)
end

function YBP:NotifyCoreDebugPage()
    self:RefreshDebugPanel()
end

local function CreateSettingsPanel(row, host)
    -- Core owns the single settings scroll surface. Reuse the controls when
    -- switching tabs or resizing; do not create an inner maintenance scroller.
    row.yiboBeastPathsHost = host
    row.yiboBeastPathsRendering = true
    local section = row.yiboBeastPathsSettings
    if not section then
        section = host.createSection(row, "", row:GetWidth() or 560, 1)
        section:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        -- Core already supplies this page's title and description. Drop the
        -- duplicated section heading so the maintenance controls follow them
        -- directly instead of spending another row on "Business settings".
        if section.title then section.title:Hide() end
        if section.rule then section.rule:Hide() end
        row.yiboBeastPathsSettings = section
        section.content = CreateFrame("Frame", nil, section)
        section.content:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -8)
        section.content:SetWidth(row:GetWidth() or 560)
        section.debugPanel = YBP:CreateCoreDebugPanel(section.content)
        section.debugPanel.hostedSettings = true
        section.debugPanel.onLayout = function(height)
            local total = height + 8
            local changed = math.abs((section:GetHeight() or 0) - total) >= 1
            section:SetHeight(total)
            if changed and not row.yiboBeastPathsRendering then
                row.yiboBeastPathsHost.refreshPanel()
            end
        end
        section:HookScript("OnHide", function() YBP:CancelCoreDebugInteraction() end)
        row:HookScript("OnSizeChanged", function(_, width)
            if not section:IsShown() or not width or width <= 0
                or math.abs((section:GetWidth() or 0) - width) < 1 then return end
            row.yiboBeastPathsHost.refreshPanel()
        end)
    end
    local width = math.max(1, row:GetWidth() or 560)
    section:SetWidth(width)
    section.content:SetWidth(width)
    section.debugPanel:SetWidth(width)
    section:Show()
    section.debugPanel:Show()
    YBP:RefreshDebugPanel()
    row.yiboBeastPathsRendering = false
    return section:GetHeight()
end
ns.CreateMaintenanceSettingsPanel = CreateSettingsPanel

local function TryRegister()
    if not IsSupportedClient() then return false end
    local core, reason = GetCore()
    if not core then unavailableReason = reason; return false end
    if registered then return true end
    -- Initialize defaults before the early ADDON_LOADED registration so a new
    -- profile's visible page does not depend on PLAYER_LOGIN event ordering.
    if YBP.InitDebugDB then YBP:InitDebugDB() end
    local addon, err = core:RegisterAddon(ADDON_ID, { requiredAPI = 14, version = "1.10.0" })
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
    YBP:RefreshWorldMapButton()
    return true
end

function YBP:OpenCoreRouteMaintenance()
    if not TryRegister() then PrintUnavailable(); return false end
    if ns.OfflinePetPage then
        if type(self.OpenOfflinePets) == "function" then return self:OpenOfflinePets("maintenance") end
        PrintUnavailable(); return false
    end
    return _G.YiboCore.AccountView:ShowSettings("addon-settings:" .. SETTINGS_ID) ~= false
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
