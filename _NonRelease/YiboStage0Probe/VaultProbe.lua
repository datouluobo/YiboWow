local Addon = _G.YiboStage0Probe

local function ContainerFunctions()
    if type(C_Container) == "table" then
        return C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo, C_Container.GetContainerItemLink, "C_Container"
    end
    return GetContainerNumSlots, GetContainerItemInfo, GetContainerItemLink, "legacy"
end

local function ReadContainerItem(getInfo, getLink, bagID, slotID)
    local ok, infoResults = Addon:SafeCall("GetContainerItemInfo", getInfo, bagID, slotID)
    if not ok then return { slot = slotID, error = infoResults.error } end
    local info = infoResults[1]
    local record = { slot = slotID }
    if type(info) == "table" then
        record.itemID = info.itemID
        record.count = info.stackCount or info.count
        record.locked = info.isLocked
        record.quality = info.quality
        record.link = Addon:DescribeItemLink(info.hyperlink)
    else
        record.count = infoResults[2]
        record.locked = infoResults[3]
        record.quality = infoResults[4]
        record.link = Addon:DescribeItemLink(infoResults[7])
    end
    if type(getLink) == "function" and not (record.link and record.link.present) then
        local linkOK, linkResults = Addon:SafeCall("GetContainerItemLink", getLink, bagID, slotID)
        if linkOK then record.link = Addon:DescribeItemLink(linkResults[1]) end
    end
    record.itemID = record.itemID or (record.link and record.link.itemID)
    if not record.itemID and not (record.count and record.count > 0) and not (record.link and record.link.present) then return nil end
    return record
end

