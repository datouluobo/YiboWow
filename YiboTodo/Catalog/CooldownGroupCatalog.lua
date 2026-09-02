local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

function Catalog:RegisterGroup(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string" then return nil, "invalid-group" end
    if Catalog.groups[definition.id] then return nil, "duplicate-group:" .. definition.id end
    Catalog.groups[definition.id] = definition
    return definition
end

function Catalog:GetGroup(id) return Catalog.groups[id] end

local groups = {
    { id = "mop.engineering.jards-energy-source", activityID = "profession.cooldown.mop.engineering.jards-energy-source", professionID = 202, requiredSkillLevel = 600, aggregation = "shared-cooldown", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "贾德的特制能量源", order = 10, active = true },
    { id = "mop.blacksmithing.lightning-steel-ingot", activityID = "profession.cooldown.mop.blacksmithing.lightning-steel-ingot", professionID = 164, requiredSkillLevel = 600, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "霹雳钢锭", order = 20, active = true },
    { id = "mop.blacksmithing.balanced-trillium-ingot", activityID = "profession.cooldown.mop.blacksmithing.balanced-trillium-ingot", professionID = 164, requiredSkillLevel = 600, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "两仪延极锭", order = 21, active = true },
    { id = "mop.alchemy.living-steel", activityID = "profession.cooldown.mop.alchemy.living-steel", professionID = 171, requiredSkillLevel = 600, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "活化钢", order = 10, active = true },
    { id = "mop.tailoring.imperial-silk", activityID = "profession.cooldown.mop.tailoring.imperial-silk", professionID = 197, requiredSkillLevel = 550, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "帝王丝绸", order = 10, active = true },
    { id = "mop.tailoring.celestial-cloth", activityID = "profession.cooldown.mop.tailoring.celestial-cloth", professionID = 197, requiredSkillLevel = 600, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "神纹布", order = 20, active = true },
    { id = "mop.enchanting.sha-crystal", activityID = "profession.cooldown.mop.enchanting.sha-crystal", professionID = 333, requiredSkillLevel = 600, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "邪煞水晶", order = 10, active = true },
    { id = "mop.inscription.scroll-of-wisdom", activityID = "profession.cooldown.mop.inscription.scroll-of-wisdom", professionID = 773, requiredSkillLevel = 540, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "智慧卷轴", order = 10, active = true },
    { id = "mop.jewelcrafting.blue-gem-research", activityID = "profession.cooldown.mop.jewelcrafting.blue-gem-research", professionID = 755, requiredSkillLevel = 525, aggregation = "shared-cooldown", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "潘达利亚蓝宝石研究", order = 10, active = true },
    { id = "mop.jewelcrafting.serpents-heart", activityID = "profession.cooldown.mop.jewelcrafting.serpents-heart", professionID = 755, requiredSkillLevel = 500, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "神龙之心", order = 20, active = true },
    { id = "mop.leatherworking.magnificent-fur", activityID = "profession.cooldown.mop.leatherworking.magnificent-fur", professionID = 165, requiredSkillLevel = 600, aggregation = "shared-cooldown", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "华丽毛皮", order = 10, active = true },
    { id = "mop.leatherworking.enhanced-magnificent-fur", activityID = "profession.cooldown.mop.leatherworking.enhanced-magnificent-fur", professionID = 165, requiredSkillLevel = 600, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "强化华丽毛皮", order = 20, active = true },
    { id = "wlk.inscription.minor-research", activityID = "profession.cooldown.wlk.inscription.minor-research", professionID = 773, requiredSkillLevel = 1, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "display", label = "小型铭文研究", order = 30, active = true },
    { id = "wlk.inscription.northrend-research", activityID = "profession.cooldown.wlk.inscription.northrend-research", professionID = 773, requiredSkillLevel = 400, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "display", label = "诺森德铭文研究", order = 31, active = true },
}
for _, group in ipairs(groups) do Catalog:RegisterGroup(group) end
