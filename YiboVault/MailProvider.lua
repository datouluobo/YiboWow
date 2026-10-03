local Addon = _G.YiboVault
local Provider = { cache = {}, views = {} }; Addon.MailProvider = Provider

local function Compatible(api)
    if type(api) ~= "table" or type(api.GetAPIVersion) ~= "function" or type(api.GetByCharacter) ~= "function"
        or type(api.GetState) ~= "function" or type(api.GetRevision) ~= "function" or type(api.HasCapability) ~= "function"
        or type(api.Events) ~= "table" or type(api.Events.Register) ~= "function" or type(api.Events.Unregister) ~= "function" then return false end
    local ok, version = pcall(api.GetAPIVersion, api)
    if not ok or version ~= 1 then return false end
    for _, name in ipairs({ "mail-items.query", "mail-items.state", "mail-items.events" }) do
        local success, available = pcall(api.HasCapability, api, name, 1)
        if not success or not available then return false end
    end
    return true
end
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
    local api = _G.YiboMail and _G.YiboMail.Items
    if self.api == api and Compatible(api) then return true end
    if self.api then pcall(self.api.Events.Unregister, self.api.Events, self) end
    self.api, self.cache = nil, {}
    if not Compatible(api) then return false end
    local ok, registered = pcall(api.Events.Register, api.Events, self, function(event, payload)
        if event == "MAIL_ITEMS_CHANGED" and type(payload) == "table" and type(payload.characterID) == "string" then
            Provider:Refresh(payload.characterID)
        end
    end)
    if not ok or not registered then return false end
    self.api = api
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
            and (state.status == "known" or state.status == "known-empty" or state.status == "partial" or state.status == "stale") then
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
    self:Connect()
    for _, character in ipairs(Addon.Core.Characters:GetAllCached()) do self:Refresh(character.id) end
end
