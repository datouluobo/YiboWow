local Core = _G.YiboCore
local Contracts = { _services = {}, _nextRef = 0 }
Core.Contracts = Contracts

local function CopyValue(value, seen)
    local kind = type(value)
    if kind == "nil" or kind == "string" or kind == "number" or kind == "boolean" then return value end
    if kind ~= "table" then error("non-value-data") end
    seen = seen or {}
    if seen[value] then error("cyclic-data") end
    seen[value] = true
    local result = {}
    for key, child in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then error("invalid-value-key") end
        result[key] = CopyValue(child, seen)
    end
    seen[value] = nil
    return result
end

local function Compatible(entry, version)
    return entry and type(version) == "table" and entry.descriptor.version.major == version.major
        and entry.descriptor.version.minor >= (version.minMinor or 0)
end

function Contracts:Register(owner, definition)
    if not Core.Registry:Get(owner) then return nil, "owner-unregistered" end
    if type(definition) ~= "table" or definition.kind ~= "service" or type(definition.name) ~= "string"
        or definition.name == "" or type(definition.providerID) ~= "string"
        or definition.providerID:sub(1, #owner + 1) ~= owner .. ":" then return nil, "invalid-definition" end
    local version = definition.version
    if type(version) ~= "table" or type(version.major) ~= "number" or version.major < 1 or version.major % 1 ~= 0
        or type(version.minor) ~= "number" or version.minor < 0 or version.minor % 1 ~= 0 then return nil, "invalid-version" end
    if type(definition.methods) ~= "table" or not next(definition.methods) then return nil, "invalid-methods" end
    for name, callback in pairs(definition.methods) do
        if type(name) ~= "string" or type(callback) ~= "function" then return nil, "invalid-methods" end
    end
    local key = definition.name .. ":" .. version.major
    local existing = self._services[key]
    if existing then
        local descriptor = existing.descriptor
        if descriptor.owner ~= owner or descriptor.providerID ~= definition.providerID then return nil, "service-conflict" end
        if descriptor.version.minor ~= version.minor then return nil, "definition-changed" end
        for name, callback in pairs(definition.methods) do if existing.methods[name] ~= callback then return nil, "definition-changed" end end
        for name in pairs(existing.methods) do if not definition.methods[name] then return nil, "definition-changed" end end
        return descriptor.registrationRef
    end
    self._nextRef = self._nextRef + 1
    local descriptor = { name = definition.name, kind = "service", owner = owner, providerID = definition.providerID,
        version = { major = version.major, minor = version.minor }, registrationRef = tostring(self._nextRef) }
    local methods = {}
    for name, callback in pairs(definition.methods) do methods[name] = callback end
    self._services[key] = { descriptor = descriptor, methods = methods }
    Core.Events:FireIsolated("BUSINESS_CONTRACT_REGISTERED", CopyValue(descriptor))
    return descriptor.registrationRef
end

function Contracts:Resolve(name, version)
    if type(name) ~= "string" or type(version) ~= "table" or type(version.major) ~= "number"
        or version.minMinor ~= nil and type(version.minMinor) ~= "number" then return nil, "invalid-version" end
    local entry = self._services[name .. ":" .. version.major]
    if not Compatible(entry, version) then return nil, "unavailable" end
    return CopyValue(entry.descriptor)
end

function Contracts:Unregister(owner, registrationRef)
    for key, entry in pairs(self._services) do
        if entry.descriptor.registrationRef == registrationRef then
            if entry.descriptor.owner ~= owner then return nil, "wrong-owner" end
            self._services[key] = nil
            Core.Events:FireIsolated("BUSINESS_CONTRACT_UNREGISTERED", CopyValue(entry.descriptor), "unregistered")
            return true
        end
    end
    return false, "unregistered"
end

function Contracts:Call(caller, descriptor, method, request)
    if not Core.Registry:Get(caller) then return nil, "caller-unregistered" end
    if type(descriptor) ~= "table" or type(descriptor.version) ~= "table" then return nil, "invalid-descriptor" end
    local entry = self._services[tostring(descriptor.name) .. ":" .. tostring(descriptor.version.major)]
    if not entry or entry.descriptor.registrationRef ~= descriptor.registrationRef then return nil, "unregistered" end
    if descriptor.version.minor ~= entry.descriptor.version.minor or descriptor.owner ~= entry.descriptor.owner
        or descriptor.providerID ~= entry.descriptor.providerID then return nil, "invalid-descriptor" end
    local callback = entry.methods[method]
    if not callback then return nil, "method-unavailable" end
    local ok, result, code, details = pcall(function()
        local result, code, details = callback(CopyValue(request), {
            callerAddon = caller, name = entry.descriptor.name, providerID = entry.descriptor.providerID,
            registrationRef = entry.descriptor.registrationRef,
        })
        return CopyValue(result), CopyValue(code), CopyValue(details)
    end)
    if not ok then return nil, "provider-error", tostring(result) end
    return result, code, details
end

function Contracts:NotifyChanged(owner, registrationRef, change)
    local ok, copy = pcall(CopyValue, change)
    if not ok or type(copy) ~= "table" then return nil, "invalid-change" end
    for _, entry in pairs(self._services) do
        if entry.descriptor.registrationRef == registrationRef then
            if owner ~= entry.descriptor.owner then return nil, "wrong-owner" end
            Core.Events:FireIsolated("BUSINESS_CONTRACT_CHANGED", CopyValue(entry.descriptor), copy)
            return true
        end
    end
    return nil, "unregistered"
end

Core.Capabilities:Register("business-services", 1)
