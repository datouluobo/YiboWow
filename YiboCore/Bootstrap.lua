local ADDON_NAME = ...

local Core = _G.YiboCore or {}
_G.YiboCore = Core

Core.NAME = "YiboCore"
Core.VERSION = "1.0"
Core.API_VERSION = 5
Core._private = Core._private or {}
Core._private.addonName = ADDON_NAME or Core.NAME
Core._private.initialized = false

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
        DEFAULT_CHAT_FRAME:AddMessage("|cff4fd8ff[YiboCore]|r " .. tostring(message))
    end
end

local lifecycleFrame = CreateFrame("Frame")
lifecycleFrame:RegisterEvent("ADDON_LOADED")
lifecycleFrame:RegisterEvent("PLAYER_LOGIN")
lifecycleFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycleFrame:RegisterEvent("PLAYER_LEVEL_UP")
lifecycleFrame:RegisterEvent("PLAYER_MONEY")
lifecycleFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
lifecycleFrame:RegisterEvent("BAG_UPDATE_DELAYED")
lifecycleFrame:RegisterEvent("BANKFRAME_OPENED")
lifecycleFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
lifecycleFrame:RegisterEvent("SKILL_LINES_CHANGED")
lifecycleFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
lifecycleFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
lifecycleFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
lifecycleFrame:RegisterEvent("UPDATE_FACTION")

lifecycleFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= Core:GetAddonName() or Core:IsInitialized() then
            return
        end

        Core:Initialize()
        return
    end

    if not Core:IsInitialized() then
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if Core.Characters then
            Core.Characters:RefreshCurrent()
        end
    end
    if Core.Profile and event ~= "ADDON_LOADED" then
        Core.Profile:RefreshCurrent(event)
    end

    if Core.Events then
        Core.Events:Fire(event)
    end
end)
