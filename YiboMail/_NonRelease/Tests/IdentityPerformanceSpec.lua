-- Run from workspace root. Real Core snapshots with unrelated large domains.
function CreateFrame() return {} end
function UnitGUID() return "Player-Mail" end
function GetServerTime() return 1000 end
MailFrame = { IsShown = function() return true end }
YiboCore = { Capabilities = { Register = function() end } }
local Core = YiboCore
dofile("_NonRelease/CoreIdentityDomainsR1/LoadClient.lua")
dofile("YiboCore/Util/Defaults.lua")
local character = { id = UnitGUID(), name = "Mailer", realm = "Realm", class = "MAGE", faction = "Alliance", domains = { inventory = {} } }
for index = 1, 10000 do character.domains.inventory[index] = { itemID = index, quantity = 20 } end
local database = { characters = { byID = { [character.id] = character } }, characterDisplay = { [character.id] = { shortName = "Short" } } }
Core.Database = { GetDB = function() return database end }
dofile("YiboCore/Data/Characters.lua")
for _, file in ipairs({ "Namespace", "Store", "Items", "Mists/Scanner", "ViewModel", "NativeUI", "Recipients" }) do dofile("YiboMail/" .. file .. ".lua") end
local Addon = YiboMail; Addon.Core = Core
Addon:InitializeDatabase()
Addon.FEATURES.account = false
local scanner = Addon.Scanner
scanner.open, scanner.updated, scanner.validAt = true, true, 1000
Addon.db.byCharacter[character.id] = { coverage = { status = "known", observedAt = 1000 }, records = {}, visibleKeys = {} }
local copies, originalCopy = 0, Core.Defaults.Copy
function Core.Defaults:Copy(value) copies = copies + 1; return originalCopy(self, value) end
local function Measure(callback)
    collectgarbage("collect"); collectgarbage("stop")
    local memory, started = collectgarbage("count"), os.clock()
    callback()
    local elapsed, allocated = os.clock() - started, collectgarbage("count") - memory
    collectgarbage("restart")
    return elapsed, allocated
end
local beforeTime, beforeKB = Measure(function() for index = 1, 100 do Core.Characters:GetCurrent() end end)
assert(copies > 0, "Baseline must exercise the real deep-copy path")
-- Warm the shared read-only directory once; it is not a per-row copy.
Core.Characters:GetAllCached(); copies = 0
local afterTime, afterKB = Measure(function()
    for index = 1, 100 do
        local context = Addon.NativeUI:Context()
        assert(context.characters[1].domains == nil, "Inbox contexts must not retain domains")
        assert(Addon.ViewModel:CharacterLabel(context.characters[1]) == "Short")
        assert(Addon.Items:GetState(character.id).status == "known")
        local sender = Addon.Recipients:Current()
        assert(sender.faction == "Alliance" and sender.domains == nil)
        sender.faction = "Horde"
        assert(character.faction == "Alliance", "Recipient projection must not mutate the shared directory")
    end
end)
assert(copies == 0, "Inbox identity, labels and live state must never deep-copy domains")
assert(afterKB < beforeKB / 20, "Identity allocations must be independent of domain size")
scanner.validAt = nil
assert(Addon.Items:GetState(character.id).status == "stale")
scanner.lastError = "header-unavailable"
assert(Addon.Items:GetState(character.id).status == "error")
scanner.lastError, scanner.open = nil, false
assert(Addon.Items:GetState(character.id).status == "stale")
assert(Core.Characters:Get("missing", { identityOnly = true }) == nil)
assert(character.domains.inventory[10000].quantity == 20, "Source domain data is preserved")
print(string.format("PASS: 100 full reads %.3fs / %.1f MB; 100 inbox identity+label+state passes %.3fs / %.1f KB; zero domain copies; live/stale/error preserved", beforeTime, beforeKB / 1024, afterTime, afterKB))
