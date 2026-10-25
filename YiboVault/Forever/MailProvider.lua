local Addon = _G.YiboVault
local Provider = {}; Addon.MailProvider = Provider
function Provider:Connect()
    local core = Addon.Core
    local current = core and core.Characters:GetCurrentID()
    local descriptor = core and core.Contracts:Resolve("mail.items", { major = 1, minMinor = 0 })
    self.descriptor = nil
    if not descriptor or not current then return false end
    local revision = core.Contracts:Call(Addon.NAME, descriptor, "GetRevision")
    local state = core.Contracts:Call(Addon.NAME, descriptor, "GetState", { characterID = current })
    if type(revision) ~= "number" or type(state) ~= "table" or type(state.status) ~= "string" then return false end
    local signature = table.concat({ descriptor.registrationRef, revision, state.status, tostring(state.observedAt) }, ":")
    if self.signature == signature and self.snapshot then self.descriptor = descriptor; return true end
    local query = core.Contracts:Call(Addon.NAME, descriptor, "GetByCharacter", { characterID = current, options = { includeStale = true } })
    if type(query) ~= "table" or query.revision ~= revision or type(query.records) ~= "table" or type(query.coverage) ~= "table"
        or type(query.coverage[current]) ~= "table" or query.coverage[current].status ~= state.status then return false end
    local records = {}
    for _, record in ipairs(query.records) do
        if record.characterID ~= current or record.source ~= "mail" or type(record.sourceID) ~= "string"
            or type(record.itemID) ~= "number" or record.itemID <= 0 or record.itemID ~= math.floor(record.itemID) or type(record.quantity) ~= "number"
            or record.quantity <= 0 or record.quantity ~= math.floor(record.quantity) or type(record.location) ~= "table"
            or (record.state ~= "observed" and record.state ~= "stale") then return false end
        records[#records + 1] = Addon.Copy(record)
    end
    local coverage = Addon.Copy(state)
    if coverage.status == "partial" then coverage.status = "stale" end
    coverage.completedScan, coverage.recordCount, coverage.location = state.observedAt ~= nil, #records, { container = "inbox" }
    coverage.providerRevision = revision
    self.signature, self.descriptor = signature, descriptor
    self.snapshot = { records = records, coverage = { inbox = coverage } }
    return true
end
function Provider:GetSnapshot(characterID)
    if characterID ~= Addon.Core.Characters:GetCurrentID() or not self:Connect() then return nil end
    return Addon.Copy(self.snapshot)
end
function Provider:Refresh()
    local previous, ids = self.signature, {}
    for _, record in ipairs(self.snapshot and self.snapshot.records or {}) do ids[record.itemID] = true end
    local current = Addon.Core.Characters:GetCurrentID()
    for _, record in ipairs(current and Addon:GetCachedCharacterRecords(current, "mail") or {}) do ids[record.itemID] = true end
    local connected = self:Connect()
    if not connected then self.signature, self.snapshot = nil, nil end
    if previous ~= self.signature then
        for _, record in ipairs(self.snapshot and self.snapshot.records or {}) do ids[record.itemID] = true end
        local changed = {}; for id in pairs(ids) do changed[#changed + 1] = id end; table.sort(changed)
        Addon._mailPendingReason = nil
        Addon:NotifyMailProviderChanged(Addon.Core.Characters:GetCurrentID(), changed)
        if not connected and Addon:IsMailboxReadable() then Addon:QueueScan(0.1) end
    end
end
function Provider:Install()
    if self.installed then return end
    self.installed = true
    local function Lifecycle(_, descriptor)
        if descriptor.name == "mail.items" then Provider:Refresh() end
    end
    for _, event in ipairs({ "BUSINESS_CONTRACT_REGISTERED", "BUSINESS_CONTRACT_UNREGISTERED", "BUSINESS_CONTRACT_CHANGED" }) do Addon.Core.Events:Register(event, self, Lifecycle) end
    self:Refresh()
end
