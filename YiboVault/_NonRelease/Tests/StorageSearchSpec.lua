_G.YiboVault = {}
dofile("YiboVault/Common/StorageBrowse.lua")
local Browse = YiboVault.StorageBrowse
local records = {
    { itemID = 101, quantity = 3, source = "bags", characterID = "char-1" },
    { itemID = 202, quantity = 1, source = "equipment", characterID = "char-1" },
    { itemID = 101, quantity = 5, source = "guild-bank", guildKey = "guild-1", location = { tabID = 2 } },
    { itemID = 101, quantity = 7, source = "auction", characterID = "out-of-scope" },
}
local transit = { { itemID = 101, quantity = 2, source = "mail", characterID = "char-1" } }
local owners = { ["char-1"] = true, ["guild-1"] = true }
local names = { [101] = "Swift Potion", [202] = "Heavy Shield" }
local function Name(record) return names[record.itemID] end

local browse = Browse:New("bags")
browse:SelectOwner("char-1")
local query = browse:SetQuery("  POTION  ")
local groups = Browse:GroupRecords(records, transit, query, Name, nil, owners)
local character, guild = groups["char-1"], groups["guild-1"]
assert(character.quantity == 5 and character.bySource.bags[1] == records[1]
    and character.bySource.mail[1] == transit[1] and not character.bySource.equipment,
    "name search groups physical and in-transit results under the matching character")
assert(guild.quantity == 5 and guild.bySource["guild-bank"][1] == records[3] and not groups["out-of-scope"],
    "only admitted owners participate in search, with guild records under the guild identity")
groups = Browse:GroupRecords(records, transit, "202", Name)
assert(groups["char-1"].quantity == 1 and groups["char-1"].bySource.equipment[1] == records[2]
    and not groups["guild-1"], "item ID search keeps only the matching record")
browse:SelectOwner("guild-1", true)
browse:SelectSource("tab:2", true)
browse:SetQuery("   ")
assert(browse:Selection().owner == "char-1" and browse:Selection().source == "bags",
    "leaving search restores both the browse owner and its source")
print("YiboVault storage search spec passed")
