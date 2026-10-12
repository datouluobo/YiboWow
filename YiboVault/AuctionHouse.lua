local Addon = _G.YiboVault
local AuctionHouse = {}
Addon.AuctionHouse = AuctionHouse

local function ParseItemID(link)
    if type(link) ~= "string" then return nil end
    local payload = link:match("|H[^:|]+:([^|]+)|h") or link:match("^[^:|]+:([^|]+)$")
    return payload and tonumber(payload:match("^(%-?%d+)")) or nil
end

local function ItemLink(itemID)
    if type(C_Item) == "table" and type(C_Item.GetItemLinkByID) == "function" then
        local ok, link = pcall(C_Item.GetItemLinkByID, itemID)
        if ok and type(link) == "string" then return link end
    end
    if type(GetItemInfo) == "function" then
        local ok, _, link = pcall(GetItemInfo, itemID)
        if ok and type(link) == "string" then return link end
    end
end

local function GetExpiryAt(observedAt, timeLeft, clockSource)
    if clockSource ~= "server" or timeLeft == nil or type(C_AuctionHouse) ~= "table"
        or type(C_AuctionHouse.GetTimeLeftBandInfo) ~= "function" then return nil end
    local ok, _, maxSeconds = pcall(C_AuctionHouse.GetTimeLeftBandInfo, timeLeft)
    if not ok or type(maxSeconds) ~= "number" or maxSeconds <= 0 then return nil end
    return observedAt + maxSeconds
end

local function MakeRecord(character, auction, index, previous)
    if type(auction) ~= "table" then return nil, "owned-auction-entry-invalid" end
    local itemKey = type(auction.itemKey) == "table" and auction.itemKey or {}
    local link = auction.itemLink or ItemLink(auction.itemID or itemKey.itemID)
    local itemID = tonumber(auction.itemID or itemKey.itemID) or ParseItemID(link)
    local quantity = tonumber(auction.quantity)
    if not itemID or itemID <= 0 then return nil, "owned-auction-item-id-unavailable" end
    if not quantity or quantity <= 0 then return nil, "owned-auction-quantity-invalid" end

    local auctionID = auction.auctionID
    local matchID = auctionID ~= nil and tostring(auctionID) or tostring(index)
    local itemKeyValue = "item:" .. itemID
    local variantKey = itemKeyValue
    local identityQuality = "item-id-only"
    if type(link) == "string" then
        local linkType, payload = link:match("|H([^:|]+):([^|]+)|h")
        if linkType and payload then
            variantKey = "link:" .. linkType .. ":" .. payload
            identityQuality = "full-link"
        end
    end
    local observedAt, clockSource = Addon:Now()
    local firstObservedAt = previous and (previous.firstObservedAt or previous.observedAt) or observedAt
    local expiryAt = previous and previous.expiryAt
        or (auctionID ~= nil and GetExpiryAt(firstObservedAt, auction.timeLeft, clockSource) or nil)
    return {
        sourceID = "auction:" .. character.id .. ":" .. matchID,
        source = "auction",
        sourceClass = "listed",
        itemID = itemID,
        itemLink = link,
        itemKey = itemKeyValue,
        variantKey = variantKey,
        identityQuality = identityQuality,
        quantity = math.floor(quantity),
        characterID = character.id,
        realm = character.realm,
        auctionID = auctionID,
        stackCount = math.floor(quantity),
        unitPrice = tonumber(auction.unitPrice),
        buyoutAmount = tonumber(auction.buyoutAmount),
        bidAmount = tonumber(auction.bidAmount),
        timeLeft = auction.timeLeft,
        firstObservedAt = firstObservedAt,
        expiryAt = expiryAt,
        expiryClockSource = expiryAt and (previous and previous.expiryClockSource or clockSource) or nil,
        status = auction.status,
        location = { container = "auction", slot = index },
        observedAt = observedAt,
        clockSource = clockSource,
        state = "observed",
    }
end

local function IsOpen()
    if AuctionHouse.open then return true end
    local frame = _G.AuctionHouseFrame
    return frame and type(frame.IsShown) == "function" and frame:IsShown() == true or false
end

