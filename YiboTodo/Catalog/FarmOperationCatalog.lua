local Addon = _G.YiboTodo
local Catalog = Addon.Catalog

-- These rules are deliberately scoped to the low-fidelity observation
-- feature. They record a witnessed action, never a crop or plot state.
Catalog.farmOperations["mop.farm.operation-observed"] = {
    id = "mop.farm.operation-observed",
    label = "农场操作",
    provider = "farm-operation-observation",
    scope = "character",
    defaultMode = "display",
    mapID = 376,
    resetHour = 7,
    rules = {
        [111003] = { kind = "till", label = "开垦土地", verificationStatus = "user-observed" },
        [129757] = { kind = "harvest", label = "收获", verificationStatus = "user-observed" },
        [129814] = { kind = "harvest", label = "收割风暴仙人掌", verificationStatus = "user-observed" },
        [129883] = { kind = "plant", label = "播种风暴仙人掌种子", verificationStatus = "user-observed" },
    },
}
