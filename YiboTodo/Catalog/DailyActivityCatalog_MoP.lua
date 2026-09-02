local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

-- All quest IDs are deliberately centralized here.  The five lessons are
-- separate repeating dailies selected by Nomi's current friendship tier; they
-- are not a one-time five-step quest chain.  If a realm hotfix changes an ID,
-- this is the only table that needs correction.
Catalog.dailyActivities["mop.nomi"] = {
    id = "mop.nomi",
    label = "诺米",
    provider = "daily-quest",
    scope = "character",
    defaultMode = "display",
    scheduleKind = "daily-07",
    resetHour = 7,
    verificationStatus = "external-queried",
    stages = {
        { questID = 31332, label = "第1课：蜜桃片" },
        { questID = 31333, label = "第2课：方便面" },
        { questID = 31334, label = "第3课：烤鱼干" },
        { questID = 31335, label = "第4课：金针菇干" },
        { questID = 31336, label = "第5课：打糕" },
    },
    graduation = { questID = 31820, label = "诺米：谢师礼" },
    daily = { questID = 31337, label = "诺米每日：感谢的礼物" },
    -- Cooking School Bell, the stable visual identity for Nomi's lessons.
    icon = "Interface\\Icons\\INV_Misc_Food_18.blp",
    iconItemID = 86425,
}

Catalog.dailyActivities["mop.halfhill.cooking-daily"] = {
    id = "mop.halfhill.cooking-daily",
    label = "MOP 半山烹饪日常",
    provider = "daily-quest",
    scope = "character",
    defaultMode = "display",
    scheduleKind = "daily-07",
    resetHour = 7,
    completionMode = "any-member-completes-group",
    verificationStatus = "external-queried",
    order = 10,
    members = {
        -- These are the five Ironpaw Master Chef rotating dailies.  The
        -- previous IDs belonged to unrelated Tillers friendship quests, so
        -- QUEST_TURNED_IN never recognized e.g. The Mile-High Grub (30331).
        { questID = 30328, label = "千年饺", turnInNPCID = 58715 }, -- 严·铁掌
        { questID = 30329, label = "呛火辣椒", turnInNPCID = 58713 }, -- 安希亚·铁掌
        { questID = 30330, label = "松露蛋奶酥", turnInNPCID = 58716 }, -- 坚·铁掌
        { questID = 30331, label = "高地美味", turnInNPCID = 58714 }, -- 美美·铁掌
        { questID = 30332, label = "肥美的山羊肉排", turnInNPCID = 58712 }, -- 柯·铁掌
    },
    icon = "Interface\\Icons\\Trade_Cooking",
    iconCurrencyID = 402, -- 铁掌徽记 / Ironpaw Token
}
