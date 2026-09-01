local Addon = _G.YiboTodo
local Integration = {}
Addon.CoreIntegration = Integration
local ICON = "Interface\\AddOns\\YiboTodo\\Media\\YiboTodoIcon-v6"

function Integration:Initialize()
    if self.initialized then return true end
    local Core = _G.YiboCore
    if not (Core and Core:CheckAPIVersion(5) and Core.AccountView and Core.Entry and Core.Characters) then return nil, "需要 YiboCore API v5。" end
    Addon.Core = Core
    local function MoveCharacterData(oldID, newID)
        if Addon.Database:MoveCharacterData(oldID, newID) then Addon:NotifyChanged() end
    end
    -- This listener covers promotions that happen after this addon has
    -- initialized.  The reconciliation below covers the login-time promotion,
    -- which may have completed before YiboTodo receives PLAYER_LOGIN.
    if not self.characterIDListenerRegistered then
        Core.Events:Register("CHARACTER_ID_CHANGED", self, function(_, oldID, newID) MoveCharacterData(oldID, newID) end)
        self.characterIDListenerRegistered = true
    end
    local current = Core.Characters:GetCurrent()
    if current then
        local legacyID = "legacy:" .. tostring(current.realm or "Unknown") .. ":" .. tostring(current.name or "Unknown")
        MoveCharacterData(legacyID, current.id)
    end
    if not self.domainListenerRegistered then
        Core.Events:Register("DATA_DOMAIN_UPDATED", self, function(_, payload)
            if payload.domainID == "professions" then Addon:NotifyChanged() end
        end)
        self.domainListenerRegistered = true
    end
    local addon, err = Core:RegisterAddon(Addon.NAME, { version = Addon.VERSION, requiredAPI = 5 })
    if not addon then return nil, err end
    if Core.CharacterCleanup then
        local ok, cleanupErr = Core.CharacterCleanup:RegisterOwner(Addon.NAME, {
            Inspect = function(character) local has = Addon.db.byCharacter[character.id] ~= nil; return { hasData = has, label = "账号待办角色快照", detail = has and "已有专业冷却观察" or "无角色缓存" } end,
            Delete = function(character) Addon.Database:DeleteCharacter(character.id); Addon:NotifyChanged(); return true end,
        })
        if not ok then return nil, cleanupErr end
    end
    local page, pageErr = Core.AccountView:RegisterPage(Addon.NAME, {
        id = "todo", title = "账号待办", icon = ICON, order = 35, defaultEnabled = true, previewEnabled = true, compactWidth = true, scope = { mode = "realms", allTitle = "所有服务器" },
        fields = {
            { id = "professionCooldown", title = "专业 CD", defaultVisible = true },
            { id = "farmOperation", title = "农场", defaultVisible = true },
            { id = "nomi", title = "诺米", defaultVisible = true },
            { id = "cooking", title = "烹饪", defaultVisible = true },
            { id = "commonProjects", title = "通用项目", defaultVisible = true },
        },
        characterFilter = {
            defaultExpression = "",
            GetExpression = function() return Addon.db.settings.levelExpr or "" end,
            SetExpression = function(expression)
                local valid, normalized, badToken = Core.LevelFilter:Validate(expression)
                if not valid then return false, "无效等级规则：" .. tostring(badToken) end
                Addon.db.settings.levelExpr = normalized; Addon:NotifyChanged(); return true
            end,
        },
        HasCharacterSnapshot = function(character) return Addon.Snapshot:GetCharacter(character.id) ~= nil end,
        GetEligibleCharacters = function(characters) local result = {}; for _, c in ipairs(characters or {}) do if Addon.Snapshot:GetCharacter(c.id) then result[#result + 1] = c end end; return result end,
        GetPreviewFields = function() return Addon.db.settings.previewColumns end,
        SetPreviewFieldVisible = function(id, visible) Addon.db.settings.previewColumns[id] = not not visible; Addon:NotifyChanged() end,
        settings = { title = "账号待办", description = "页面、入口和字段由 Core 管理；冷却目录与观察数据由账号待办保存。", CreateSettingsPanel = function(parent, context) return Addon.Settings:CreatePanel(parent, context) end },
        Create = Addon.AccountPage.Create, Refresh = Addon.AccountPage.Refresh,
        GetSurfaceMetrics = Addon.AccountPage.GetSurfaceMetrics,
        GetHoverMetrics = Addon.AccountPage.GetHoverMetrics,
        GetMeasuredHeight = Addon.AccountPage.GetMeasuredHeight,
        GetSummary = function(characters) return string.format("%d 名角色有待办快照", #(characters or {})) end,
        GetActions = function(characters) local actions = {}; for _, c in ipairs(characters or {}) do local s = Addon.Snapshot:GetCharacter(c.id).summary; if s.todo > 0 then actions[#actions + 1] = { priority = 2, title = c.name, text = table.concat(s.items, "、") } end end; return actions end,
    })
    if not page then return nil, pageErr end
    local entry, entryErr = Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "ytd", brokerName = "YiboTodo", pageID = "todo", text = "[Yibo] 账号待办", icon = ICON })
    if not entry then return nil, entryErr end
    self.initialized = true; return true
end

function Addon:OpenAccountPage() if self.Core and self.Core.AccountView then self.Core.AccountView:Toggle("todo") end end
