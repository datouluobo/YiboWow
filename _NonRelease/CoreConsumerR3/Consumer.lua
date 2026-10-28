-- Synthetic consumer only. No native pet API, SavedVariables or production addon code.
local REQUIRED = {
    { "runtime", 1 }, { "events", 1 }, { "characters", 1 },
    { "character-identity", 1 }, { "character-name-format", 1 },
    { "character-cleanup", 2 }, { "account-view", 2 },
    { "account-character-admission", 1 }, { "account-surface-budget", 2 },
    { "account-entry", 2 }, { "builtin-entry-bar", 3 }, { "localization", 1 },
}
local METHODS = {
    { "Characters", "GetCurrentID" }, { "Characters", "GetCurrent" },
    { "Characters", "Get" }, { "Characters", "GetAll" }, { "Characters", "FormatName" },
    { "CharacterCleanup", "RegisterOwner" }, { "AccountView", "RegisterPage" },
    { "AccountView", "UnregisterPage" }, { "AccountView", "BuildContext" },
    { "AccountView", "NotifyPageChanged" }, { "AccountView", "GetScrollSurfaceWidth" },
    { "Entry", "RegisterBusinessEntry" }, { "Locale", "Register" }, { "Locale", "Get" },
    { "Events", "Register" }, { "Events", "Unregister" },
}
local function Gate(core)
    if not core then return nil, "core-missing" end
    for _, name in ipairs({ "IsInitialized", "CheckAPIVersion", "HasCapability", "RegisterAddon" }) do
        if type(core[name]) ~= "function" then return nil, "core-interface-missing", name end
    end
    if not core:CheckAPIVersion(13) then return nil, "core-api-old" end
    if not core:IsInitialized() then return nil, "core-not-ready" end
    for _, requirement in ipairs(REQUIRED) do
        if not core:HasCapability(requirement[1], requirement[2]) then
            return nil, "core-capability-old", requirement[1]
        end
    end
    for _, method in ipairs(METHODS) do
        if type(core[method[1]]) ~= "table" or type(core[method[1]][method[2]]) ~= "function" then
            return nil, "core-interface-missing", method[1] .. "." .. method[2]
        end
    end
    return true
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for key, child in pairs(value) do result[key] = Copy(child) end; return result
end
return { Required = REQUIRED, Methods = METHODS, Gate = Gate, New = function(resolve)
    local self = { owner = "CoreR3Consumer", pageID = "r3-offline", entryID = "r3-offline",
        snapshots = {}, active = false, starts = 0,
        refreshes = 0, creates = 0, notifications = 0, routeCalls = 0, ownerCalls = 0 }
    local core, waiting
    function self:Route() self.routeCalls = self.routeCalls + 1; return "route-ok" end
    function self:Admitted(character)
        local snapshot = self.snapshots[character.id]
        return character.class == "HUNTER" and type(snapshot) == "table"
            and type(snapshot.stable) == "table" and type(snapshot.stable.observedAt) == "number"
    end
    function self:Project(context)
        local rows = {}
        for _, character in ipairs(context.characters) do
            rows[#rows + 1] = { id = character.id, name = core.Characters:FormatName(character, { nameMode = "short", realmMode = "full" }),
                groups = Copy(self.snapshots[character.id]) }
        end
        return rows
    end
    local function Changed()
        self.notifications = self.notifications + 1
        if self.active then core.AccountView:NotifyPageChanged(self.pageID) end
    end
    local function Ready() self:Start() end
    function self:Watch()
        local candidate = resolve()
        if candidate and candidate.Events and type(candidate.Events.Register) == "function" then
            if waiting and waiting ~= candidate then waiting.Events:Unregister("CORE_READY", self, Ready) end
            waiting = candidate
            waiting.Events:Register("CORE_READY", self, Ready)
        end
        return self:Start()
    end
    function self:Start()
        local candidate = resolve()
        local ok, code, detail = Gate(candidate)
        if not ok then return nil, code, detail end
        if self.active then return true end
        core = candidate
        core.Locale:Register(self.owner, "zh", { TITLE = "离线快照夹具", BUSINESS = "业务设置", CACHE = "数据与缓存",
            UNKNOWN = "暂不可读；保留上次快照", KNOWN = "已采集", TIME = "采集时间：%s" })
        core.Locale:Register(self.owner, "en", { TITLE = "Offline snapshot fixture", BUSINESS = "Business settings", CACHE = "Data and cache",
            UNKNOWN = "Unavailable; previous snapshot retained", KNOWN = "Observed", TIME = "Observed at: %s" })
        assert(core:RegisterAddon(self.owner, { requiredAPI = 13, version = "fixture" }))
        if not self.ownerRegistered then
            assert(core.CharacterCleanup:RegisterOwner(self.owner, {
                Inspect = function(character)
                    return { hasData = self.snapshots[character.id] ~= nil,
                        label = core.Locale:Get(self.owner, "TITLE") }
                end,
                Delete = function(character, _, context)
                    self.ownerCalls = self.ownerCalls + 1
                    self.lastDeletion = Copy(context)
                    if self.failDelete then return nil, "fixture-delete-failed" end
                    local snapshot = self.snapshots[character.id]
                    if snapshot then
                        for group, value in pairs(snapshot) do
                            if not context.replay or (value.observedAt or 0) <= context.deletedAt then snapshot[group] = nil end
                        end
                        if next(snapshot) == nil then self.snapshots[character.id] = nil end
                    end
                    return true
                end,
            }))
            self.ownerRegistered = true
        end
        self.page = assert(core.AccountView:RegisterPage(self.owner, {
            id = self.pageID, title = core.Locale:Get(self.owner, "TITLE"), scope = { mode = "realms" },
            settings = { CreateSettingsPanel = function(parent)
                parent.r3Sections = { core.Locale:Get(self.owner, "BUSINESS"), core.Locale:Get(self.owner, "CACHE") }
            end },
            previewEnabled = true,
            -- Default Core preview limit of 20; no unlimited-preview exception is needed.
            HasCharacterSnapshot = function(character) return self:Admitted(character) end,
            GetEligibleCharacters = function(characters)
                local result = {}; for _, character in ipairs(characters) do
                    if self:Admitted(character) then result[#result + 1] = character end
                end; return result
            end,
            fields = { { id = "groups", title = core.Locale:Get(self.owner, "TITLE"),
                defaultVisible = true, defaultPreviewVisible = true } },
            GetSurfaceMetrics = function(context)
                return { naturalContentWidth = 620, naturalContentHeight = 60 + #context.characters * 38,
                    minContentWidth = 320, minContentHeight = 100,
                    scrollContentHeight = #context.characters * 38, scrollFixedHeight = 60 }
            end,
            Create = function() self.creates = self.creates + 1 end,
            Refresh = function(parent, context)
                self.refreshes = self.refreshes + 1
                parent.r3Rows = self:Project(context)
                parent.r3Width = core.AccountView:GetScrollSurfaceWidth(context, parent, #parent.r3Rows * 38, 60)
            end,
        }))
        assert(core.Entry:RegisterBusinessEntry(self.owner, { id = self.entryID, pageID = self.pageID,
            text = core.Locale:Get(self.owner, "TITLE"), defaultChannels = { minimap = false, broker = false, builtinBar = false } }))
        for _, event in ipairs({ "ACCOUNT_VIEW_CHARACTERS_CHANGED", "CHARACTER_DISPLAY_UPDATED", "CHARACTER_CACHE_DELETED" }) do
            core.Events:Register(event, self, Changed)
        end
        self.starts = self.starts + 1; self.active = true
        return true
    end
    function self:Stop()
        if waiting then waiting.Events:Unregister("CORE_READY", self, Ready); waiting = nil end
        if not self.active then return end
        self.active = false
        for _, event in ipairs({ "ACCOUNT_VIEW_CHARACTERS_CHANGED", "CHARACTER_DISPLAY_UPDATED", "CHARACTER_CACHE_DELETED" }) do
            core.Events:Unregister(event, self, Changed)
        end
        core.AccountView:UnregisterPage(self.pageID)
        -- Cleanup owners are session-lived: keep the single owner registration.
    end
    function self:ReadSnapshot(id) return Copy(self.snapshots[id]) end
    return self
end }
