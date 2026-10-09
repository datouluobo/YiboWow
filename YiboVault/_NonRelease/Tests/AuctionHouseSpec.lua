local timers, now = {}, 0
local currentCharacter = { id = "Tester-Realm", name = "Tester", realm = "Realm" }
local db = { revision = 0 }
local stored, coverage, replaceCount, errorCount = {}, {}, 0, 0

_G.YiboVault = {
    Core = { Characters = { GetCurrent = function() return currentCharacter end } },
    db = db,
    Now = function() return 1000 + now, "server" end,
    Print = function() end,
    ReplaceLocation = function(_, characterID, source, key, records, location)
        local same = #stored == #records
        if same then
            for index, record in ipairs(records) do
                local previous = stored[index]
                if not previous or previous.sourceID ~= record.sourceID or previous.itemID ~= record.itemID
                    or previous.quantity ~= record.quantity or previous.buyoutAmount ~= record.buyoutAmount
                    or previous.bidAmount ~= record.bidAmount or previous.timeLeft ~= record.timeLeft then
                    same = false
                    break
                end
            end
        end
        if not same then
            stored = records
            db.revision = db.revision + 1
        end
        replaceCount = replaceCount + 1
        coverage[key] = { status = #records > 0 and "known" or "known-empty", recordCount = #records, location = location }
        return not same, coverage[key]
    end,
    MarkLocationError = function() errorCount = errorCount + 1 end,
}

C_Timer = { After = function(delay, callback) timers[#timers + 1] = { at = now + delay, callback = callback } end }
C_Item = { GetItemLinkByID = function() return nil end }
GetItemInfo = function() return nil end

local auctions = {
    { auctionID = 42, itemKey = { itemID = 72988 }, quantity = 3, buyoutAmount = 900, bidAmount = 300, timeLeft = 2 },
    { auctionID = 43, itemKey = { itemID = 13544 }, quantity = 1, buyoutAmount = 1200, timeLeft = 3 },
}
local queryCount = 0
C_AuctionHouse = {
    QueryOwnedAuctions = function(sortOptions)
        assert(type(sortOptions) == "table" and sortOptions[1].sortOrder == 1, "query uses the validated sort shape")
        queryCount = queryCount + 1
    end,
    GetOwnedAuctions = function() return {} end,
    GetNumOwnedAuctions = function() return #auctions end,
    GetOwnedAuctionInfo = function(index) return auctions[index] end,
}

local function RunDueTimers()
    while true do
        local selected
        for index, timer in ipairs(timers) do
            if timer.at <= now and (not selected or timer.at < timers[selected].at) then selected = index end
        end
        if not selected then return end
        local timer = table.remove(timers, selected)
        timer.callback()
    end
end

local frameShown = true
AuctionHouseFrame = { IsShown = function() return frameShown end }
dofile("YiboVault/AuctionHouse.lua")
local auctionHouse = YiboVault.AuctionHouse

auctionHouse:OnEvent("AUCTION_HOUSE_SHOW")
now = 0.2
RunDueTimers()
assert(queryCount == 1 and auctionHouse.scan ~= nil, "opening any auction-house tab requests owned auctions")
auctionHouse:OnEvent("OWNED_AUCTIONS_UPDATED")
now = 0.4
RunDueTimers()
assert(replaceCount == 1 and #stored == 2, "updated event commits a complete owned-auction snapshot")
assert(stored[1].sourceClass == "listed" and stored[1].quantity == 3, "auction rows are listed stock with stack quantities")
assert(stored[1].buyoutAmount == 900 and stored[1].bidAmount == 300 and stored[1].timeLeft == 2, "optional auction facts are preserved")
assert(coverage.auction.status == "known", "successful nonempty snapshot becomes known")
assert(db.revision == 1, "first changed snapshot increments revision")

auctionHouse:Start("repeat")
auctionHouse:OnEvent("OWNED_AUCTIONS_UPDATED")
now = 0.61
RunDueTimers()
assert(replaceCount == 2 and db.revision == 1, "same-content repeat scan does not increment revision (replace=" .. replaceCount .. ", revision=" .. db.revision .. ", status=" .. tostring(auctionHouse.lastStatus) .. ")")

auctionHouse:Start("close-during-query")
frameShown = false
auctionHouse:OnEvent("AUCTION_HOUSE_CLOSED")
assert(replaceCount == 2 and #stored == 2, "closing before response preserves the last successful snapshot")

frameShown = true
auctionHouse.open = true
auctions[1].quantity = 4
auctionHouse:OnEvent("OWNED_AUCTIONS_UPDATED")
now = 0.82
RunDueTimers()
assert(replaceCount == 3 and stored[1].quantity == 4,
    "unsolicited owned updates refresh the snapshot after the initial scan finished")

local readEntry = C_AuctionHouse.GetOwnedAuctionInfo
C_AuctionHouse.GetOwnedAuctionInfo = function(index)
    if index == 2 then return nil end
    return readEntry(index)
end
auctionHouse:OnEvent("OWNED_AUCTIONS_UPDATED")
now = 1.03
RunDueTimers()
assert(replaceCount == 3 and #stored == 2 and errorCount == 1,
    "incomplete indexed results preserve the previous complete snapshot")
C_AuctionHouse.GetOwnedAuctionInfo = readEntry

auctions = {}
auctionHouse:OnEvent("OWNED_AUCTIONS_UPDATED")
now = 1.24
RunDueTimers()
assert(replaceCount == 4 and #stored == 0 and coverage.auction.status == "known-empty",
    "a valid empty owned update clears previous listings")

frameShown = false
auctionHouse:OnEvent("AUCTION_HOUSE_CLOSED")
auctionHouse:OnEvent("OWNED_AUCTIONS_UPDATED")
now = 1.45
RunDueTimers()
assert(replaceCount == 4, "owned updates received after closing cannot overwrite the snapshot")

print("AuctionHouseSpec: OK")
