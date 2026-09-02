local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

-- These old-world definitions are intentionally opt-in probes.  They are
-- shown in Todo settings, but not in a fresh account matrix until verified in
-- this client build and explicitly enabled by the player.
local function LegacyDaily(id, label, icon, members, order, professionID, defaultEnabled, verificationStatus, evidence)
    Catalog.dailyActivities[id] = {
        id = id, label = label, provider = "daily-quest", scope = "character",
        scheduleKind = "daily-07", resetHour = 7,
        completionMode = "any-member-completes-group",
        verificationStatus = verificationStatus or "needs-live-confirmation", icon = icon, members = members,
        order = order, professionID = professionID, defaultEnabled = defaultEnabled,
        evidence = evidence,
    }
end

LegacyDaily("tbc.cooking-daily", "TBC 沙塔斯烹饪日常", "Interface\\Icons\\INV_Misc_Food_15", {
    { questID = 11377, label = "超级美味烧烤" }, { questID = 11379, label = "魔法美味" },
    { questID = 11380, label = "热辣塔布羊排" }, { questID = 11381, label = "魔法晶球" },
}, 40, nil, true, "verified", "live-observation:2026-09-02")
LegacyDaily("tbc.fishing-daily", "TBC 沙塔斯钓鱼日常", "Interface\\Icons\\Trade_Fishing", {
    { questID = 11665, label = "城中的鳄鱼" }, { questID = 11666, label = "鱼饵小偷" },
    { questID = 11667, label = "逃脱的鱼" }, { questID = 11668, label = "巨型淡水虾" },
    { questID = 11669, label = "魔血鲷鱼" },
}, 40, nil, true, "verified", "live-observation:2026-09-02")
-- 35348 is the Bag of Fishing Treasures shown as this daily's reward.
Catalog.dailyActivities["tbc.fishing-daily"].iconItemID = 35348
LegacyDaily("wlk.cooking-daily", "WLK 达拉然烹饪日常", "Interface\\Icons\\INV_Misc_Food_65", {
    { questID = 13115, label = "格雷格的美酒" }, { questID = 13113, label = "魔法旅店的聚会" },
    { questID = 13112, label = "灌注蘑菇肉糕" }, { questID = 13107, label = "芥末热狗" },
    { questID = 13100, label = "下水道炖肉" },
}, 30, nil, true, "verified", "live-observation:2026-09-02")
Catalog.dailyActivities["wlk.cooking-daily"].iconItemID = 43016 -- 美食家奖章 / Dalaran Cooking Award
LegacyDaily("wlk.fishing-daily", "WLK 达拉然钓鱼日常", "Interface\\Icons\\INV_Fishingpole_02", {
    { questID = 13830, label = "幽灵鱼" }, { questID = 13832, label = "下水道的珍宝" },
    { questID = 13833, label = "鲜血浓于水" }, { questID = 13834, label = "危险的美味" },
    { questID = 13836, label = "解除武装！" },
}, 30, nil, true, "verified", "live-observation:2026-09-02")
-- 46007 is the blue Bag of Fishing Treasures reward shown by the daily.
Catalog.dailyActivities["wlk.fishing-daily"].iconItemID = 46007
LegacyDaily("wlk.jewelcrafting-daily", "WLK 达拉然珠宝日常", "Interface\\Icons\\INV_Misc_Gem_01", {
    { questID = 12958, label = "货运：血玉护符" }, { questID = 12962, label = "货运：明亮护甲遗物" },
    { questID = 12959, label = "货运：闪光象牙雕像" }, { questID = 12961, label = "货运：精巧骨质雕像" },
    { questID = 12963, label = "货运：变幻日光饰物" }, { questID = 12960, label = "货运：邪恶日光胸针" },
}, 30, 755, true, "verified", "live-observation:2026-09-02")
LegacyDaily("ctm.jewelcrafting-daily", "CTM 珠宝日常", "Interface\\Icons\\INV_Misc_Gem_Variety_01", {
    -- Alliance/Horde IDs differ.  The quest-log provider accepts either one
    -- and projects them as the same shared daily column.
    { questID = 25154, label = "给莉拉的礼物" }, { questID = 25160, label = "给莉拉的礼物" },
    { questID = 25156, label = "元素粘稠物" }, { questID = 25162, label = "元素粘稠物" },
    { questID = 25158, label = "尼伯！不！" }, { questID = 25164, label = "尼伯！不！" },
    { questID = 25155, label = "诡异的欧格塔尼亚斯" }, { questID = 25161, label = "诡异的欧格塔尼亚斯" },
    { questID = 25157, label = "最新潮流！" }, { questID = 25163, label = "最新潮流！" },
}, 20, 755, true, "verified", "live-observation:2026-09-02")

-- Cataclysm capital-city fishing has one shared daily completion per day.
-- Stormwind and Orgrimmar each rotate one of these five quest IDs.
LegacyDaily("ctm.fishing-daily", "CTM 主城钓鱼日常", "Interface\\Icons\\Trade_Fishing", {
    { questID = 26488, label = "CTM 暴风城钓鱼日常" }, { questID = 26420, label = "CTM 暴风城钓鱼日常" },
    { questID = 26414, label = "CTM 暴风城钓鱼日常" }, { questID = 26442, label = "CTM 暴风城钓鱼日常" },
    { questID = 26536, label = "CTM 暴风城钓鱼日常" }, { questID = 26588, label = "CTM 奥格瑞玛钓鱼日常" },
    { questID = 26572, label = "CTM 奥格瑞玛钓鱼日常" }, { questID = 26557, label = "CTM 奥格瑞玛钓鱼日常" },
    { questID = 26543, label = "CTM 奥格瑞玛钓鱼日常" }, { questID = 26556, label = "CTM 奥格瑞玛钓鱼日常" },
}, 20, nil, true, "verified", "live-observation:2026-09-02")
Catalog.dailyActivities["ctm.fishing-daily"].iconItemID = 67414 -- Bag of Shiny Things

-- Cataclysm capital-city cooking has one shared daily completion per day.
-- The currently verified Stormwind rotation and its Orgrimmar counterpart are
-- both included; other capital rotations remain outside this first probe set.
LegacyDaily("ctm.cooking-daily", "CTM 主城烹饪日常", "Interface\\Icons\\INV_Misc_Food_15", {
    { questID = 26190, label = "CTM 暴风城烹饪日常" }, { questID = 26177, label = "CTM 暴风城烹饪日常" },
    { questID = 26192, label = "CTM 暴风城烹饪日常" }, { questID = 26153, label = "CTM 暴风城烹饪日常" },
    { questID = 26183, label = "CTM 暴风城烹饪日常" }, { questID = 26227, label = "CTM 奥格瑞玛烹饪日常" },
    { questID = 26226, label = "CTM 奥格瑞玛烹饪日常" }, { questID = 26235, label = "CTM 奥格瑞玛烹饪日常" },
    { questID = 26220, label = "CTM 奥格瑞玛烹饪日常" }, { questID = 26233, label = "CTM 奥格瑞玛烹饪日常" },
}, 20, nil, true, "verified", "live-observation:2026-09-02")
Catalog.dailyActivities["ctm.cooking-daily"].iconCurrencyID = 81 -- Chef's Award
