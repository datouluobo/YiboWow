local ADDON_NAME, NS = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        if not NS.Data or NS.Data.schemaVersion ~= 1 then return end
        NS:EnsureDB()
        if NS.Probe then NS.Probe:Initialize() end
        NS.Tooltip:Initialize()
    elseif event == "PLAYER_LOGIN" and NS.CoreIntegration then
        NS.CoreIntegration:Initialize()
    end
end)
