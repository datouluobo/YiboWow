YiboAutoOpen = {}
dofile("YiboAutoOpen/Catalog.lua")

local catalog = YiboAutoOpen.Catalog.defaultOrder
assert(#catalog == 40, "V1 directory must contain 40 IDs")
local seen = {}; for index, id in ipairs(catalog) do assert(not seen[id], "duplicate ID"); seen[id] = true end
assert(catalog[14] == 54516); assert(catalog[26] == 52340); assert(not seen[5234000])

print("Catalog spec passed")
