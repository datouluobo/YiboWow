local Addon = _G.YiboVault
local function Pack(...) return { n = select("#", ...), ... } end
local function Read(fn, ...)
    if type(fn) ~= "function" then error("mail-api-unavailable") end
    local result = Pack(pcall(fn, ...))
    if not result[1] then error("mail-api-read-failed") end
    for index = 2, result.n do
        if type(issecretvalue) == "function" and issecretvalue(result[index]) then error("restricted-mail-value") end
    end
    return unpack(result, 2, result.n)
end
local function Integer(value, minimum, maximum)
    if type(issecretvalue) == "function" and issecretvalue(value) then error("restricted-mail-value") end
    if type(value) ~= "number" or value ~= math.floor(value) or value < minimum or value > maximum then error("invalid-mail-number") end
    return value
end
local function Counts()
    local loaded, total = Read(GetInboxNumItems)
    return Integer(loaded, 0, 1000), Integer(total, 0, 100000)
end
local function Header(index, slots)
    local values = Pack(Read(GetInboxHeaderInfo, index))
    -- An attachment-free letter can have a nil item count; an unloaded header
    -- also lacks its subject and must not be interpreted as an empty letter.
    if type(values[4]) ~= "string" then error("mail-header-unavailable") end
    local count = values[8]
    values[8] = count == nil and 0 or Integer(count, 0, slots)
    return values
end
function Addon:IsMailboxReadable()
    if not self._inWorld or not self._mailOpen then return false end
    if MailFrame and type(MailFrame.IsShown) == "function" and not MailFrame:IsShown() then return false end
    return true
end
local function Stage()
    if C_Mail and type(C_Mail.IsCommandPending) == "function" and Read(C_Mail.IsCommandPending) == true then return nil, "mail-command-pending" end
    local character = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not character then error("current-character-unavailable") end
    local loaded, total = Counts()
    if total < loaded then error("invalid-mail-count") end
    if loaded ~= total then return nil, "mail-incomplete" end
    if loaded == 0 and not Addon._ready.mail then return nil, "mail-awaiting-data" end
    local slots = Integer(ATTACHMENTS_MAX_RECEIVE, 1, 32)
    local records, headers = {}, {}
    for mailIndex = 1, loaded do
        local header = Header(mailIndex, slots)
        headers[mailIndex] = header
        local found = 0
        for attachment = 1, slots do
            local name, id, _, quantity, _, _, isCurrency = Read(GetInboxItem, mailIndex, attachment)
            local link = Read(GetInboxItemLink, mailIndex, attachment)
            if name ~= nil or id ~= nil or quantity ~= nil or link ~= nil then
                if isCurrency then error("currency-mail-attachment-unsupported") end
                Integer(id, 1, 2147483647); Integer(quantity, 1, 2147483647)
                if link ~= nil and type(link) ~= "string" then error("invalid-mail-link") end
                if link then
                    local linkID = tonumber(link:match("|Hitem:(%d+)") or link:match("^item:(%d+)"))
                    if linkID ~= id then error("mail-link-mismatch") end
                end
                local record = Addon.BuildItemRecord("mail", character, "inbox", mailIndex, id, quantity, link)
                record.sourceID = "mail:" .. character.id .. ":" .. mailIndex .. ":" .. attachment
                record.sourceClass = "external"
                record.location.attachmentIndex = attachment
                records[#records + 1] = record
                found = found + 1
            end
        end
        if found ~= header[8] then error("mail-attachments-incomplete") end
    end
    local finalLoaded, finalTotal = Counts()
    if finalLoaded ~= loaded or finalTotal ~= total then error("mail-count-changed") end
    for index = 1, loaded do
        local after = Header(index, slots)
        for _, field in ipairs({ 3, 4, 5, 6, 8 }) do
            if after[field] ~= headers[index][field] then error("mail-header-changed") end
        end
    end
    local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if not Addon:IsMailboxReadable() or not current or current.id ~= character.id then return nil, "mail-context-changed" end
    if C_Mail and type(C_Mail.IsCommandPending) == "function" and Read(C_Mail.IsCommandPending) == true then return nil, "mail-command-pending" end
    return { records = records, characterID = character.id, loaded = loaded, total = total }
end
function Addon:ScanMail()
    if self.MailProvider and self.MailProvider:Connect() then self._mailPendingReason = nil; return true end
    if not self:IsMailboxReadable() then return nil, "mail-closed" end
    local ok, result, reason = pcall(Stage)
    if not ok then
        self._mailPendingReason = nil
        self:MarkLocationError("mail", "inbox", { container = "inbox" }, tostring(result))
        return nil, "read-failed"
    end
    if not result then
        self._mailPendingReason = reason
        local current = self.Core.Characters:GetCurrentID()
        if current then self:MarkLocationStale(current, "mail", "inbox") end
        self.Core.AccountView:NotifyPageChanged("vault-items")
        return nil, reason
    end
    self._mailPendingReason = nil
    self:ReplaceLocation(result.characterID, "mail", "inbox", result.records, { container = "inbox" }, nil,
        { currentCount = result.loaded, totalCount = result.total, unscannedCount = 0 })
    return true
end
function Addon:CloseMail()
    self._mailOpen, self._mailPendingReason = false, nil
    if self._ready then self._ready.mail = nil end
    if self.MailProvider and self.MailProvider:Connect() then self.Core.AccountView:NotifyPageChanged("vault-items"); return end
    local current = self.Core.Characters:GetCurrentID()
    if current then self:MarkLocationStale(current, "mail", "inbox") end
    self.Core.AccountView:NotifyPageChanged("vault-items")
end
