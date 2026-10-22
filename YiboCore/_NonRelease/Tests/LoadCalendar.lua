-- Load the production Mists calendar contract into a controlled test runtime.
_G.YiboCore = _G.YiboCore or {}
if not _G.YiboCore.Capabilities then dofile("YiboCore/Runtime/Capabilities.lua") end
dofile("YiboCore/Mists/Calendar.lua")
if _G.YAB then dofile("YiboAltoBoss/Mists/Calendar.lua") end
