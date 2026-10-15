local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Provider = { ID = "YiboCurrency:archive-currency" }
Addon.ArchiveProvider = Provider
function Provider:Read(request)
    if type(request) ~= "table" or type(request.characterIDs) ~= "table" or type(request.fieldIDs) ~= "table" then return nil, "invalid-request" end
    local requested = false
    for _, fieldID in ipairs(request.fieldIDs) do if fieldID ~= "character.money" then return nil, "invalid-field" end; requested = true end
    local result = { sourceID = self.ID, revision = Addon.Store.db.revision or 0, generatedAt = Addon.Store.Now(), characters = {} }
    for _, id in ipairs(request.characterIDs) do
        if type(id) ~= "string" then return nil, "invalid-character" end
        local row = { fields = {} }; result.characters[id] = row
        if requested and Core.Characters:Get(id, { identityOnly = true }) then
            local value, state = Addon:GetValue({ id = id }, { source = "money" })
            local snapshot = Addon.Store:Get(id, "native")
            row.fields["character.money"] = { value = value and value.quantity,
                state = state == "historical" and "stale" or state,
                observedAt = snapshot and snapshot.observedAt }
        end
    end
    return result
end
function Provider:Initialize()
    if self.ref then return true end
    self.definition = { name = "character-archive.fields", kind = "provider", providerID = self.ID, version = { major = 1, minor = 0 },
        methods = {
            GetFields = function() return { { id = "character.money", title = Addon:T("CURRENCY.GOLD_61F608"),
                order = 110, width = 72, formatKind = "money", defaultVisible = false, defaultPreviewVisible = false } } end,
            Read = function(request) return Provider:Read(request) end,
        } }
    local ref, err = Core.Contracts:Register(Addon.NAME, self.definition)
    if not ref then return nil, err end
    self.ref = ref
    return true
end
