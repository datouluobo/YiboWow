local ADDON_NAME = ...
local Addon = _G.YiboBuilds or {}
_G.YiboBuilds = Addon

Addon.NAME = ADDON_NAME or "YiboBuilds"
Addon.VERSION = "1.1.0"
Addon.REQUIRED_CORE_API = 5
Addon.PAGE_ID = "builds"
Addon.ICON = "Interface\\AddOns\\YiboBuilds\\Media\\YiboBuildsIcon-v1"

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
        DEFAULT_CHAT_FRAME:AddMessage("|cff20e070[Yibo] 构筑:|r " .. tostring(message))
    end
end

function Addon:NotifyChanged()
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
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON_NAME then Addon:EnsureDB() end
        return
    end
    if event == "PLAYER_LOGIN" then
        if Addon.CoreIntegration then
            local ok, err = Addon.CoreIntegration:Initialize()
            if not ok then Addon:Print("Core 接入失败：" .. tostring(err)) end
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
            end)
        end
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        if Addon.Snapshot then Addon.Snapshot:HandleSpecChanged() end
    elseif event == "PLAYER_TALENT_UPDATE" or event == "GLYPH_UPDATED" or event == "GLYPH_ADDED" or event == "GLYPH_REMOVED" or event == "USE_GLYPH" or event == "SPELLS_CHANGED" then
        -- USE_GLYPH refreshes the catalog when a glyph is learned without
        -- changing a socket. SPELLS_CHANGED covers the spellbook update path.
        if Addon.Snapshot then Addon.Snapshot:ScheduleCapture("glyph-catalog-update", 0.35) end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Keep a single latest observation rather than an equipment history.
        -- The short debounce absorbs multi-slot swaps and preserves the final
        -- state even when the player later logs out on another character.
        if Addon.Snapshot then
            Addon.Snapshot:MarkEquipmentDirty()
            Addon.Snapshot:ScheduleCapture("equipment-change", 0.4)
        end
    elseif event == "PLAYER_LOGOUT" then
        if Addon.Snapshot then Addon.Snapshot:Capture("logout", true) end
    end
end)
