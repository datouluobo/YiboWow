local Addon = _G.YiboBuilds
local Integration = {}
Addon.CoreIntegration = Integration

function Integration:Initialize()
    if self.initialized then return true end
    local Core = _G.YiboCore
    if not Addon:HasCompatibleCore() or not Addon.AccountPage then
        return nil, Addon.STARTUP_REQUIREMENTS
    end
    Addon.Core = Core
    local registered, err = Core:RegisterAddon(Addon.NAME, { version = Addon.VERSION, requiredAPI = Addon.REQUIRED_CORE_API })
    if not registered then return nil, err end
    if not self.cleanupRegistered then
        local cleanup, cleanupError = Core.CharacterCleanup:RegisterOwner(Addon.NAME, {
            Inspect = function(character)
                local record = Addon.Snapshot:GetCharacter(character.id)
                return { hasData = record ~= nil, label = Addon:T("UI.BUILD_SNAPSHOT"), detail = record and Addon:T("UI.PRIMARY_SECONDARY_BUILDS_RECORDED") or Addon:T("UI.NO_BUILD_CACHE") }
            end,
            Delete = function(character, aliases, context)
                local db = Addon:EnsureDB()
                local function Remove(id)
                    local record = db.characters[id]
                    -- Keep only data freshly observed after the deletion tombstone.
                    if context and context.replay and record then
                        local deletedAt, now = tonumber(context.deletedAt), Addon:Now()
                        local function IsNew(value)
                            local stamp = tonumber(value)
                            return deletedAt and stamp and stamp > deletedAt and stamp <= now
                        end
                        local retained = false
                        for key, slot in pairs(record.slots or {}) do
                            local fresh = IsNew(slot.updatedAt)
                            for _, field in ipairs({ "observedEquipment", "confirmedEquipment" }) do
                                local equipment = slot[field]
                                if equipment and not IsNew(equipment.capturedAt) then slot[field] = nil
                                elseif equipment then fresh = true end
                            end
                            if fresh then retained = true else record.slots[key] = nil end
                        end
                        if retained then return end
                    end
                    db.characters[id] = nil
                end
                Remove(character.id)
                for id in pairs(aliases or {}) do Remove(id) end
                Addon:NotifyChanged()
                return true
            end,
        })
        if not cleanup then return nil, cleanupError end
        self.cleanupRegistered = true
    end
    local page, pageError = Core.AccountView:RegisterPage(Addon.NAME, {
        id = Addon.PAGE_ID, title = Addon:T("UI.CHARACTER_BUILDS"), icon = Addon.ICON, order = -15,
        defaultEnabled = true, previewEnabled = true, compactWidth = true,
        firstUseTip = { title = Addon:T("UI.EQUIPMENT_MODEL"), lines = { Addon:T("UI.DRAG_THE_MODEL_TO_ROTATE_IT_SCROLL_TO_ZOOM") } },
        scope = { mode = "realms", allTitle = Addon:T("UI.ALL_REALMS") },
        HasCharacterSnapshot = function(character) return Addon.Snapshot:GetCharacter(character.id) ~= nil end,
        GetEligibleCharacters = function(characters)
            local result = {}
            for _, character in ipairs(characters or {}) do if Addon.Snapshot:GetCharacter(character.id) then result[#result + 1] = character end end
            return result
        end,
        settings = { title = Addon:T("UI.CHARACTER_BUILDS"), description = Addon:T("UI.CORE_MANAGES_PAGES_ENTRIES_CHARACTER_SCOPE_AND_PREVIEW_FIELDS_YIBOBUILDS_OW") },
        fields = Addon.AccountPage:GetFields(),
        GetPreviewFieldDefinitions = function() return Addon.AccountPage:GetPreviewFieldDefinitions() end,
        GetPreviewFields = function() return Core.Defaults:Copy(Addon:GetSettings().previewColumns) end,
        SetPreviewFieldVisible = function(id, visible)
            for _, field in ipairs(Addon.AccountPage:GetPreviewFieldDefinitions()) do
                if field.id == id then Addon:GetSettings().previewColumns[id] = not not visible; Addon:NotifyChanged(); return true end
            end
            for _, field in ipairs(Addon.AccountPage:GetFields()) do
                if field.id == id then Addon:GetSettings().previewColumns[id] = not not visible; Addon:NotifyChanged(); return true end
            end
            return false
        end,
        Create = Addon.AccountPage.Create,
        Refresh = Addon.AccountPage.Refresh,
        GetSurfaceMetrics = Addon.AccountPage.GetSurfaceMetrics,
        GetHoverMetrics = Addon.AccountPage.GetHoverMetrics,
        GetSummary = function(characters) return string.format(Addon:T("UI.D_CHARACTERS_WITH_BUILD_SNAPSHOTS"), #(characters or {})) end,
    })
    if not page then return nil, pageError end
    local entry, entryError = Core.Entry:RegisterBusinessEntry(Addon.NAME, {
        id = "ybb", brokerName = "YiboBuilds", pageID = Addon.PAGE_ID,
        text = Addon:T("UI.YIBO_CHARACTER_BUILDS"), icon = Addon.ICON, defaultMode = "none",
    })
    if not entry then return nil, entryError end
    if Addon.GoalTargets then
        local targets, targetError = Addon.GoalTargets:Initialize()
        if not targets then return nil, targetError end
    end
    self.initialized = true
    return true
end

function Addon:OpenAccountPage()
    if self.Core and self.Core.AccountView then self.Core.AccountView:Toggle(self.PAGE_ID) end
end
