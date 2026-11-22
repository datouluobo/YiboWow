-- Test-only dependency setup for fixtures loading individual Core modules.
local Core = assert(_G.YiboCore)
if not Core.Capabilities then dofile("YiboCore/Runtime/Capabilities.lua") end
-- Theme registers its pixel-line refresh on Core events at load time (API 14).
if not Core.Events then dofile("YiboCore/Runtime/Events.lua") end
-- Without a configured surface every client read reports "unavailable", so
-- pixel lines keep the 1 UI-unit fallback in these fixtures.
if not Core.Client then dofile("YiboCore/Runtime/Client.lua") end
GetLocale = GetLocale or function() return "zhCN" end
if not Core.Locale then
    dofile("YiboCore/Runtime/Locale.lua")
    dofile("YiboCore/Locales/zhCN.lua")
    dofile("YiboCore/Locales/enUS.lua")
end

if not Core.EntryConfig then dofile("YiboCore/Runtime/EntryConfig.lua") end
