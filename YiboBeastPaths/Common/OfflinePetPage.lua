local _, ns = ...
if not ns.YBP_TARGET_OK then return end
local Snapshot = ns.OfflinePetSnapshot
local Page = {}
ns.OfflinePetPage = Page

-- The context supplied by Core already contains its hidden/realm/level filters.
-- Never add characters back or return references to the business database.
function Page.Eligible(root, target, characters)
    if not Snapshot.CheckStore(root, target) then return {} end
    local records = root.offlinePets and root.offlinePets.characters or {}
    local eligible = {}
    for _, character in ipairs(characters or {}) do
        local record = records[character.id]
        if character.class == "HUNTER" and type(record) == "table"
            and (Snapshot.IsCompleteGroup(record.stable) or Snapshot.IsObservation(record.observation)) then
            eligible[#eligible + 1] = character
        end
    end
    return eligible
end

function Page.Project(root, target, characters, formatName)
    local out = {}
    for _, character in ipairs(Page.Eligible(root, target, characters)) do
        local record = root.offlinePets.characters[character.id]
        local observed = Snapshot.IsObservation(record.observation) and record.observation or nil
        local function group(name)
            if Snapshot.IsCompleteGroup(record[name]) then return Snapshot.Copy(record[name]) end
            if observed and #observed[name] > 0 then
                return { items = Snapshot.Copy(observed[name]), capturedAt = observed.capturedAt, completeness = "unverified" }
            end
        end
        out[#out + 1] = { id = character.id, name = formatName(character),
            active = group("active"), stable = group("stable"),
            lastAttempt = Snapshot.Copy(record.lastAttempt) }
    end
    return out
end

-- Registration state belongs to one owner/session. The runtime caller supplies
-- the already registered YBP owner and a renderer; no second settings owner.
function Page.New(core, root, target, renderer, text, invalidateCapture)
    local self = { active = false, cleanupRegistered = false, pageRegistered = false, entryRegistered = false }
    local owner, pageID = "YiboBeastPaths", "yibo-beastpaths-offline-pets"
    local unified = type(ns.CreateMaintenancePage) == "function" and type(ns.RefreshMaintenancePage) == "function"
    self.selectedTab = "stable"
    function self:SelectTab(tab)
        self.selectedTab = tab == "maintenance" and "maintenance" or "stable"
        if self.active then core.AccountView:NotifyPageChanged(pageID) end
    end
    local function admitted(character)
        return #Page.Eligible(root, target, { character }) == 1
    end
    local function previewEnabled()
        local settings = root.settings
        local columns = type(settings) == "table" and settings.previewColumns
        return type(columns) ~= "table" or columns.pets ~= false
    end
    function self:Start()
        local ready, reason = ns.CheckOfflinePetCore(core)
        if not ready then return false, reason end
        local valid, invalidReason = Snapshot.CheckStore(root, target)
        if not valid and invalidReason ~= "invalid-store" then return false, invalidReason end
        if not self.cleanupRegistered then
            local registered, err = core.CharacterCleanup:RegisterOwner(owner, {
                Inspect = function(character)
                    local store = root.offlinePets
                    local current = type(store) == "table" and type(store.characters) == "table"
                        and store.characters[character.id]
                    return { hasData = current ~= nil, label = text("OFFLINE_TITLE") }
                end,
                Delete = function(character, _, context)
                    if invalidateCapture then invalidateCapture() end
                    return Snapshot.Delete(root, target, character.id, context)
                end,
            })
            if not registered then return false, err end
            self.cleanupRegistered = true
        end
        if not self.pageRegistered then
            local page, err = core.AccountView:RegisterPage(owner, {
                id = pageID, title = text(unified and "TITLE" or "OFFLINE_TITLE"), defaultEnabled = true,
                settings = unified and { CreateSettingsPanel = ns.CreateMaintenanceSettingsPanel } or nil,
                previewEnabled = true, scope = { mode = "realms" },
                HasCharacterSnapshot = admitted,
                GetEligibleCharacters = function(characters) return Page.Eligible(root, target, characters) end,
                fields = { { id = "pets", title = text("OFFLINE_TITLE"),
                    defaultVisible = true, defaultPreviewVisible = true } },
                GetPreviewFields = function() return { pets = previewEnabled() } end,
                SetPreviewFieldVisible = function(id, visible)
                    if id ~= "pets" or (root.settings ~= nil and type(root.settings) ~= "table") then return false end
                    if not root.settings then root.settings = {} end
                    if root.settings.previewColumns ~= nil and type(root.settings.previewColumns) ~= "table" then return false end
                    root.settings.previewColumns = root.settings.previewColumns or {}
                    root.settings.previewColumns.pets = visible == true
                    core.AccountView:NotifyPageChanged(pageID)
                    return true
                end,
                Create = function(parent, context)
                    if not unified or context.preview then return renderer.Create(parent, context) end
                    parent.businessTabs = core.UITheme:CreateBusinessTabs(parent, {
                        { id = "stable", title = text("OFFLINE_TITLE") },
                        { id = "maintenance", title = text("OFFLINE_MAINTENANCE_TAB") },
                    }, function(id) self:SelectTab(id) end)
                    parent.stableView = CreateFrame("Frame", nil, parent)
                    parent.stableView:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -38)
                    parent.stableView:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
                    renderer.Create(parent.stableView, context)
                    parent.maintenanceView = CreateFrame("Frame", nil, parent)
                    parent.maintenanceView:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -38)
                    parent.maintenanceView:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
                    ns.CreateMaintenancePage(parent.maintenanceView)
                end,
                Refresh = function(parent, context)
                    if unified and not context.preview then
                        parent.businessTabs:SetActive(self.selectedTab)
                        if self.selectedTab == "maintenance" then
                            parent.stableView:Hide()
                            parent.maintenanceView:Show()
                            ns.RefreshMaintenancePage(parent.maintenanceView, context)
                            return
                        end
                        parent.maintenanceView:Hide()
                        parent.stableView:Show()
                        parent = parent.stableView
                    end
                    local rows = Page.Project(root, target, context.characters or {}, function(character)
                        return core.Characters:FormatName(character)
                    end)
                    local visible = not context.preview or previewEnabled()
                    if type(context.fields) == "table" then
                        visible = false
                        for _, field in ipairs(context.fields) do
                            if field.id == "pets" then visible = true; break end
                        end
                    end
                    local _, storeReason = Snapshot.CheckStore(root, target)
                    renderer.Refresh(parent, context, rows, visible, storeReason == "invalid-store")
                end,
                GetSurfaceMetrics = function(context)
                    if unified and not context.preview and self.selectedTab == "maintenance" then
                        local budget = context.surfaceAvailableHeight or 720
                        return { minContentWidth = 620, naturalContentWidth = 760,
                            minContentHeight = math.min(460, budget), naturalContentHeight = math.min(720, budget) }
                    end
                    return renderer.GetSurfaceMetrics(context)
                end,
            })
            if not page then return false, err end
            self.pageRegistered = true
        end
        if not self.entryRegistered then
            local entry, err = core.Entry:RegisterBusinessEntry(owner, {
                id = "ybp-offline-pets", pageID = pageID, text = text("OFFLINE_TITLE"),
                defaultChannels = { minimap = false, broker = false, builtinBar = false },
            })
            if not entry then
                core.AccountView:UnregisterPage(pageID)
                self.pageRegistered = false
                return false, err
            end
            self.entryRegistered = true
        end
        self.active = true
        return true
    end
    return self
end
