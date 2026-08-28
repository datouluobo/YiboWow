local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

-- This is deliberately a baseline, not shipped active business data.  IDs and
-- cooldown semantics must be captured by /ytd probe on the target 5.5.4 build
-- before an entry may become verified and active.
local candidates = {
    {
        id = "mop.engineering.jards-energy-source", professionID = 202, recipeSpellID = 139176, resultItemID = 94113,
        cooldownGroupID = "mop.engineering.jards-energy-source", label = "贾德的特制能量源",
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "live-observation:2026-08-29",
        active = true,
    },
    {
        id = "mop.blacksmithing.lightning-steel-ingot", professionID = 164, recipeSpellID = 138646, resultItemID = 94111,
        cooldownGroupID = "mop.blacksmithing.lightning-steel-ingot", label = "霹雳钢锭",
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "live-observation:2026-08-29", active = true,
    },
    {
        id = "mop.blacksmithing.balanced-trillium-ingot", professionID = 164, recipeSpellID = 143255, resultItemID = 98717,
        cooldownGroupID = "mop.blacksmithing.balanced-trillium-ingot", label = "两仪延极锭",
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "live-observation:2026-08-29", active = true,
    },
    { id = "mop.alchemy.living-steel", professionID = 171, recipeSpellID = 114780, resultItemID = 72104, cooldownGroupID = "mop.alchemy.transmute", label = "活化钢", verificationStatus = "candidate" },
    { id = "mop.tailoring.imperial-silk", professionID = 197, recipeSpellID = 125557, resultItemID = 82441, cooldownGroupID = "mop.tailoring.imperial-silk", label = "帝王丝绸", verificationStatus = "candidate" },
}

for _, recipe in ipairs(candidates) do
    recipe.introducedIn = "5.x"
    if recipe.active == nil then recipe.active = false end
    if recipe.verificationStatus ~= "verified" then recipe.verifiedBuild, recipe.evidence = nil, nil end
    Catalog.recipes[recipe.id] = recipe
end
