local ADDON_NAME, NS = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
    if event ~= "ADDON_LOADED" or name ~= ADDON_NAME then return end
    if not NS.Data or NS.Data.schemaVersion ~= 1 then return end
    if NS.Probe then NS.Probe:Initialize() end
    NS.Tooltip:Initialize()
end)
