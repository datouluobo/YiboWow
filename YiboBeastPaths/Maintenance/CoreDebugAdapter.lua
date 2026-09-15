local addonName, ns = ...
local YBP = _G.YiboBeastPaths

-- Mists-only adapter.  BeastPaths stays independently loadable: this file
-- merely registers optional Core UI when the required host is present.
local ADDON_ID = "YiboBeastPaths"
local ADDON_TITLE = GetLocale and GetLocale() == "zhCN" and "隐兽寻踪" or ADDON_ID
local PAGE_ID = "yibo-beastpaths-route-maintenance"
local SETTINGS_ID = "yibo-beastpaths"
local registered, pageRegistered, unavailableReason = false, false, nil
local notifiedReasons = {}

local function IsMists()
    return ns and ns.IS_MISTS == true
end

local function GetCore()
    local core = _G.YiboCore
    if not core then return nil, "需要 YiboCore API v6。" end
    local compatible = core.CheckAPIVersion and core:CheckAPIVersion(6)
    if not compatible then return nil, "需要 YiboCore API v6。" end
    if not (core.Registry and core.SettingsRegistry and core.AccountView) then
        return nil, "YiboCore 正在初始化，请稍后重试路线维护。"
    end
    return core
end

local function PrintUnavailable(reason)
    reason = reason or unavailableReason or "路线维护功能当前不可用。"
    if notifiedReasons[reason] then return end
    notifiedReasons[reason] = true
    print("|cffffcc00[YiboBeastPaths]|r " .. reason)
end

local function RefreshCorePage()
    local core = _G.YiboCore
    if core and core.AccountView and core.AccountView.NotifyPageChanged then
        core.AccountView:NotifyPageChanged(PAGE_ID)
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
    if not YBP:IsDebugEnabled() then return end
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

local function RegisterPage(core)
    if pageRegistered or not YBP:IsDebugEnabled() then return true end
    local page, err = core.AccountView:RegisterPage(ADDON_ID, {
        id = PAGE_ID,
        title = ADDON_TITLE,
        compactWidth = true,
        defaultEnabled = true,
        Create = CreateDebugPage,
        Refresh = RefreshDebugPage,
        GetSurfaceMetrics = function()
            return { minContentWidth = 620, naturalContentWidth = 760, minContentHeight = 460, naturalContentHeight = 720 }
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

local function SetMaintenanceMode(enabled)
    if not registered then
        PrintUnavailable()
        return false
    end
    YBP:SetDebugEnabled(enabled)
    local core = _G.YiboCore
    if enabled then
        if not RegisterPage(core) then return false end
        core.AccountView:ShowPage(PAGE_ID)
    elseif pageRegistered then
        core.AccountView:UnregisterPage(PAGE_ID)
        pageRegistered = false
    end
    return true
end

local function CreateSettingsPanel(row, host)
    local core, theme = _G.YiboCore, _G.YiboCore.UITheme
    local section = host.createSection(row, "业务设置", row:GetWidth() or 560, 178)
    section:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    local status = theme:CreateText(section, theme.Font.assist, theme.Colors.muted, "LEFT")
    status:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -42)
    status:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -42)
    status:SetWordWrap(true)
    local toggle = theme:CreateButton(section, 160, YBP:IsDebugEnabled() and "关闭路线维护模式" or "开启路线维护模式", YBP:IsDebugEnabled() and "danger" or "default")
    toggle:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -92)
    toggle:SetScript("OnClick", function()
        SetMaintenanceMode(not YBP:IsDebugEnabled())
        core.AccountView:RefreshPage()
    end)
    local open = theme:CreateButton(section, 160, "前往路线维护", "secondary")
    open:SetPoint("LEFT", toggle, "RIGHT", 12, 0)
    open:SetEnabled(YBP:IsDebugEnabled() and pageRegistered)
    open:SetScript("OnClick", function()
        if pageRegistered then core.AccountView:ShowPage(PAGE_ID) end
    end)
    local coreOK = GetCore() and "可用（API v6）" or "不可用"
    local pageState = YBP:IsDebugEnabled() and pageRegistered and "已启用" or "已关闭"
    status:SetText("路线维护模式允许修改本地路线维护数据。客户端：Mists Classic；Core：" .. coreOK .. "；业务页：" .. pageState .. "。")
    row:SetHeight(178)
    return 178
end

local function TryRegister()
    if registered or not IsMists() then return registered end
    local core, reason = GetCore()
    if not core then unavailableReason = reason; return false end
    local addon, err = core:RegisterAddon(ADDON_ID, { requiredAPI = 6, version = "1.6" })
    if not addon then unavailableReason = err; return false end
    local settings, settingsErr = core:RegisterSettingsPanel(ADDON_ID, {
        id = SETTINGS_ID,
        title = ADDON_TITLE,
        CreateSettingsPanel = CreateSettingsPanel,
    })
    if not settings then unavailableReason = settingsErr; return false end
    registered = true
    RegisterPage(core)
    return true
end

function YBP:OpenCoreRouteMaintenance()
    if not TryRegister() then PrintUnavailable(); return false end
    if not self:IsDebugEnabled() then
        _G.YiboCore.AccountView:ShowSettings("addon-settings:" .. SETTINGS_ID)
        return true
    end
    if RegisterPage(_G.YiboCore) then
        _G.YiboCore.AccountView:ShowPage(PAGE_ID)
        return true
    end
    return false
end

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == addonName or name == "YiboCore" then
        TryRegister()
    end
end)
