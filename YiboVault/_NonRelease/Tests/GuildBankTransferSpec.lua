local timers, committed = {}, {}
local character = { id = "A-Realm", realm = "Realm", profile = { guild = "Guild" } }
_G.YiboVault = {
    Core = { Characters = { GetCurrent = function() return character end } },
    GetGuildIdentity = function() return "Guild-Realm" end,
    Now = function() return 1000, "server" end,
    Print = function() end,
    ReplaceGuildTab = function(_, _, _, _, tabID, _, records)
        committed[tabID] = records
    end,
    MarkGuildTabError = function(_, _, _, _, tabID, reason)
        error("unexpected tab error " .. tostring(tabID) .. ": " .. tostring(reason))
    end,
}
_G.C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
_G.MAX_GUILDBANK_SLOTS_PER_TAB = 1
_G.GetGuildInfo = function() return "Guild" end
_G.GetCurrentGuildBankTab = function() return 1 end
_G.GetGuildBankTabInfo = function(tabID) return "Tab " .. tabID, nil, true end
_G.GetGuildBankItemInfo = function(tabID)
    if tabID == 1 then return true, 80 end
    return false, 0
end
_G.GetGuildBankItemLink = function(tabID)
    if tabID == 1 then return "|Hitem:100:0|h[Item]|h" end
end
dofile("YiboVault/GuildBank.lua")
local scanner = YiboVault.GuildBank
scanner.open = true
scanner.scan = { guild = { key = "Guild-Realm", name = "Guild", realm = "Realm",
        visitorCharacterID = character.id }, queue = { 2 }, index = 1, requestToken = 1,
    waitingTab = 2, completed = 0, failed = 0 }
scanner:HandleTabUpdate()
assert(#timers == 2, "an update during the full scan must schedule both current and queried tabs")
for _, callback in ipairs(timers) do callback() end
assert(committed[1] and committed[1][1] and committed[1][1].quantity == 80,
    "a guild withdrawal must refresh the visible tab even while another tab is queried")
print("GuildBankTransferSpec: OK")
