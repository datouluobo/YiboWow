local Addon = _G.YiboMail
local Items = { API_VERSION = 1, Events = { listeners = {} }, transfersCache = {} }; Addon.Items = Items
function Items:GetAPIVersion() return 1 end
function Items:GetCapabilities() return Addon.Copy(Addon.CAPABILITIES) end
function Items:HasCapability(name, minimumVersion)
    local version = Addon.CAPABILITIES[name]; return version ~= nil and version >= (tonumber(minimumVersion) or 1), version
end
function Items:GetRevision() return Addon.db and Addon.db.revision or 0 end
function Items:ReleaseCaches(clearDirectory, preserveEvidence)
    self.transferIndex, self.transferIndexKey, self.transfersCache, self.transferKey = nil, nil, {}, nil
    if not preserveEvidence then self.transferEvidence = nil end
    if clearDirectory then self.transferDirectory = nil end
end
function Items:OnPublish(revision, transfersUnchanged, characterID)
    if not transfersUnchanged or self.transferDataRevision == nil then
        self.transferDataRevision = revision
        if self.transferEvidence and characterID then self.transferEvidence.byID[characterID] = nil end
        self:ReleaseCaches(nil, type(characterID) == "string")
    end
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
local function TransferIndex(characters, directorySignature)
    local addresses, resolved, signatures, index = {}, {}, {}, { sends = {}, received = {}, returned = {} }
    local cache = Items.transferEvidence
    -- Core may replace its lightweight array for an unrelated domain update.
    -- Evidence depends on id/name/realm values, not the array's allocation.
    if not cache or cache.directorySignature ~= directorySignature then
        cache = { directorySignature = directorySignature, byID = {} }; Items.transferEvidence = cache
    end
    for _, character in ipairs(characters) do
        if character.name and character.realm then
            addresses[Addon.Recipients:Key(character.name .. "-" .. character.realm)] = character
        end
    end
    local function Resolve(address, realm)
        if type(address) ~= "string" then return end
        local key = realm or false
        local bucket = resolved[key]
        if not bucket then bucket = {}; resolved[key] = bucket end
        local result = bucket[address]
        if result ~= nil then return result or nil end
        local normalized = Addon.Recipients:Normalize(address, realm)
        result = normalized and addresses[Addon.Recipients:Key(normalized)]
        bucket[address] = result or false
        return result
    end
    local function Signature(items)
        if type(items) ~= "table" then return end
        local value = signatures[items]
        if value == nil then value = AttachmentSignature(items) or false; signatures[items] = value end
        return value or nil
    end
    local function Append(target, source)
        for key, values in pairs(source) do
            local bucket = target[key]
            if not bucket then bucket = {}; target[key] = bucket end
            for _, value in ipairs(values) do bucket[#bucket + 1] = value end
        end
    end
    local pieces, present, hasSends = {}, {}, false
    for _, owner in ipairs(characters) do
        present[owner.id] = true
        local snapshot = Addon.db.byCharacter[owner.id]
        local coverage = snapshot and snapshot.coverage
        local revision = coverage and coverage.revision
        local versioned = type(revision) == "number" and revision == revision and revision >= 0 and revision < math.huge
        local piece = versioned and cache.byID[owner.id]
        if not piece or piece.snapshot ~= snapshot or piece.coverage ~= coverage or piece.revision ~= revision
            or piece.records ~= snapshot.records or piece.history ~= snapshot.history or piece.historyCount ~= #(snapshot.history or {}) then
            piece = { snapshot = snapshot, coverage = coverage, revision = revision,
                records = snapshot and snapshot.records, history = snapshot and snapshot.history,
                historyCount = #(snapshot and snapshot.history or {}), sends = {} }
            for _, history in ipairs(piece.history or {}) do
                if history.state == "in-transit" and history.transferReview ~= "legacy-unverified" and type(history.recipient) == "string" then
                    local recipient = Resolve(history.recipient, owner.realm)
                    local attachmentKey = recipient and Signature(history.attachments)
                    if attachmentKey then
                        local sends = piece.sends[recipient.id]
                        if not sends then sends = {}; piece.sends[recipient.id] = sends end
                        sends[#sends + 1] = { history = history, sender = owner, attachmentKey = attachmentKey }
                    end
                end
            end
            cache.byID[owner.id] = versioned and piece or nil
        end
        pieces[owner.id] = piece
        if next(piece.sends) then hasSends = true; Append(index.sends, piece.sends) end
    end
    for id in pairs(cache.byID) do if not present[id] then cache.byID[id] = nil end end
    if not hasSends then return index end
    for _, owner in ipairs(characters) do
        local piece = pieces[owner.id]
        if not piece.received then
            local received, returned, seen = {}, {}, {}
            local function Evidence(mail, stamp, identity, allowReturn)
                if not mail or type(stamp) ~= "number" or (mail.wasReturned and not allowReturn) then return end
                local other = Resolve(mail.sender, owner.realm)
                local attachmentKey = other and Signature(mail.attachments)
                if not attachmentKey then return end
                local key = Addon.Encode({ owner.id, other.id, attachmentKey })
                local bucket = mail.wasReturned and returned or received
                local identityKey = Addon.Encode({ mail.wasReturned == true, key, identity })
                if seen[identityKey] then return end
                seen[identityKey] = true
                bucket[key] = bucket[key] or {}
                bucket[key][#bucket[key] + 1] = { at = stamp, id = identity }
            end
            for key, mail in pairs(piece.records or {}) do
                if mail.state == "observed" or mail.wasReturned then
                    Evidence(mail, mail.observedAt, "inbox:" .. owner.id .. ":" .. key, true)
                end
            end
            for _, history in ipairs(piece.history or {}) do
                if history.state == "discovered" or history.state == "collected-archived" then
                    local mail = history.mail or history
                    Evidence(mail, history.observedAt or mail.observedAt,
                        "history:" .. owner.id .. ":" .. tostring(history.eventID or history.sourceMailKey or ""), history.state == "collected-archived")
                end
            end
            piece.received, piece.returned = received, returned
        end
        Append(index.received, piece.received); Append(index.returned, piece.returned)
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
local function TransferDirectory()
    local characters = Addon.Core and Addon.Core.Characters:GetAllCached({ identityOnly = true }) or {}
    local prior = Items.transferDirectory
    if prior and prior.characters == characters then return prior end
    local parts, byID = {}, {}
    for _, character in ipairs(characters) do
        parts[#parts + 1] = Addon.Encode({ character.id, character.name or "", character.realm or "" })
        byID[character.id] = character
    end
    table.sort(parts)
    local directory = { characters = characters, signature = table.concat(parts), byID = byID }
    Items.transferDirectory = directory
    return directory
end
local function GetTransferResult(characterID)
    local self = Items
    if type(characterID) ~= "string" or characterID == "" then return nil, "invalid-character-id" end
    local revision = self:GetRevision()
    local directory = TransferDirectory()
    local characters = directory.characters
    local dataRevision = self.transferDataRevision or revision
    local key = self.transferKey
    if not key or key.directory ~= directory or key.revision ~= dataRevision then
        key = { directory = directory, revision = dataRevision, value = Addon.Encode({ dataRevision, directory.signature }) }
        self.transferKey = key
    end
    local cacheKey = key.value
    local cached = self.transfersCache[characterID]
    if cached and cached.cacheKey == cacheKey then
        cached.result.revision = revision; return cached.result
    end
    local target = directory.byID[characterID]
    if not target then
        local empty = { apiVersion = 1, revision = revision, characterID = characterID, records = {} }
        self.transfersCache[characterID] = { cacheKey = cacheKey, result = empty }
        return empty
    end

    if self.transferIndexKey ~= cacheKey then
        self.transferIndex = TransferIndex(characters, directory.signature)
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
    return result
end
-- Direct Mail API callers keep independent mutable results. Registered
-- service callbacks return privately to Core, which isolates the contract once.
function Items:GetTransfers(characterID)
    local result, err = GetTransferResult(characterID)
    if not result then return nil, err end
    return Addon.Copy(result)
end
function Items:RegisterService()
    local contracts = Addon.Core.Contracts
    self.serviceDefinition = self.serviceDefinition or {
        name = "mail.items", kind = "service", providerID = Addon.NAME .. ":inbox", version = { major = 1, minor = Addon.Target and 0 or 1 },
        methods = {
            GetState = function(request) return Items:GetState(request and request.characterID) end,
            GetByCharacter = function(request) return Items:GetByCharacter(request and request.characterID, request and request.options) end,
            GetTransfers = function(request) return GetTransferResult(request and request.characterID) end,
            GetRevision = function() return Items:GetRevision() end,
        },
    }
    if Addon.Target then self.serviceDefinition.methods.GetTransfers = nil end
    local ref, err = contracts:Register(Addon.NAME, self.serviceDefinition)
    if not ref then return nil, err end
    self.serviceRef = ref
    return true
end
local function RegisterListener(events, owner, callback, signalOnly)
    if owner == nil or type(callback) ~= "function" then return nil, "invalid-listener" end
    for _, listener in ipairs(events.listeners) do
        if listener.owner == owner and listener.callback == callback then
            if listener.signalOnly ~= signalOnly then return nil, "listener-mode-conflict" end
            return true
        end
    end
    events.listeners[#events.listeners + 1] = { owner = owner, callback = callback, signalOnly = signalOnly }
    return true
end
function Items.Events:Register(owner, callback) return RegisterListener(self, owner, callback, false) end
-- Mail-owned invalidation subscribers explicitly opt out of unused payloads.
function Items.Events:RegisterSignal(owner, callback) return RegisterListener(self, owner, callback, true) end
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
        local ok, err
        if listener.signalOnly then ok, err = pcall(listener.callback, "MAIL_ITEMS_CHANGED")
        else ok, err = pcall(listener.callback, "MAIL_ITEMS_CHANGED", Addon.Copy(payload)) end
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end
function Items:GetState(characterID)
    if type(characterID) ~= "string" or characterID == "" then return nil, "invalid-character-id" end
    if Addon.Target then
        local current = Addon.Core.Characters:GetCurrent({ identityOnly = true })
        if not current or current.id ~= characterID then return nil, "scope-not-supported" end
    end
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
    -- Optional cache stamp: inbox revision is character-local, whereas transit
    -- evidence can change when any sender/recipient changes real mail data.
    result.transfersRevision = self.transferDataRevision or self:GetRevision()
    return result
end
local function Resolve(scope)
    local core = Addon.Core
    if not core then return {} end
    if Addon.Target and scope ~= nil then
        local current = core.Characters:GetCurrent({ identityOnly = true })
        if not current then return nil, "current-character-unavailable" end
        if type(scope) ~= "table" or scope.mode ~= "characters" or type(scope.characterIDs) ~= "table" then return nil, "scope-not-supported" end
        for _, id in pairs(scope.characterIDs) do if id ~= current.id then return nil, "scope-not-supported" end end
    end
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
        for _, character in ipairs(core.Characters:GetAllCached({ identityOnly = true })) do byID[character.id] = character end
        for _, id in ipairs(scope.characterIDs) do if byID[id] and not seen[id] then result[#result + 1] = byID[id]; seen[id] = true end end
        return result
    end
    if scope.mode ~= "account" and scope.mode ~= "realm" then return nil, "invalid-scope" end
    if scope.mode == "realm" and (type(scope.realm) ~= "string" or scope.realm == "") then return nil, "invalid-scope" end
    local result = {}
    for _, character in ipairs(core.AccountView:GetVisibleCharacters({ identityOnly = true })) do
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
