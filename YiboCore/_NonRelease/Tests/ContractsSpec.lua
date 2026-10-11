-- Run from workspace root with Lua 5.1. Uses the actual Core runtimes.
function CreateFrame() return { RegisterEvent = function() end, SetScript = function() end } end
GetServerTime = function() return 1000 end
dofile("YiboCore/Bootstrap.lua")
dofile("YiboCore/Util/Defaults.lua")
dofile("YiboCore/Runtime/Capabilities.lua")
dofile("YiboCore/Runtime/Events.lua")
dofile("YiboCore/Runtime/Registry.lua")
dofile("YiboCore/Runtime/Contracts.lua")
local Core, checks, errors = YiboCore, 0, 0
Core.Print = function() errors = errors + 1 end
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, (label or "value") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function Code(callback, expected)
    local _, code = callback()
    Equal(code, expected, "error code")
end
for _, owner in ipairs({ "A", "Z", "Z:Nested", "Consumer" }) do
    assert(Core.Registry:Register(owner, { requiredAPI = 11 }))
end
Equal(Core:HasCapability("business-services", 1), true)
Equal(Core:HasCapability("business-providers", 1), true)
Equal(Core:HasCapability("business-providers", 2), false)
local C = Core.Contracts
local discovered, removed, changed = {}, {}, {}
local function Registered(_, descriptor)
    Equal(C:Call("Consumer", descriptor, "Query", {} ) ~= nil, true, "registration visible before notification")
    discovered[#discovered + 1] = descriptor
end
Core.Events:Register("BUSINESS_CONTRACT_REGISTERED", "consumer", Registered)
Core.Events:Register("BUSINESS_CONTRACT_REGISTERED", "consumer", Registered)
Core.Events:Register("BUSINESS_CONTRACT_UNREGISTERED", "consumer", function(_, descriptor, reason)
    Code(function() return C:Call("Consumer", descriptor, "Query", {}) end, "unregistered")
    removed[#removed + 1] = descriptor
    Equal(reason, "unregistered")
end)
Core.Events:Register("BUSINESS_CONTRACT_CHANGED", "bad", function(_, descriptor, change)
    descriptor.name, change.revision = "tampered", -1
    error("listener failure")
end)
Core.Events:Register("BUSINESS_CONTRACT_CHANGED", "consumer", function(_, descriptor, change)
    Equal(descriptor.name, "work.todo")
    Equal(change.revision, 3)
    changed[#changed + 1] = change
end)
local backing = { tasks = { { key = "one", value = 7 } } }
local function Definition(owner, minor, kind, name, major, providerID)
    return { name = name or "work.todo", kind = kind or "provider", providerID = providerID or owner .. ":todo",
        version = { major = major or 1, minor = minor or 0 }, methods = {
            Query = function(request, context)
                request.nested = { changed = true }
                Equal(context.callerAddon, "Consumer")
                return backing, nil, { meta = { value = 1 } }
            end,
            Fail = function() error("business failure") end,
        } }
end
local a, z = Definition("A", 1), Definition("Z", 0)
Equal(#C:List("work.todo", { major = 1 }), 0, "absent provider list")
local zRef = assert(C:Register("Z", z))
local aRef = assert(C:Register("A", a))
Equal(#discovered, 2, "late registration")
Equal(C:Register("A", a), aRef, "idempotent reference")
Equal(#discovered, 2, "idempotent notification")
local list = assert(C:List("work.todo", { major = 1 }))
Equal(#list, 2)
Equal(list[1].providerID, "A:todo", "stable order regardless of registration")
Equal(list[2].providerID, "Z:todo")
Equal(#C:List("work.todo", { major = 1, minMinor = 1 }), 1)
Equal(#C:List("work.todo", { major = 1, minMinor = 2 }), 0)
Equal(#C:List("work.todo", { major = 2 }), 0)
Code(function() return C:Resolve("work.todo", { major = 1 }) end, "unavailable")
local request = { nested = { original = true } }
local result, _, details = C:Call("Consumer", list[1], "Query", request)
Equal(request.nested.original, true, "request isolation")
result.tasks[1].value, details.meta.value = 99, 99
Equal(backing.tasks[1].value, 7, "result isolation")
list[1].version.minor = 99
Equal(C:List("work.todo", { major = 1 })[1].version.minor, 1, "descriptor isolation")
Code(function() return C:Call("Consumer", list[1], "Query", {}) end, "invalid-descriptor")
list = C:List("work.todo", { major = 1 })
Code(function() return C:Call("Unknown", list[1], "Query", {}) end, "caller-unregistered")
Code(function() return C:Call("Consumer", list[1], "Missing", {}) end, "method-unavailable")
Code(function() return C:Call("Consumer", list[1], "Fail", {}) end, "provider-error")
Equal(C:Call("Consumer", list[2], "Query", {}) ~= nil, true, "other provider remains callable")
local cyclic = {}; cyclic.self = cyclic
Code(function() return C:Call("Consumer", list[1], "Query", cyclic) end, "provider-error")
Code(function() return C:Call("Consumer", list[1], "Query", { fn = function() end }) end, "provider-error")
Code(function() return C:NotifyChanged("Z", aRef, {}) end, "wrong-owner")
Code(function() return C:NotifyChanged("A", aRef, cyclic) end, "invalid-change")
local change = { revision = 3, nested = { value = 1 } }
Equal(C:NotifyChanged("A", aRef, change), true)
Equal(change.revision, 3, "notification input isolation")
Equal(#changed, 1)
Equal(errors, 1, "bad listener isolated")
local changedDefinition = Definition("A", 1)
Code(function() return C:Register("A", changedDefinition) end, "definition-changed")
local bad = Definition("A"); bad.version.minor, bad.version.minMinor = nil, 1
Code(function() return C:Register("A", bad) end, "invalid-version")
bad = Definition("A"); bad.providerID = "Z:todo"
Code(function() return C:Register("A", bad) end, "invalid-definition")
Code(function() return C:Register("Unknown", Definition("Unknown")) end, "owner-unregistered")
-- An overlapping owner prefix still cannot overwrite the same stable ID.
local nested = Definition("Z", 0, "provider", "nested.todo", 1, "Z:Nested:todo")
assert(C:Register("Z", nested))
Code(function() return C:Register("Z:Nested", Definition("Z:Nested", 0, "provider", "nested.todo")) end, "provider-conflict")
Code(function() return C:Register("A", Definition("A", 0, "service")) end, "kind-conflict")
Code(function() return C:Unregister("Z", aRef) end, "wrong-owner")
Equal(C:Unregister("A", aRef), true)
Equal(#removed, 1)
Equal(#C:List("work.todo", { major = 1 }), 1)
Code(function() return C:Call("Consumer", list[1], "Query", {}) end, "unregistered")
Code(function() return C:NotifyChanged("A", aRef, {}) end, "unregistered")
local newRef = assert(C:Register("A", a))
Equal(newRef ~= aRef, true, "re-registration gets new reference")
Code(function() return C:Call("Consumer", list[1], "Query", {}) end, "unregistered")
Equal(#C:List("work.todo", { major = 1 }), 2)
local v2 = Definition("A", 0, "provider", "work.todo", 2)
assert(C:Register("A", v2))
Equal(#C:List("work.todo", { major = 2 }), 1, "major versions separate")
for _, version in ipairs({ { major = 0 }, { major = 1.5 }, { major = 1, minMinor = -1 }, { major = math.huge } }) do
    Code(function() return C:List("work.todo", version) end, "invalid-version")
    Code(function() return C:Resolve("work.todo", version) end, "invalid-version")
end
-- Keep the v9 singleton contract, including old service descriptors.
local service = Definition("A", 0, "service", "work.items")
local serviceRef = assert(C:Register("A", service))
Equal(C:Register("A", service), serviceRef)
Code(function() return C:Register("Z", Definition("Z", 0, "service", "work.items")) end, "service-conflict")
Code(function() return C:Register("Z", Definition("Z", 0, "provider", "work.items")) end, "kind-conflict")
Equal(#C:List("work.items", { major = 1 }), 0, "List does not enumerate services")
local descriptor = assert(C:Resolve("work.items", { major = 1 }))
descriptor.kind = nil
Equal(C:Call("Consumer", descriptor, "Query", {}) ~= nil, true, "legacy descriptor compatibility")
Equal(C:Unregister("A", serviceRef), true)
Equal(C:Unregister("A", serviceRef), false)
-- Removing the last provider frees the mechanism for that name/major.
assert(C:Unregister("A", newRef))
assert(C:Unregister("Z", zRef))
assert(C:Register("A", Definition("A", 0, "service")))
Equal(#C:List("work.todo", { major = 1 }), 0)
Core.Events:Unregister("BUSINESS_CONTRACT_REGISTERED", "consumer")
local previous = #discovered
assert(C:Register("Z", Definition("Z", 0, "provider", "later.todo")))
Equal(#discovered, previous, "subscription cleanup")
print("ContractsSpec passed: " .. checks .. " checks")
