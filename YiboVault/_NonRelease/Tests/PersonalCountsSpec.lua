CreateFrame = function() return {} end
local queued = {}
C_Timer = { After = function(_, callback) queued[#queued + 1] = callback end }
YiboCore = {
    Characters = { GetAllCached = function() return { { id = "A" }, { id = "B" } } end,
        GetCurrent = function() return { id = "A" } end },
    AccountView = { GetVisibleCharacters = function() return { { id = "A" }, { id = "B" } } end },
}
dofile("YiboVault/Namespace.lua")
local addon = YiboVault
addon.Core = YiboCore
addon.Copy = function(value) return value end
addon.db = { revision = 3, byCharacter = {
    A = { bags = { ["0"] = { { itemID = 10, quantity = 2 } } }, bank = {},
        coverage = { bags = { ["0"] = { completedScan = true } }, bank = {} } },
    B = { bags = { ["0"] = {} }, bank = { ["-1"] = { { itemID = 10, quantity = 4 } } },
        coverage = { bags = { ["0"] = { completedScan = true } }, bank = { ["-1"] = { completedScan = true } } } },
} }
dofile("YiboVault/Items.lua")
dofile("YiboVault/PersonalCounts.lua")
local items = addon.Items
local ready = 0
items.Events:Register({}, function(event) if event == "VAULT_PERSONAL_COUNTS_READY" then ready = ready + 1 end end)
items:WarmPersonalCountsIndex()
local options = { scope = { mode = "characters", characterIDs = { "A", "B" } }, itemIDs = { 10, 11 } }
local result, errorCode = items:GetPersonalCounts(options)
assert(result == nil and errorCode == "index-pending", "cold index must not scan on query")
queued[1]()
result, errorCode = items:GetPersonalCounts(options)
assert(result == nil and errorCode == "index-pending", "index builds across frames")
local nextCallback = 2
while ready == 0 and queued[nextCallback] do
    queued[nextCallback]()
    nextCallback = nextCallback + 1
end
result = assert(items:GetPersonalCounts(options))
assert(ready == 1 and result.revision == 3, "ready event follows complete index build")
assert(result.characters.A.items[10].bags == 2 and result.characters.A.items[10].bank == nil,
    "known bag count and unknown bank stay distinct")
assert(result.characters.B.items[10].bags == 0 and result.characters.B.items[10].bank == 4,
    "known empty bag is zero; bank contributes separately")
assert(result.characters.B.items[11].bank == 0, "missing item in scanned source is zero")
assert(result.characters.A.items[10].equipment == nil,
    "unscanned equipment remains unknown")
assert(items:GetPersonalCounts({ itemIDs = { 10, "bad" } }) == nil, "invalid IDs are rejected")
addon.db.byCharacter.B.bank["-1"][1].quantity = 5
addon.db.revision = 4
items:UpdatePersonalCountsIndex("bank", "B")
assert(items:GetPersonalCounts(options).characters.B.items[10].bank == 5,
    "only changed personal source is refreshed")
addon.db.byCharacter.A.equipment = { equipment = { { itemID = 10, quantity = 1 } } }
addon.db.byCharacter.A.coverage.equipment = { equipment = { completedScan = true } }
addon.db.revision = 5
items:UpdatePersonalCountsIndex("equipment", "A")
assert(items:GetPersonalCounts(options).characters.A.items[10].equipment == 1,
    "equipment changes refresh the compact count index")
print("PersonalCountsSpec: OK")
