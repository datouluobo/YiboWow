local timers, stored, coverage, replaceCount, errorCount = {}, {}, {}, 0, 0
local character = { id = "Tester-Realm", name = "Tester", realm = "Realm" }
local shown, currentCount, totalCount = true, 2, 2
local attachments = {
    [1] = { [1] = { itemID = 72092, quantity = 20, link = "|Hitem:72092:0|h[Ore]|h" } },
    [2] = { [1] = { itemID = 72096, quantity = 3, link = "|Hitem:72096:0|h[Bar]|h" } },
}

_G.YiboVault = {
    Core = { Characters = { GetCurrent = function() return character end } },
    Now = function() return 1000, "server" end,
    Print = function() end,
    ReplaceLocation = function(_, characterID, source, key, records, location, capacity, scanMeta)
        assert(characterID == character.id and source == "mail" and key == "inbox")
        assert(location.container == "inbox" and capacity == nil)
        stored, coverage = records, scanMeta
        replaceCount = replaceCount + 1
        return true, coverage
    end,
    MarkLocationError = function(_, source, key, location, message)
        assert(source == "mail" and key == "inbox" and location.container == "inbox")
        assert(type(message) == "string" and message ~= "")
        errorCount = errorCount + 1
    end,
}
MailFrame = { IsShown = function() return shown end }
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
GetInboxNumItems = function() return currentCount, totalCount end
GetInboxHeaderInfo = function(index)
    return "Package", "Sender", "Subject", 1, 0, 0, 0, attachments[index] and 1 or 0
end
GetInboxItem = function(mailIndex, attachmentIndex)
    local item = attachments[mailIndex] and attachments[mailIndex][attachmentIndex]
    if item then return "Ore", item.itemID, "icon", item.quantity end
end
GetInboxItemLink = function(mailIndex, attachmentIndex)
    local item = attachments[mailIndex] and attachments[mailIndex][attachmentIndex]
    return item and item.link
end

local function Flush()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end

dofile("YiboVault/MailItems.lua")
local scanner = YiboVault.MailItems
scanner:OnEvent("MAIL_SHOW")
scanner:OnEvent("MAIL_INBOX_UPDATE")
scanner:OnEvent("MAIL_INBOX_UPDATE")
Flush()
assert(replaceCount == 1 and #stored == 2, "debounced update commits one full snapshot")
assert(coverage.status == "known" and coverage.currentCount == 2 and coverage.totalCount == 2)
assert(stored[1].sourceClass == "external" and stored[1].quantity == 20)
assert(stored[1].location.attachmentIndex == 1 and stored[1].variantKey == "link:item:72092:0")

totalCount = 5
scanner:OnEvent("MAIL_INBOX_UPDATE")
Flush()
assert(coverage.status == "partial" and coverage.unscannedCount == 3, "unexposed mail is explicitly partial")

attachments[1][1] = { itemID = 72092, quantity = nil, link = "|Hitem:72092:0|h[Ore]|h" }
scanner:OnEvent("MAIL_INBOX_UPDATE")
Flush()
assert(replaceCount == 2 and scanner:GetStatus() == "error" and errorCount == 1,
    "incomplete attachment preserves records and reports a source-state failure")

attachments[1][1].quantity = 20
scanner:OnEvent("MAIL_INBOX_UPDATE")
shown = false
Flush()
assert(replaceCount == 2, "closing before timer preserves cache")
scanner:OnEvent("MAIL_INBOX_UPDATE")
Flush()
assert(replaceCount == 2, "closed inbox API residue never refreshes cache")

shown, currentCount, totalCount = true, 0, 0
scanner:OnEvent("MAIL_SHOW")
scanner:OnEvent("MAIL_INBOX_UPDATE")
Flush()
assert(replaceCount == 3 and #stored == 0 and coverage.status == "known-empty", "open 0/0 clears inbox")
scanner:OnEvent("MAIL_CLOSED")
shown, currentCount, totalCount = false, 2, 2
scanner:OnEvent("MAIL_INBOX_UPDATE")
scanner:OnEvent("MAIL_SHOW")
Flush()
assert(replaceCount == 3, "a mail event before the frame is visible must not read stale inbox data")
shown = true
Flush()
assert(replaceCount == 4 and #stored == 2,
    "mail-show must retry after the frame becomes visible even without a later inbox event")
print("MailItemsSpec: OK")
