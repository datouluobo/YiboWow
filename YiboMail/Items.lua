local Addon = _G.YiboMail
local Items = { API_VERSION = 1, Events = { listeners = {} } }; Addon.Items = Items
function Items:GetAPIVersion() return 1 end
function Items:GetCapabilities() return Addon.Copy(Addon.CAPABILITIES) end
function Items:HasCapability(name, minimumVersion)
    local version = Addon.CAPABILITIES[name]; return version ~= nil and version >= (tonumber(minimumVersion) or 1), version
end
function Items:GetRevision() return Addon.db and Addon.db.revision or 0 end
function Items:RegisterService()
    local contracts = Addon.Core.Contracts
    self.serviceDefinition = self.serviceDefinition or {
        name = "mail.items", kind = "service", providerID = Addon.NAME .. ":inbox", version = { major = 1, minor = 0 },
        methods = {
            GetState = function(request) return Items:GetState(request and request.characterID) end,
            GetByCharacter = function(request) return Items:GetByCharacter(request and request.characterID, request and request.options) end,
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
    local current = (mailboxOpen or Addon.Scanner.lastError) and Addon.Core and Addon.Core.Characters:GetCurrent()
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
    if scope == nil then local current = core.Characters:GetCurrent(); return current and { current } or {} end
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
    local current = Addon.Core and Addon.Core.Characters:GetCurrent()
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
