local addonName, ns = ...

local projectID = _G.WOW_PROJECT_ID

ns.WOW_PROJECT_ID = projectID
ns.FLAVOR = "unknown"
ns.IS_RETAIL = false
ns.IS_MISTS = false
ns.IS_CLASSIC = false

if projectID == _G.WOW_PROJECT_MAINLINE then
    ns.FLAVOR = "retail"
    ns.IS_RETAIL = true
elseif projectID == _G.WOW_PROJECT_MISTS_CLASSIC then
    ns.FLAVOR = "mists"
    ns.IS_MISTS = true
    ns.IS_CLASSIC = true
elseif projectID == _G.WOW_PROJECT_CLASSIC
    or projectID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC
    or projectID == _G.WOW_PROJECT_WRATH_CLASSIC
    or projectID == _G.WOW_PROJECT_CATACLYSM_CLASSIC then
    ns.FLAVOR = "classic"
    ns.IS_CLASSIC = true
end

ns.CLASSIC = ns.IS_CLASSIC
