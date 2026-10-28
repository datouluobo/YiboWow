-- Expose the swallowed provider error without editing business code or bypassing assertions.
local file = assert(io.open("_NonRelease/TaskGoalIntegration/GoalSourcesSpec.lua", "rb"))
local source = file:read("*a"); file:close()
source = source:gsub('local Core = YiboCore', [[
local Core = YiboCore
local originalCall = Core.Contracts.Call
Core.Contracts.Call = function(self, ...)
    local value, code, details = originalCall(self, ...)
    if code == "provider-error" then print("Provider diagnostic: " .. tostring(details)) end
    return value, code, details
end
]])
source = source:gsub('local vg = assert%(Hub.Goals:Add%(vi%)%)', [[
local vg, code, details = Hub.Goals:Add(vi)
assert(vg, tostring(code) .. ": " .. tostring(details))
]])
assert(loadstring(source, "@GoalSourcesSpec-diagnostic"))()
