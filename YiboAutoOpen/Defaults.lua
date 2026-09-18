local Addon = _G.YiboAutoOpen
Addon.DEFAULTS = { schemaVersion = 1, catalogVersion = 1, enabled = true, scanExistingOnLogin = true, bindConfirmFollowCursor = true, minFreeSlots = 5, notificationMode = "issues" }
Addon.LIMITS = { minFreeSlots = { min = 1, max = 20 }, listPageSize = 20, maxRetries = 2, operationTimeout = 2.0, retryBackoff = 15 }
