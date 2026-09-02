local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

-- A monitoring group is a user-visible business choice and exactly one
-- account-matrix column.  Members are resolved from the existing activity and
-- cooldown catalogs so a future verified item can inherit its parent group.
Catalog.monitoringGroups = {
    ["profession-cooldown"] = { id = "profession-cooldown", label = "商业冷却", order = 10, memberKind = "cooldown-group" },
    farm = { id = "farm", label = "农场", order = 20, memberKind = "farm-operation", members = { "mop.farm.operation-observed" } },
    nomi = { id = "nomi", label = "诺米", order = 30, memberKind = "daily-activity", members = { "mop.nomi" } },
    ["jewelcrafting-daily"] = { id = "jewelcrafting-daily", label = "珠宝日常", order = 40, memberKind = "daily-activity", members = { "wlk.jewelcrafting-daily", "ctm.jewelcrafting-daily" } },
    ["cooking-daily"] = { id = "cooking-daily", label = "烹饪日常", order = 50, memberKind = "daily-activity", members = { "ctm.cooking-daily", "mop.halfhill.cooking-daily", "tbc.cooking-daily", "wlk.cooking-daily" } },
    ["fishing-daily"] = { id = "fishing-daily", label = "钓鱼日常", order = 60, memberKind = "daily-activity", members = { "ctm.fishing-daily", "tbc.fishing-daily", "wlk.fishing-daily" } },
}
