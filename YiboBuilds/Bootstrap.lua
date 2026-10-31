local ADDON_NAME = ...
local Addon = _G.YiboBuilds or {}
_G.YiboBuilds = Addon

Addon.NAME = ADDON_NAME or "YiboBuilds"
Addon.VERSION = "1.5.3"
Addon.REQUIRED_CORE_API = 13
Addon.PAGE_ID = "builds"
Addon.ICON = "Interface\\AddOns\\YiboBuilds\\Media\\YiboBuildsIcon"

-- A bilingual bootstrap error is needed when the language service is unavailable.
Addon.STARTUP_REQUIREMENTS = "YiboBuilds: 请升级 YiboCore 至 1.12.5 / API13 并启用所需能力。 / Upgrade YiboCore to 1.12.5 / API13 with the required capabilities."
Addon.REQUIRED_CAPABILITIES = {
    ["localization"] = 1, ["character-name-format"] = 1, ["character-identity"] = 1,
    ["account-view"] = 2, ["account-entry"] = 2,
    ["character-cleanup"] = 2, ["business-providers"] = 1,
    ["business-item-actions"] = 1, ["characters"] = 1,
}
function Addon:HasCompatibleCore()
    if type(WOW_PROJECT_CAMELOT)=="number" and WOW_PROJECT_ID==WOW_PROJECT_CAMELOT then return false end
    local core = _G.YiboCore
    if not (core and core.CheckAPIVersion and core:CheckAPIVersion(self.REQUIRED_CORE_API)
        and core.HasCapability and core.Locale and core.IsInitialized and core:IsInitialized()) then return false end
    for name, version in pairs(self.REQUIRED_CAPABILITIES) do
        if not core:HasCapability(name, version) then return false end
    end
    return core.Characters and type(core.Characters.FormatName) == "function"
        and core.AccountView and core.Entry and core.Contracts and core.CharacterCleanup
        and core.BusinessItemActions and core.Defaults
end
if type(WOW_PROJECT_CAMELOT)=="number" and WOW_PROJECT_ID==WOW_PROJECT_CAMELOT then return end
function Addon:T(key, ...)
    return _G.YiboCore.Locale:Get(self.NAME, key, ...)
end

local function Defaults(target, values)
    for key, value in pairs(values) do
        if type(value) == "table" then
            target[key] = type(target[key]) == "table" and target[key] or {}
            Defaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function Addon:Now()
    return (GetServerTime and GetServerTime()) or time()
end

function Addon:EnsureDB()
    YiboBuildsDB = YiboBuildsDB or {}
    local db = YiboBuildsDB
    db.schemaVersion = math.max(1, tonumber(db.schemaVersion) or 0)
    Defaults(db, {
        schemaVersion = 1,
        characters = {},
        settings = {
            previewColumns = {
                spec = true, talent1 = true, talent2 = true, talent3 = true,
                talent4 = true, talent5 = true, talent6 = true,
                major1 = true, major2 = true, major3 = true,
                minor1 = true, minor2 = true, minor3 = true,
                equipment = true,
                equipment_head = true, equipment_neck = true, equipment_shoulder = true,
                equipment_chest = true, equipment_waist = true, equipment_legs = true,
                equipment_feet = true, equipment_back = true, equipment_wrist = true,
                equipment_hands = true, equipment_finger1 = true, equipment_finger2 = true,
                equipment_trinket1 = true, equipment_trinket2 = true,
                equipment_mainhand = true, equipment_offhand = true,
                equipment_shirt = false, equipment_tabard = false,
            },
            appearanceMode = "transmog",
            previewMatrixMode = "equipment",
            previewSpecMode = "current",
            previewEquipmentMode = "current",
        },
    })
    self.db = db
    return db
end

function Addon:GetSettings()
    return self:EnsureDB().settings
end

function Addon:Print(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] YiboBuilds:|r " .. tostring(message))
    end
end

function Addon:NotifyChanged()
    if self.GoalTargets and self.GoalTargets.ref then
        local db = self:EnsureDB(); db.goalRevision = (db.goalRevision or 0) + 1
        self.Core.Contracts:NotifyChanged(self.NAME, self.GoalTargets.ref, { reason = "equipment-changed" })
    end
    if self.Core and self.Core.AccountView then
        self.Core.AccountView:NotifyPageChanged(self.PAGE_ID)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("GLYPH_UPDATED")
