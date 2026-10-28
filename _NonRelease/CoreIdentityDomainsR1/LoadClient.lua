-- Standalone unit fixtures load the real internal client boundary explicitly.
-- The fixture chooses its target; production target detection is not bypassed.
local Core = assert(_G.YiboCore)
Core._private = Core._private or {}
Core._private.target = Core._private.target or { id = "Mists", requireGUID = false, legacyImports = true }
if not Core._private.target.addons then dofile("YiboCore/" .. Core._private.target.id .. "/Metadata.lua") end
if not (Core.Client and Core.Client.reader) then
dofile("YiboCore/Runtime/Client.lua")
dofile("YiboCore/Common/ClientReaders.lua")
dofile("YiboCore/" .. Core._private.target.id .. "/Client.lua")

end
if not Core.Client.surface then
    dofile("YiboCore/Common/ClientSurface.lua")
    dofile("YiboCore/" .. Core._private.target.id .. "/Surface.lua")
end
