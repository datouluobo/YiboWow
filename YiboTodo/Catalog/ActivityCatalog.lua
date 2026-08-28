local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

function Catalog:RegisterActivity(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string" then return nil, "invalid-activity" end
    if Catalog.activities[definition.id] then return nil, "duplicate-activity:" .. definition.id end
    Catalog.activities[definition.id] = definition
    return definition
end

function Catalog:GetActivity(id) return Catalog.activities[id] end

for _, activity in ipairs({
    { id = "profession.cooldown.mop.engineering.jards-energy-source", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "api-reported", completionMode = "any-member-starts-group", groupPath = { "profession", "mop", "202", "mop.engineering.jards-energy-source" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.blacksmithing.lightning-steel-ingot", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "api-reported", completionMode = "single", groupPath = { "profession", "mop", "164", "mop.blacksmithing.lightning-steel-ingot" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.blacksmithing.balanced-trillium-ingot", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "api-reported", completionMode = "single", groupPath = { "profession", "mop", "164", "mop.blacksmithing.balanced-trillium-ingot" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.alchemy.transmute", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "api-reported", completionMode = "any-member-starts-group", groupPath = { "profession", "mop", "171", "mop.alchemy.transmute" }, defaultMode = "required", active = false },
    { id = "profession.cooldown.mop.tailoring.imperial-silk", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "api-reported", completionMode = "any-member-starts-group", groupPath = { "profession", "mop", "197", "mop.tailoring.imperial-silk" }, defaultMode = "required", active = false },
}) do Catalog:RegisterActivity(activity) end
