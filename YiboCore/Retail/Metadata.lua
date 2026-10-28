local Core = _G.YiboCore
local target = Core._private.target
assert(target and target.id == "Retail", "addon-metadata-target-mismatch")
if target.addons then return end
-- Existing independent routes only; no offline-stable integration or cleanup owner yet.
target.addons = {
    YiboBeastPaths = {
        descriptionKey = "CORE.BEAST_PATHS_ROUTES",
        operation = { "CORE.YIBOBEASTPATHS_BEAST_PATHS", "CORE.CLICK_THE_ADDON_BUTTON_ON_THE_WORLD" },
    },
}