function Addon:ReadContainer(bagID)
    local getSlots, getInfo, getLink, apiFamily = ContainerFunctions()
    local payload = { bagID = bagID, apiFamily = apiFamily, apiAvailable = type(getSlots) == "function" and type(getInfo) == "function" }
    if not payload.apiAvailable then return payload end
    local ok, slotResults = self:SafeCall("GetContainerNumSlots", getSlots, bagID)
    if not ok then payload.error = slotResults.error; return payload end
    payload.numSlots = tonumber(slotResults[1]) or 0
    payload.items = {}
    for slotID = 1, payload.numSlots do
        local item = ReadContainerItem(getInfo, getLink, bagID, slotID)
        if item then payload.items[#payload.items + 1] = item end
    end
    payload.itemCount = #payload.items
    return payload
end

function Addon:ProbeBags()
    local maximum = tonumber(_G.NUM_BAG_SLOTS) or 4
    local payload = { range = { first = 0, last = maximum }, containers = {} }
    for bagID = 0, maximum do payload.containers[#payload.containers + 1] = self:ReadContainer(bagID) end
    self:AddSample("vault.bags", payload)
    self:Print("背包探针完成：扫描 " .. #payload.containers .. " 个容器。")
    return payload
end

function Addon:ProbeEquipment()
    local firstSlot = tonumber(_G.INVSLOT_FIRST_EQUIPPED) or 1
    local lastSlot = tonumber(_G.INVSLOT_LAST_EQUIPPED) or 19
    local payload = { firstSlot = firstSlot, lastSlot = lastSlot, apiAvailable = type(GetInventoryItemID) == "function", items = {} }
    if payload.apiAvailable then
        for slotID = firstSlot, lastSlot do
            local itemID = GetInventoryItemID("player", slotID)
            local link = type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", slotID) or nil
            if itemID or link then
                payload.items[#payload.items + 1] = { slot = slotID, itemID = itemID, link = self:DescribeItemLink(link) }
            end
        end
    end
    payload.itemCount = #payload.items
    self:AddSample("vault.equipment", payload)
    self:Print("装备探针完成：记录 " .. payload.itemCount .. " 个已装备物品。")
    return payload
end

function Addon:ProbeBank()
    local bankContainer = tonumber(_G.BANK_CONTAINER) or -1
    local bagSlots = tonumber(_G.NUM_BAG_SLOTS) or 4
    local bankBagSlots = tonumber(_G.NUM_BANKBAGSLOTS) or 7
    local payload = {
        eventOpen = self.Runtime.bankOpen == true,
        frameShown = self:IsFrameShown("BankFrame"), -- 兼容旧样本；不能单独作为银行状态。
        frameVisibility = self:GetFrameVisibility({ "BankFrame", "BankPanel", "AccountBankPanel" }),
        bankContainer = bankContainer,
        bagRange = { first = bagSlots + 1, last = bagSlots + bankBagSlots },
        containers = { self:ReadContainer(bankContainer) },
    }
    for bagID = payload.bagRange.first, payload.bagRange.last do payload.containers[#payload.containers + 1] = self:ReadContainer(bagID) end
    payload.readableContainerCount = 0
    payload.totalSlots = 0
    payload.itemCount = 0
    payload.baseContainerSlots = 0
    payload.bankBagSlots = 0
    for index, container in ipairs(payload.containers) do
        if container.apiAvailable and container.error == nil and type(container.numSlots) == "number" then
            payload.readableContainerCount = payload.readableContainerCount + 1
            payload.totalSlots = payload.totalSlots + container.numSlots
            payload.itemCount = payload.itemCount + (container.itemCount or 0)
            if index == 1 then
                payload.baseContainerSlots = container.numSlots
            else
                payload.bankBagSlots = payload.bankBagSlots + container.numSlots
            end
        end
    end
    payload.openEvidence = payload.eventOpen and "event"
        or (self:IsBankOpen() and "visible-frame")
        or "none"
    payload.accessible = payload.openEvidence ~= "none"
    payload.cachedContainersReadable = payload.totalSlots > 0
    payload.containerExposure = payload.totalSlots == 0 and "none"
        or (payload.bankBagSlots > 0 and "base-plus-bank-bags")
        or "base-container-only"
    self:AddSample("vault.bank", payload)
    self:Print(string.format(
        "银行探针完成；open=%s，evidence=%s，BankFrame=%s，slots=%d，exposure=%s。",
        tostring(payload.accessible), payload.openEvidence, tostring(payload.frameShown), payload.totalSlots, payload.containerExposure
    ))
    return payload
end

function Addon:ReadGuildBankTab(tabID)
    local tab = { tabID = tabID, maxSlots = tonumber(_G.MAX_GUILDBANK_SLOTS_PER_TAB) or 98, items = {} }
    if type(GetGuildBankTabInfo) == "function" then
        local ok, results = self:SafeCall("GetGuildBankTabInfo", GetGuildBankTabInfo, tabID)
        tab.tabInfoOK = ok
        if ok then
            tab.name = self:DescribePrivateString(results[1])
            tab.iconPresent = results[2] ~= nil
            tab.isViewable = results[3]
            tab.canDeposit = results[4]
            tab.numWithdrawals = results[5]
            tab.remainingWithdrawals = results[6]
        else
            tab.tabInfoError = results.error
        end
    end
    if type(GetGuildBankItemInfo) ~= "function" then tab.error = "missing-item-api"; return tab end
    for slotID = 1, tab.maxSlots do
        local ok, results = self:SafeCall("GetGuildBankItemInfo", GetGuildBankItemInfo, tabID, slotID)
        if ok then
            local link = type(GetGuildBankItemLink) == "function" and GetGuildBankItemLink(tabID, slotID) or nil
            local count = results[2]
            if link or (type(count) == "number" and count > 0) then
                tab.items[#tab.items + 1] = { slot = slotID, count = count, link = self:DescribeItemLink(link) }
            end
        else
            tab.error = results.error
            break
        end
    end
    tab.itemCount = #tab.items
    return tab
end

function Addon:ProbeGuildBank()
    local payload = {
        frameShown = self:IsFrameShown("GuildBankFrame"),
        api = {
            getTabs = type(GetNumGuildBankTabs) == "function",
            getCurrentTab = type(GetCurrentGuildBankTab) == "function",
            getInfo = type(GetGuildBankItemInfo) == "function",
            getLink = type(GetGuildBankItemLink) == "function",
        },
        tabs = {},
    }
    local tabCount = type(GetNumGuildBankTabs) == "function" and (GetNumGuildBankTabs() or 0) or 0
    local currentTab = type(GetCurrentGuildBankTab) == "function" and GetCurrentGuildBankTab() or nil
    payload.tabCount, payload.currentTab = tabCount, currentTab
    if payload.api.getInfo and type(currentTab) == "number" and currentTab > 0 then
        payload.tabs[#payload.tabs + 1] = self:ReadGuildBankTab(currentTab)
    end
    self:AddSample("vault.guild-bank", payload)
    self:Print("公会银行探针完成；当前页签=" .. tostring(currentTab) .. "。")
    return payload
end

function Addon:FinishGuildBankAllProbe(reason)
    local state = self.GuildBankAllState
    if not state then return end
    state.payload.finishedAt = self:Now()
    state.payload.finishReason = reason or "complete"
    state.payload.completedTabs = #state.payload.tabs
    self:AddSample("vault.guild-bank-all", state.payload)
    self.GuildBankAllState = nil
    self:Print(string.format(
        "公会银行全页探针完成：%d / %d 页，结果=%s。",
        state.payload.completedTabs, state.payload.requestedTabs, state.payload.finishReason
    ))
end

function Addon:RequestNextGuildBankTab()
    local state = self.GuildBankAllState
    if not state then return end
    state.index = state.index + 1
    local tabID = state.queue[state.index]
    if not tabID then self:FinishGuildBankAllProbe("complete"); return end
    state.waitingTab = tabID
    state.requestToken = state.requestToken + 1
    local token = state.requestToken
    local ok, results = self:SafeCall("QueryGuildBankTab", QueryGuildBankTab, tabID)
    if not ok then
        state.payload.tabs[#state.payload.tabs + 1] = { tabID = tabID, queryError = results.error }
        self:RequestNextGuildBankTab()
        return
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(2, function()
            local current = Addon.GuildBankAllState
            if current and current.requestToken == token and current.waitingTab == tabID then
                local tab = Addon:ReadGuildBankTab(tabID)
                tab.response = "timeout-fallback"
                current.payload.tabs[#current.payload.tabs + 1] = tab
                current.waitingTab = nil
                Addon:RequestNextGuildBankTab()
            end
        end)
    end
end

function Addon:HandleGuildBankSlotsChanged()
    local state = self.GuildBankAllState
    if not (state and state.waitingTab) then return end
    local tabID, token = state.waitingTab, state.requestToken
    state.waitingTab = nil
    local capture = function()
        local current = Addon.GuildBankAllState
        if not (current and current.requestToken == token) then return end
        local tab = Addon:ReadGuildBankTab(tabID)
        tab.response = "event"
        current.payload.tabs[#current.payload.tabs + 1] = tab
        Addon:RequestNextGuildBankTab()
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.2, capture) else capture() end
end

function Addon:ProbeAllGuildBankTabs()
    if self.GuildBankAllState then self:Print("公会银行全页探针正在运行。"); return nil end
    local open = self.Runtime.guildBankOpen or self:IsFrameShown("GuildBankFrame")
    local tabCount = type(GetNumGuildBankTabs) == "function" and (GetNumGuildBankTabs() or 0) or 0
    local payload = {
        frameShown = self:IsFrameShown("GuildBankFrame"),
        eventOpen = self.Runtime.guildBankOpen == true,
        queryAvailable = type(QueryGuildBankTab) == "function",
        tabCount = tabCount,
        requestedTabs = 0,
        tabs = {},
    }
    if not open then payload.error = "guild-bank-not-open"; self:AddSample("vault.guild-bank-all", payload); self:Print("请先打开公会银行。"); return payload end
    if not payload.queryAvailable then payload.error = "missing-query-api"; self:AddSample("vault.guild-bank-all", payload); self:Print("QueryGuildBankTab 不可用。"); return payload end
    local queue = {}
    for tabID = 1, tabCount do
        local viewable = nil
        if type(GetGuildBankTabInfo) == "function" then
            local ok, results = self:SafeCall("GetGuildBankTabInfo", GetGuildBankTabInfo, tabID)
            if ok then viewable = results[3] end
        end
        if viewable ~= false then queue[#queue + 1] = tabID end
    end
    payload.requestedTabs = #queue
    self.GuildBankAllState = { queue = queue, index = 0, requestToken = 0, payload = payload }
    self:Print("开始顺序请求 " .. #queue .. " 个可访问公会银行页签；请保持银行窗口打开。")
    self:RequestNextGuildBankTab()
    return payload
end

local function DescribeAuctionTable(auction)
    if type(auction) ~= "table" then return { valueType = type(auction) } end
    local itemKey = auction.itemKey
    return {
        auctionID = auction.auctionID,
        itemID = auction.itemID or (type(itemKey) == "table" and itemKey.itemID),
        quantity = auction.quantity,
        timeLeft = auction.timeLeft,
        buyoutAmount = auction.buyoutAmount,
        bidAmount = auction.bidAmount,
        status = auction.status,
    }
end

function Addon:ReadOwnedAuctionSnapshot(reason, queryRequested, querySent, response)
    local modern = type(C_AuctionHouse) == "table"
    local payload = {
        frameShown = self:IsFrameShown("AuctionHouseFrame"),
        eventOpen = self.Runtime.auctionHouseOpen == true,
        modern = modern,
        legacyAvailable = type(GetNumAuctionItems) == "function" and type(GetAuctionItemInfo) == "function",
        reason = reason or "manual-read",
        queryRequested = queryRequested == true,
        querySent = querySent,
        response = response or "immediate-read",
        items = {},
    }
    if modern then
        payload.modernAPI = {
            getOwnedAuctions = type(C_AuctionHouse.GetOwnedAuctions) == "function",
            getNumOwnedAuctions = type(C_AuctionHouse.GetNumOwnedAuctions) == "function",
            getOwnedAuctionInfo = type(C_AuctionHouse.GetOwnedAuctionInfo) == "function",
            queryOwnedAuctions = type(C_AuctionHouse.QueryOwnedAuctions) == "function",
        }
        if payload.modernAPI.getOwnedAuctions then
            local ok, results = self:SafeCall("GetOwnedAuctions", C_AuctionHouse.GetOwnedAuctions)
            if ok and type(results[1]) == "table" then
                for _, auction in ipairs(results[1]) do payload.items[#payload.items + 1] = DescribeAuctionTable(auction) end
            elseif not ok then payload.readError = results.error end
        elseif payload.modernAPI.getNumOwnedAuctions and payload.modernAPI.getOwnedAuctionInfo then
            local countOK, countResults = self:SafeCall("GetNumOwnedAuctions", C_AuctionHouse.GetNumOwnedAuctions)
            if countOK then
                payload.itemCountReported = tonumber(countResults[1]) or 0
                for index = 1, payload.itemCountReported do
                    local itemOK, itemResults = self:SafeCall("GetOwnedAuctionInfo", C_AuctionHouse.GetOwnedAuctionInfo, index)
                    if itemOK then payload.items[#payload.items + 1] = DescribeAuctionTable(itemResults[1])
                    else payload.readError = itemResults.error; break end
                end
            else
                payload.readError = countResults.error
            end
        end
    elseif payload.legacyAvailable then
        local ok, results = self:SafeCall("GetNumAuctionItems", GetNumAuctionItems, "owner")
        payload.itemCountReported = ok and results[1] or nil
        local count = tonumber(payload.itemCountReported) or 0
        for index = 1, count do
            local itemOK, itemResults = self:SafeCall("GetAuctionItemInfo", GetAuctionItemInfo, "owner", index)
            local link = type(GetAuctionItemLink) == "function" and GetAuctionItemLink("owner", index) or nil
            payload.items[#payload.items + 1] = {
                index = index,
                returns = itemOK and self:DescribeReturns(itemResults) or itemResults,
                link = self:DescribeItemLink(link),
            }
        end
    end
    payload.itemCount = #payload.items
    self:AddSample("vault.auction", payload)
    self:Print("拍卖行探针完成；记录 " .. payload.itemCount .. " 条本人上架数据。")
    return payload
end

function Addon:FinishOwnedAuctionProbe(reason, response, errorMessage)
    local state = self.OwnedAuctionState
    if not state then return nil end
    self.OwnedAuctionState = nil
    if errorMessage then
        local payload = {
            frameShown = self:IsFrameShown("AuctionHouseFrame"),
            eventOpen = self.Runtime.auctionHouseOpen == true,
            modern = type(C_AuctionHouse) == "table",
            reason = reason or state.reason,
            queryRequested = true,
            querySent = state.querySent,
            queryMethod = "QueryOwnedAuctions",
            response = response,
            queryError = errorMessage,
        }
        self:AddSample("vault.auction", payload)
        self:Print("拍卖行本人上架查询未完成：" .. tostring(errorMessage) .. "。")
        return payload
    end
    local payload = self:ReadOwnedAuctionSnapshot(reason or state.reason, true, state.querySent, response)
    payload.queryMethod = "QueryOwnedAuctions"
    return payload
end

function Addon:HandleOwnedAuctionsUpdated()
    local state = self.OwnedAuctionState
    if not state then return end
    local token = state.token
    local capture = function()
        local current = Addon.OwnedAuctionState
        if not (current and current.token == token) then return end
        Addon:FinishOwnedAuctionProbe(current.reason, "event")
    end
    if C_Timer and type(C_Timer.After) == "function" then C_Timer.After(0.2, capture) else capture() end
end

function Addon:StartOwnedAuctionProbe(reason)
    if self.OwnedAuctionState then
        self:Print("拍卖行本人上架查询正在等待更新事件。")
        return self.OwnedAuctionState
    end
    local open = self.Runtime.auctionHouseOpen or self:IsFrameShown("AuctionHouseFrame")
    if not open then
        local payload = { reason = reason, queryRequested = true, querySent = false, queryError = "auction-house-not-open" }
        self:AddSample("vault.auction", payload)
        self:Print("请先打开拍卖行。")
        return payload
    end
    if type(C_AuctionHouse) ~= "table" or type(C_AuctionHouse.QueryOwnedAuctions) ~= "function" then
        local payload = { reason = reason, queryRequested = true, querySent = false, queryError = "missing-query-api" }
        self:AddSample("vault.auction", payload)
        self:Print("C_AuctionHouse.QueryOwnedAuctions 不可用。")
        return payload
    end
    self.OwnedAuctionToken = (self.OwnedAuctionToken or 0) + 1
    local token = self.OwnedAuctionToken
    -- 先标记为已发起，兼容测试桩或客户端立即同步触发更新事件的情况。
    self.OwnedAuctionState = { token = token, reason = reason or "manual-query", querySent = true }
    local ok, results = self:SafeCall(
        "QueryOwnedAuctions",
        C_AuctionHouse.QueryOwnedAuctions,
        { { sortOrder = 1, reverseSort = false } }
    )
    local state = self.OwnedAuctionState
    if not ok then
        if state and state.token == token then state.querySent = false end
        return self:FinishOwnedAuctionProbe(reason, "query-error", results.error)
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(3, function()
            local current = Addon.OwnedAuctionState
            if current and current.token == token then
                Addon:FinishOwnedAuctionProbe(current.reason, "timeout", "owned-auctions-update-timeout")
            end
        end)
    end
    return self.OwnedAuctionState
end

function Addon:ProbeAuction(requestQuery)
    if requestQuery then return self:StartOwnedAuctionProbe("manual-query") end
    return self:ReadOwnedAuctionSnapshot("manual-read", false, nil, "immediate-read")
end
