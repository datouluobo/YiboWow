local Addon = _G.YiboAutoOpen
local Integration = {}; Addon.CoreIntegration = Integration
function Integration:Initialize()
    local Core = _G.YiboCore
    if not Core then return true end
    local compatible = Core:CheckAPIVersion(6)
    if not compatible then Addon:NotifyIssue("core-old", "Core 版本不兼容，已继续使用命令模式。"); return true end
    local registered, errorMessage = Core:RegisterAddon(Addon.NAME, { version = Addon.VERSION, requiredAPI = 6 })
    if not registered then Addon:NotifyIssue("core-register", "Core 注册失败，已继续使用命令模式：" .. tostring(errorMessage)); return true end
    local panel, panelError = Core:RegisterSettingsPanel(Addon.NAME, {
        id = Addon.NAME, title = "自动开包", description = "管理自动开启目录、安全阈值与运行状态。",
        icon = "Interface\\AddOns\\YiboAutoOpen\\Media\\YiboAutoOpenIcon-v2",
        CreateSettingsPanel = function(parent, host) return Addon.Settings:CreatePanel(parent, host) end,
    })
    if not panel then Addon:NotifyIssue("core-panel", "Core 设置注册失败，已继续使用命令模式：" .. tostring(panelError)) end
    Addon.Core = Core
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
