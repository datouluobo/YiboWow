local Addon = _G.YiboMailStage0Probe

local function StableHash(value)
    value = tostring(value or "")
    local hash = 2166136261
    for index = 1, #value do
        hash = (hash * 16777619 + string.byte(value, index)) % 4294967296
    end
    return string.format("%08x", hash)
end

local function CopyArray(values, limit)
    local copy = {}
    for index = 1, math.min(#values, limit or #values) do copy[index] = values[index] end
    return copy
end

function Addon:DescribePrivateString(value)
    if type(value) ~= "string" then return nil end
    return { present = value ~= "", length = #value, hash = StableHash(value) }
end

function Addon:DescribeItemLink(value)
    if type(value) ~= "string" or value == "" then return { present = false } end
    local linkType, linkPayload = value:match("|H([^:|]+):([^|]+)|h")
    if not linkType then linkType, linkPayload = value:match("^([^:|]+):([^|]+)$") end
    local itemString = linkType == "item" and linkPayload or nil
    local itemID = itemString and tonumber(itemString:match("^(%-?%d+)")) or nil
    return {
        present = true,
        linkType = linkType,
        payloadLength = linkPayload and #linkPayload or nil,
        payloadHash = linkPayload and StableHash(linkPayload) or nil,
        itemID = itemID,
        itemStringLength = itemString and #itemString or nil,
        itemStringHash = itemString and StableHash(itemString) or nil,
    }
end

function Addon:DescribeReturns(values, stringMode)
    local result = { count = values.n or #values, values = {} }
    for index = 1, result.count do
        local value = values[index]
        local valueType = type(value)
        local entry = { index = index, type = valueType }
        if valueType == "number" or valueType == "boolean" then
            entry.value = value
        elseif valueType == "string" then
            entry.value = stringMode == "item-link" and self:DescribeItemLink(value) or self:DescribePrivateString(value)
        elseif value == nil then
            entry.type = "nil"
        end
        result.values[#result.values + 1] = entry
    end
    return result
end

function Addon:InitializeDatabase()
    local now, clockSource = self:Now()
    if type(_G.YiboMailStage0ProbeDB) ~= "table" or _G.YiboMailStage0ProbeDB.schemaVersion ~= self.SCHEMA_VERSION then
        _G.YiboMailStage0ProbeDB = { schemaVersion = self.SCHEMA_VERSION, sessions = {} }
    end
    self.DB = _G.YiboMailStage0ProbeDB
    self.DB.sessions = self.DB.sessions or {}
    local characterName = type(UnitName) == "function" and UnitName("player") or "Unknown"
    local realmName = type(GetRealmName) == "function" and GetRealmName() or "Unknown"
    local version, build, date, interfaceVersion
    if type(GetBuildInfo) == "function" then version, build, date, interfaceVersion = GetBuildInfo() end
    local session = {
        id = tostring(now) .. ":" .. StableHash(tostring(characterName) .. "-" .. tostring(realmName)),
        startedAt = now,
        clockSource = clockSource,
        addonVersion = self.VERSION,
        client = { version = version, build = build, buildDate = date, interface = interfaceVersion },
        character = {
            name = self:DescribePrivateString(characterName),
            realm = self:DescribePrivateString(realmName),
        },
        eventLogging = false,
        samples = {},
        events = {},
    }
    self.DB.sessions[#self.DB.sessions + 1] = session
    while #self.DB.sessions > 10 do table.remove(self.DB.sessions, 1) end
    self.Session = session
end

function Addon:AddSample(kind, payload)
    if not self.Session then self:InitializeDatabase() end
    local now, clockSource = self:Now()
    local sample = { kind = kind, observedAt = now, clockSource = clockSource, payload = payload }
    local samples = self.Session.samples
    samples[#samples + 1] = sample
    while #samples > self.MAX_SAMPLES do table.remove(samples, 1) end
    self.Session.lastSampleAt = now
    return sample
end

function Addon:AddEvent(eventName, ...)
    if not (self.Session and self.Session.eventLogging) then return end
    local now, clockSource = self:Now()
    local args = { ... }
    local described = {}
    for index = 1, math.min(#args, 8) do
        local value = args[index]
        described[index] = type(value) == "string" and self:DescribePrivateString(value) or value
    end
    local events = self.Session.events
    events[#events + 1] = { event = eventName, observedAt = now, clockSource = clockSource, args = described }
    while #events > self.MAX_EVENTS do table.remove(events, 1) end
end

function Addon:SetEventLogging(enabled)
    if not self.Session then self:InitializeDatabase() end
    self.Session.eventLogging = enabled == true
    self:Print("事件记录已" .. (self.Session.eventLogging and "开启" or "关闭") .. "。")
end

function Addon:ClearDiagnostics()
    if not self.Session then self:InitializeDatabase() end
    self.Session.samples = {}
    self.Session.events = {}
    self.LastMailProbe = nil
    self.Session.clearedAt = self:Now()
    self:Print("已清除当前会话的可再生诊断样本和事件记录。")
end

function Addon:GetReportSummary()
    if not self.Session then return { samples = 0, events = 0, kinds = {} } end
    local kinds = {}
    for _, sample in ipairs(self.Session.samples or {}) do kinds[sample.kind] = (kinds[sample.kind] or 0) + 1 end
    return { samples = #(self.Session.samples or {}), events = #(self.Session.events or {}), kinds = kinds }
end
