local Addon = _G.YiboCrafting
local Core = _G.YiboCore

function Addon:Initialize()
    if self.initialized then return true end
    if not (Core and Core.CheckAPIVersion and Core.Characters and Core.DataDomains) then
        return nil, "YiboCore 不可用。"
    end
    local compatible = Core:CheckAPIVersion(6)
    if not compatible then return nil, "需要 YiboCore API v6。" end
    local db, errorMessage = self.Store:Initialize()
    if not db then return nil, errorMessage end
    local registered, registerError = Core:RegisterAddon(self.NAME, { version = self.VERSION, requiredAPI = 6 })
    if not registered then return nil, registerError end
    if Core.CharacterCleanup then
        local cleanup, cleanupError = Core.CharacterCleanup:RegisterOwner(self.NAME, {
            Inspect = function(character)
                local record = db.characters[character.id]
                return {
                    hasData = record ~= nil,
                    label = "专业制造配方缓存",
                    detail = record and "包含已确认的配方记录" or "无配方缓存",
                }
            end,
            Delete = function(character)
                db.characters[character.id] = nil
                return true
            end,
        })
        if not cleanup then return nil, cleanupError end
    end
    if Core.Events then
        Core.Events:Register("CHARACTER_ID_CHANGED", self, function(_, oldID, newID)
            self.Store:MoveCharacterID(oldID, newID)
        end)
    end
    local page, pageError = self.AccountPage:Register()
    if not page then return nil, pageError end
    self.initialized = true
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_UPDATE")
frame:RegisterEvent("NEW_RECIPE_LEARNED")
-- Some client builds expose this event while others do not.  The stage-0
-- probe treats it as optional, so registration must not prevent addon startup.
pcall(frame.RegisterEvent, frame, "TRADE_SKILL_LIST_UPDATE")

local scanSequence = 0
local function ScheduleRecipeScan(reason, delay)
    scanSequence = scanSequence + 1
    local scheduledSequence = scanSequence
    local function Run()
        if scheduledSequence ~= scanSequence or not Addon.initialized then return end
        Addon.Collector:Scan(reason)
    end
    if C_Timer and C_Timer.After then C_Timer.After(delay, Run) else Run() end
end

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then Addon:Initialize(); return end
    if not Addon.initialized then return end
    -- TRADE_SKILL_SHOW fires before the legacy recipe list is populated.  Wait
    -- for the window/list events to settle, coalescing the burst into one scan.
    ScheduleRecipeScan(event, event == "TRADE_SKILL_SHOW" and 0.5 or 0.2)
end)
