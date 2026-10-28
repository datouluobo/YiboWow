-- Diagnostic only: the historical ActionIntegration failure occurs before
-- identity/domain production modules are loaded. All its Core runtime inputs
-- match R1-01/02; the locale files differ only by the new domain-error key.
-- Removing that key in memory reproduces their recorded prior-stage bytes.
local original = dofile
function dofile(path)
    if path == "YiboCore/Locales/enUS.lua" or path == "YiboCore/Locales/zhCN.lua" then
        local file = assert(io.open(path, "rb"))
        local source = file:read("*a"); file:close()
        local restored, count = source:gsub('[^\n]*CORE%.DOMAIN_INVALID_DATA[^\n]*\n', '')
        assert(count == 1, "baseline locale no longer matches this diagnostic")
        return assert(loadstring(restored, "@" .. path))()
    end
    return original(path)
end
dofile("_NonRelease/TaskChainPerformance/PerformanceSpec.lua")
