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
    ["nat-pagle"] = { id = "nat-pagle", label = "纳特·帕格", order = 70, memberKind = "special-activity", members = { "mop.nat-pagle.flying-tiger-gourami", "mop.nat-pagle.spinefish-alpha", "mop.nat-pagle.mimic-octopus" } },
    ["darkmoon-faire"] = { id = "darkmoon-faire", label = "暗月马戏团", order = 80, memberKind = "special-activity", members = { "mop.darkmoon-faire.29506", "mop.darkmoon-faire.29507", "mop.darkmoon-faire.29508", "mop.darkmoon-faire.29509", "mop.darkmoon-faire.29510", "mop.darkmoon-faire.29511", "mop.darkmoon-faire.29512", "mop.darkmoon-faire.29513", "mop.darkmoon-faire.29514", "mop.darkmoon-faire.29515", "mop.darkmoon-faire.29516", "mop.darkmoon-faire.29517", "mop.darkmoon-faire.29518", "mop.darkmoon-faire.29519", "mop.darkmoon-faire.29520" } },
    ["brilltron-4000"] = { id = "brilltron-4000", label = "布林顿 4000", order = 90, memberKind = "special-activity", members = { "mop.brilltron-4000" } },
}
