local Core = _G.YiboCore
if Core._private.lifecycleFrame then return end

local frame = CreateFrame("Frame")
Core._private.lifecycleFrame = frame
Core._private.eventRegistration = {}
local function Register(event)
    if Core._private.eventRegistration[event] ~= nil then return end
    local ok, err = pcall(frame.RegisterEvent, frame, event)
    Core._private.eventRegistration[event] = (ok and err ~= false) and true or tostring(err)
end
Register("ADDON_LOADED")
local target = Core._private.target
if target and target.supported then
    for _, event in ipairs(target.events) do Register(event) end
    Core._private.RegisterDomainEvents = function(events)
        for event, enabled in pairs(events or {}) do if enabled then Register(event) end end
    end
    for _, definition in ipairs(Core.DataDomains:GetDefinitions()) do
        Core._private.RegisterDomainEvents(definition.events)
    end
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }) do
        if Core._private.eventRegistration[event] ~= true then
            Core._private.lifecycleError = event .. ": " .. tostring(Core._private.eventRegistration[event])
            break
        end
    end
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == Core:GetAddonName() and not Core:IsInitialized() then Core:Initialize() end
        return
    end
    if not Core:IsInitialized() then return end
    local pending = Core._private.characterPending
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or Core._private.characterPending
        or (target and target.characterEvents and target.characterEvents[event]) then
        Core.Characters:RefreshCurrent()
    end
    if pending and not Core._private.characterPending and Core._private.RefreshCharacterDomains then
        Core._private.RefreshCharacterDomains(event)
    end
    if Core.Profile then Core.Profile:RefreshCurrent(event) end
    Core.Events:Fire(event)
end)