frame:RegisterEvent("GLYPH_ADDED")
frame:RegisterEvent("GLYPH_REMOVED")
frame:RegisterEvent("USE_GLYPH")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("SOCKET_INFO_SUCCESS")
frame:RegisterEvent("SOCKET_INFO_FAILURE")
frame:RegisterEvent("SOCKET_INFO_CLOSE")
frame:RegisterEvent("PLAYER_LOGOUT")
pcall(frame.RegisterEvent, frame, "GET_ITEM_INFO_RECEIVED")
frame:SetScript("OnEvent", function(_, event, name, success)
    if event == "ADDON_LOADED" then
        if name == ADDON_NAME then Addon:EnsureDB() end
        return
    end
    if event ~= "PLAYER_LOGIN" and not (Addon.CoreIntegration and Addon.CoreIntegration.initialized) then return end
    if event == "PLAYER_LOGIN" then
        if Addon.CoreIntegration then
            local ok, err = Addon.CoreIntegration:Initialize()
            if not ok then Addon:Print(err); return end
        end
        if Addon.Snapshot then Addon.Snapshot:ScheduleCapture("login", 0.3) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if Addon.Snapshot then Addon.Snapshot:ScheduleCapture("login", 0.5) end
        if C_Timer and C_Timer.After then
            C_Timer.After(2, function()
                local current = Addon.Core and Addon.Core.Characters and Addon.Core.Characters:GetCurrent()
                local record = current and Addon.Snapshot and Addon.Snapshot:GetCharacter(current.id)
                local slot = record and record.slots and record.slots[record.lastActiveSlot or "primary"]
                if slot and slot.glyphs and not slot.glyphs.ready then Addon.Snapshot:Capture("glyphs-ready") end
                if Addon.Snapshot then Addon.Snapshot:ScheduleCapture("login-settled", 0, { equipment = true }) end
            end)
        end
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if Addon.Snapshot then Addon.Snapshot:HandleSpecChanged() end
    elseif event == "PLAYER_TALENT_UPDATE" or event == "GLYPH_UPDATED" or event == "GLYPH_ADDED" or event == "GLYPH_REMOVED" or event == "USE_GLYPH" or event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_LIST_UPDATE" then
        -- USE_GLYPH refreshes the catalog when a glyph is learned without
        -- changing a socket. SPELLS_CHANGED covers the spellbook update path.
        if Addon.Snapshot then
            Addon.Snapshot:ScheduleCapture("glyph-catalog-update", 0.35, { glyphs = true, talents = event == "PLAYER_TALENT_UPDATE" })
        end
        if (event == "SPELLS_CHANGED" or event == "SKILL_LINES_CHANGED" or event == "TRADE_SKILL_LIST_UPDATE")
            and Addon.AccountPage then
            Addon.AccountPage:InvalidateRecipeCache()
            Addon.AccountPage:RefreshOpenDetail()
        end
    elseif event == "SOCKET_INFO_FAILURE" or event == "SOCKET_INFO_CLOSE" then
        if Addon.AccountPage then Addon.AccountPage:OnSocketEvent(event) end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "SOCKET_INFO_SUCCESS"
        or (event == "UNIT_INVENTORY_CHANGED" and name == "player") then
        if event == "SOCKET_INFO_SUCCESS" and Addon.AccountPage then
            Addon.AccountPage:OnSocketEvent(event)
        end
        -- Capture immediately after the inventory event, then once more after
        -- the client has settled item links, socket data and model updates.
        if Addon.Snapshot then
            Addon.Snapshot:ScheduleEquipmentCapture()
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Bag candidates are live state, not part of a saved equipment snapshot.
        if Addon.AccountPage and Addon.AccountPage.RefreshOpenDetail then
            Addon.AccountPage:RefreshOpenDetail()
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if Addon.AccountPage then Addon.AccountPage:OnItemInfoReceived(name, success) end
    elseif event == "PLAYER_LOGOUT" then
        if Addon.Snapshot then Addon.Snapshot:Capture("logout", true) end
    end
end)
