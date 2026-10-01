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

local function MakeRecord(character, auction, index)
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
        Addon:Print("拍卖行上架扫描失败，保留已有快照：" .. self.lastResult .. "。")
        return
    end
    if reason == "closed" then
        self.lastStatus = "closed"
        self.lastResult = "拍卖行已关闭；未用关闭状态覆盖已有快照"
        return
    end

    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character or character.id ~= state.characterID then
        self.lastStatus = "error"
        self.lastResult = "角色上下文已变化，未提交扫描结果"
        Addon:Print("拍卖行扫描结果未提交：角色上下文已变化。")
        return
    end
    local changed, coverage = Addon:ReplaceLocation(character.id, "auction", "auction", state.records, {
        auctionHouse = true,
    })
    self.lastStatus = "complete"
    self.lastResult = string.format("成功 %d 条上架记录；%s", #state.records, changed and "缓存已更新" or "内容未变化")
    return coverage
end

function AuctionHouse:Capture(reason)
    local state = self.scan
    if not state or not IsOpen() then return end
    local api = C_AuctionHouse
    if type(api) ~= "table" or type(api.GetOwnedAuctions) ~= "function" then
        self:Finish(reason, "客户端本人上架读取 API 不可用")
        return
    end
    local ok, auctions = pcall(api.GetOwnedAuctions)
    if not ok or type(auctions) ~= "table" then
        self:Finish(reason, "读取本人上架列表失败")
        return
    end
    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character or character.id ~= state.characterID then
        self:Finish(reason, "角色上下文不可用或已变化")
        return
    end
    local records = {}
    for index, auction in ipairs(auctions) do
        local record, errorMessage = MakeRecord(character, auction, index)
        if not record then
            self:Finish(reason, errorMessage)
            return
        end
        records[#records + 1] = record
    end
    table.sort(records, function(left, right) return left.sourceID < right.sourceID end)
    state.records = records
    self:Finish(reason)
end

function AuctionHouse:Start(reason)
    if not IsOpen() then
        self.lastStatus, self.lastResult = "unavailable", "拍卖行尚未打开"
        return false
    end
    if self.scan then return false end
    local api = C_AuctionHouse
    if type(api) ~= "table" or type(api.QueryOwnedAuctions) ~= "function" then
        self.lastStatus, self.lastResult = "unavailable", "客户端本人上架查询 API 不可用"
        Addon:Print("拍卖行扫描不可用：客户端本人上架查询 API 不可用。")
        return false
    end
    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character then
        self.lastStatus, self.lastResult = "error", "当前角色上下文不可用"
        return false
    end

    self.token = (self.token or 0) + 1
    local token = self.token
    self.scan = { token = token, characterID = character.id, reason = reason or "manual", records = {} }
    self.lastStatus, self.lastResult = "waiting", "已查询本人上架列表，等待更新事件"
    local ok = pcall(api.QueryOwnedAuctions, { { sortOrder = 1, reverseSort = false } })
    if not ok then
        self:Finish(reason, "发起本人上架查询失败")
        return false
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(3, function()
            local current = AuctionHouse.scan
            if current and current.token == token then AuctionHouse:Finish("timeout", "等待本人上架更新事件超时") end
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
    return self.lastStatus or "idle", self.lastResult or "尚未在本次会话打开拍卖行"
end
