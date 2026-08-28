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
    local pending = Profile._pendingLegacyUpdates[characterID]
    if pending then pending.reason = reason or pending.reason; return end
    Profile._pendingLegacyUpdates[characterID] = { reason = reason }
    local function Flush()
        local item, record = Profile._pendingLegacyUpdates[characterID], GetMutableRecord(characterID)
        Profile._pendingLegacyUpdates[characterID] = nil
        if record then Core.Events:Fire("CHARACTER_PROFILE_UPDATED", characterID, Copy(record), item and item.reason) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Flush) else Flush() end
end

function Profile:RegisterCollector(name, callback, events)
    if type(name) ~= "string" or name == "" or type(callback) ~= "function" then return nil, "角色档案采集器必须提供名称和回调。" end
    if self._collectors[name] then return nil, "角色档案采集器已存在: " .. name end
    self._collectors[name] = { callback = callback, events = events }
    return true
end

local function RunLegacyCollectors(reason)
    local character = Core.Characters:GetCurrent()
    local record = character and GetMutableRecord(character.id)
    if not record then return end
    record.observedAt, record.availability = record.observedAt or {}, record.availability or {}
    local now = Timestamp()
    for name, collector in pairs(Profile._collectors) do
        if not collector.events or collector.events[reason] then
            local ok, errorMessage = xpcall(function() collector.callback(record, reason, now) end, function(message) return tostring(message) end)
            if ok then
                record.observedAt.collectors = record.observedAt.collectors or {}; record.observedAt.collectors[name] = now
            else
                record.availability["collector:" .. name] = "error"
                Core:Print("角色档案采集器 “" .. name .. "” 失败：" .. errorMessage)
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
    local domain, record = Core.DomainStore:Get(payload.characterID, payload.domainID), GetMutableRecord(payload.characterID)
    if definition and definition.ProjectLegacy and domain and record then definition.ProjectLegacy(record, domain.data or {}, domain) end
    QueueLegacyUpdate(payload.characterID, payload.reason)
end)

Core.Capabilities:Register("character-profile", 1)
