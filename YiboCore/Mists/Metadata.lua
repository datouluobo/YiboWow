local Core = _G.YiboCore
local target = Core._private.target
assert(target and target.id == "Mists", "addon-metadata-target-mismatch")
if target.addons then return end

-- Display and cleanup policy only; it does not register or initialize business plugins.
target.addons = {
    YiboAltoBoss = {
        cleanupKey = "CORE.BOSS_TRACKER_CHARACTER_RECORDS",
        operation = { "CORE.YIBOALTOBOSS_BOSSES_LOCKOUTS", "CORE.CLICK_A_CHARACTER_TARGET_STATUS_CELL_TO" },
    },
    YiboAutoOpen = {
        operation = { "CORE.YIBOAUTOOPEN_AUTO_OPEN", "CORE.IN_SETTINGS_DROP_A_BAG_ITEM_INTO" },
    },
    YiboBeastPaths = {
        operation = { "CORE.YIBOBEASTPATHS_BEAST_PATHS", "CORE.CLICK_THE_ADDON_BUTTON_ON_THE_WORLD" },
    },
    YiboBuilds = {
        cleanupKey = "CORE.BUILDS_CHARACTER_SNAPSHOTS",
        operation = { "CORE.YIBOBUILDS_EQUIPMENT_APPEARANCE", "CORE.MODEL_PREVIEW_DRAG_TO_ROTATE_AND_USE" },
        note = { "CORE.CHARACTER_BUILDS", "CORE.DRAG_TO_ROTATE_MOUSE_WHEEL_TO_ZOOM" },
    },
    YiboCrafting = {
        cleanupKey = "CORE.CRAFTING_CHARACTER_SNAPSHOTS",
        operation = { "CORE.YIBOCRAFTING_PROFESSION_RECIPES", "CORE.CLICK_A_RECIPE_ROW_NAME_OR_ITEM" },
    },
    YiboCurrency = {
        cleanupKey = "CORE.CURRENCY_CHARACTER_SNAPSHOTS",
        operation = { "CORE.YIBOCURRENCY_CURRENCY_OVERVIEW", "CORE.RIGHT_CLICK_A_CURRENCY_ROW_TO_TOGGLE" },
    },
    YiboLegendary = {
        cleanupKey = "CORE.LEGENDARY_PATHS_CHARACTER_PROGRESS",
        operation = { "CORE.YIBOLEGENDARY_LEGENDARY_PATHS", "CORE.CLICK_A_TARGET_COLUMN_OR_CHARACTER_PROGRESS" },
    },
    YiboMail = {
        cleanupKey = "CORE.MAIL_SNAPSHOTS_AND_BACKLOG_CACHE",
        operation = { "CORE.YIBOMAIL_MAIL", "CORE.RULE_BASED_MAIL_DROP_A_BAG_ITEM" },
    },
    YiboMounts = {
        operation = { "CORE.YIBOMOUNTS_MOUNT_JOURNAL", "CORE.USE_THE_COLLECTED_AND_NOT_COLLECTED_CHECKBOXES" },
    },
    YiboQuestBlocker = {
        cleanupKey = "CORE.QUEST_BLOCKER_PERSONAL_SETTINGS",
        operation = { "CORE.YIBOQUESTBLOCKER_QUEST_BLOCKER", "CORE.CLICK_A_QUEST_ROW_S_EXPAND_ICON" },
    },
    YiboReputation = {
        cleanupKey = "CORE.REPUTATION_CHARACTER_SNAPSHOTS",
        operation = { "CORE.YIBOREPUTATION_REPUTATION_OVERVIEW", "CORE.CLICK_A_REPUTATION_NAME_TO_EXPAND_OR" },
        note = { "CORE.REPUTATION_MONITORING_SETTINGS", "CORE.ADD_STARS_QUICKLY_IN_THE_MAIN_MATRIX" },
    },
    YiboTodo = {
        cleanupKey = "CORE.TODO_CHARACTER_SNAPSHOTS",
        operation = { "CORE.YIBOTODO_DAILY_ACTIONS", "CORE.CLICK_AN_AVAILABLE_ACTION_ICON_FOR_THE" },
        note = { "CORE.ACCOUNT_TO_DO_SETTINGS", "CORE.EACH_SWITCH_CONTROLS_A_COLUMN_IN_THE" },
    },
    YiboTaskHub = {
        operation = { "CORE.YIBOTASKHUB_ACTION_HUB", "CORE.TASK_HUB_SOURCE_TARGETS" },
    },
    YiboVault = {
        cleanupKey = "CORE.ACCOUNT_INVENTORY_SNAPSHOTS",
        operation = { "CORE.YIBOVAULT_ACCOUNT_STORAGE", "CORE.SELECT_A_CHARACTER_OR_GUILD_ON_THE" },
    },
}
