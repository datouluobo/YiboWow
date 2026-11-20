if not _G.YAB.CoreReady then return end
local YAB, Core = _G.YAB, _G.YiboCore
local addonName = ...
local Store = YAB.Store

local function Initialize()
    if not Store:Initialize() then return nil, YAB.Text("FOREVER.STORE_MISMATCH") end
    local registered, err = Core:RegisterAddon(addonName, { version = YAB.Version, requiredAPI = 13 })
    if not registered then return nil, err end
    registered, err = Core.CharacterCleanup:RegisterOwner(addonName, {
        Inspect = function(character)
            local db, id = Store.db, character.id
            return { hasData = db.marks[id] ~= nil or db.instanceSnapshots[id] ~= nil, label = YAB.Text("FOREVER.TITLE") }
        end,
        Delete = function(character)
            local db, id = Store.db, character.id
            db.marks[id], db.instanceSnapshots[id] = nil, nil
            return true
        end,
    })
    if not registered then return nil, err end
    registered, err = YAB.RegisterForeverPages()
    if not registered then return nil, err end
    SLASH_YIBOALTOBOSS1 = "/yab"
    SlashCmdList.YIBOALTOBOSS = function() Core.AccountView:Toggle(YAB.GetAccountBusinessPageID()) end
    return true
end

if YAB.loginFrame then return end
local frame = CreateFrame("Frame")
YAB.loginFrame = frame
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    if YAB.initializationStarted then return end
    YAB.initializationStarted = true
    frame:UnregisterEvent("PLAYER_LOGIN")
    local ok, err = Initialize()
    if ok then YAB.initialized = true
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(YAB.Text("FOREVER.START_FAILED", tostring(err)))
    end
end)
