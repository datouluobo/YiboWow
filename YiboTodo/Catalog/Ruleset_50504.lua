local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

Catalog.rulesets[Addon.RULESET_ID] = {
    id = Addon.RULESET_ID,
    interface = 50504,
    supportedProvider = "profession-cooldown",
    activeGroups = {
        ["mop.engineering.jards-energy-source"] = true,
        ["mop.blacksmithing.lightning-steel-ingot"] = true,
        ["mop.blacksmithing.balanced-trillium-ingot"] = true,
    },
}
