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
    icon = "Interface\\Icons\\INV_Misc_Food_18.blp",
}

Catalog.dailyActivities["mop.halfhill.cooking-daily"] = {
    id = "mop.halfhill.cooking-daily",
    label = "半山烹饪日常",
    provider = "daily-quest",
    scope = "character",
    defaultMode = "display",
    scheduleKind = "daily-07",
    resetHour = 7,
    completionMode = "any-member-completes-group",
    verificationStatus = "external-queried",
    members = {
        { questID = 30386 }, { questID = 30402 }, { questID = 30408 },
        { questID = 30414 }, { questID = 30421 }, { questID = 30427 },
    },
    icon = "Interface\\Icons\\Trade_Cooking",
}
