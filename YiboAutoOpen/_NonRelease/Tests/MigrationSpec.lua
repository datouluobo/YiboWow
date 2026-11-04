YiboAutoOpenDB = {
    catalogVersion = 1, catalogSeeded = true, catalog = { order = { 24476, 39883, 24476, 52340 }, entries = { [24476] = true } },
    confirmSourceOrder = { "auto-open-catalog", "object:210565" },
    confirmSourceEntries = {
        ["auto-open-catalog"] = { kind = "catalog", label = "YAO 打开的目录箱子" },
        ["object:210565"] = { kind = "object", objectID = 210565, label = "潘达利亚泥土" },
    },
}

dofile("YiboAutoOpen/Bootstrap.lua")
dofile("YiboAutoOpen/Defaults.lua")
dofile("YiboAutoOpen/Catalog.lua")
YiboAutoOpen.Catalog.version = 2
YiboAutoOpen.Catalog.migrations = { { toVersion = 2, addedIDs = { 90735 } } }
dofile("YiboAutoOpen/Database.lua")

YiboAutoOpen.Database:Initialize()

assert(YiboAutoOpenDB.catalogVersion == 2, "the catalog migration should complete")
assert(not YiboAutoOpenDB.catalog.entries[24476], "existing Jaggal Clam entries must be removed on initialization")
assert(YiboAutoOpenDB.catalog.entries[39883] and YiboAutoOpenDB.catalog.entries[52340], "other saved catalog items must remain")
local before = #YiboAutoOpen.Database:GetOrderedItems()
local added, reason = YiboAutoOpen.Database:AddItem("24476")
assert(not added and reason == "manual_only", "all add callers must reject Jaggal Clam")
assert(#YiboAutoOpen.Database:GetOrderedItems() == before and not YiboAutoOpenDB.catalog.entries[24476])
YiboAutoOpen.Database:Initialize()
assert(not YiboAutoOpenDB.catalog.entries[24476], "normalization must be idempotent")
assert(YiboAutoOpenDB.catalog.entries[90735], "the migrated item should be added without recursive initialization")
assert(YiboAutoOpenDB.bindConfirmFollowCursor == true, "existing profiles should enable bind-confirm cursor placement by default")
assert(#YiboAutoOpenDB.confirmSourceOrder == 1, "existing profiles should receive only the catalog confirmation source")
assert(YiboAutoOpen.Database:IsConfirmSourceEnabled("auto-open-catalog"), "catalog confirmation source should be enabled by default")
assert(YiboAutoOpen.Database:SetConfirmSourceLabel("auto-open-catalog", "自动打开的目录箱子"), "confirmation source alias should be editable")
assert(YiboAutoOpen.Database:GetConfirmSources()[1].label == "自动打开的目录箱子", "confirmation source alias should be persisted")
local builtinRemoved, builtinReason = YiboAutoOpen.Database:RemoveConfirmSource("auto-open-catalog")
assert(not builtinRemoved and builtinReason == "builtin", "the catalog confirmation source must not be removable")
assert(not YiboAutoOpen.Database:HasConfirmSource("object:210565"), "Pandaria Dark Soil must require explicit user addition")
assert(YiboAutoOpen.Database:AddConfirmObject(999999), "custom confirmation object should be addable")
assert(YiboAutoOpen.Database:IsConfirmSourceEnabled("object:999999"), "custom confirmation object should be persisted")
assert(YiboAutoOpen.Database:RemoveConfirmSource("object:999999"), "custom confirmation object should be removable")

print("Migration spec passed")
