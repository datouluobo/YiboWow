_G.YiboCore = { UITheme = { Colors = {} } }
_G.YiboVault = {}
local names = { [101] = "Swift Potion", [202] = "Heavy Shield" }
_G.GetItemInfo = function(item) return names[tonumber(item)] end
dofile("YiboVault/StoragePage.lua")
local page = YiboVault.StoragePage

local character = { records = {}, counts = {}, matchQuantity = 0 }
local guild = { records = {}, counts = {}, matchQuantity = 0 }
local owners = { ["char-1"] = character, ["guild-1"] = guild }
local records = {
    { itemID = 101, quantity = 3, source = "bags", characterID = "char-1" },
    { itemID = 202, quantity = 1, source = "equipment", characterID = "char-1" },
    { itemID = 101, quantity = 5, source = "guild-bank", guildKey = "guild-1", location = { tabID = 2 } },
    { itemID = 101, quantity = 7, source = "auction", characterID = "out-of-scope" },
}
page:CollectMatches(records, "potion", owners)
assert(character.matchQuantity == 3 and character.counts.bags == 3
    and character.counts.equipment == nil, "name search must retain only matching character items")
assert(guild.matchQuantity == 5 and guild.counts["tab:2"] == 5,
    "guild tab match must use the shared guild owner and its tab key")
page:CollectMatches(records, "202", owners)
assert(character.matchQuantity == 4 and character.counts.equipment == 1,
    "item ID search must include the matching source")
assert(guild.matchQuantity == 5, "item ID search must not add unrelated guild records")
print("YiboVault storage search spec passed")