function AuctionHouse:Finish(reason, errorMessage)
    local state = self.scan
    if not state then return end
    self.scan = nil
    if errorMessage then
        local character = Addon.Core and Addon.Core.Characters:GetCurrent()
        if character then
            Addon:MarkLocationError("auction", "auction", { auctionHouse = true }, errorMessage)
        end
        self.lastStatus = "error"
        self.lastResult = tostring(errorMessage)
        Addon:Print(Addon:T("ERROR.AUCTION_SCAN_FAILED", self.lastResult))
        return
    end
    if reason == "closed" then
        self.lastStatus = "closed"
        self.lastResult = Addon:T("TEXT.AUCTION_HOUSE_CLOSED_THE_EXISTING_SNAPSHOT_0389D9")
        return
    end

    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character or character.id ~= state.characterID then
        self.lastStatus = "error"
        self.lastResult = Addon:T("TEXT.THE_CHARACTER_CONTEXT_CHANGED_SCAN_RESULTS_5AE151")
        Addon:Print(Addon:T("ERROR.AUCTION_CONTEXT_CHANGED"))
        return
    end
    local changed, coverage = Addon:ReplaceLocation(character.id, "auction", "auction", state.records, {
        auctionHouse = true,
    })
    self.lastStatus = "complete"
    self.lastResult = string.format(Addon:T("TEXT.READ_D_AUCTION_LISTINGS_SUCCESSFULLY_S_F19F0F"), #state.records, changed and Addon:T("TEXT.CACHE_UPDATED_A90A54") or Addon:T("TEXT.NO_CONTENT_CHANGES_B20790"))
    return coverage
end

function AuctionHouse:Capture(reason)
    local state = self.scan
    if not state or not IsOpen() then return end
    local api = C_AuctionHouse
    if type(api) ~= "table" or type(api.GetNumOwnedAuctions) ~= "function"
        or type(api.GetOwnedAuctionInfo) ~= "function" then
        self:Finish(reason, Addon:T("TEXT.THE_CLIENT_OWNED_AUCTION_READ_API_IS_UNAVA_6B2EE2"))
        return
    end
    local ok, count = pcall(api.GetNumOwnedAuctions)
    if not ok or type(count) ~= "number" or count < 0 or count % 1 ~= 0 then
        self:Finish(reason, Addon:T("TEXT.COULD_NOT_READ_YOUR_OWNED_AUCTION_LISTINGS_E42147"))
        return
    end
    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character or character.id ~= state.characterID then
        self:Finish(reason, Addon:T("TEXT.CHARACTER_CONTEXT_IS_UNAVAILABLE_OR_HAS_CH_4082F8"))
        return
    end
    local records = {}
    local previousByID = {}
    for _, record in ipairs(Addon:GetCachedCharacterRecords(character.id, "auction")) do
        if record.auctionID ~= nil then previousByID[tostring(record.auctionID)] = record end
    end
    for index = 1, count do
        local readOK, auction = pcall(api.GetOwnedAuctionInfo, index)
        if not readOK or type(auction) ~= "table" then
            self:Finish(reason, Addon:T("TEXT.OWNED_AUCTION_DATA_IS_NOT_READY_60C9DB") .. index .. "/" .. count)
            return
        end
        local previous = auction.auctionID ~= nil and previousByID[tostring(auction.auctionID)] or nil
        local record, errorMessage = MakeRecord(character, auction, index, previous)
        if not record then
            self:Finish(reason, errorMessage)
            return
        end
        records[#records + 1] = record
    end
    local countOK, finalCount = pcall(api.GetNumOwnedAuctions)
    if not countOK or finalCount ~= count then
        self:Finish(reason, Addon:T("TEXT.OWNED_AUCTIONS_CHANGED_WHILE_BEING_READ_DE99D7"))
        return
    end
    table.sort(records, function(left, right) return left.sourceID < right.sourceID end)
    state.records = records
    self:Finish(reason)
    local currentTime, currentClock = Addon:Now()
    if currentClock == "server" then Addon:ExpireAuctions(currentTime) end
    self:ScheduleExpiry()
end

function AuctionHouse:ScheduleExpiry()
    if not (C_Timer and type(C_Timer.After) == "function") then return end
    self.expiryToken = (self.expiryToken or 0) + 1
    local token = self.expiryToken
    local now, clockSource = Addon:Now()
    if clockSource ~= "server" then return end
    for _, character in pairs(Addon.db.byCharacter or {}) do
        for _, locationItems in pairs(character.auction or {}) do
            for _, record in ipairs(locationItems) do
                if record.auctionID ~= nil and not record.expiryAt and record.clockSource == "server"
                    and type(record.observedAt) == "number" then
                    local expiryAt = GetExpiryAt(record.observedAt, record.timeLeft, "server")
                    if expiryAt then
                        record.firstObservedAt = record.firstObservedAt or record.observedAt
                        record.expiryAt = expiryAt
                        record.expiryClockSource = "server"
                    end
                end
            end
        end
    end
    Addon:ExpireAuctions(now)
    local nextExpiry
    for _, character in pairs(Addon.db.byCharacter or {}) do
        for _, locationItems in pairs(character.auction or {}) do
            for _, record in ipairs(locationItems) do
                if record.expiryClockSource == "server" and type(record.expiryAt) == "number"
                    and (not nextExpiry or record.expiryAt < nextExpiry) then
                    nextExpiry = record.expiryAt
                end
            end
        end
    end
    if not nextExpiry then return end
    local delay = math.max(1, math.min(nextExpiry - now, 3600))
    C_Timer.After(delay, function()
        if AuctionHouse.expiryToken ~= token then return end
        local currentTime, currentClock = Addon:Now()
        if currentClock == "server" then Addon:ExpireAuctions(currentTime) end
        AuctionHouse:ScheduleExpiry()
    end)
end

function AuctionHouse:Start(reason)
    if not IsOpen() then
        self.lastStatus, self.lastResult = "unavailable", Addon:T("TEXT.AUCTION_HOUSE_IS_NOT_OPEN_D3B28B")
        return false
    end
    if self.scan then return false end
    local api = C_AuctionHouse
    if type(api) ~= "table" or type(api.QueryOwnedAuctions) ~= "function" then
        self.lastStatus, self.lastResult = "unavailable", Addon:T("TEXT.THE_CLIENT_OWNED_AUCTION_QUERY_API_IS_UNAV_F9BCBD")
        Addon:Print(Addon:T("TEXT.AUCTION_SCAN_UNAVAILABLE_THE_CLIENT_OWNED_5EA810"))
        return false
    end
    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character then
        self.lastStatus, self.lastResult = "error", Addon:T("TEXT.THE_CURRENT_CHARACTER_CONTEXT_IS_UNAVAILAB_460E1B")
        return false
    end

    self.token = (self.token or 0) + 1
    local token = self.token
    self.scan = { token = token, characterID = character.id, reason = reason or "manual", records = {} }
    self.lastStatus, self.lastResult = "waiting", Addon:T("TEXT.OWNED_AUCTIONS_QUERIED_WAITING_FOR_THE_UPD_19B51D")
    local ok = pcall(api.QueryOwnedAuctions, { { sortOrder = 1, reverseSort = false } })
    if not ok then
        self:Finish(reason, Addon:T("TEXT.COULD_NOT_QUERY_YOUR_ACTIVE_AUCTIONS_6ED882"))
        return false
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(3, function()
            local current = AuctionHouse.scan
            if current and current.token == token then AuctionHouse:Finish("timeout", Addon:T("TEXT.TIMED_OUT_WAITING_FOR_THE_OWNED_AUCTION_UP_09F1FA")) end
        end)
    end
    return true
end

function AuctionHouse:OnEvent(event)
    if event == "AUCTION_HOUSE_SHOW" then
        self.open = true
        if self.scan then return end
        local start = function()
            if IsOpen() and not AuctionHouse.scan then AuctionHouse:Start("auto-open") end
        end
        if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.2, start) else start() end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        self.open = false
        self.token = (self.token or 0) + 1
        if self.scan then self:Finish("closed") end
        if self.lastStatus ~= "error" then self.lastStatus = "closed" end
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        if not IsOpen() then return end
        if not self.scan then
            local character = Addon.Core and Addon.Core.Characters:GetCurrent()
            if not character then return end
            self.token = (self.token or 0) + 1
            self.scan = { token = self.token, characterID = character.id,
                reason = "owned-update", records = {} }
        end
        local state = self.scan
        if not state or state.captureScheduled then return end
        state.captureScheduled = true
        local token = state.token
        local capture = function()
            local current = AuctionHouse.scan
            if current and current.token == token then AuctionHouse:Capture("updated-event") end
        end
        if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.2, capture) else capture() end
    end
end

function AuctionHouse:GetStatus()
    if self.scan then return self.lastStatus or "waiting", self.lastResult end
    return self.lastStatus or "idle", self.lastResult or Addon:T("TEXT.THE_AUCTION_HOUSE_HAS_NOT_BEEN_OPENED_THIS_449B5B")
end
