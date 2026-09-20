local Addon = _G.YiboAutoOpen
Addon.DEFAULTS = {
    schemaVersion = 1, catalogVersion = 1, confirmSourceVersion = 2, enabled = true, scanExistingOnLogin = true,
    bindConfirmFollowCursor = true, minFreeSlots = 5, notificationMode = "issues",
    confirmSourceOrder = { "auto-open-catalog" },
    confirmSourceEntries = {
        ["auto-open-catalog"] = { kind = "catalog", label = "YAO 打开的目录箱子" },
    },
}
Addon.LIMITS = { minFreeSlots = { min = 1, max = 20 }, listPageSize = 20, maxRetries = 2, operationTimeout = 2.0, retryBackoff = 15 }
