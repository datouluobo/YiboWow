local Core = _G.YiboCore

-- API v4 compatibility facade. New code should use DataDomains and
-- DATA_DOMAIN_UPDATED; this module no longer owns Core fact collection.
local Profile = {}
Core.Profile = Profile
Profile._collectors = Profile._collectors or {}
Profile._pendingLegacyUpdates = Profile._pendingLegacyUpdates or {}

local function Timestamp() return (GetServerTime and GetServerTime()) or time() end
local function Copy(value) return Core.Defaults:Copy(value) end
local function GetMutableRecord(characterID)
    local db = Core.Database:GetDB()
    return db and db.characters and db.characters.byID and db.characters.byID[characterID]
end

local function QueueLegacyUpdate(characterID, reason)
    if not Core.Events:HasListeners("CHARACTER_PROFILE_UPDATED") then return end
    local pending = Profile._pendingLegacyUpdates[characterID]
    if pending then pending.reason = reason or pending.reason; return end
    Profile._pendingLegacyUpdates[characterID] = { reason = reason }
    local function Flush()
        local item, record = Profile._pendingLegacyUpdates[characterID], GetMutableRecord(characterID)
        Profile._pendingLegacyUpdates[characterID] = nil
        if record and Core.Events:HasListeners("CHARACTER_PROFILE_UPDATED") then
            Core.Events:Fire("CHARACTER_PROFILE_UPDATED", characterID, Copy(record), item and item.reason)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Flush) else Flush() end
end

function Profile:RegisterCollector(name, callback, events)
    if type(name) ~= "string" or name == "" or type(callback) ~= "function" then return nil, Core:Text("CORE.CHARACTER_PROFILE_COLLECTORS_REQUIRE_A_NAME_AND") end
    if events ~= nil then
        if type(events) ~= "table" then return nil, Core:Text("CORE.DOMAIN_EVENTS_MUST_BE_A_SET_OF") end
        for event, enabled in pairs(events) do
            if type(event) ~= "string" or type(enabled) ~= "boolean" then return nil, Core:Text("CORE.DOMAIN_EVENTS_MAY_ONLY_CONTAIN_ENABLED_EVENT") end
        end
    end
    if self._collectors[name] then return nil, Core:Text("CORE.CHARACTER_PROFILE_COLLECTOR_ALREADY_EXISTS") .. name end
    self._collectors[name] = { callback = callback, events = events }
    if Core._private.RegisterDomainEvents then Core._private.RegisterDomainEvents(events) end
    return true
end

local function RunLegacyCollectors(reason)
    if not next(Profile._collectors) then return end
    local record, now
    for name, collector in pairs(Profile._collectors) do
        if not collector.events or collector.events[reason] then
            if not record then
                local character = Core.Characters:GetCurrent({ identityOnly = true })
                record = character and GetMutableRecord(character.id)
                if not record then return end
                record.observedAt, record.availability = record.observedAt or {}, record.availability or {}
                now = Timestamp()
            end
            local ok, errorMessage = xpcall(function() collector.callback(record, reason, now) end, function(message) return tostring(message) end)
            if ok then
                record.observedAt.collectors = record.observedAt.collectors or {}; record.observedAt.collectors[name] = now
            else
                record.availability["collector:" .. name] = "error"
                Core:Print(Core:Text("CORE.CHARACTER_PROFILE_COLLECTOR") .. name .. Core:Text("CORE.FAILED") .. errorMessage)
            end
        end
    end
end

function Profile:RefreshCurrent(reason)
    local dispatched = Core.DataDomains:Dispatch(reason)
    RunLegacyCollectors(reason)
    return dispatched
end

function Profile:Get(characterID)
    -- Domain projections retain the v4 aggregate shape; v6 records without
    -- domains stay readable until their first successful domain collection.
    return Core.Characters:Get(characterID)
end

Core.Events:Register("DATA_DOMAIN_UPDATED", Profile, function(_, payload)
    local definition = Core.DataDomains._definitions[payload.domainID]
    if definition and definition.ProjectLegacy then
        local domain, record = Core.DomainStore:Get(payload.characterID, payload.domainID), GetMutableRecord(payload.characterID)
        if domain and record then definition.ProjectLegacy(record, domain.data or {}, domain) end
    end
    QueueLegacyUpdate(payload.characterID, payload.reason)
end)

Core.Capabilities:Register("character-profile", 1)
