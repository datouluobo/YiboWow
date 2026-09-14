YiboAutoOpenDB = { catalogVersion = 1, catalogSeeded = true, catalog = { order = { 39883 } } }

dofile("YiboAutoOpen/Bootstrap.lua")
dofile("YiboAutoOpen/Defaults.lua")
dofile("YiboAutoOpen/Catalog.lua")
YiboAutoOpen.Catalog.version = 2
YiboAutoOpen.Catalog.migrations = { { toVersion = 2, addedIDs = { 90735 } } }
dofile("YiboAutoOpen/Database.lua")

YiboAutoOpen.Database:Initialize()

assert(YiboAutoOpenDB.catalogVersion == 2, "the catalog migration should complete")
assert(YiboAutoOpenDB.catalog.entries[90735], "the migrated item should be added without recursive initialization")

print("Migration spec passed")
