local Addon = _G.YiboVault
local function Read(fn, ...)
    if type(fn) ~= "function" then error("auction-api-unavailable") end
    local ok, value = pcall(fn, ...)
    if not ok then error("auction-api-read-failed") end
    if type(issecretvalue) == "function" and issecretvalue(value) then error("restricted-auction-value") end
    return value
end
local function Integer(value, minimum, maximum)
    if type(issecretvalue) == "function" and issecretvalue(value) then error("restricted-auction-value") end
    if type(value) ~= "number" or value ~= math.floor(value) or value < minimum or value > maximum then error("invalid-auction-number") end
    return value
end
function Addon:IsAuctionReadable()
    if not self._inWorld or not self._auctionOpen then return false end
    if AuctionHouseFrame and type(AuctionHouseFrame.IsShown) == "function" and not AuctionHouseFrame:IsShown() then return false end
    return true
end
function Addon:StaleAuctions()
    local current = self.Core.Characters:GetCurrentID()
    if current then self:MarkLocationStale(current, "auction", "auction") end
end
function Addon:OpenAuctions()
    self._auctionOpen, self._ready.auction = true, nil
    self._auctionPendingReason, self._auctionQueryWaiting = "auction-awaiting-results", false
    self._auctionToken = (self._auctionToken or 0) + 1
    local token = self._auctionToken
    self:StaleAuctions()
    -- The native show event can precede construction/display of its UI frame.
    local function Request()
        if self._auctionOpen and self._auctionToken == token then self:RequestOwnedAuctions() end
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.2, Request) else Request() end
    self.Core.AccountView:NotifyPageChanged("vault-items")
end
function Addon:RequestOwnedAuctions()
    if not self:IsAuctionReadable() then return nil, "auction-closed" end
    self._ready.auction, self._auctionQueryWaiting = nil, true
    self._auctionPendingReason = "auction-awaiting-results"
    self:StaleAuctions()
    self._auctionToken = (self._auctionToken or 0) + 1
    local token = self._auctionToken
    local ok, reason = pcall(function()
        if C_AuctionHouse and type(C_AuctionHouse.IsThrottledMessageSystemReady) == "function"
            and Read(C_AuctionHouse.IsThrottledMessageSystemReady) ~= true then return "auction-throttled" end
        Read(C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions, {})
    end)
    if not ok then
        self._auctionPendingReason, self._auctionQueryWaiting = nil, false
        self:MarkLocationError("auction", "auction", { container = "auction" }, tostring(reason))
        return nil, "read-failed"
    end
    if reason then self._auctionPendingReason = reason end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(8, function()
            if self._auctionToken == token and self._auctionOpen and self._auctionQueryWaiting then
                self.Core.AccountView:NotifyPageChanged("vault-items")
            end
        end)
    end
    self.Core.AccountView:NotifyPageChanged("vault-items")
    return true
end
local function Capture(character)
    local active = Enum and Enum.AuctionStatus and Enum.AuctionStatus.Active
    local sold = Enum and Enum.AuctionStatus and Enum.AuctionStatus.Sold
    if type(active) ~= "number" or type(sold) ~= "number" or active == sold then error("auction-status-unavailable") end
    local count = Integer(Read(C_AuctionHouse.GetNumOwnedAuctions), 0, 10000)
    local records, entries = {}, {}
    for index = 1, count do
        local entry = Read(C_AuctionHouse.GetOwnedAuctionInfo, index)
        if type(entry) ~= "table" then error("auction-entry-unavailable") end
        local id = Integer(entry.auctionID, 1, 9007199254740991)
        local status = Integer(entry.status, 0, 2147483647)
        if entries[id] or (status ~= active and status ~= sold) then error("invalid-owned-auction") end
        local signature = { status = status }
        entries[id] = signature
        if status == active then
            if type(entry.itemKey) ~= "table" then error("auction-item-key-unavailable") end
            local itemID = Integer(entry.itemKey.itemID, 1, 2147483647)
            local quantity = Integer(entry.quantity, 1, 2147483647)
            local link = entry.itemLink
            if type(issecretvalue) == "function" and issecretvalue(link) then error("restricted-auction-value") end
            if link ~= nil then
                if type(link) ~= "string" then error("invalid-auction-link") end
                local linkID = tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
                if linkID ~= itemID then error("auction-link-mismatch") end
            end
            local record = Addon.BuildItemRecord("auction", character, "auction", index, itemID, quantity, link)
            record.sourceID, record.auctionID = "auction:" .. character.id .. ":" .. string.format("%.0f", id), id
            record.sourceClass, record.status, record.stackCount = "listed", status, quantity
            signature.itemID, signature.quantity, signature.link = itemID, quantity, link
            records[#records + 1] = record
        end
    end
    return records, entries, count
end
local function Stage()
    if not Addon._ready.auction then return nil, Addon._auctionPendingReason or "auction-awaiting-results" end
    if Read(C_AuctionHouse and C_AuctionHouse.HasFullOwnedAuctionResults) ~= true then return nil, "auction-incomplete" end
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not character then error("current-character-unavailable") end
    local revision = Addon._auctionResultsRevision
    local records, entries, count = Capture(character)
    local _, after, finalCount = Capture(character)
    if finalCount ~= count then error("auction-count-changed") end
    for id, entry in pairs(entries) do
        local other = after[id]
        if not other or other.status ~= entry.status or other.itemID ~= entry.itemID or other.quantity ~= entry.quantity or other.link ~= entry.link then error("auction-content-changed") end
    end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not Addon:IsAuctionReadable() or not current or current.id ~= character.id or revision ~= Addon._auctionResultsRevision then return nil, "auction-context-changed" end
    if Read(C_AuctionHouse.HasFullOwnedAuctionResults) ~= true then return nil, "auction-incomplete" end
    table.sort(records, function(a, b) return a.auctionID < b.auctionID end)
    return { records = records, characterID = character.id }
end
function Addon:ScanAuctions()
    if not self:IsAuctionReadable() then return nil, "auction-closed" end
    if not self._ready.auction and not self._auctionQueryWaiting then return nil, "auction-not-ready" end
    local ok, result, reason = pcall(Stage)
    if not ok then
        self._auctionPendingReason, self._auctionQueryWaiting = nil, false
        self:MarkLocationError("auction", "auction", { container = "auction" }, tostring(result))
        return nil, "read-failed"
    end
    if not result then
        self._auctionPendingReason = reason
        self:StaleAuctions()
        self.Core.AccountView:NotifyPageChanged("vault-items")
        return nil, reason
    end
    self._auctionPendingReason, self._auctionQueryWaiting = nil, false
    self:ReplaceLocation(result.characterID, "auction", "auction", result.records, { container = "auction" })
    return true
end
function Addon:CloseAuctions()
    self._auctionOpen, self._auctionQueryWaiting, self._auctionPendingReason = false, false, nil
    self._auctionToken = (self._auctionToken or 0) + 1
    if self._ready then self._ready.auction = nil end
    self:StaleAuctions()
    self.Core.AccountView:NotifyPageChanged("vault-items")
end
