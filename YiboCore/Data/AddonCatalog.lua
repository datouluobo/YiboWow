local Core = _G.YiboCore

-- Static presentation metadata only.  Versions deliberately live in the
-- generated packaging manifest and in the player's installed TOCs.
Core.AddonCatalog = {
    {
        name = "YiboAltoBoss",
        title = "Boss 周常",
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YAB_MinimapIcon",
        description = "跨角色首领与周常进度。",
        projectURL = "https://www.curseforge.com/wow/addons/yibo-altoboss",
    },
    {
        name = "YiboCurrency",
        title = "货币管家",
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon-v1",
        description = "跨角色货币追踪。",
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
        description = "账号待办事项。",
        projectURL = "https://www.curseforge.com/wow/addons/yibotodo",
    },
    {
        name = "YiboReputation",
        title = "声望之路",
        relation = "core-child",
        description = "跨角色声望进度。",
        projectURL = "https://www.curseforge.com/wow/addons/yibo-reputation",
    },
    {
        name = "YiboBeastPaths",
        title = "猎人宠物路线图",
        relation = "independent",
        description = "潘达利亚隐藏猎人宠物路线图。",
        projectURL = "https://www.curseforge.com/wow/addons/yibo-beastpaths",
    },
}

Core.Capabilities:Register("addon-catalog", 1)
