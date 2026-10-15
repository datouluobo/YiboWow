local Core = _G.YiboCore

-- Static presentation metadata only.  Versions deliberately live in the
-- generated packaging manifest and in the player's installed TOCs.
Core.AddonCatalog = Core.Locale:Bind(function()
    local addons = {
    {
        name = "YiboAltoBoss",
        title = Core:Text("CORE.BOSS_TRACKER"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboAltoBoss\\Media\\YiboAltoBossIcon",
        description = Core:Text("CORE.TRACK_WORLD_BOSSES_HOLIDAY_BOSSES_AND_CUSTOM"),
        projectURL = "https://www.curseforge.com/wow/addons/yiboaltoboss",
    },
    {
        name = "YiboBuilds",
        title = Core:Text("CORE.CHARACTER_BUILDS"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboBuilds\\Media\\YiboBuildsIcon",
        description = Core:Text("CORE.VIEW_EQUIPMENT_TALENTS_AND_GLYPH_BUILDS_ACROSS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibobuilds",
    },
    {
        name = "YiboCurrency",
        title = Core:Text("CORE.CURRENCY_MANAGER"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon",
        description = Core:Text("CORE.TRACK_CURRENCIES_ACROSS_CHARACTERS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibocurrency",
    },
    {
        name = "YiboCrafting",
        title = Core:Text("CORE.CRAFTING"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboCrafting\\Media\\YiboCraftingIcon",
        description = Core:Text("CORE.VIEW_CONFIRMED_LEARNED_PROFESSION_RECIPES_ACROSS_CHARACTERS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibocrafting",
    },
    {
        name = "YiboLegendary",
        title = Core:Text("CORE.LEGENDARY_PATHS"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon",
        description = Core:Text("CORE.TRACK_LEGENDARY_ITEM_COLLECTION_PROGRESS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibolegendary",
    },
    {
        name = "YiboQuestBlocker",
        title = Core:Text("CORE.QUEST_BLOCKER"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboQuestBlocker\\Media\\YiboQuestBlockerIcon",
        description = Core:Text("CORE.QUEST_PREREQUISITES_AND_BLOCKING_CONDITIONS"),
        projectURL = "https://www.curseforge.com/wow/addons/yiboquestblocker",
    },
    {
        name = "YiboTodo",
        title = Core:Text("CORE.ACCOUNT_TO_DO"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboTodo\\Media\\YiboTodoIcon",
        description = Core:Text("CORE.ACCOUNT_TASKS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibotodo",
    },
    {
        name = "YiboVault",
        title = Core:Text("CORE.ITEM_OVERVIEW"),
        relation = "core-child",
        description = Core:Text("CORE.FIND_ITEMS_IN_BAGS_EQUIPMENT_AND_OTHER"),
        icon = "Interface\\AddOns\\YiboVault\\Media\\YiboVaultIcon",
        projectURL = "https://www.curseforge.com/wow/addons/yibovault",
    },
    {
        name = "YiboMail",
        title = Core:Text("CORE.MAIL_ASSISTANT"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboMail\\Media\\YiboMailIcon",
        description = Core:Text("CORE.MAIL_SNAPSHOTS_BACKLOG_CACHES_AND_ATTACHMENT_SOURCES"),
        projectURL = "https://www.curseforge.com/wow/addons/yibomail",
    },
    {
        name = "YiboReputation",
        title = Core:Text("CORE.REPUTATION_PATHS"),
        relation = "core-child",
        icon = "Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon",
        description = Core:Text("CORE.REPUTATION_PROGRESS_ACROSS_CHARACTERS"),
        projectURL = "https://www.curseforge.com/wow/addons/yiboreputation",
    },
    {
        name = "YiboAutoOpen",
        title = Core:Text("CORE.AUTO_OPEN"),
        relation = "optional-core",
        icon = "Interface\\AddOns\\YiboAutoOpen\\Media\\YiboAutoOpenIcon",
        description = Core:Text("CORE.SAFELY_OPEN_CONTAINER_ITEMS_FROM_THE_ACCOUNT"),
        projectURL = "https://www.curseforge.com/wow/addons/yiboautoopen",
    },
    {
        name = "YiboBeastPaths",
        title = Core:Text("CORE.BEAST_PATHS"),
        relation = "optional-core",
        icon = "Interface\\AddOns\\YiboBeastPaths\\Media\\YiboBeastPathsIcon",
        description = Core:Text("CORE.HIDDEN_HUNTER_PET_ROUTES_IN_PANDARIA"),
        projectURL = "https://www.curseforge.com/wow/addons/yibobeastpaths",
    },
    {
        name = "YiboMounts",
        title = Core:Text("CORE.MOUNT_JOURNAL"),
        relation = "optional-core",
        icon = "Interface\\AddOns\\YiboMounts\\Media\\YiboMountsIcon",
        description = Core:Text("CORE.SHOW_MOUNT_SOURCES_IN_AURAS_CHAT_LINKS"),
        projectURL = "https://www.curseforge.com/wow/addons/yibomounts",
    },
    }
    local getAddonInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    for _, addon in ipairs(addons) do
        if not getAddonInfo or not getAddonInfo(addon.name) then
            addon.icon = "Interface\\AddOns\\YiboCore\\Media\\YiboCoreIcon"
        end
    end
    return addons
end)

Core.Capabilities:Register("addon-catalog", 1)
