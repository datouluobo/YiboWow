CreateFrame = function() return {} end
YiboCore = {
    UITheme = {
        Colors = {},
        Table = { rowHeight = 1 },
    },
}
YiboVault = {}

dofile("YiboVault/AccountPage.lua")

local Page = YiboVault.AccountPage
local currentID = "Current-Realm"

assert(not Page:IsStaleForCurrentView({ state = "observed", source = "bags", characterID = currentID }, currentID),
    "observed current-character data is not stale")
assert(Page:IsStaleForCurrentView({ state = "stale", source = "bags", characterID = currentID }, currentID),
    "stale current-character data keeps its marker")
assert(not Page:IsStaleForCurrentView({ state = "stale", source = "bags", characterID = "Other-Realm" }, currentID),
    "historical data for another character is not marked stale")
assert(Page:IsStaleForCurrentView({ state = "stale", source = "guild-bank", guildKey = "Guild-Realm" }, currentID),
    "stale shared guild-bank data keeps its marker")

local pageDefinition = { id = "vault-items" }
YiboCore.AccountView = {
    GetRegisteredPages = function() return { pageDefinition } end,
    BuildContext = function() return { scope = "realm:Realm", characters = {
        { id = "A-Realm", realm = "Realm" }, { id = "B-Other", realm = "Other" },
    } } end,
}
local scope, characters = Page:GetScope()
assert(#scope.characterIDs == 1 and scope.characterIDs[1] == "A-Realm"
    and #characters == 1 and characters[1].id == "A-Realm",
    "tooltip scope must enforce the selected realm even if context characters are broader")

print("AccountPageFreshnessSpec: OK")
