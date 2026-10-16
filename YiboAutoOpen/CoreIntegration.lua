local Addon = _G.YiboAutoOpen
local Integration = {}; Addon.CoreIntegration = Integration
function Integration:Initialize()
    if self.initialized then return true end
    local Core = _G.YiboCore
    if not Core then
        Addon:NotifyIssue("core-missing", Addon:T("CORE.MISSING"))
        return true
    end
    local compatible = Core.CheckAPIVersion and Core:CheckAPIVersion(13)
    local localized = Core.HasCapability and Core:HasCapability("localization", 1)
    local localeAPI = Core.Locale and type(Core.Locale.Get) == "function" and type(Core.Locale.Register) == "function"
    if not (compatible and localized and localeAPI and Core.RegisterAddon and Core.RegisterSettingsPanel and Core.UITheme) then
        Addon:NotifyIssue("core-incompatible", Addon:T("CORE.UPGRADE_REQUIRED"))
        return true
    end
    Addon.Core = Core
    local registered, errorMessage = Core:RegisterAddon(Addon.NAME, { version = Addon.VERSION, requiredAPI = 13 })
    if not registered then Addon:NotifyIssue("core-register", Addon:T("CORE.REGISTER_FAILED", tostring(errorMessage))); return true end
    local panel, panelError = Core:RegisterSettingsPanel(Addon.NAME, {
        id = Addon.NAME, title = Addon:T("SETTINGS.TITLE"), description = Addon:T("SETTINGS.DESCRIPTION"),
        icon = "Interface\\AddOns\\YiboAutoOpen\\Media\\YiboAutoOpenIcon",
        CreateSettingsPanel = function(parent, host) return Addon.Settings:CreatePanel(parent, host) end,
    })
    if not panel then Addon:NotifyIssue("core-panel", Addon:T("CORE.PANEL_FAILED", tostring(panelError))) end
    self.initialized = panel ~= nil
    if panel and Core.AccountView and Core.AccountView.activePageID == "settings" then
        Core.AccountView:RefreshNavigation()
        Core.AccountView:RefreshPage()
    end
    return true
end

-- This file is loaded after the settings implementation.  Register now so
-- the Core navigation is ready before the player opens the settings window;
-- PLAYER_LOGIN repeats this safely when the runtime starts.
Integration:Initialize()
