local Core = _G.YiboCore

-- Static presentation metadata only.  Versions deliberately live in the
-- generated packaging manifest and in the player's installed TOCs.
Core.AddonCatalog = Core.Locale:Bind(function()
    local addons = {
    {
        name = "YiboAltoBoss",
        supportedTargets = { Mists = true },
        title = Core:Text("CORE.BOSS_TRACKER"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboAltoBoss\\Media\\YiboAltoBossIcon",
        description = Core:Text("CORE.TRACK_WORLD_BOSSES_HOLIDAY_BOSSES_AND_CUSTOM"),
        projectURL = "https://www.curseforge.com/wow/addons/yiboaltoboss",
    },
    {
        name = "YiboBuilds",
        supportedTargets = { Mists = true, Forever = true },
        title = Core:Text("CORE.CHARACTER_BUILDS"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboBuilds\\Media\\YiboBuildsIcon",
        description = Core:Text("CORE.VIEW_EQUIPMENT_TALENTS_AND_GLYPH_BUILDS_ACROSS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibobuilds",
    },
    {
        name = "YiboCurrency",
        supportedTargets = { Mists = true, Forever = true },
        title = Core:Text("CORE.CURRENCY_MANAGER"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon",
        description = Core:Text("CORE.TRACK_CURRENCIES_ACROSS_CHARACTERS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibocurrency",
    },
    {
        name = "YiboCrafting",
        supportedTargets = { Mists = true, Forever = true },
        title = Core:Text("CORE.CRAFTING"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboCrafting\\Media\\YiboCraftingIcon",
        description = Core:Text("CORE.VIEW_CONFIRMED_LEARNED_PROFESSION_RECIPES_ACROSS_CHARACTERS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibocrafting",
    },
    {
        name = "YiboLegendary",
        supportedTargets = { Mists = true },
        title = Core:Text("CORE.LEGENDARY_PATHS"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon",
        description = Core:Text("CORE.TRACK_LEGENDARY_ITEM_COLLECTION_PROGRESS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibolegendary",
    },
    {
        name = "YiboQuestBlocker",
        supportedTargets = { Mists = true },
        title = Core:Text("CORE.QUEST_BLOCKER"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboQuestBlocker\\Media\\YiboQuestBlockerIcon",
        description = Core:Text("CORE.QUEST_PREREQUISITES_AND_BLOCKING_CONDITIONS"),
        projectURL = "https://www.curseforge.com/wow/addons/yiboquestblocker",
    },
    {
        name = "YiboTodo",
        supportedTargets = { Mists = true },
        title = Core:Text("CORE.ACCOUNT_TO_DO"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboTodo\\Media\\YiboTodoIcon",
        description = Core:Text("CORE.ACCOUNT_TASKS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibotodo",
    },
    {
        name = "YiboVault",
        supportedTargets = { Mists = true, Forever = true },
        title = Core:Text("CORE.ITEM_OVERVIEW"),
        relation = "core-child",
        description = Core:Text("CORE.FIND_ITEMS_IN_BAGS_EQUIPMENT_AND_OTHER"),
        icon = "Interface\\AddOns\\YiboVault\\Media\\YiboVaultIcon",
        projectURL = "https://www.curseforge.com/wow/addons/yibovault",
    },
    {
        name = "YiboMail",
        supportedTargets = { Mists = true, Forever = true },
        title = Core:Text("CORE.MAIL_ASSISTANT"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboMail\\Media\\YiboMailIcon",
        description = Core:Text("CORE.MAIL_SNAPSHOTS_BACKLOG_CACHES_AND_ATTACHMENT_SOURCES"),
        projectURL = "https://www.curseforge.com/wow/addons/yibomail",
    },
    {
        name = "YiboReputation",
        supportedTargets = { Mists = true, Forever = true },
        title = Core:Text("CORE.REPUTATION_PATHS"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon",
        description = Core:Text("CORE.REPUTATION_PROGRESS_ACROSS_CHARACTERS"),
        projectURL = "https://www.curseforge.com/wow/addons/yiboreputation",
    },
    {
        name = "YiboAutoOpen",
        supportedTargets = { Mists = true },
        title = Core:Text("CORE.AUTO_OPEN"),
        relation = "optional-core",
        icon = "Interface\\AddOns\\YiboAutoOpen\\Media\\YiboAutoOpenIcon",
        description = Core:Text("CORE.SAFELY_OPEN_CONTAINER_ITEMS_FROM_THE_ACCOUNT"),
        projectURL = "https://www.curseforge.com/wow/addons/yiboautoopen",
    },
    {
        name = "YiboBeastPaths",
        -- Existing route support; this is not a Core Retail target or offline-stable capability.
        supportedTargets = { Mists = true, Retail = true },
        title = Core:Text("CORE.BEAST_PATHS"),
        relation = "optional-core",
        icon = "Interface\\AddOns\\YiboBeastPaths\\Media\\YiboBeastPathsIcon",
        description = Core:Text("CORE.BEAST_PATHS_ROUTES"),
        projectURL = "https://www.curseforge.com/wow/addons/yibobeastpaths",
    },
    {
        name = "YiboMounts",
        supportedTargets = { Mists = true },
        title = Core:Text("CORE.MOUNT_JOURNAL"),
        relation = "optional-core",
        icon = "Interface\\AddOns\\YiboMounts\\Media\\YiboMountsIcon",
        description = Core:Text("CORE.SHOW_MOUNT_SOURCES_IN_AURAS_CHAT_LINKS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibomounts",
    },
    }
    addons[#addons + 1] = {
        name = "YiboTaskHub", supportedTargets = { Mists = true },
        title = Core:Text("CORE.ACTION_HUB"), relation = "core-child",
        icon = "Interface\\AddOns\\YiboTaskHub\\Media\\YiboTaskHubIcon-128",
        description = Core:Text("CORE.TASK_HUB_SOURCE_TARGETS"),
    }
    local target = Core._private and Core._private.target
    local policies = target and target.addons
    if type(policies) ~= "table" then return {} end
    local applicable = {}
    for _, addon in ipairs(addons) do
        -- Installed files and an enabled checkbox do not establish target support.
        local policy = policies[addon.name]
        if policy and addon.supportedTargets and addon.supportedTargets[target.id] then
            if policy.descriptionKey then addon.description = Core:Text(policy.descriptionKey) end
            if not Core.Client:ReadAddon(addon.name).installed then
                addon.icon = "Interface\\AddOns\\YiboCore\\Media\\YiboCoreIcon"
            end
            applicable[#applicable + 1] = addon
        end
    end
    table.sort(applicable, function(left, right) return left.name < right.name end)
    return applicable
end)

Core.Capabilities:Register("addon-catalog", 1)
