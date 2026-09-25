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
    {
        id = "SULFURAS", title = "萨弗拉斯，炎魔拉格纳罗斯之手", shortTitle = "萨弗拉斯",
        sortOrder = 20,
        expansion = "CLASSIC", expansionLabel = "经典旧世", routeKind = "collection", routeLabel = "制作／掉落链",
        availability = "obtainable", iconItemId = 17182, finalItemIds = { 17182 }, finalItemId = 17182,
        eligibility = { allowedClasses = { WARRIOR = true, PALADIN = true, DEATHKNIGHT = true } },
        routeDescription = "熔火之心取得萨弗拉斯之眼，再与萨弗隆铁锤合成。",
        nodes = {
            { id = "SULFURAS_EYE", title = "萨弗拉斯之眼", kind = "bossDrop", itemId = 17204, boss = "拉格纳罗斯（熔火之心）" },
            { id = "SULFURON_HAMMER", title = "萨弗隆铁锤", kind = "craftedItem", itemId = 17193, sourceZone = "黑石深渊／熔火之心" },
            { id = "SULFURAS_ITEM", title = "萨弗拉斯，炎魔拉格纳罗斯之手", kind = "finalItem", itemId = 17182 },
        },
    },
    {
        id = "ATIESH", title = "埃提耶什，守护者的传说之杖", shortTitle = "埃提耶什",
        sortOrder = 30,
        expansion = "CLASSIC", expansionLabel = "经典旧世", routeKind = "collection", routeLabel = "后续接入",
        availability = "unavailable", archived = true, catalogOnly = true, iconItemId = 22589,
        finalItemIds = { 22589, 22630, 22631, 22632 },
        eligibility = { allowedClasses = { MAGE = true, WARLOCK = true, PRIEST = true, DRUID = true } },
        routeDescription = "目录占位：职业分支与碎片收集路线尚未接入。", nodes = {
            { id = "ATIESH_SPLINTERS", title = "埃提耶什碎片", kind = "itemCount", itemId = 22726, target = 40 },
            { id = "ATIESH_FRAME", title = "埃提耶什之杖框架", kind = "item", itemId = 22727 },
        },
    },
    {
        id = "BLACK_QIRAJI_TANK", title = "黑色其拉作战坦克", shortTitle = "黑虫子",
        sortOrder = 25,
        expansion = "CLASSIC", expansionLabel = "经典旧世", routeKind = "special", routeLabel = "历史收藏",
        availability = "unavailable", archived = true, catalogOnly = true, iconItemId = 21176,
        finalItemIds = { 21176 }, finalItemId = 21176,
        routeDescription = "目录占位：特殊绝版收藏证据尚未接入。", nodes = {},
    },
    {
        id = "WARGLAIVES", title = "埃辛诺斯战刃", shortTitle = "蛋刀",
        sortOrder = 50,
        expansion = "TBC", expansionLabel = "燃烧的远征", routeKind = "collection", routeLabel = "双刃掉落",
        availability = "obtainable", iconItemId = 32837, finalItemIds = { 32837, 32838 },
        eligibility = { allowedClasses = { WARRIOR = true, ROGUE = true } },
        routeDescription = "黑暗神殿伊利丹分别掉落左右两把战刃。",
        nodes = {
            { id = "WARGLAIVE_MAIN", title = "埃辛诺斯战刃（主手）", kind = "bossDrop", itemId = 32837, boss = "伊利丹·怒风（黑暗神殿）", parallelGroup = "WARGLAIVES" },
            { id = "WARGLAIVE_OFF", title = "埃辛诺斯战刃（副手）", kind = "bossDrop", itemId = 32838, boss = "伊利丹·怒风（黑暗神殿）", parallelGroup = "WARGLAIVES" },
        },
    },
    {
        id = "VALANYR", title = "瓦兰奈尔，远古王者之锤", shortTitle = "瓦兰奈尔",
        sortOrder = 60,
        expansion = "WLK", expansionLabel = "巫妖王之怒", routeKind = "collection", routeLabel = "碎片收集",
        availability = "obtainable", iconItemId = 46017, finalItemIds = { 46017 },
        eligibility = { allowedClasses = { PALADIN = true, PRIEST = true, SHAMAN = true, DRUID = true } },
        routeDescription = "奥杜尔收集 30 个 Val'anyr 碎片并完成最终任务。",
        nodes = {
            { id = "VALANYR_FRAGMENTS", title = "Val'anyr 碎片", kind = "itemCount", itemId = 45038, target = 30, sourceZone = "奥杜尔" },
            { id = "VALANYR_UNBOUND", title = "未束缚的 Val'anyr 碎片", kind = "item", itemId = 45896, sourceZone = "奥杜尔" },
            { id = "VALANYR_ITEM", title = "瓦兰奈尔，远古王者之锤", kind = "finalItem", itemId = 46017, sourceZone = "奥杜尔" },
        },
    },
    {
        id = "SHADOWMOURNE", title = "影之哀伤", shortTitle = "影之哀伤",
        sortOrder = 70,
        expansion = "WLK", expansionLabel = "巫妖王之怒", routeKind = "questline", routeLabel = "任务／收集链",
        availability = "obtainable", iconItemId = 49623, finalItemIds = { 49623 },
        eligibility = { allowedClasses = { WARRIOR = true, PALADIN = true, DEATHKNIGHT = true } },
        routeDescription = "冰冠堡垒任务链、血魄／冰霜／邪恶灌注与 50 个影锋碎片。",
        nodes = {
            { id = "SHADOWS_EDGE", title = "影之锋", kind = "intermediateItem", itemId = 49888, sourceZone = "冰冠堡垒" },
            { id = "SHADOWFROST_SHARDS", title = "影霜碎片", kind = "itemCount", itemId = 50274, target = 50, sourceZone = "冰冠堡垒" },
            { id = "SHADOWMOURNE_ITEM", title = "影之哀伤", kind = "finalItem", itemId = 49623, sourceZone = "冰冠堡垒" },
        },
    },
    {
        id = "DRAGONWRATH", title = "巨龙之怒，塔雷克苟萨的寄魂杖", shortTitle = "巨龙之怒",
        sortOrder = 80,
        expansion = "CATACLYSM", expansionLabel = "大地的裂变", routeKind = "collection", routeLabel = "任务／收集链",
        availability = "obtainable", iconItemId = 71086, finalItemIds = { 71086 },
        eligibility = { allowedClasses = { MAGE = true, PRIEST = true, SHAMAN = true, WARLOCK = true, DRUID = true } },
        routeDescription = "火焰之地任务线与熔火前线收集，最终获得巨龙之怒。",
        nodes = {
            { id = "DRAGONWRATH_EMBERS", title = "永恒余烬", kind = "itemCount", itemId = 43314, target = 25, sourceZone = "火焰之地" },
            { id = "DRAGONWRATH_BRANCH", title = "诺达希尔的分枝", kind = "intermediateItem", itemId = 69646, sourceZone = "火焰之地" },
            { id = "DRAGONWRATH_CINDERS", title = "阴燃之灰", kind = "itemCount", itemId = 69815, target = 1000, sourceZone = "火焰之地" },
            { id = "DRAGONWRATH_RUNESTAFF", title = "诺达希尔符文法杖", kind = "intermediateItem", itemId = 71085, sourceZone = "火焰之地" },
            { id = "DRAGONWRATH_ITEM", title = "巨龙之怒，塔雷克苟萨的寄魂杖", kind = "finalItem", itemId = 71086, sourceZone = "火焰之地" },
        },
    },
    {
        id = "FANGS", title = "龙父之牙", shortTitle = "龙父之牙",
        sortOrder = 90,
        expansion = "CATACLYSM", expansionLabel = "大地的裂变", routeKind = "questline", routeLabel = "潜行者任务链",
        availability = "obtainable", iconItemId = 77949, finalItemIds = { 77949, 77950 }, finalItemsRequired = 2,
        eligibility = { allowedClasses = { ROGUE = true } },
        routeDescription = "巨龙之魂潜行者专属任务链，最终获得龙父之牙双匕首。",
        nodes = {
            { id = "FANGS_DREAMER", title = "梦境", kind = "intermediateItem", itemId = 77948, sourceZone = "巨龙之魂" },
            { id = "FANGS_ITEM", title = "龙父之牙", kind = "finalItem", itemId = 77949, sourceZone = "巨龙之魂" },
        },
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
