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
    { id = "mop.engineering.jards-energy-source", activityID = "profession.cooldown.mop.engineering.jards-energy-source", professionID = 202, aggregation = "shared-cooldown", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "贾德的特制能量源", order = 10, active = true },
    { id = "mop.blacksmithing.lightning-steel-ingot", activityID = "profession.cooldown.mop.blacksmithing.lightning-steel-ingot", professionID = 164, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "霹雳钢锭", order = 20, active = true },
    { id = "mop.blacksmithing.balanced-trillium-ingot", activityID = "profession.cooldown.mop.blacksmithing.balanced-trillium-ingot", professionID = 164, aggregation = "single-recipe", resetPolicyID = "daily-07", resetKind = "daily-07", resetHour = 7, defaultMode = "required", label = "两仪延极锭", order = 21, active = true },
    { id = "mop.alchemy.transmute", activityID = "profession.cooldown.mop.alchemy.transmute", professionID = 171, aggregation = "shared-cooldown", resetPolicyID = "api-reported", defaultMode = "required", label = "炼金转化", order = 10, active = false },
    { id = "mop.tailoring.imperial-silk", activityID = "profession.cooldown.mop.tailoring.imperial-silk", professionID = 197, aggregation = "shared-cooldown", resetPolicyID = "api-reported", defaultMode = "required", label = "帝王丝绸", order = 20, active = false },
}
for _, group in ipairs(groups) do Catalog:RegisterGroup(group) end
