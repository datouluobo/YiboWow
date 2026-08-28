local Core = _G.YiboCore

-- Data domains describe collection boundaries.  They deliberately contain no
-- window, entry, or SavedVariables ownership outside YiboCoreDB.
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
    if type(events) ~= "table" then return nil, "领域 events 必须是事件名集合。" end
    for eventName, enabled in pairs(events) do
        if type(eventName) ~= "string" or eventName == "" or enabled ~= true then
            return nil, "领域 events 只能包含启用的事件名。"
        end
    end
    return true
end

function DataDomains:IsStateValid(state)
    return VALID_STATES[state] == true
end

function DataDomains:Register(owner, definition)
    if type(owner) ~= "string" or owner == "" then return nil, "领域必须声明 owner。" end
    if type(definition) ~= "table" then return nil, "领域定义不能为空。" end
    local id, version = definition.id, tonumber(definition.version)
    if type(id) ~= "string" or id == "" then return nil, "领域必须提供 id。" end
    if not version or version < 1 or version % 1 ~= 0 then return nil, "领域 version 必须为正整数。" end
    if type(definition.Collect) ~= "function" then return nil, "领域必须提供 Collect 回调。" end
    local validEvents, eventError = ValidateEvents(definition.events)
    if not validEvents then return nil, eventError end
    local current = self._definitions[id]
    if current then
        return nil, "领域 ID 已被 " .. current.owner .. " 占用: " .. id
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

function DataDomains:Dispatch(eventName)
    local definitions = self._events[eventName]
    if not definitions or not Core:IsInitialized() then return 0 end
    local character = Core.Characters and Core.Characters:GetCurrent()
    if not character then return 0 end
    local count = 0
    for _, definition in ipairs(definitions) do
        local context = { characterID = character.id, character = character, reason = eventName, domainID = definition.id }
        local ok, data, state, changedKeys = xpcall(function()
            return definition.Collect(context)
        end, function(message) return tostring(message) end)
        if ok then
            state = state or "known"
            if self:IsStateValid(state) then
                context.changedKeys = changedKeys
                Core.DomainStore:Commit(character.id, definition.id, data or {}, state, context)
            else
                Core:Print("领域 “" .. definition.id .. "” 返回了非法状态: " .. tostring(state))
                Core.DomainStore:Commit(character.id, definition.id, nil, "error", context)
            end
        else
            Core:Print("领域 “" .. definition.id .. "” 采集失败: " .. tostring(data))
            Core.DomainStore:Commit(character.id, definition.id, nil, "error", context)
        end
        count = count + 1
    end
    return count
end

Core.Capabilities:Register("data-domains", 1)
