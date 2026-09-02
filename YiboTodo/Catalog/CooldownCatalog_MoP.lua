local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

-- BASELINE.md is the authoritative data baseline. Entries with a known
-- spell ID are collectable now; entries still missing IDs remain visible as
-- unknown catalog items so the UI and settings do not silently omit a
-- maintainer-confirmed requirement.
local recipes = {
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
    {
        id = "mop.alchemy.living-steel", professionID = 171, recipeSpellID = 114780, resultItemID = 72104,
        cooldownGroupID = "mop.alchemy.living-steel", label = "活化钢", verificationStatus = "user-confirmed",
        evidence = "user-confirmed-baseline:2026-08-29", active = true,
    },
    {
        id = "mop.tailoring.imperial-silk", professionID = 197, recipeSpellID = 125557, resultItemID = 82447,
        cooldownGroupID = "mop.tailoring.imperial-silk", label = "帝王丝绸", verificationStatus = "user-confirmed",
        evidence = "user-confirmed-baseline:2026-08-29", active = true,
    },
    {
        id = "mop.tailoring.celestial-cloth", professionID = 197, recipeSpellID = 143011, resultItemID = 98619,
        cooldownGroupID = "mop.tailoring.celestial-cloth", label = "神纹布", verificationStatus = "verified",
        verifiedBuild = "5.5.4", evidence = "live-observation:2026-08-30", active = true,
    },
    {
        id = "mop.enchanting.sha-crystal", professionID = 333, recipeSpellID = 116499, resultItemID = 74248,
        cooldownGroupID = "mop.enchanting.sha-crystal", label = "邪煞水晶", verificationStatus = "user-confirmed",
        evidence = "user-confirmed-baseline:2026-08-29", active = true,
    },
    {
        id = "mop.inscription.scroll-of-wisdom", professionID = 773, recipeSpellID = 112996, resultItemID = 79731,
        cooldownGroupID = "mop.inscription.scroll-of-wisdom", label = "智慧卷轴", verificationStatus = "user-confirmed",
        evidence = "user-confirmed-baseline:2026-08-29", active = true,
    },
    {
        id = "mop.jewelcrafting.research-131593", professionID = 755, recipeSpellID = 131593,
        cooldownGroupID = "mop.jewelcrafting.blue-gem-research", label = "潘达利亚蓝宝石研究", order = 10,
        verificationStatus = "user-confirmed", evidence = "user-confirmed-baseline:2026-08-29", active = true,
    },
    {
        id = "mop.jewelcrafting.research-131688", professionID = 755, recipeSpellID = 131688,
        cooldownGroupID = "mop.jewelcrafting.blue-gem-research", label = "潘达利亚蓝宝石研究", order = 11,
        verificationStatus = "user-confirmed", evidence = "user-confirmed-baseline:2026-08-29", active = true,
    },
    {
        id = "mop.jewelcrafting.research-131691", professionID = 755, recipeSpellID = 131691,
        cooldownGroupID = "mop.jewelcrafting.blue-gem-research", label = "潘达利亚蓝宝石研究", order = 12,
        verificationStatus = "user-confirmed", evidence = "user-confirmed-baseline:2026-08-29", active = true,
    },
    {
        id = "mop.jewelcrafting.research-131695", professionID = 755, recipeSpellID = 131695,
        cooldownGroupID = "mop.jewelcrafting.blue-gem-research", label = "潘达利亚蓝宝石研究", order = 13,
        verificationStatus = "user-confirmed", evidence = "user-confirmed-baseline:2026-08-29", active = true,
    },
    {
        id = "mop.jewelcrafting.research-131686", professionID = 755, recipeSpellID = 131686,
        cooldownGroupID = "mop.jewelcrafting.blue-gem-research", label = "潘达利亚蓝宝石研究", order = 14,
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "wowhead-spell:131686", active = true,
    },
    {
        id = "mop.jewelcrafting.research-131690", professionID = 755, recipeSpellID = 131690,
        cooldownGroupID = "mop.jewelcrafting.blue-gem-research", label = "潘达利亚蓝宝石研究", order = 15,
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "wowhead-spell:131690", active = true,
    },
    {
        id = "mop.jewelcrafting.serpents-heart", professionID = 755, recipeSpellID = 140050, resultItemID = 95469,
        cooldownGroupID = "mop.jewelcrafting.serpents-heart", label = "神龙之心", verificationStatus = "user-confirmed",
        evidence = "user-confirmed-baseline:2026-08-29", active = true,
    },
    {
        -- "华丽制皮秘决" and "华丽制鳞秘决" both make 华丽毛皮 and
        -- share a daily cooldown.  They must therefore be two members of one
        -- group instead of two independently actionable projects.
        id = "mop.leatherworking.magnificence-of-leather", professionID = 165, recipeSpellID = 140040, resultItemID = 72163,
        cooldownGroupID = "mop.leatherworking.magnificent-fur", label = "华丽毛皮", order = 10,
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "live-observation:2026-08-30", active = true,
    },
    {
        id = "mop.leatherworking.magnificence-of-scales", professionID = 165, recipeSpellID = 140041, resultItemID = 72163,
        cooldownGroupID = "mop.leatherworking.magnificent-fur", label = "华丽毛皮", order = 11,
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "shared-cooldown:140040", active = true,
    },
    {
        id = "mop.leatherworking.enhanced-magnificent-fur", professionID = 165, recipeSpellID = 142976, resultItemID = 98617,
        cooldownGroupID = "mop.leatherworking.enhanced-magnificent-fur", label = "强化华丽毛皮",
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "spell-index:142976", active = true,
    },
    {
        id = "mop.alchemy.balanced-trillium-ingot", professionID = 171, recipeSpellID = 114783, resultItemID = 72095,
        cooldownGroupID = "mop.alchemy.other-transmutes", label = "转化：延极锭",
        verificationStatus = "excluded-no-cooldown", catalogEnabled = false, trackCooldown = false,
    },
    {
        id = "wlk.inscription.minor-research", professionID = 773, recipeSpellID = 61288,
        cooldownGroupID = "wlk.inscription.minor-research", label = "小型铭文研究",
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "live-observation:2026-09-02", active = true,
    },
    {
        id = "wlk.inscription.northrend-research", professionID = 773, recipeSpellID = 61177,
        cooldownGroupID = "wlk.inscription.northrend-research", label = "诺森德铭文研究",
        verificationStatus = "verified", verifiedBuild = "5.5.4", evidence = "live-observation:2026-09-02", active = true,
    },
}

for _, recipe in ipairs(recipes) do
    recipe.introducedIn = recipe.introducedIn or "5.x"
    if recipe.catalogEnabled == nil then recipe.catalogEnabled = recipe.active == true end
    if recipe.trackCooldown == nil then recipe.trackCooldown = recipe.catalogEnabled and recipe.recipeSpellID ~= nil end
    Catalog.recipes[recipe.id] = recipe
end
