YiboAutoOpenDB = {
    catalogVersion = 1, catalogSeeded = true, catalog = { order = { 39883 } },
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
