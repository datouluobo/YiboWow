local Addon = _G.YiboAutoOpen
local FALLBACK = {
    zh = {
        ["CORE.MISSING"] = "完整设置功能需要 YiboCore API v13；未安装 Core 不影响自动开包与 /yao 命令使用。",
        ["CORE.UPGRADE_REQUIRED"] = "YiboAutoOpen 设置页需要 YiboCore API v13 与 localization:1，请升级 Core。",
        ["SETTINGS.TITLE"] = "自动开包",
        ["SETTINGS.DESCRIPTION"] = "管理自动开启目录、安全阈值与运行状态。",
        ["CORE.REGISTER_FAILED"] = "Core 注册失败，已继续使用命令模式：%s",
        ["CORE.PANEL_FAILED"] = "Core 设置注册失败，已继续使用命令模式：%s",
    },
    en = {
        ["CORE.MISSING"] = "Full settings require YiboCore API v13. Without Core, automatic opening and /yao commands remain available.",
        ["CORE.UPGRADE_REQUIRED"] = "The YiboAutoOpen settings page requires YiboCore API v13 and localization:1. Please update YiboCore.",
        ["SETTINGS.TITLE"] = "Auto Open",
        ["SETTINGS.DESCRIPTION"] = "Manage the opening catalog, safety threshold, and runtime status.",
        ["CORE.REGISTER_FAILED"] = "Core registration failed. Command mode remains available: %s",
        ["CORE.PANEL_FAILED"] = "Core settings registration failed. Command mode remains available: %s",
    },
}

function Addon:T(key, ...)
    local Core = self.Core or _G.YiboCore
    if Core and Core.HasCapability and Core:HasCapability("localization", 1)
        and Core.Locale and type(Core.Locale.Get) == "function" and type(Core.Locale.Register) == "function" then
        return Core.Locale:Get(self.NAME, key, ...)
    end
    local language = (GetLocale and GetLocale() or "enUS"):match("^zh") and "zh" or "en"
    local value = FALLBACK[language][key] or FALLBACK.en[key] or key
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then return formatted end
    end
    return value
end

local Core = _G.YiboCore
if Core and Core.Locale and type(Core.Locale.Register) == "function" then
    Core.Locale:Register(Addon.NAME, "zh", FALLBACK.zh)
    Core.Locale:Register(Addon.NAME, "en", FALLBACK.en)
end
