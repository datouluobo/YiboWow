local ADDON_NAME, NS = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if not NS.CLIENT_SUPPORTED then
        if event == "ADDON_LOADED" and name == ADDON_NAME and DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(NS:L("CLIENT_REQUIRED"))
        end
        return
    end
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        if not NS.Data or NS.Data.schemaVersion ~= 1 then return end
        NS:EnsureDB()
        if NS.Probe then NS.Probe:Initialize() end
    elseif event == "PLAYER_LOGIN" and NS.CoreIntegration then
        -- Core-backed status text/settings are enabled only for API 13. The
        -- independent source tooltip keeps its bundled bilingual catalog.
        NS.CoreIntegration:Initialize()
        NS.Tooltip:Initialize()
    end
end)
