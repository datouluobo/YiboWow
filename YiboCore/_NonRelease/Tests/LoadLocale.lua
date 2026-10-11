-- Test-only dependency setup for fixtures loading individual Core modules.
local Core = assert(_G.YiboCore)
if not Core.Capabilities then dofile("YiboCore/Runtime/Capabilities.lua") end
GetLocale = GetLocale or function() return "zhCN" end
if not Core.Locale then
    dofile("YiboCore/Runtime/Locale.lua")
    dofile("YiboCore/Locales/zhCN.lua")
    dofile("YiboCore/Locales/enUS.lua")
end

if not Core.EntryConfig then dofile("YiboCore/Runtime/EntryConfig.lua") end
