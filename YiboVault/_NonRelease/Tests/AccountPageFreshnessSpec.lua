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
    GetVisibleCharacters = function() return {
        { id = "A-Realm", realm = "Realm" }, { id = "B-Other", realm = "Other" },
    } end,
    GetEffectiveCharacterSort = function() return {} end,
    GetCustomCharacterOrder = function() return {} end,
}
YiboCore.Characters = {
    GetCurrent = function() return { id = "A-Realm", realm = "Realm" } end,
    GetCurrentID = function() return "A-Realm" end,
}
YiboCore.CharacterSort = { Sort = function(_, characters) return characters end }
YiboVault.db = { settings = { tooltipRealmScope = "current" } }
local scope, characters = Page:GetScope()
assert(#scope.characterIDs == 1 and scope.characterIDs[1] == "A-Realm"
    and #characters == 1 and characters[1].id == "A-Realm",
    "storage page scope must enforce the selected realm")

scope, characters = Page:GetTooltipScope()
assert(#scope.characterIDs == 1 and scope.characterIDs[1] == "A-Realm" and #characters == 1,
    "current-realm tooltip scope should include only current-realm characters")
YiboVault.db.settings.tooltipRealmScope = "all"
scope, characters = Page:GetTooltipScope()
assert(#scope.characterIDs == 2 and #characters == 2 and characters[2].id == "B-Other",
    "all-realm tooltip scope must ignore the storage page's selected realm")

print("AccountPageFreshnessSpec: OK")
