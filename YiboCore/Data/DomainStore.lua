local Core = _G.YiboCore

local DomainStore = {}
Core.DomainStore = DomainStore

local function Copy(value) return Core.Defaults:Copy(value) end
local function Timestamp() return (GetServerTime and GetServerTime()) or time() end

local function Equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    for key, value in pairs(left) do if not Equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

local function GetRecord(characterID)
    local db = Core.Database:GetDB()
    return db and db.characters and db.characters.byID and db.characters.byID[characterID]
end

local function ChangedKeys(previous, current)
    local changed = {}
    for key, value in pairs(previous or {}) do if not Equal(value, (current or {})[key]) then changed[key] = true end end
    for key, value in pairs(current or {}) do if not Equal(value, (previous or {})[key]) then changed[key] = true end end
    return changed
end

function DomainStore:Get(characterID, domainID)
    local record = GetRecord(characterID)
    local domain = record and record.domains and record.domains[domainID]
    return domain and Copy(domain) or nil
end

function DomainStore:GetState(characterID, domainID)
    local domain = self:Get(characterID, domainID)
    return domain and domain.state or nil
end

function DomainStore:Commit(characterID, domainID, data, state, context)
    local record = GetRecord(characterID)
    if not record then return nil, "角色不存在: " .. tostring(characterID) end
    if not (Core.DataDomains and Core.DataDomains:IsStateValid(state)) then return nil, "非法领域状态: " .. tostring(state) end
    local definition = Core.DataDomains._definitions[domainID]
    if not definition then return nil, "未注册领域: " .. tostring(domainID) end
    record.domains = record.domains or {}
    local previous = record.domains[domainID]
    local previousData = previous and previous.data or nil
    local nextData = data == nil and Copy(previousData or {}) or Copy(data)
    local changed = not previous or previous.state ~= state or previous.schemaVersion ~= definition.version or not Equal(previousData, nextData)
    if not changed then return Copy(previous), false end
    local snapshot = {
        schemaVersion = definition.version, state = state, updatedAt = Timestamp(),
        revision = (previous and tonumber(previous.revision) or 0) + 1, data = nextData,
    }
    record.domains[domainID] = snapshot
    local changedKeys = context and context.changedKeys or ChangedKeys(previousData, nextData)
    Core.Events:Fire("DATA_DOMAIN_UPDATED", {
        characterID = characterID, domainID = domainID, revision = snapshot.revision,
        changedKeys = Copy(changedKeys), reason = context and context.reason,
        updatedAt = snapshot.updatedAt, state = state,
    })
    return Copy(snapshot), true
end

Core.Capabilities:Register("domain-store", 1)
