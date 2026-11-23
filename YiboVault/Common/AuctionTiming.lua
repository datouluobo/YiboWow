local Addon = _G.YiboVault
local Timing = {}; Addon.AuctionTiming = Timing
local DAY = 86400

function Timing:ReadObservation(auction, record)
    local status = Enum and Enum.AuctionStatus
    local id = record.auctionID
    if not status or type(id) ~= "number" or id <= 0 or id % 1 ~= 0 then return end
    local bid, bidder, seconds = auction.bidAmount, auction.bidder, auction.timeLeftSeconds
    if type(issecretvalue) == "function" and (issecretvalue(auction.status) or issecretvalue(bid)
        or issecretvalue(bidder) or issecretvalue(seconds)) then return end
    local active = auction.status == status.Active and type(status.Active) == "number"
    if not active and auction.status ~= status.Sold then return end
    if not active or (bid ~= nil and bid ~= 0) or (bidder ~= nil and bidder ~= "") then
        return { auctionID = id, excluded = true }
    end
    return { auctionID = id, itemID = record.itemID, quantity = record.quantity,
        seconds = type(seconds) == "number" and seconds >= 0 and seconds < math.huge and seconds or nil }
end

local function NotifyChanged(characterID, now)
    local ref = Addon.Items.serviceRef
    if ref then
        Addon.Core.Contracts:NotifyChanged(Addon.NAME, ref, { source = "auction", reason = "auction-timing",
            characterID = characterID, observedAt = now })
    end
end

local function Prune(entries, now)
    for id, entry in pairs(entries) do
        local untilAt = entry.endedAt and entry.endedAt + 90 * DAY or (entry.endsAt or entry.observedAt) + 7 * DAY
        if now >= untilAt then entries[id] = nil end
    end
end

function Timing:Prune()
    local now, clock = Addon:Now()
    if clock ~= "server" then return end
    for _, character in pairs(Addon.db.byCharacter) do
        if character.auctionTimings then Prune(character.auctionTimings, now) end
    end
end

function Timing:Commit(characterID, observations, complete)
    local now, clock = Addon:Now()
    if clock ~= "server" then return end
    local store = Addon:GetCharacterStore(characterID)
    local entries = store.auctionTimings or {}; store.auctionTimings = entries
    local changed, present = false, {}
    for _, row in ipairs(observations) do
        local id = row.auctionID
        local old = entries[id]
        present[id] = true
        if row.excluded then
            if old and not old.endedAt then entries[id] = nil; changed = true end
        elseif not (old and old.endedAt) then
            local endsAt = row.seconds and now + row.seconds or (old and old.endsAt)
            if old and endsAt and old.endsAt and math.abs(endsAt - old.endsAt) <= 2 then endsAt = old.endsAt end
            if not old or old.status ~= "active" or old.endsAt ~= endsAt or old.quantity ~= row.quantity or old.itemID ~= row.itemID then
                changed = true
            end
            entries[id] = { auctionID = id, itemID = row.itemID, quantity = row.quantity,
                status = "active", endsAt = endsAt, observedAt = now }
        end
    end
    if complete then
        for id, entry in pairs(entries) do
            if not present[id] and entry.status == "active" then
                entry.status = "unverified"
                changed = true
            end
        end
    end
    Prune(entries, now)
    if changed then NotifyChanged(characterID, now) end
end

function Timing:OnEvent(event, id)
    if event ~= "AUCTION_HOUSE_AUCTIONS_EXPIRED" and event ~= "AUCTION_CANCELED" then return end
    local now, clock = Addon:Now()
    if clock ~= "server" then return end
    local characterID = Addon.Core.Characters:GetCurrentID()
    local store = characterID and Addon:GetCharacterStore(characterID)
    local entries = store and store.auctionTimings
    local entry = entries and entries[id]
    if not entry or entry.endedAt then return end
    if event == "AUCTION_CANCELED" then
        entries[id] = nil
    else
        entry.endedAt, entry.status = now, "expired"
    end
    NotifyChanged(characterID, now)
end

function Timing:RegisterEvents(frame)
    for _, event in ipairs({ "AUCTION_HOUSE_AUCTIONS_EXPIRED", "AUCTION_CANCELED" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
end

function Timing:GetByCharacter(characterID, now)
    local store = Addon:GetCharacterStore(characterID)
    local coverage = store and store.coverage and store.coverage.auction and store.coverage.auction.auction
    local result = { status = coverage and coverage.status or "not-yet-scanned", observedAt = coverage and coverage.observedAt, records = {} }
    for _, entry in pairs(store and store.auctionTimings or {}) do
        if (entry.status == "active" and entry.endsAt and entry.endsAt > now)
            or (entry.endedAt and now < entry.endedAt + 90 * DAY) then
            result.records[#result.records + 1] = Addon.Copy(entry)
        end
    end
    return result
end
