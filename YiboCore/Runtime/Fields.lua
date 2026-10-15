local Core = _G.YiboCore

local Fields = {}
Core.Fields = Fields
Fields._definitions = Fields._definitions or {}

local function Copy(value) return Core.Defaults:Copy(value) end

function Fields:Register(owner, definition)
    if type(owner) ~= "string" or owner == "" then return nil, Core:Text("CORE.FIELDS_MUST_DECLARE_OWNER") end
    if type(definition) ~= "table" then return nil, Core:Text("CORE.FIELD_DEFINITION_CANNOT_BE_EMPTY") end
    if type(definition.id) ~= "string" or definition.id == "" then return nil, Core:Text("CORE.FIELDS_REQUIRE_ID") end
    if type(definition.consumer) ~= "string" or definition.consumer == "" then return nil, Core:Text("CORE.FIELDS_REQUIRE_CONSUMER") end
    if type(definition.domain) ~= "string" or not Core.DataDomains._definitions[definition.domain] then return nil, Core:Text("CORE.FIELDS_MUST_REFERENCE_A_REGISTERED_DOMAIN") end
    if definition.resource ~= nil and (type(definition.resource) ~= "string" or not Core.Resources:Get(definition.resource)) then return nil, Core:Text("CORE.FIELDS_MUST_REFERENCE_A_REGISTERED_RESOURCE") end
    if type(definition.Read) ~= "function" then return nil, Core:Text("CORE.FIELDS_REQUIRE_A_READ_CALLBACK") end
    if self._definitions[definition.id] then return nil, Core:Text("CORE.FIELD_ID_IS_ALREADY_OWNED_BY") .. self._definitions[definition.id].owner .. Core:Text("CORE.PUNCTUATION_79") .. definition.id end
    local order = tonumber(definition.order)
    if not order then return nil, Core:Text("CORE.FIELDS_REQUIRE_A_NUMERIC_ORDER") end
    local claimed, errorMessage = Core.Registry:ClaimResource("field", definition.id, owner, { consumer = definition.consumer, domain = definition.domain })
    if not claimed then return nil, errorMessage end
    local entry = {
        id = definition.id, owner = owner, consumer = definition.consumer, domain = definition.domain, resource = definition.resource,
        title = definition.title or definition.id, order = order, width = tonumber(definition.width) or 80,
        minWidth = tonumber(definition.minWidth), maxWidth = tonumber(definition.maxWidth), gapAfter = tonumber(definition.gapAfter),
        defaultVisible = definition.defaultVisible == true, defaultPreviewVisible = definition.defaultPreviewVisible == true,
        align = definition.align == "RIGHT" and "RIGHT" or "LEFT", Read = definition.Read, Format = definition.Format,
        GetIcon = definition.GetIcon, GetColor = definition.GetColor,
    }
    self._definitions[entry.id] = entry
    return entry
end

function Fields:GetByConsumer(consumer)
    local result = {}
    for _, field in pairs(self._definitions) do if field.consumer == consumer then result[#result + 1] = field end end
    if consumer == "character-archive" and Core.ArchiveFields then
        for _, field in ipairs(Core.ArchiveFields:GetDefinitions(result)) do result[#result + 1] = field end
    end
    table.sort(result, function(left, right) return left.order == right.order and left.id < right.id or left.order < right.order end)
    return result
end

function Fields:GetValue(character, field)
    if field.archiveProvider then return Core.ArchiveFields:GetCell(character, field) end
    local domain = character and character.domains and character.domains[field.domain]
    return field.Read(character, domain and Copy(domain.data) or nil, domain and domain.state)
end

function Fields:FormatValue(character, field, snapshot)
    if field.archiveProvider then return Core.ArchiveFields:FormatValue(character, field, snapshot) end
    local value = self:GetValue(character, field)
    if field.Format then return field.Format(value, character), value end
    return value == nil and "—" or tostring(value), value
end

Core.Capabilities:Register("fields", 1)
