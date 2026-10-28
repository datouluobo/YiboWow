local Core = _G.YiboCore
local target = Core._private.target
assert(target and target.id == "Forever", "addon-metadata-target-mismatch")
if target.addons then return end

-- Display and cleanup policy only; it does not register or initialize business plugins.
target.addons = {
    YiboBuilds = {
        cleanupKey = "CORE.BUILDS_CHARACTER_SNAPSHOTS",
        descriptionKey = "CORE.BUILDS_CURRENT_EQUIPMENT",
        operation = { "CORE.YIBOBUILDS_EQUIPMENT_APPEARANCE", "CORE.BUILDS_CURRENT_EQUIPMENT" },
    },
    YiboCrafting = {
        cleanupKey = "CORE.CRAFTING_CHARACTER_SNAPSHOTS",
        descriptionKey = "CORE.CRAFTING_CURRENT_OBSERVED",
        operation = { "CORE.YIBOCRAFTING_PROFESSION_RECIPES", "CORE.CRAFTING_CURRENT_OBSERVED" },
    },
    YiboCurrency = {
        cleanupKey = "CORE.CURRENCY_CHARACTER_SNAPSHOTS",
        descriptionKey = "CORE.CURRENCY_CURRENT_MONEY",
        operation = { "CORE.YIBOCURRENCY_CURRENCY_OVERVIEW", "CORE.CURRENCY_CURRENT_MONEY" },
    },
    YiboMail = {
        cleanupKey = "CORE.MAIL_SNAPSHOTS_AND_BACKLOG_CACHE",
        descriptionKey = "CORE.MAIL_CURRENT_INBOX",
        operation = { "CORE.YIBOMAIL_MAIL", "CORE.MAIL_CURRENT_INBOX" },
    },
    YiboReputation = {
        cleanupKey = "CORE.REPUTATION_CHARACTER_SNAPSHOTS",
        descriptionKey = "CORE.REPUTATION_CURRENT_OBSERVED",
        operation = { "CORE.YIBOREPUTATION_REPUTATION_OVERVIEW", "CORE.REPUTATION_CURRENT_OBSERVED" },
    },
    YiboVault = {
        cleanupKey = "CORE.ACCOUNT_INVENTORY_SNAPSHOTS",
        descriptionKey = "CORE.VAULT_CURRENT_BAGS_EQUIPMENT",
        operation = { "CORE.YIBOVAULT_ACCOUNT_STORAGE", "CORE.VAULT_CURRENT_BAGS_EQUIPMENT" },
    },
}
