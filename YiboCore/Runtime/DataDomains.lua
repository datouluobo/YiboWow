local Core = _G.YiboCore

-- Data domains describe collection boundaries.  They deliberately contain no
-- window, entry, or SavedVariables ownership outside Core's target store.
local DataDomains = {}
Core.DataDomains = DataDomains
DataDomains._definitions = DataDomains._definitions or {}
DataDomains._events = DataDomains._events or {}

local VALID_STATES = {
    known = true, ["not-yet-scanned"] = true, unavailable = true,
    stale = true, error = true,
}

local function Copy(value)
    return Core.Defaults:Copy(value)
end

local function ValidateEvents(events)
    if events == nil then return true end
    if type(events) ~= "table" then return nil, Core:Text("CORE.DOMAIN_EVENTS_MUST_BE_A_SET_OF") end
    for eventName, enabled in pairs(events) do
        if type(eventName) ~= "string" or eventName == "" or enabled ~= true then
            return nil, Core:Text("CORE.DOMAIN_EVENTS_MAY_ONLY_CONTAIN_ENABLED_EVENT")
        end
    end
    return true
end

function DataDomains:IsStateValid(state)
    return VALID_STATES[state] == true
end

function DataDomains:Register(owner, definition)
    if type(owner) ~= "string" or owner == "" then return nil, Core:Text("CORE.DOMAINS_MUST_DECLARE_OWNER") end
    if type(definition) ~= "table" then return nil, Core:Text("CORE.DOMAIN_DEFINITION_CANNOT_BE_EMPTY") end
    local id, version = definition.id, tonumber(definition.version)
    if type(id) ~= "string" or id == "" then return nil, Core:Text("CORE.DOMAINS_REQUIRE_ID") end
    if not version or version < 1 or version % 1 ~= 0 then return nil, Core:Text("CORE.DOMAIN_VERSION_MUST_BE_A_POSITIVE_INTEGER") end
    if type(definition.Collect) ~= "function" then return nil, Core:Text("CORE.DOMAINS_REQUIRE_A_COLLECT_CALLBACK") end
    local validEvents, eventError = ValidateEvents(definition.events)
    if not validEvents then return nil, eventError end
    local current = self._definitions[id]
    if current then
        return nil, Core:Text("CORE.DOMAIN_ID_IS_ALREADY_OWNED_BY") .. current.owner .. Core:Text("CORE.PUNCTUATION_79") .. id
    end
    local claimed, claimError = Core.Registry:ClaimResource("data-domain", id, owner, { version = version })
    if not claimed then return nil, claimError end
    local entry = {
        id = id, owner = owner, version = version, events = Copy(definition.events or {}),
        Collect = definition.Collect, ProjectLegacy = definition.ProjectLegacy,
    }
    self._definitions[id] = entry
    for eventName in pairs(entry.events) do
        self._events[eventName] = self._events[eventName] or {}
        self._events[eventName][#self._events[eventName] + 1] = entry
        table.sort(self._events[eventName], function(left, right) return left.id < right.id end)
    end
    if Core._private.RegisterDomainEvents then Core._private.RegisterDomainEvents(entry.events) end
    return entry
end

function DataDomains:GetDefinitions()
    local result = {}
    for _, definition in pairs(self._definitions) do result[#result + 1] = definition end
    table.sort(result, function(left, right) return left.id < right.id end)
    return result
end

function DataDomains:Get(characterID, domainID)
    return Core.DomainStore and Core.DomainStore:Get(characterID, domainID) or nil
end

function DataDomains:GetState(characterID, domainID)
    return Core.DomainStore and Core.DomainStore:GetState(characterID, domainID) or nil
end

local function CollectDefinitions(definitions, eventName)
    if not definitions or not Core:IsInitialized() then return 0 end
    local identity = Core.Characters and Core.Characters:GetCurrent({ identityOnly = true })
    if not identity then return 0 end
    local fullCharacter
    local count = 0
    for _, definition in ipairs(definitions) do
        -- Core collectors read native facts from identity. Third-party collectors
        -- retain the complete, isolated context promised by the existing API.
        local character = identity
        if definition.owner ~= Core.NAME then
            fullCharacter = fullCharacter or Core.Characters:GetCurrent()
            character = fullCharacter
        end
        local context = { characterID = character.id, character = character, reason = eventName, domainID = definition.id }
        local ok, data, state, changedKeys = xpcall(function()
            return definition.Collect(context)
        end, function(message) return tostring(message) end)
        if ok then
            if state == nil then state = "known" end
            if DataDomains:IsStateValid(state) and (state ~= "known" or type(data) == "table") then
                context.changedKeys = state == "known" and changedKeys or nil
                -- Failure/partial results cannot replace the last good values.
                -- A known empty table is an explicit, successful empty snapshot.
                Core._private.CommitCollectedDomain(character.id, definition.id, state == "known" and data or nil, state, context)
            else
                if DataDomains:IsStateValid(state) then Core:Print(Core:Text("CORE.DOMAIN_INVALID_DATA", definition.id))
                else Core:Print(Core:Text("CORE.DOMAIN") .. definition.id .. Core:Text("CORE.RETURNED_AN_INVALID_STATE") .. tostring(state)) end
                Core._private.CommitCollectedDomain(character.id, definition.id, nil, "error", context)
            end
        else
            Core:Print(Core:Text("CORE.DOMAIN") .. definition.id .. Core:Text("CORE.COLLECTION_FAILED") .. tostring(data))
            Core._private.CommitCollectedDomain(character.id, definition.id, nil, "error", context)
        end
        count = count + 1
    end
    return count
end

function DataDomains:Dispatch(eventName)
    return CollectDefinitions(self._events[eventName], eventName)
end

if Core._private then
    Core._private.RefreshCharacterDomains = function(nativeEvent)
        local missing = {}
        for _, definition in ipairs(DataDomains:GetDefinitions()) do
            if definition.owner == Core.NAME and not definition.events[nativeEvent] then missing[#missing + 1] = definition end
        end
        return CollectDefinitions(missing, "character-ready")
    end
end

Core.Capabilities:Register("data-domains", 1)
