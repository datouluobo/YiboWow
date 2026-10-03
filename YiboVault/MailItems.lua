local Addon = _G.YiboVault
local MailItems = {}
Addon.MailItems = MailItems

local function ItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
end

local function MakeRecord(character, mailIndex, attachmentIndex, itemID, quantity, link, observedAt, clockSource)
    local linkType, payload
    if type(link) == "string" then
        linkType, payload = link:match("|H([^:|]+):([^|]+)|h")
        if not linkType then linkType, payload = link:match("^([^:|]+):([^|]+)$") end
    end
    local itemKey = "item:" .. itemID
    return {
        sourceID = "mail:" .. character.id .. ":" .. mailIndex .. ":" .. attachmentIndex,
        source = "mail", sourceClass = "external",
        itemID = itemID, itemLink = link, itemKey = itemKey,
        variantKey = linkType and payload and ("link:" .. linkType .. ":" .. payload) or itemKey,
        identityQuality = linkType and payload and "full-link" or "item-id-only",
        quantity = math.floor(quantity), characterID = character.id, realm = character.realm,
        location = { container = "inbox", slot = mailIndex, attachmentIndex = attachmentIndex },
        observedAt = observedAt, clockSource = clockSource, state = "observed",
    }
end

function MailItems:IsOpen()
    local frame = _G.MailFrame
    if frame and type(frame.IsShown) == "function" then return frame:IsShown() == true end
    return self.open == true
end

function MailItems:ScheduleScan(reason, delay, retries)
    self.scanToken = (self.scanToken or 0) + 1
    local token = self.scanToken
    local function Attempt(remaining)
        if self.scanToken ~= token or not self.open then return end
        if self:IsOpen() then
            local success = self:Scan(reason)
            if success or self.lastStatus ~= "error" then return end
        end
        if remaining <= 0 then
            if self.lastStatus == "error" then Addon:Print("邮箱附件扫描失败：" .. tostring(self.lastResult) .. "。") end
            return
        end
        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.5, function() Attempt(remaining - 1) end)
        end
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay or 0, function() Attempt(retries or 0) end)
    else
        Attempt(0)
    end
end

function MailItems:InstallFrameHooks()
    local frame = _G.MailFrame
    if not (frame and type(frame.HookScript) == "function") or self.hookedFrame == frame then return false end
    frame:HookScript("OnShow", function()
        MailItems.open = true
        MailItems:ScheduleScan("mail-frame-show", 0.8, 3)
    end)
    frame:HookScript("OnHide", function() MailItems:OnEvent("MAIL_CLOSED") end)
    self.hookedFrame = frame
    if type(frame.IsShown) == "function" and frame:IsShown() then
        self.open = true
        self:ScheduleScan("mail-frame-already-open", 0.8, 3)
    end
    return true
end

function MailItems:Fail(message)
    self.lastStatus, self.lastResult = "error", message
    if self:IsOpen() and type(Addon.MarkLocationError) == "function" then
        Addon:MarkLocationError("mail", "inbox", { container = "inbox" }, message)
    end
    return false
end

function MailItems:Scan(reason)
    local current = Addon.Core and Addon.Core.Characters:GetCurrent()
    local provided = current and Addon.MailProvider and Addon.MailProvider:GetSnapshot(current.id)
    if provided then
        self.lastStatus, self.lastResult = provided.coverage.inbox.status, "YiboMail API"
        return true, false, Addon.Copy(provided.coverage.inbox)
    end
    if not self:IsOpen() then
        self.lastStatus, self.lastResult = "closed", "邮箱未打开，保留已有快照"
        return false
    end
    local character = Addon.Core and Addon.Core.Characters:GetCurrent()
    if not character then
        return self:Fail("当前角色不可用")
    end
    if type(GetInboxNumItems) ~= "function" or type(GetInboxHeaderInfo) ~= "function"
        or type(GetInboxItem) ~= "function" or type(GetInboxItemLink) ~= "function" then
        return self:Fail("邮箱附件 API 不可用")
    end
    local ok, currentCount, totalCount = pcall(GetInboxNumItems)
    currentCount, totalCount = tonumber(currentCount), tonumber(totalCount)
    if not ok or not currentCount or not totalCount or currentCount < 0 or totalCount < currentCount then
        return self:Fail("邮箱数量读取失败")
    end
    local records, observedAt, clockSource = {}, Addon:Now()
    local attachmentSlots = tonumber(ATTACHMENTS_MAX_RECEIVE) or 16
    for mailIndex = 1, currentCount do
        local header = { pcall(GetInboxHeaderInfo, mailIndex) }
        if not header[1] then
            return self:Fail("邮件头读取失败：" .. mailIndex)
        end
        local expectedAttachments = tonumber(header[9])
        if not expectedAttachments or expectedAttachments < 0 or expectedAttachments > attachmentSlots then
            return self:Fail("邮件头附件数量尚未就绪：" .. mailIndex)
        end
        local foundAttachments = 0
        for attachmentIndex = 1, attachmentSlots do
            local itemOK, _, itemID, _, quantity = pcall(GetInboxItem, mailIndex, attachmentIndex)
            local linkOK, link = pcall(GetInboxItemLink, mailIndex, attachmentIndex)
            if not itemOK or not linkOK then
                return self:Fail("附件读取失败：" .. mailIndex .. "/" .. attachmentIndex)
            end
            itemID = tonumber(itemID) or ItemIDFromLink(link)
            quantity = tonumber(quantity)
            if itemID or quantity or link then
                if not itemID or itemID <= 0 or not quantity or quantity <= 0 then
                    return self:Fail("附件身份或数量不完整：" .. mailIndex .. "/" .. attachmentIndex)
                end
                foundAttachments = foundAttachments + 1
                records[#records + 1] = MakeRecord(character, mailIndex, attachmentIndex,
                    itemID, quantity, link, observedAt, clockSource)
            end
        end
        if foundAttachments ~= expectedAttachments then
            return self:Fail("附件尚未完全载入：" .. mailIndex)
        end
    end
    local stillCurrent = Addon.Core.Characters:GetCurrent()
    if not self:IsOpen() or not stillCurrent or stillCurrent.id ~= character.id then
        self.lastStatus, self.lastResult = "closed", "邮箱或角色状态已变化，保留已有快照"
        return false
    end
    table.sort(records, function(left, right) return left.sourceID < right.sourceID end)
    local unscannedCount = totalCount - currentCount
    local status = unscannedCount > 0 and "partial" or (#records > 0 and "known" or "known-empty")
    local changed, coverage = Addon:ReplaceLocation(character.id, "mail", "inbox", records,
        { container = "inbox" }, nil,
        { status = status, currentCount = currentCount, totalCount = totalCount, unscannedCount = unscannedCount })
    self.lastStatus = status
    self.lastResult = string.format("可见 %d/%d 封、附件 %d 件；%s", currentCount, totalCount, #records,
        changed and "缓存已更新" or "内容未变化")
    return true, changed, coverage
end

function MailItems:OnEvent(event)
    if event == "MAIL_SHOW" then
        self.open = true
        self:InstallFrameHooks()
        self:ScheduleScan("mail-show", 0.8, 3)
    elseif event == "MAIL_CLOSED" then
        self.open = false
        self.scanToken = (self.scanToken or 0) + 1
    elseif event == "MAIL_INBOX_UPDATE" and (self.open or self:IsOpen()) then
        self.open = true
        self:ScheduleScan("inbox-update", 0.2, 3)
    end
end

function MailItems:GetStatus()
    return self.lastStatus or "idle", self.lastResult or "尚未在本次会话扫描邮箱"
end
