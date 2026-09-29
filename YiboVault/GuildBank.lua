local Addon = _G.YiboVault
local GuildBank = {}
Addon.GuildBank = GuildBank

local function CurrentGuildIdentity()
    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character then return nil, "current-character-unavailable" end
    local name = type(GetGuildInfo) == "function" and GetGuildInfo("player") or nil
    name = name or (character.profile and character.profile.guild)
    if type(name) ~= "string" or name == "" then return nil, "guild-identity-unavailable" end
    local identity = { realm = character.realm, profile = { guild = name } }
    local guildKey = Addon:GetGuildIdentity(identity)
    if not guildKey then return nil, "guild-key-unavailable" end
    return {
        key = guildKey,
        name = name,
        realm = character.realm,
        visitorCharacterID = character.id,
    }
end

local function ParseItemID(link)
    if type(link) ~= "string" then return nil end
    local payload = link:match("|H[^:|]+:([^|]+)|h") or link:match("^[^:|]+:([^|]+)$")
    return payload and tonumber(payload:match("^(%-?%d+)")) or nil
end

local function BuildRecord(guild, tabID, tabName, slotID, itemID, quantity, link)
    itemID, quantity = tonumber(itemID), tonumber(quantity)
    if not itemID or itemID <= 0 or not quantity or quantity <= 0 then return nil end
    local linkType, payload
    if type(link) == "string" then linkType, payload = link:match("|H([^:|]+):([^|]+)|h") end
    local itemKey = "item:" .. itemID
    local observedAt, clockSource = Addon:Now()
    return {
        sourceID = "guild-bank:" .. guild.key .. ":" .. tostring(tabID) .. ":" .. tostring(slotID),
        source = "guild-bank",
        sourceClass = "physical",
        itemID = itemID,
        itemLink = link,
        itemKey = itemKey,
        variantKey = linkType and payload and ("link:" .. linkType .. ":" .. payload) or itemKey,
        identityQuality = linkType and payload and "full-link" or "item-id-only",
        quantity = math.floor(quantity),
        visitorCharacterID = guild.visitorCharacterID,
        realm = guild.realm,
        guildKey = guild.key,
        guildName = guild.name,
        location = { container = tabID, tabID = tabID, tabName = tabName, slot = slotID },
        observedAt = observedAt,
        clockSource = clockSource,
        state = "observed",
    }
end

