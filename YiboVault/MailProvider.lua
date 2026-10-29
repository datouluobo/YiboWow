local Addon = _G.YiboVault
local Provider = { cache = {}, views = {} }; Addon.MailProvider = Provider

local function Fingerprint(snapshot)
    local parts = {}
    local state = snapshot.coverage.inbox or {}
    for _, field in ipairs({ "status", "completedScan", "currentCount", "totalCount", "unscannedCount" }) do
        parts[#parts + 1] = tostring(state[field])
    end
    for _, record in ipairs(snapshot.records) do
        for _, value in ipairs({ record.sourceID, record.itemID, record.quantity, record.variantKey or "", record.itemLink or "", record.mailStatus or "",
            record.location and record.location.slot or "", record.location and record.location.attachmentIndex or "" }) do
            value = tostring(value); parts[#parts + 1] = #value .. ":" .. value
        end
    end
    return table.concat(parts, "|")
end
function Provider:LocalSnapshot(characterID)
    return { records = Addon:GetCachedCharacterRecords(characterID, "mail"), coverage = Addon:GetCachedCharacterCoverage(characterID, "mail") }
end
function Provider:Connect()
    local core = Addon.Core
    if not (core and type(core.HasCapability) == "function" and core:HasCapability("character-identity-cache", 1)) then
        self.api, self.descriptor, self.cache = nil, nil, {}
        return false
    end
    local descriptor = core and core.Contracts and core.Contracts:Resolve("mail.items", { major = 1, minMinor = 0 })
    if descriptor and self.descriptor and descriptor.registrationRef == self.descriptor.registrationRef then return true end
    self.api, self.cache = nil, {}
    self.descriptor = descriptor
    if not descriptor then return false end
    self.api = {
        GetState = function(_, characterID) return core.Contracts:Call(Addon.NAME, descriptor, "GetState", { characterID = characterID }) end,
        GetRevision = function() return core.Contracts:Call(Addon.NAME, descriptor, "GetRevision") end,
        GetByCharacter = function(_, characterID, options)
            return core.Contracts:Call(Addon.NAME, descriptor, "GetByCharacter", { characterID = characterID, options = options })
        end,
    }
    if (descriptor.version.minor or 0) >= 1 then
        self.api.GetTransfers = function(_, characterID)
            return core.Contracts:Call(Addon.NAME, descriptor, "GetTransfers", { characterID = characterID })
        end
    end
    return true
end
function Provider:GetSnapshot(characterID, force)
    local snapshot
    if self:Connect() then
        local ok, state = pcall(self.api.GetState, self.api, characterID)
        local revisionOK, revision = pcall(self.api.GetRevision, self.api)
        local cached = self.cache[characterID]
        local stamped = type(state) == "table" and type(state.revision) == "number"
            and type(state.transfersRevision) == "number" and state.revision >= 0 and state.transfersRevision >= 0
            and state.revision < math.huge and state.transfersRevision < math.huge
        local sameVersion = cached and (stamped and cached.stateRevision == state.revision
            and cached.transfersRevision == state.transfersRevision or not stamped and cached.revision == revision)
        if not force and ok and revisionOK and type(state) == "table" and cached
            and cached.snapshot and sameVersion and cached.status == state.status and cached.observedAt == state.observedAt then
            snapshot = cached.snapshot
        elseif ok and revisionOK and type(state) == "table" and state.observedAt
            and (state.status == "known" or state.status == "known-empty" or state.status == "partial" or state.status == "stale" or state.status == "error") then
            local queryOK, result = pcall(self.api.GetByCharacter, self.api, characterID, { includeStale = true })
            local coverage = queryOK and type(result) == "table" and result.coverage and result.coverage[characterID]
            if type(coverage) == "table" and type(result.records) == "table" and coverage.status == state.status then
                local valid = true
                for _, record in ipairs(result.records) do
                    if record.source ~= "mail" or record.characterID ~= characterID or type(record.itemID) ~= "number"
                        or type(record.quantity) ~= "number" or record.quantity <= 0 or record.quantity % 1 ~= 0
                        or type(record.sourceID) ~= "string" or type(record.location) ~= "table"
                        or (record.state ~= "observed" and record.state ~= "stale" and record.state ~= "in-transit") then valid = false; break end
                end
                if valid then
                    -- Contracts:Call has already returned consumer-owned copies.
                    local inbox = coverage
                    inbox.providerRevision, inbox.revision = coverage.revision, Addon.Items:GetRevision()
                    inbox.completedScan, inbox.location, inbox.recordCount = true, { container = "inbox" }, #result.records
                    local records = result.records
                    local transitCoverage
                    if self.api.GetTransfers then
                        local transfersOK, transfers = pcall(self.api.GetTransfers, self.api, characterID)
                        if transfersOK and type(transfers) == "table" and transfers.characterID == characterID
                            and type(transfers.records) == "table" then
                            local validTransfers = true
                            for _, record in ipairs(transfers.records) do
                                if record.source ~= "mail" or record.mailStatus ~= "in-transit" or record.state ~= "in-transit"
                                    or record.characterID ~= characterID or type(record.itemID) ~= "number"
                                    or type(record.quantity) ~= "number" or record.quantity <= 0 or record.quantity % 1 ~= 0
                                    or type(record.sourceID) ~= "string" or type(record.senderCharacterID) ~= "string" then
                                    validTransfers = false; break
                                end
                            end
                            if validTransfers then
                                for _, record in ipairs(transfers.records) do records[#records + 1] = record end
                                transitCoverage = { status = "known", completedScan = true, revision = inbox.revision,
                                    recordCount = #transfers.records, location = { container = "in-transit" } }
                            end
                        end
                    end
                    snapshot = { records = records, coverage = { inbox = inbox, transit = transitCoverage } }
                    table.sort(snapshot.records, function(a, b) return a.sourceID < b.sourceID end)
                end
            end
        end
        if not snapshot and self.api.GetTransfers then
            local transfersOK, transfers = pcall(self.api.GetTransfers, self.api, characterID)
            if transfersOK and type(transfers) == "table" and transfers.characterID == characterID
                and type(transfers.records) == "table" then
                local valid = true
                for _, record in ipairs(transfers.records) do
                    if record.source ~= "mail" or record.mailStatus ~= "in-transit" or record.state ~= "in-transit"
                        or record.characterID ~= characterID or type(record.itemID) ~= "number"
                        or type(record.quantity) ~= "number" or record.quantity <= 0 or record.quantity % 1 ~= 0
                        or type(record.sourceID) ~= "string" or type(record.senderCharacterID) ~= "string" then
                        valid = false; break
                    end
                end
                if valid then
                    local records = transfers.records
                    local transitCoverage = { status = "known", completedScan = true,
                        revision = Addon.Items:GetRevision(), recordCount = #records,
                        location = { container = "in-transit" } }
                    snapshot = { records = records, coverage = { transit = transitCoverage } }
                end
            end
        end
        if snapshot and not snapshot.coverage.inbox then
            local localSnapshot = self:LocalSnapshot(characterID)
            snapshot.coverage.inbox = localSnapshot.coverage.inbox
            for _, record in ipairs(localSnapshot.records) do snapshot.records[#snapshot.records + 1] = record end
            table.sort(snapshot.records, function(a, b) return a.sourceID < b.sourceID end)
        end
        if ok and revisionOK and type(state) == "table" then
            self.cache[characterID] = { revision = revision, status = state.status, observedAt = state.observedAt, snapshot = snapshot,
                stateRevision = stamped and state.revision or nil, transfersRevision = stamped and state.transfersRevision or nil }
        end
    end
    if not self.views[characterID] then self.views[characterID] = snapshot or self:LocalSnapshot(characterID) end
    return snapshot
end
function Provider:Refresh(characterID)
    local before = self.views[characterID] or self:LocalSnapshot(characterID)
    local after = self:GetSnapshot(characterID) or self:LocalSnapshot(characterID)
    self.views[characterID] = after
    if before == after then return end
    if Fingerprint(before) == Fingerprint(after) then return end
    local ids, seen = {}, {}
    for _, snapshot in ipairs({ before, after }) do
        for _, record in ipairs(snapshot.records) do if not seen[record.itemID] then seen[record.itemID] = true; ids[#ids + 1] = record.itemID end end
    end
    table.sort(ids)
    if self.cache[characterID] and self.cache[characterID].snapshot then
        local coverage = self.cache[characterID].snapshot.coverage
        if coverage.inbox then coverage.inbox.revision = Addon.Items:GetRevision() + 1 end
        if coverage.transit then coverage.transit.revision = Addon.Items:GetRevision() + 1 end
    end
    Addon:NotifyMailProviderChanged(characterID, ids)
end
function Provider:Install()
    if not (Addon.Core and type(Addon.Core.HasCapability) == "function" and Addon.Core:HasCapability("character-identity-cache", 1)) then
        self:Connect()
        if not self.identityUpgradeShown then
            self.identityUpgradeShown = true
            Addon:Print(Addon:T("BOOT.CORE_REQUIRED"))
        end
        return
    end
    if not self.directoryListenersInstalled and Addon.Core.Events then
        -- Transfer matching also depends on the public character directory.
        -- Its changes are independent of Mail's own data revision.
        local function DirectoryChanged()
            Provider.cache = {}
            for _, character in ipairs(Addon.Core.Characters:GetAllCached({ identityOnly = true })) do Provider:Refresh(character.id) end
        end
        for _, event in ipairs({ "CHARACTER_UPDATED", "CHARACTER_IMPORTED", "CHARACTER_ID_CHANGED", "CHARACTER_DELETED" }) do
            Addon.Core.Events:Register(event, self, DirectoryChanged)
        end
        self.directoryListenersInstalled = true
    end
    if not self.listenersInstalled and Addon.Core.Events then
        local function Lifecycle(_, descriptor, change)
            if descriptor.name ~= "mail.items" then return end
            Provider:Connect()
            if Addon.MailItems then Addon.MailItems.scanToken = (Addon.MailItems.scanToken or 0) + 1 end
            if change and change.characterID then
                -- A send recorded by one character can change the transit view
                -- of any other character in the account.
                if change.transfersUnchanged == true then Provider:Refresh(change.characterID)
                else for _, character in ipairs(Addon.Core.Characters:GetAllCached({ identityOnly = true })) do Provider:Refresh(character.id) end end
            else
                for _, character in ipairs(Addon.Core.Characters:GetAllCached({ identityOnly = true })) do Provider:Refresh(character.id) end
                if not Provider.api and Addon.MailItems and Addon.MailItems:IsOpen() then
                    Addon.MailItems.open = true; Addon.MailItems:ScheduleScan("provider-unregistered", 0.2, 3)
                end
            end
        end
        for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do
            Addon.Core.Events:Register(event, self, Lifecycle)
        end
        self.listenersInstalled = true
    end
    self:Connect()
    for _, character in ipairs(Addon.Core.Characters:GetAllCached({ identityOnly = true })) do self:Refresh(character.id) end
end
