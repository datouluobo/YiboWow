local ADDON_NAME = ...

local Core = _G.YiboCore or {}
_G.YiboCore = Core
if Core._private and Core._private.bootstrapLoaded then return end

Core.NAME = "YiboCore"
Core.VERSION = "1.12.11"
Core.API_VERSION = 13
Core._private = Core._private or {}
Core._private.addonName = ADDON_NAME or Core.NAME
Core._private.initialized = false
Core._private.bootstrapLoaded = true

function Core:GetAddonName()
    return self._private.addonName
end

function Core:IsInitialized()
    return self._private.initialized == true
end

function Core:GetVersion()
    return self.VERSION
end

function Core:CheckAPIVersion(requiredVersion)
    requiredVersion = tonumber(requiredVersion) or 1
    return self.API_VERSION >= requiredVersion, self.API_VERSION
end

function Core:Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(Core:Text("CORE.CFF20E070_YIBO_R_CORE") .. tostring(message))
    end
end