local function ReadTab(guild, tabID)
    if type(GetGuildBankItemInfo) ~= "function" then return nil, "guild-bank-item-api-unavailable" end
    local tabName
    if type(GetGuildBankTabInfo) == "function" then
        local ok, name, _, viewable = pcall(GetGuildBankTabInfo, tabID)
        if not ok then return nil, "guild-bank-tab-info-failed" end
        if viewable == false then return nil, "guild-bank-tab-not-viewable" end
        tabName = type(name) == "string" and name or nil
    end
    local maxSlots = tonumber(MAX_GUILDBANK_SLOTS_PER_TAB) or 98
    local records = {}
    for slotID = 1, maxSlots do
        local ok, hasItem, quantity = pcall(GetGuildBankItemInfo, tabID, slotID)
        if not ok then return nil, "guild-bank-item-read-failed" end
        local link
        if type(GetGuildBankItemLink) == "function" then
            local linkOK, value = pcall(GetGuildBankItemLink, tabID, slotID)
            if not linkOK then return nil, "guild-bank-item-link-read-failed" end
            link = value
        end
        if hasItem or (tonumber(quantity) or 0) > 0 or link then
            local itemID = ParseItemID(link)
            if not itemID then return nil, "guild-bank-occupied-slot-without-item-id" end
            local record = BuildRecord(guild, tabID, tabName, slotID, itemID, quantity or 1, link)
            if record then records[#records + 1] = record end
        end
    end
    local capacity
    -- The slot limit must come from this client; a fallback scan limit is not
    -- evidence that the guild tab actually has that many usable slots.
    if type(MAX_GUILDBANK_SLOTS_PER_TAB) == "number" and MAX_GUILDBANK_SLOTS_PER_TAB > 0 then
        capacity = { totalSlots = MAX_GUILDBANK_SLOTS_PER_TAB, freeSlots = MAX_GUILDBANK_SLOTS_PER_TAB - #records }
    end
    return records, nil, tabName, capacity
end

local function IsOpen()
    return GuildBank.open == true
end

function GuildBank:OnFrameShown()
    if self.open and (self.scan or self.lastStatus == "complete") then return end
    self.open = true
    self.lastOpenSource = "GuildBankFrame.OnShow"
    self.lastStatus, self.lastResult = "starting", "已检测到 GuildBankFrame 显示，正在准备扫描"
    Addon:Print("已检测到公会银行窗口显示，正在准备扫描。")
    local ok, result = pcall(self.Start, self)
    if not ok then
        self.lastStatus, self.lastResult = "error", "窗口显示启动异常：" .. tostring(result)
        self.scan = nil
        Addon:Print("公会银行扫描启动异常；请执行 /yva status 查看诊断状态。")
    end
end

function GuildBank:InstallFrameHooks()
    local frame = _G.GuildBankFrame
    if not (frame and type(frame.HookScript) == "function") or self.hookedFrame == frame then return false end
    frame:HookScript("OnShow", function() GuildBank:OnFrameShown() end)
    frame:HookScript("OnHide", function()
        if GuildBank.open then GuildBank:OnEvent("GUILDBANKFRAME_CLOSED") end
    end)
    self.hookedFrame = frame
    if type(frame.IsShown) == "function" and frame:IsShown() then self:OnFrameShown() end
    return true
end

local function MarkTabError(state, tabID, reason)
    Addon:MarkGuildTabError(state.guild.key, state.guild.name, state.guild.realm, tabID, reason)
    state.failed = state.failed + 1
end

local function CommitTab(state, tabID)
    local records, err, tabName, capacity = ReadTab(state.guild, tabID)
    if not records then
        MarkTabError(state, tabID, err)
        return false
    end
    Addon:ReplaceGuildTab(state.guild.key, state.guild.name, state.guild.realm, tabID,
        state.guild.visitorCharacterID, records, tabName, capacity)
    state.completed = state.completed + 1
    return true
end

function GuildBank:Finish(reason)
    local state = self.scan
    if not state then return end
    self.scan = nil
    if reason == "closed" then
        self.lastResult = "扫描在窗口关闭时中止"
        self.lastStatus = "closed"
        return
    end
    self.lastResult = string.format("成功 %d/%d 个页签，失败 %d。", state.completed, #state.queue, state.failed)
    self.lastStatus = state.failed > 0 and "error" or "complete"
    Addon:Print("公会银行扫描完成：" .. self.lastResult)
end

function GuildBank:RequestNext()
    local state = self.scan
    if not (state and IsOpen()) then self:Finish("closed"); return end
    state.index = state.index + 1
    local tabID = state.queue[state.index]
    if not tabID then self:Finish("complete"); return end
    self.lastStatus = "waiting"
    self.lastResult = string.format("等待页签 %d 的客户端响应", tabID)
    if type(QueryGuildBankTab) ~= "function" then
        MarkTabError(state, tabID, "guild-bank-query-api-unavailable")
        self:RequestNext()
        return
    end
    state.waitingTab = tabID
    state.responseScheduled = false
    state.requestToken = state.requestToken + 1
    local token = state.requestToken
    local ok = pcall(QueryGuildBankTab, tabID)
    if not ok then
        state.waitingTab = nil
        MarkTabError(state, tabID, "guild-bank-query-failed")
        self:RequestNext()
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(3, function()
            local current = GuildBank.scan
            if current and current.requestToken == token and current.waitingTab == tabID then
                current.waitingTab = nil
                MarkTabError(current, tabID, "guild-bank-tab-update-timeout")
                GuildBank:RequestNext()
            end
        end)
    end
end

function GuildBank:Start()
    if not IsOpen() or self.scan then return false end
    local guild, identityError = CurrentGuildIdentity()
    if not guild then
        self.lastStatus, self.lastResult = "error", "未开始：" .. tostring(identityError)
        Addon:Print("公会银行未开始扫描：" .. tostring(identityError))
        return false
    end
    if type(GetNumGuildBankTabs) ~= "function" or type(QueryGuildBankTab) ~= "function" then
        self.lastStatus, self.lastResult = "error", "客户端缺少页签查询 API"
        Addon:Print("公会银行扫描不可用：客户端缺少页签查询 API。")
        return false
    end
    local countOK, tabCount = pcall(GetNumGuildBankTabs)
    if not countOK then
        self.lastStatus, self.lastResult = "error", "读取页签数量失败：" .. tostring(tabCount)
        Addon:Print("公会银行扫描失败：读取页签数量时发生错误。")
        return false
    end
    tabCount = tonumber(tabCount) or 0
    local queue = {}
    for tabID = 1, tabCount do
        local viewable
        if type(GetGuildBankTabInfo) == "function" then
            local ok, _, _, value = pcall(GetGuildBankTabInfo, tabID)
            if not ok then
                -- An unreadable permission bit is not evidence that the tab is absent.
                viewable = nil
            else
                viewable = value
            end
        end
        if viewable ~= false then queue[#queue + 1] = tabID end
    end
    self.token = (self.token or 0) + 1
    self.scan = { token = self.token, guild = guild, queue = queue, index = 0, requestToken = 0, completed = 0, failed = 0 }
    self.lastStatus = "scanning"
    self.lastResult = string.format("已启动，排队 %d 个可访问页签", #queue)
    self:RequestNext()
    return true
end

function GuildBank:HandleTabUpdate()
    local state = self.scan
    if state and state.waitingTab then
        if state.responseScheduled then return end
        state.responseScheduled = true
        local token, tabID = state.requestToken, state.waitingTab
        local capture = function()
            local current = GuildBank.scan
            if not (current and current.requestToken == token and current.waitingTab == tabID) then return end
            current.waitingTab = nil
            CommitTab(current, tabID)
            GuildBank:RequestNext()
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.2, capture) else capture() end
        return
    end
    if not IsOpen() then return end
    local tabID = type(GetCurrentGuildBankTab) == "function" and GetCurrentGuildBankTab() or nil
    local guild = CurrentGuildIdentity()
    if not (guild and type(tabID) == "number" and tabID > 0) then return end
    self.refreshToken = (self.refreshToken or 0) + 1
    local token = self.refreshToken
    local refresh = function()
        if not IsOpen() or GuildBank.refreshToken ~= token then return end
        local records, err, tabName = ReadTab(guild, tabID)
        if records then
            Addon:ReplaceGuildTab(guild.key, guild.name, guild.realm, tabID, guild.visitorCharacterID, records, tabName)
        else
            Addon:MarkGuildTabError(guild.key, guild.name, guild.realm, tabID, err)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, refresh) else refresh() end
end

function GuildBank:OnEvent(event)
    if event == "GUILDBANKFRAME_OPENED" then
        if self.open and (self.scan or self.lastStatus == "complete") then return end
        self.open = true
        self.lastOpenSource = "GUILDBANKFRAME_OPENED"
        self.lastStatus, self.lastResult = "starting", "已收到公会银行打开事件，正在准备扫描"
        Addon:Print("已检测到公会银行打开事件，正在准备扫描。")
        local ok, result = pcall(self.Start, self)
        if not ok then
            self.lastStatus, self.lastResult = "error", "打开事件启动异常：" .. tostring(result)
            self.scan = nil
            Addon:Print("公会银行扫描启动异常；请执行 /yva status 查看诊断状态。")
        end
    elseif event == "GUILDBANKFRAME_CLOSED" then
        self.open = false
        self.lastStatus = "closed"
        self.token = (self.token or 0) + 1
        if self.scan then
            local state = self.scan
            if state.waitingTab then MarkTabError(state, state.waitingTab, "guild-bank-closed-before-tab-update") end
            self.scan = nil
        end
    elseif event == "GUILDBANKBAGSLOTS_CHANGED" then
        self:HandleTabUpdate()
    end
end

function GuildBank:GetStatus()
    local scan = self.scan
    if scan then
        return self.lastStatus or "scanning", string.format("%d/%d 页已完成；失败 %d；等待页签 %s",
            scan.completed, #scan.queue, scan.failed, tostring(scan.waitingTab or "无"))
    end
    if self.lastResult then return self.lastStatus or "idle", self.lastResult end
    return self.open and "open" or "idle", self.open and "窗口已打开，尚未开始扫描" or "尚未收到打开事件"
end

function GuildBank:OnAddonLoaded(addonName)
    if addonName == "Blizzard_GuildBankUI" then self:InstallFrameHooks() end
end
