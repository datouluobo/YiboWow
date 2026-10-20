local Addon = _G.YiboMail
local Items = { API_VERSION = 1, Events = { listeners = {} }, transfersCache = {} }; Addon.Items = Items
function Items:GetAPIVersion() return 1 end
function Items:GetCapabilities() return Addon.Copy(Addon.CAPABILITIES) end
function Items:HasCapability(name, minimumVersion)
    local version = Addon.CAPABILITIES[name]; return version ~= nil and version >= (tonumber(minimumVersion) or 1), version
end
function Items:GetRevision() return Addon.db and Addon.db.revision or 0 end
function Items:OnPublish(revision, transfersUnchanged)
    if not transfersUnchanged or self.transferDataRevision == nil then self.transferDataRevision = revision end
end
local function ItemVariantKey(item)
    if type(item) ~= "table" then return nil end
    if type(item.variantKey) == "string" and item.variantKey ~= "" then return item.variantKey end
    if type(item.itemLink) == "string" then
        local payload = item.itemLink:match("|H([^|]+)|h")
        if payload then return "link:" .. payload end
    end
    return type(item.itemID) == "number" and ("item:" .. item.itemID) or nil
end
local function AttachmentSignature(items)
    if type(items) ~= "table" or #items == 0 then return nil end
    local identities = {}
    for _, item in ipairs(items) do
        if type(item) ~= "table" or type(item.itemID) ~= "number" or type(item.quantity) ~= "number" then return nil end
        -- Item links can differ between the send and inbox APIs for the same
        -- item. Correlate the complete attachment multiset by item ID/count.
        identities[#identities + 1] = Addon.Encode({ item.itemID, item.quantity })
    end
    table.sort(identities)
    return Addon.Encode(identities)
end
local function TransferIndex(characters)
    local addresses, seen, index = {}, {}, { sends = {}, received = {}, returned = {} }
    for _, character in ipairs(characters) do
        if character.name and character.realm then
            addresses[Addon.Recipients:Key(character.name .. "-" .. character.realm)] = character
        end
    end
    local function Resolve(address, realm)
        local normalized = Addon.Recipients:Normalize(address, realm)
        return normalized and addresses[Addon.Recipients:Key(normalized)]
    end
    local function Evidence(owner, mail, stamp, identity, allowReturn)
        if not mail or type(stamp) ~= "number" or (mail.wasReturned and not allowReturn) then return end
        local other = Resolve(mail.sender, owner.realm)
        local attachmentKey = other and AttachmentSignature(mail.attachments)
        if not attachmentKey then return end
        -- Subjects are user-editable and can summarize only one attachment,
        -- so they must never participate in send/receipt correlation.
        local key = Addon.Encode({ owner.id, other.id, attachmentKey })
        local bucket = mail.wasReturned and index.returned or index.received
        bucket[key] = bucket[key] or {}
        local identityKey = Addon.Encode({ mail.wasReturned == true, key, identity })
        if seen[identityKey] then return end
        seen[identityKey] = true
        bucket[key][#bucket[key] + 1] = { at = stamp, id = identity }
    end
    -- Visit each mailbox/history once for the whole account, rather than
    -- rescanning every sender's history for each send and each recipient.
    for _, owner in ipairs(characters) do
        local snapshot = Addon.db.byCharacter[owner.id]
        for key, mail in pairs(snapshot and snapshot.records or {}) do
            if mail.state == "observed" or mail.wasReturned then
                Evidence(owner, mail, mail.observedAt, "inbox:" .. owner.id .. ":" .. key, true)
            end
        end
        for _, history in ipairs(snapshot and snapshot.history or {}) do
            if history.state == "discovered" or history.state == "collected-archived" then
                local mail = history.mail or history
                Evidence(owner, mail, history.observedAt or mail.observedAt,
                    "history:" .. owner.id .. ":" .. tostring(history.eventID or history.sourceMailKey or ""), history.state == "collected-archived")
            elseif history.state == "in-transit" and history.transferReview ~= "legacy-unverified" and type(history.recipient) == "string" then
                local recipient = Resolve(history.recipient, owner.realm)
                local attachmentKey = recipient and AttachmentSignature(history.attachments)
                if attachmentKey then
                    index.sends[recipient.id] = index.sends[recipient.id] or {}
                    local sends = index.sends[recipient.id]
                    sends[#sends + 1] = { history = history, sender = owner, attachmentKey = attachmentKey }
                end
            end
        end
    end
    for _, buckets in ipairs({ index.received, index.returned }) do
        for _, evidence in pairs(buckets) do
            table.sort(evidence, function(a, b) if a.at ~= b.at then return a.at < b.at end; return a.id < b.id end)
        end
    end
    return index
end
local function ConsumeEvidence(evidence, at, consumed)
    if not evidence then return false end
    -- Find the first sufficiently recent occurrence. Path compression skips
    -- already consumed occurrences even when sends are not timestamp ordered.
    local low, high = 1, #evidence + 1
    while low < high do
        local middle = math.floor((low + high) / 2)
        if evidence[middle].at < at then low = middle + 1 else high = middle end
    end
    local parents = consumed[evidence]
    if not parents then parents = {}; consumed[evidence] = parents end
    local function Next(slot)
        local result = slot
        while parents[result] do result = parents[result] end
        while parents[slot] do local nextSlot = parents[slot]; parents[slot] = result; slot = nextSlot end
        return result
    end
    local slot = Next(low)
    if slot > #evidence then return false end
    parents[slot] = Next(slot + 1)
    return true
end
function Items:GetTransfers(characterID)
    if type(characterID) ~= "string" or characterID == "" then return nil, "invalid-character-id" end
    local revision = self:GetRevision()
    local characters = Addon.Core and Addon.Core.Characters:GetAllCached() or {}
    local directory = {}
    for _, character in ipairs(characters) do
        directory[#directory + 1] = Addon.Encode({ character.id, character.name or "", character.realm or "" })
    end
    table.sort(directory)
    local cacheKey = Addon.Encode({ self.transferDataRevision or revision, table.concat(directory) })
    local cached = self.transfersCache[characterID]
    if cached and cached.cacheKey == cacheKey then
        local result = Addon.Copy(cached.result); result.revision = revision; return result
    end
    local target
    for _, character in ipairs(characters) do
        if character.id == characterID then target = character end
    end
    if not target then
        local empty = { apiVersion = 1, revision = revision, characterID = characterID, records = {} }
        self.transfersCache[characterID] = { cacheKey = cacheKey, result = empty }
        return Addon.Copy(empty)
    end

    if self.transferIndexKey ~= cacheKey then
        self.transferIndex = TransferIndex(characters)
        self.transferIndexKey = cacheKey
        self.transfersCache = {}
    end
    local index = self.transferIndex
    local consumed, consumedReturns, records = {}, {}, {}
    for _, candidate in ipairs(index.sends[characterID] or {}) do
        local history, senderCharacter = candidate.history, candidate.sender
        local sentAt = tonumber(history.observedAt or history.attemptedAt) or 0
        local receiptKey = Addon.Encode({ characterID, senderCharacter.id, candidate.attachmentKey })
        local returnKey = Addon.Encode({ senderCharacter.id, characterID, candidate.attachmentKey })
        local returned = ConsumeEvidence(index.returned[returnKey], sentAt, consumedReturns)
        local received = not returned and ConsumeEvidence(index.received[receiptKey], sentAt, consumed)
        if not returned and not received then
            for attachmentIndex, item in ipairs(history.attachments) do
                local variantKey = ItemVariantKey(item)
                records[#records + 1] = {
                    sourceID = "mail-transit:" .. senderCharacter.id .. ":" .. tostring(history.eventID or sentAt) .. ":" .. attachmentIndex,
                    source = "mail", sourceClass = "external", mailStatus = "in-transit",
                    itemID = item.itemID, itemLink = item.itemLink,
                    itemKey = item.itemKey or ("item:" .. item.itemID), variantKey = variantKey,
                    identityQuality = variantKey and variantKey ~= ("item:" .. item.itemID) and "full-link" or "item-id-only",
                    quantity = item.quantity,
                    characterID = characterID, realm = target.realm, senderCharacterID = senderCharacter.id,
                    senderName = senderCharacter.name, recipientCharacterID = characterID,
                    location = { container = "in-transit", attachmentIndex = attachmentIndex },
                    observedAt = sentAt, state = "in-transit", subject = history.subject,
                }
            end
        end
    end
    table.sort(records, function(a, b) return a.sourceID < b.sourceID end)
    local result = { apiVersion = 1, revision = revision, characterID = characterID, records = records }
    self.transfersCache[characterID] = { cacheKey = cacheKey, result = result }
    return Addon.Copy(result)
end
function Items:RegisterService()
    local contracts = Addon.Core.Contracts
    self.serviceDefinition = self.serviceDefinition or {
        name = "mail.items", kind = "service", providerID = Addon.NAME .. ":inbox", version = { major = 1, minor = 1 },
        methods = {
            GetState = function(request) return Items:GetState(request and request.characterID) end,
            GetByCharacter = function(request) return Items:GetByCharacter(request and request.characterID, request and request.options) end,
            GetTransfers = function(request) return Items:GetTransfers(request and request.characterID) end,
            GetRevision = function() return Items:GetRevision() end,
        },
    }
    local ref, err = contracts:Register(Addon.NAME, self.serviceDefinition)
    if not ref then return nil, err end
    self.serviceRef = ref
    return true
end
function Items.Events:Register(owner, callback)
    if owner == nil or type(callback) ~= "function" then return nil, "invalid-listener" end
    for _, listener in ipairs(self.listeners) do if listener.owner == owner and listener.callback == callback then return true end end
    self.listeners[#self.listeners + 1] = { owner = owner, callback = callback }; return true
end
function Items.Events:Unregister(owner, callback)
    for index = #self.listeners, 1, -1 do
        local listener = self.listeners[index]
        if listener.owner == owner and (callback == nil or callback == listener.callback) then table.remove(self.listeners, index) end
    end
end
function Items.Events:Emit(payload)
    if Items.serviceRef then Addon.Core.Contracts:NotifyChanged(Addon.NAME, Items.serviceRef, payload) end
    local listeners = {}; for index, listener in ipairs(self.listeners) do listeners[index] = listener end
    for _, listener in ipairs(listeners) do
        local ok, err = pcall(listener.callback, "MAIL_ITEMS_CHANGED", Addon.Copy(payload))
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end
function Items:GetState(characterID)
    if type(characterID) ~= "string" or characterID == "" then return nil, "invalid-character-id" end
    local snapshot = Addon.db and Addon.db.byCharacter[characterID]
    local result = snapshot and Addon.Copy(snapshot.coverage) or { status = "not-yet-scanned", revision = self:GetRevision() }
    -- Closed mailbox state is stale without consulting a full Core snapshot.
    -- When live/error identity is needed, read it once for this query.
    local mailboxOpen = Addon.Scanner:IsOpen()
    local current = (mailboxOpen or Addon.Scanner.lastError) and Addon.Core and Addon.Core.Characters:GetCurrent({ identityOnly = true })
    if snapshot then
        local live = current and current.id == characterID and mailboxOpen and Addon.Scanner.updated
            and Addon.Scanner.validAt == snapshot.coverage.observedAt and not Addon.Scanner.lastError
        if not live then
            result.lastScanStatus = result.status
            result.status = current and current.id == characterID and Addon.Scanner.lastError and "error" or "stale"
        end
    end
    if current and current.id == characterID and Addon.Scanner.lastError then
        result.lastScanStatus, result.status = snapshot and snapshot.coverage.status or "not-yet-scanned", "error"
    end
    return result
end
local function Resolve(scope)
    local core = Addon.Core
    if not core then return {} end
    if scope == nil then local current = core.Characters:GetCurrent({ identityOnly = true }); return current and { current } or {} end
    if type(scope) ~= "table" then return nil, "invalid-scope" end
    if scope.mode == "characters" then
        if type(scope.characterIDs) ~= "table" then return nil, "invalid-scope" end
        local count = 0
        for key, id in pairs(scope.characterIDs) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or type(id) ~= "string" or id == "" then return nil, "invalid-scope" end
            count = count + 1
        end
        for index = 1, count do if scope.characterIDs[index] == nil then return nil, "invalid-scope" end end
        local byID, result, seen = {}, {}, {}
        for _, character in ipairs(core.Characters:GetAllCached()) do byID[character.id] = character end
        for _, id in ipairs(scope.characterIDs) do if byID[id] and not seen[id] then result[#result + 1] = byID[id]; seen[id] = true end end
        return result
    end
    if scope.mode ~= "account" and scope.mode ~= "realm" then return nil, "invalid-scope" end
    if scope.mode == "realm" and (type(scope.realm) ~= "string" or scope.realm == "") then return nil, "invalid-scope" end
    local result = {}
    for _, character in ipairs(core.AccountView:GetVisibleCharacters()) do
        if scope.mode == "account" or character.realm == scope.realm then result[#result + 1] = character end
    end
    return result
end
function Items:Query(options)
    if options ~= nil and type(options) ~= "table" then return nil, "invalid-options" end
    options = options or {}
    if options.itemID ~= nil and (type(options.itemID) ~= "number" or options.itemID <= 0 or options.itemID % 1 ~= 0) then return nil, "invalid-item-id" end
    local mode = options.identityMode
    if mode == nil then mode = "item-id" end
    if mode ~= "item-id" and mode ~= "strict" then return nil, "invalid-identity-mode" end
    if options.variantKey ~= nil and (mode ~= "strict" or type(options.variantKey) ~= "string" or options.variantKey == "") then return nil, "invalid-variant-key" end
    if options.includeStale ~= nil and type(options.includeStale) ~= "boolean" then return nil, "invalid-include-stale" end
    local characters, err = Resolve(options.scope); if not characters then return nil, err end
    local now = Addon:Now()
    local result = { apiVersion = 1, revision = self:GetRevision(), generatedAt = now, records = {}, quantity = 0, coverage = {} }
    local current = Addon.Core and Addon.Core.Characters:GetCurrent({ identityOnly = true })
    for _, character in ipairs(characters) do
        result.coverage[character.id] = self:GetState(character.id)
        local snapshot = Addon.db and Addon.db.byCharacter[character.id]
        local live = current and current.id == character.id and Addon.Scanner:IsOpen() and Addon.Scanner.updated and not Addon.Scanner.lastError
            and Addon.Scanner.validAt == (snapshot and snapshot.coverage.observedAt)
        if snapshot and (live or options.includeStale ~= false) then
            for _, key in ipairs(snapshot.visibleKeys) do
                local mail = snapshot.records[key]
                for _, item in ipairs(mail and mail.attachments or {}) do
                    if (options.itemID == nil or options.itemID == item.itemID) and (options.variantKey == nil or options.variantKey == item.variantKey) then
                        local record = Addon.Copy(item)
                        record.sourceID = "mail:" .. character.id .. ":" .. key .. ":" .. item.attachmentIndex
                        record.source, record.sourceClass = "mail", "external"
                        record.characterID, record.realm, record.mailKey = character.id, character.realm, key
                        record.location = { container = "inbox", slot = mail.inboxIndex, attachmentIndex = item.attachmentIndex }
                        for _, field in ipairs({ "sender", "subject", "mailType", "expiresAtEstimate", "daysLeftAtScan", "observedAt", "clockSource" }) do record[field] = mail[field] end
                        record.state = live and "observed" or "stale"
                        result.records[#result.records + 1] = record; result.quantity = result.quantity + record.quantity
                    end
                end
            end
        end
    end
    table.sort(result.records, function(a, b) return a.sourceID < b.sourceID end)
    return result
end
function Items:GetByCharacter(characterID, options)
    if type(characterID) ~= "string" or characterID == "" then return nil, "invalid-character-id" end
    if options ~= nil and type(options) ~= "table" then return nil, "invalid-options" end
    options = Addon.Copy(options or {}); options.scope = { mode = "characters", characterIDs = { characterID } }
    return self:Query(options)
end
