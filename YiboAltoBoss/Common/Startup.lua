local YAB = _G.YAB or {}
_G.YAB = YAB

local messages = {
    en = {
        WRONG_MISTS = "Install the YiboAltoBoss package for Mists.",
        WRONG_FOREVER = "Install the YiboAltoBoss package for Forever.",
        CORE_MISTS = "YiboAltoBoss requires YiboCore API13, account-surface-budget:2 and calendar-day-query:1. Upgrade YiboCore.",
        CORE_FOREVER = "YiboAltoBoss requires YiboCore API13 with current account UI capabilities. Enable or upgrade YiboCore.",
    },
    zh = {
        WRONG_MISTS = "请安装 YiboAltoBoss 熊猫人之谜版本。",
        WRONG_FOREVER = "请安装 YiboAltoBoss 无限服版本。",
        CORE_MISTS = "YiboAltoBoss 需要 YiboCore API13、account-surface-budget:2 和 calendar-day-query:1。请升级 YiboCore。",
        CORE_FOREVER = "YiboAltoBoss 需要 YiboCore API13 和最新账号界面能力。请启用或升级 YiboCore。",
    },
}

function YAB.PrintStartupMessage(key)
    if not DEFAULT_CHAT_FRAME then return end
    local locale = GetLocale and GetLocale()
    local language = (locale == "zhCN" or locale == "zhTW") and "zh" or "en"
    DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo]|r " .. messages[language][key])
end
