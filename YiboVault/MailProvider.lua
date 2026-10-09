local Addon = _G.YiboVault
local Provider = { cache = {}, views = {} }; Addon.MailProvider = Provider

local function Fingerprint(snapshot)
    local parts = {}
    local state = snapshot.coverage.inbox or {}
    for _, field in ipairs({ "status", "completedScan", "currentCount", "totalCount", "unscannedCount" }) do
        parts[#parts + 1] = tostring(state[field])
    end
    for _, record in ipairs(snapshot.records) do
        for _, value in ipairs({ record.sourceID, record.itemID, record.quantity, record.variantKey or "", record.itemLink or "",
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
    return true
end
function Provider:GetSnapshot(characterID, force)
    local snapshot
    if self:Connect() then
        local ok, state = pcall(self.api.GetState, self.api, characterID)
        local revisionOK, revision = pcall(self.api.GetRevision, self.api)
        local cached = self.cache[characterID]
        if not force and ok and revisionOK and type(state) == "table" and cached
            and cached.snapshot and cached.revision == revision and cached.status == state.status and cached.observedAt == state.observedAt then
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
                        or (record.state ~= "observed" and record.state ~= "stale") then valid = false; break end
                end
                if valid then
                    local inbox = Addon.Copy(coverage)
                    inbox.providerRevision, inbox.revision = coverage.revision, Addon.Items:GetRevision()
                    inbox.completedScan, inbox.location, inbox.recordCount = true, { container = "inbox" }, #result.records
                    snapshot = { records = Addon.Copy(result.records), coverage = { inbox = inbox } }
                    table.sort(snapshot.records, function(a, b) return a.sourceID < b.sourceID end)
                end
            end
        end
        if ok and revisionOK and type(state) == "table" then
            self.cache[characterID] = { revision = revision, status = state.status, observedAt = state.observedAt, snapshot = snapshot }
        end
    end
    if not self.views[characterID] then self.views[characterID] = snapshot or self:LocalSnapshot(characterID) end
    return snapshot
end
function Provider:Refresh(characterID)
    local before = self.views[characterID] or self:LocalSnapshot(characterID)
    local after = self:GetSnapshot(characterID, true) or self:LocalSnapshot(characterID)
    self.views[characterID] = after
    if Fingerprint(before) == Fingerprint(after) then return end
    local ids, seen = {}, {}
    for _, snapshot in ipairs({ before, after }) do
        for _, record in ipairs(snapshot.records) do if not seen[record.itemID] then seen[record.itemID] = true; ids[#ids + 1] = record.itemID end end
    end
    table.sort(ids)
    if self.cache[characterID] and self.cache[characterID].snapshot then
        self.cache[characterID].snapshot.coverage.inbox.revision = Addon.Items:GetRevision() + 1
    end
    Addon:NotifyMailProviderChanged(characterID, ids)
end
function Provider:Install()
    if not self.listenersInstalled and Addon.Core.Events then
        local function Lifecycle(_, descriptor, change)
            if descriptor.name ~= "mail.items" then return end
            Provider:Connect()
            if Addon.MailItems then Addon.MailItems.scanToken = (Addon.MailItems.scanToken or 0) + 1 end
            if change and change.characterID then Provider:Refresh(change.characterID)
            else
                for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do Provider:Refresh(character.id) end
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
    for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do self:Refresh(character.id) end
end
