local messages, scans, mailScans = {}, 0, 0
local character = { id = "A-Realm" }
local coverage = {}
_G.YiboVault = {
    AccountPage = { Open = function() end },
    ScanInitial = function() scans = scans + 1 end,
    MailItems = { IsOpen = function() return true end,
        Scan = function() mailScans = mailScans + 1; return true end },
    Core = { Characters = { GetCurrent = function() return character end } },
    GetCharacterCoverage = function(_, _, source) return coverage[source] or {} end,
    GetGuildIdentity = function() return nil end,
    Print = function(_, message) messages[#messages + 1] = message end,
}
_G.SlashCmdList = {}
dofile("YiboVault/Commands.lua")
SlashCmdList.YIBOVAULT("scan")
SlashCmdList.YIBOVAULT("status")
assert(scans == 1 and mailScans == 1 and #messages == 0,
    "successful manual scans and error-free status checks must be silent")
coverage.bank = { ["-1"] = { status = "error", error = "read-failed" } }
SlashCmdList.YIBOVAULT("status")
assert(#messages == 1 and messages[1]:find("read-failed", 1, true),
    "status must report a stored scan error")
coverage.bank = nil
YiboVault.GuildBank = { GetStatus = function() return "error", "tab query failed" end }
SlashCmdList.YIBOVAULT("status")
assert(#messages == 2 and messages[2]:find("tab query failed", 1, true),
    "status must report scanner errors that have no saved location")
print("ChatOutputSpec: OK")
