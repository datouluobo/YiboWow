local Addon = _G.YiboLegendary
local Catalog = {}
Addon.Catalog = Catalog

Catalog.targets = {
    {
        id = "CLOAK",
        sortOrder = 100,
        title = "传说披风",
        shortTitle = "橙披",
        expansion = "MOP",
        expansionLabel = "熊猫人之谜",
        routeKind = "questline",
        routeLabel = "长任务链",
        availability = "obtainable",
        routeDescription = "黑王子任务线：五个章节、并行目标与最终披风。",
        iconItemId = 102249,
        completionQuestId = 33105,
        -- 现有橙披定义仍保留在 Data.lua，以保持已发布 SavedVariables 与
        -- 任务日志兼容回退的稳定性；目录只引用其稳定的节点定义。
        nodes = Addon.Data.definitions,
    },
    {
        id = "THUNDERFURY",
        sortOrder = 10,
        title = "雷霆之怒，逐风者的祝福之剑",
        shortTitle = "风剑",
        expansion = "CLASSIC",
        expansionLabel = "经典旧世",
        routeKind = "collection",
        routeLabel = "掉落／收集链",
        availability = "obtainable",
        routeDescription = "两个逐风者禁锢之颅、元素锭与桑德兰的最终事件。",
        iconItemId = 19019,
        finalItemIds = { 19019 },
        finalItemId = 19019,
        eligibility = { excludedClasses = { PRIEST = true, SHAMAN = true, DRUID = true } },
        nodes = {
            { id = "BINDING_LEFT", title = "逐风者禁锢之颅（左）", kind = "bossDrop", itemId = 18563, boss = "加尔（熔火之心）", parallelGroup = "BINDINGS", requires = {} },
            { id = "BINDING_RIGHT", title = "逐风者禁锢之颅（右）", kind = "bossDrop", itemId = 18564, boss = "迦顿男爵（熔火之心）", parallelGroup = "BINDINGS", requires = {} },
            { id = "ELEMENTIUM", title = "元素锭", kind = "itemCount", itemId = 18562, current = 0, target = 10, sourceZone = "黑翼之巢", requires = { "BINDING_LEFT", "BINDING_RIGHT" } },
            { id = "THUNDERAAN", title = "逐风者桑德兰", kind = "event", boss = "桑德兰王子（希利苏斯）", requires = { "BINDING_LEFT", "BINDING_RIGHT", "ELEMENTIUM" } },
        },
    },
    {
        id = "SORIDAL",
        sortOrder = 40,
        title = "索利达尔，群星之怒",
        shortTitle = "索利达尔",
        expansion = "TBC",
        expansionLabel = "燃烧的远征",
        routeKind = "directDrop",
        routeLabel = "直接掉落",
        availability = "obtainable",
        routeDescription = "太阳之井高地基尔加丹直接掉落；历史获得可使用人工证据确认。",
        iconItemId = 34334,
        finalItemIds = { 34334 },
        finalItemId = 34334,
        manualEvidenceAllowed = true,
        eligibility = { allowedClasses = { HUNTER = true, WARRIOR = true, ROGUE = true } },
        nodes = {
            { id = "SORIDAL_DROP", title = "基尔加丹掉落", kind = "bossDrop", itemId = 34334, boss = "基尔加丹（太阳之井高地）", evidenceAllowed = true },
            { id = "SORIDAL_ITEM", title = "索利达尔，群星之怒", kind = "finalItem", itemId = 34334, evidenceAllowed = true },
        },
    },
    -- 目录占位：先接入稳定图标和目标元数据，用于验证未来目标数量增长
    -- 时的图标栏布局；未接入采集器前不得生成角色进度。
    {
        id = "SULFURAS", title = "萨弗拉斯，炎魔拉格纳罗斯之手", shortTitle = "萨弗拉斯",
        sortOrder = 20,
        expansion = "CLASSIC", expansionLabel = "经典旧世", routeKind = "collection", routeLabel = "后续接入",
        availability = "catalog", catalogOnly = true, iconItemId = 17182,
        routeDescription = "目录占位：制作与拉格纳罗斯掉落路线尚未接入。", nodes = {},
    },
    {
        id = "ATIESH", title = "埃提耶什，守护者的传说之杖", shortTitle = "埃提耶什",
        sortOrder = 30,
        expansion = "CLASSIC", expansionLabel = "经典旧世", routeKind = "collection", routeLabel = "后续接入",
        availability = "unavailable", archived = true, catalogOnly = true, iconItemId = 22589,
        routeDescription = "目录占位：职业分支与碎片收集路线尚未接入。", nodes = {},
    },
    {
        id = "BLACK_QIRAJI_TANK", title = "黑色其拉作战坦克", shortTitle = "黑虫子",
        sortOrder = 25,
        expansion = "CLASSIC", expansionLabel = "经典旧世", routeKind = "special", routeLabel = "历史收藏",
        availability = "unavailable", archived = true, catalogOnly = true, iconItemId = 21176,
        routeDescription = "目录占位：特殊绝版收藏证据尚未接入。", nodes = {},
    },
    {
        id = "WARGLAIVES", title = "埃辛诺斯战刃", shortTitle = "蛋刀",
        sortOrder = 50,
        expansion = "TBC", expansionLabel = "燃烧的远征", routeKind = "directDrop", routeLabel = "后续接入",
        availability = "catalog", catalogOnly = true, iconItemId = 32837,
        routeDescription = "目录占位：伊利丹直接掉落与双刃判定尚未接入。", nodes = {},
    },
    {
        id = "VALANYR", title = "瓦兰奈尔，远古王者之锤", shortTitle = "瓦兰奈尔",
        sortOrder = 60,
        expansion = "WLK", expansionLabel = "巫妖王之怒", routeKind = "collection", routeLabel = "后续接入",
        availability = "catalog", catalogOnly = true, iconItemId = 46017,
        routeDescription = "目录占位：碎片收集与职业限制尚未接入。", nodes = {},
    },
    {
        id = "SHADOWMOURNE", title = "影之哀伤", shortTitle = "影之哀伤",
        sortOrder = 70,
        expansion = "WLK", expansionLabel = "巫妖王之怒", routeKind = "questline", routeLabel = "后续接入",
        availability = "catalog", catalogOnly = true, iconItemId = 49623,
        routeDescription = "目录占位：任务链、材料和职业限制尚未接入。", nodes = {},
    },
    {
        id = "DRAGONWRATH", title = "巨龙之怒，塔雷克苟萨的寄魂杖", shortTitle = "巨龙之怒",
        sortOrder = 80,
        expansion = "CATACLYSM", expansionLabel = "大地的裂变", routeKind = "collection", routeLabel = "后续接入",
        availability = "catalog", catalogOnly = true, iconItemId = 71086,
        routeDescription = "目录占位：巨龙之怒任务与熔火精华收集尚未接入。", nodes = {},
    },
    {
        id = "FANGS", title = "龙父之牙", shortTitle = "龙父之牙",
        sortOrder = 90,
        expansion = "CATACLYSM", expansionLabel = "大地的裂变", routeKind = "questline", routeLabel = "后续接入",
        availability = "catalog", catalogOnly = true, iconItemId = 77949,
        routeDescription = "目录占位：潜行者任务链与双匕首判定尚未接入。", nodes = {},
    },
}

table.sort(Catalog.targets, function(left, right)
    local leftOrder, rightOrder = tonumber(left.sortOrder) or 0, tonumber(right.sortOrder) or 0
    if leftOrder == rightOrder then return left.id < right.id end
    return leftOrder > rightOrder
end)

Catalog.byID = {}
for _, target in ipairs(Catalog.targets) do Catalog.byID[target.id] = target end

function Catalog:GetTargets()
    return self.targets
end

function Catalog:GetActiveTargets()
    local result = {}
    for _, target in ipairs(self.targets) do
        if not target.archived then result[#result + 1] = target end
    end
    return result
end

function Catalog:GetArchivedTargets()
    local result = {}
    for _, target in ipairs(self.targets) do
        if target.archived then result[#result + 1] = target end
    end
    return result
end

function Catalog:GetTarget(id)
    return self.byID[id]
end
