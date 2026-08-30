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
        ["mop.alchemy.living-steel"] = true,
        ["mop.tailoring.imperial-silk"] = true,
        ["mop.tailoring.celestial-cloth"] = true,
        ["mop.enchanting.sha-crystal"] = true,
        ["mop.inscription.scroll-of-wisdom"] = true,
        ["mop.jewelcrafting.blue-gem-research"] = true,
        ["mop.jewelcrafting.serpents-heart"] = true,
        ["mop.leatherworking.magnificent-fur"] = true,
        ["mop.leatherworking.enhanced-magnificent-fur"] = true,
    },
}
