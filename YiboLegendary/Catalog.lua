local Addon = _G.YiboLegendary
local Catalog = {}
Addon.Catalog = Catalog

Catalog.targets = {
    {
        id = "CLOAK",
        title = "传说披风",
        shortTitle = "橙披",
        expansion = "MOP",
        expansionLabel = "熊猫人之谜",
        routeKind = "questline",
        routeLabel = "长任务链",
        availability = "obtainable",
        routeDescription = "黑王子任务线：五个章节、并行目标与最终披风。",
        completionQuestId = 33105,
        -- 现有橙披定义仍保留在 Data.lua，以保持已发布 SavedVariables 与
        -- 任务日志兼容回退的稳定性；目录只引用其稳定的节点定义。
        nodes = Addon.Data.definitions,
    },
    {
        id = "THUNDERFURY",
        title = "雷霆之怒，逐风者的祝福之剑",
        shortTitle = "风剑",
        expansion = "CLASSIC",
        expansionLabel = "经典旧世",
        routeKind = "collection",
        routeLabel = "掉落／收集链",
        availability = "obtainable",
        routeDescription = "两个逐风者禁锢之颅、元素锭与桑德兰的最终事件。",
        finalItemId = 19019,
        eligibility = { excludedClasses = { PRIEST = true, SHAMAN = true, DRUID = true } },
        nodes = {
            { id = "BINDING_LEFT", title = "逐风者禁锢之颅（左）", kind = "bossDrop", itemId = 18563, boss = "加尔（熔火之心）" },
            { id = "BINDING_RIGHT", title = "逐风者禁锢之颅（右）", kind = "bossDrop", itemId = 18564, boss = "迦顿男爵（熔火之心）" },
            { id = "ELEMENTIUM", title = "元素锭", kind = "itemCount", itemId = 18562, target = 10, boss = "黑翼之巢" },
            { id = "THUNDERAAN", title = "逐风者桑德兰", kind = "event", boss = "希利苏斯" },
        },
    },
}

Catalog.byID = {}
for _, target in ipairs(Catalog.targets) do Catalog.byID[target.id] = target end

function Catalog:GetTargets()
    return self.targets
end

function Catalog:GetTarget(id)
    return self.byID[id]
end
