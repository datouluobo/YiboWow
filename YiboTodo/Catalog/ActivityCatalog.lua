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
    { id = "profession.cooldown.mop.engineering.jards-energy-source", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "any-member-starts-group", groupPath = { "profession", "mop", "202", "mop.engineering.jards-energy-source" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.blacksmithing.lightning-steel-ingot", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "164", "mop.blacksmithing.lightning-steel-ingot" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.blacksmithing.balanced-trillium-ingot", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "164", "mop.blacksmithing.balanced-trillium-ingot" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.alchemy.living-steel", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "171", "mop.alchemy.living-steel" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.tailoring.imperial-silk", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "197", "mop.tailoring.imperial-silk" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.tailoring.celestial-cloth", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "197", "mop.tailoring.celestial-cloth" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.enchanting.sha-crystal", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "333", "mop.enchanting.sha-crystal" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.inscription.scroll-of-wisdom", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "773", "mop.inscription.scroll-of-wisdom" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.jewelcrafting.blue-gem-research", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "any-member-starts-group", groupPath = { "profession", "mop", "755", "mop.jewelcrafting.blue-gem-research" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.jewelcrafting.serpents-heart", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "755", "mop.jewelcrafting.serpents-heart" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.leatherworking.magnificent-fur", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "165", "mop.leatherworking.magnificent-fur" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.mop.leatherworking.enhanced-magnificent-fur", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "mop", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "mop", "165", "mop.leatherworking.enhanced-magnificent-fur" }, defaultMode = "required", active = true },
    { id = "profession.cooldown.wlk.inscription.minor-research", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "wlk", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "wlk", "773", "wlk.inscription.minor-research" }, defaultMode = "display", active = true },
    { id = "profession.cooldown.wlk.inscription.northrend-research", kind = "profession-cooldown", provider = "profession-cooldown", scope = "character", sourceExpansion = "wlk", scheduleKind = "daily-07", completionMode = "single", groupPath = { "profession", "wlk", "773", "wlk.inscription.northrend-research" }, defaultMode = "display", active = true },
}) do Catalog:RegisterActivity(activity) end
