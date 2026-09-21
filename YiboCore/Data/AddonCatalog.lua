local Core = _G.YiboCore
local beastPathsTitle = GetLocale and GetLocale() == "zhCN" and "隐兽寻踪" or "YiboBeastPaths"
local altoBossTitle = GetLocale and GetLocale() == "zhCN" and "首领追踪" or "Boss Tracker"
local altoBossDescription = GetLocale and GetLocale() == "zhCN"
    and "跨角色追踪世界首领、节日首领与自定义目标；副本 CD 监控即将加入。"
    or "Tracks world bosses, holiday bosses, and custom targets across characters; instance lockout tracking is planned."

-- Static presentation metadata only.  Versions deliberately live in the
-- generated packaging manifest and in the player's installed TOCs.
Core.AddonCatalog = {
    {
        name = "YiboAltoBoss",
        title = altoBossTitle,
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YAB_MinimapIcon",
        description = altoBossDescription,
        projectURL = "https://www.curseforge.com/wow/addons/yibo-altoboss",
    },
    {
        name = "YiboBuilds",
        title = "角色构筑",
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboBuilds\\Media\\YiboBuildsIcon-v1",
        description = "跨角色查看装备、天赋与雕文构筑。",
        projectURL = "https://www.curseforge.com/wow/addons/yibobuilds",
    },
    {
        name = "YiboCurrency",
        title = "货币管家",
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon-v1",
        description = "跨角色货币追踪。",
        projectURL = "https://www.curseforge.com/wow/addons/yibocurrency",
    },
    {
        name = "YiboLegendary",
        title = "传说之路",
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1",
        description = "传说物品收集进度。",
        projectURL = "https://www.curseforge.com/wow/addons/yibo-legendary",
    },
    {
        name = "YiboQuestBlocker",
        title = "任务阻断",
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YQB_MinimapIcon",
        description = "任务前置条件与阻断原因。",
        projectURL = "https://www.curseforge.com/wow/addons/yibo-quest-blocker",
    },
    {
        name = "YiboTodo",
        title = "账号待办",
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboTodo\\Media\\YiboTodoIcon-v6",
        description = "账号待办事项。",
        projectURL = "https://www.curseforge.com/wow/addons/yibotodo",
    },
    {
        name = "YiboReputation",
        title = "声望之路",
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon-v1",
        description = "跨角色声望进度。",
        projectURL = "https://www.curseforge.com/wow/addons/yibo-reputation",
    },
    {
        name = "YiboAutoOpen",
        title = "自动开包",
        relation = "optional-core",
        icon = "Interface\\AddOns\\YiboAutoOpen\\Media\\YiboAutoOpenIcon-v2",
        description = "安全地自动开启账号目录中的容器物品。",
        projectURL = "https://www.curseforge.com/wow/addons/yiboautoopen",
    },
    {
        name = "YiboBeastPaths",
        title = beastPathsTitle,
        relation = "optional-core",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YBP_AddonIcon",
        description = "潘达利亚隐藏猎人宠物路线图。",
        projectURL = "https://www.curseforge.com/wow/addons/yibo-beastpaths",
    },
    {
        name = "YiboMounts",
        title = "坐骑图鉴",
        relation = "optional-core",
        icon = "Interface\\AddOns\\YiboMounts\\Media\\YiboMountsIcon-v1",
        description = "在光环、聊天链接与坐骑面板提示中显示坐骑获取来源。",
        projectURL = "https://www.curseforge.com/wow/addons/yibomounts",
    },
}

Core.Capabilities:Register("addon-catalog", 1)
