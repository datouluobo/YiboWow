YiboAutoOpen = {}
dofile("YiboAutoOpen/Catalog.lua")

local catalog = YiboAutoOpen.Catalog.defaultOrder
assert(#catalog == 40, "V1 directory must contain 40 IDs")
local seen = {}; for index, id in ipairs(catalog) do assert(not seen[id], "duplicate ID"); seen[id] = true end
assert(catalog[14] == 54516); assert(catalog[26] == 52340); assert(not seen[5234000])
assert(YiboAutoOpen.Catalog:IsManualOnly(52340), "Abyssal Clam must be explicitly marked as manual-only")
assert(YiboAutoOpen.Catalog:IsManualOnly(24476), "Jaggal Clam must be manual-only")
assert(YiboAutoOpen.Catalog:IsExcludedFromCatalog(24476), "Jaggal Clam must not enter the catalog")
assert(not YiboAutoOpen.Catalog:IsExcludedFromCatalog(52340), "existing Abyssal Clam catalog behavior remains supported")
assert(not YiboAutoOpen.Catalog:IsManualOnly(90735), "ordinary catalog items must remain eligible for automatic opening")
assert(YiboAutoOpen.Catalog:GetGameObjectID("GameObject-0-0-0-0-210565-0000000001") == 210565, "Pandaria Dark Soil object ID must be decoded")
assert(YiboAutoOpen.Catalog:GetGameObjectID("GameObject-0-0-0-0-123456-0000000001") == 123456, "game object IDs must be decoded consistently")

print("Catalog spec passed")
