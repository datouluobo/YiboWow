local eventHandler, cleanupOwner, coreListener
local now = 1790500000
local linked, shown = false, true
local rows = {
    { "材料", "header" },
    { "配方甲", "optimal", "|Hspell:1001|h[配方甲]|h" },
    { "配方乙", "trivial", "|Henchant:1002|h[配方乙]|h" },
}

function GetServerTime() return now end
function CreateFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, callback) eventHandler = callback end,
    }
end
TradeSkillFrame = { IsShown = function() return shown end }
function IsTradeSkillLinked() return linked end
function IsTradeSkillGuild() return false end
function GetTradeSkillLine() return "裁缝", 75, 75 end
function GetNumTradeSkills() return #rows end
function GetTradeSkillInfo(index) return rows[index][1], rows[index][2] end
function GetTradeSkillRecipeLink(index) return rows[index][3] end
function GetTradeSkillItemLink(index)
    if index == 2 then return "|Hitem:2001|h[成品甲]|h" end
    if index == 3 then return "|Hitem:2002|h[成品乙]|h" end
end
function GetItemInfo(itemID)
    if itemID == 2001 then return "成品甲" end
    if itemID == 2002 then return "成品乙" end
end
C_Timer = { After = function(_, callback) callback() end }

local domain = { state = "known", data = { professions = { { id = 197, name = "裁缝" } } } }
YiboCore = {
    CheckAPIVersion = function() return true end,
    RegisterAddon = function() return true end,
    Characters = { GetCurrentID = function() return "Player-test" end },
    DataDomains = { Get = function() return domain end },
    CharacterCleanup = { RegisterOwner = function(_, _, owner) cleanupOwner = owner; return true end },
    Events = { Register = function(_, _, _, callback) coreListener = callback end },
    UITheme = {
        Colors = { text = {}, muted = {}, warning = {} },
        Table = { rowHeight = 28 },
        GetCharacterMatrixColumnWidth = function() return 80 end,
    },
    AccountView = {
        RegisterPage = function(_, owner, definition)
            assert(owner == "YiboCrafting" and definition.id == "crafting")
            return definition
        end,
        NotifyPageChanged = function() end,
    },
    Entry = { RegisterBusinessEntry = function() return true end },
}

dofile("YiboCrafting/Namespace.lua")
dofile("YiboCrafting/Store.lua")
dofile("YiboCrafting/Collector.lua")
dofile("YiboCrafting/AccountPage.lua")
dofile("YiboCrafting/Bootstrap.lua")
eventHandler(nil, "PLAYER_LOGIN")
assert(YiboCrafting.initialized and YiboCraftingDB.schemaVersion == 1)
eventHandler(nil, "TRADE_SKILL_SHOW")
local store = YiboCrafting.Store
assert(store:GetRecipeState("Player-test", 197, 1001) == "learned")
assert(store:GetRecipeState("Player-test", 197, 1002) == "learned")
assert(store:GetRecipeState("Player-test", 197, 1003) == "unknown")
assert(store:GetProfession("Player-test", 197).lastAttempt.state == "partial")

rows = { rows[1], rows[2] }
eventHandler(nil, "TRADE_SKILL_UPDATE")
assert(#store:GetKnownRecipeIDs("Player-test", 197) == 2)
assert(store:GetRecipeState("Player-test", 197, 1002) == "learned")
assert(store:GetProfession("Player-test", 197).lastAttempt.visibleRecipeCount == 1)

linked = true
eventHandler(nil, "TRADE_SKILL_UPDATE")
assert(#store:GetKnownRecipeIDs("Player-test", 197) == 2)
linked = false
shown = false
eventHandler(nil, "TRADE_SKILL_UPDATE")
assert(#store:GetKnownRecipeIDs("Player-test", 197) == 2)
shown = true

GetNumTradeSkills = function() error("client failure") end
eventHandler(nil, "TRADE_SKILL_UPDATE")
assert(store:GetProfession("Player-test", 197).lastAttempt.state == "error")
assert(#store:GetKnownRecipeIDs("Player-test", 197) == 2)

coreListener(nil, "Player-test", "Player-new")
assert(store:GetProfession("Player-test", 197) == nil)
assert(store:GetRecipeState("Player-new", 197, 1002) == "learned")
local snapshotContext = { characters = { { id = "Player-new", name = "测试角色" } } }
local entries, professionList = YiboCrafting.AccountPage:Snapshot(snapshotContext)
assert(#entries == 2 and #professionList == 1 and professionList[1].id == 197)
local visibleProfessions = YiboCrafting.AccountPage:ProfessionsForCharacter({ { id = 164 }, { id = 197 } }, "Player-new")
assert(#visibleProfessions == 1 and visibleProfessions[1].id == 197)
assert(#YiboCrafting.AccountPage:Filtered(entries, snapshotContext.characters, { character = "Player-new" }) == 2)
assert(#YiboCrafting.AccountPage:Filtered(entries, snapshotContext.characters, { search = "1002" }) == 1)
assert(#YiboCrafting.AccountPage:Filtered(entries, snapshotContext.characters, { search = "成品乙" }) == 1)
assert(#YiboCrafting.AccountPage:Filtered(entries, snapshotContext.characters, { status = "unknown" }) == 0)
local accountCatalog = YiboCrafting.AccountPage:Snapshot({ characters = {} })
assert(#accountCatalog == 2)
assert(cleanupOwner.Inspect({ id = "Player-new" }).hasData)
assert(cleanupOwner.Delete({ id = "Player-new" }))
assert(store:GetProfession("Player-new", 197) == nil)
print("YiboCrafting positive-cache smoke OK")
