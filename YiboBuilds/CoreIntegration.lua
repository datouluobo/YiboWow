local Addon = _G.YiboBuilds
local Integration = {}
Addon.CoreIntegration = Integration

function Integration:Initialize()
    if self.initialized then return true end
    local Core = _G.YiboCore
    if not (Core and Core.CheckAPIVersion and Core:CheckAPIVersion(5) and Core.AccountView and Core.Entry and Core.Characters) then
        return nil, "需要 YiboCore API v5。"
    end
    Addon.Core = Core
    local registered, err = Core:RegisterAddon(Addon.NAME, { version = Addon.VERSION, requiredAPI = Addon.REQUIRED_CORE_API })
    if not registered then return nil, err end
    if Core.CharacterCleanup then
        Core.CharacterCleanup:RegisterOwner(Addon.NAME, {
            Inspect = function(character)
                local record = Addon.Snapshot:GetCharacter(character.id)
                return { hasData = record ~= nil, label = "构筑快照", detail = record and "已记录主/副天赋构筑" or "无构筑缓存" }
            end,
            Delete = function(character)
                Addon:EnsureDB().characters[character.id] = nil
                Addon:NotifyChanged()
                return true
            end,
        })
    end
    local page, pageError = Core.AccountView:RegisterPage(Addon.NAME, {
        id = Addon.PAGE_ID, title = "角色构筑", icon = Addon.ICON, order = -15,
        defaultEnabled = true, previewEnabled = true, compactWidth = true,
        scope = { mode = "realms", allTitle = "所有服务器" },
        HasCharacterSnapshot = function(character) return Addon.Snapshot:GetCharacter(character.id) ~= nil end,
        GetEligibleCharacters = function(characters)
            local result = {}
            for _, character in ipairs(characters or {}) do if Addon.Snapshot:GetCharacter(character.id) then result[#result + 1] = character end end
            return result
        end,
        settings = { title = "角色构筑", description = "Core 管理页面、入口、角色范围和悬停字段；YiboBuilds 保存构筑快照与显示偏好。" },
        fields = Addon.AccountPage:GetFields(),
        GetPreviewFieldDefinitions = function() return Addon.AccountPage:GetPreviewFieldDefinitions() end,
        GetPreviewFields = function() return Addon:GetSettings().previewColumns end,
        SetPreviewFieldVisible = function(id, visible) Addon:GetSettings().previewColumns[id] = not not visible; Addon:NotifyChanged() end,
        Create = Addon.AccountPage.Create,
        Refresh = Addon.AccountPage.Refresh,
        GetSurfaceMetrics = Addon.AccountPage.GetSurfaceMetrics,
        GetHoverMetrics = Addon.AccountPage.GetHoverMetrics,
        GetSummary = function(characters) return string.format("%d 名角色有构筑快照", #(characters or {})) end,
    })
    if not page then return nil, pageError end
    local entry, entryError = Core.Entry:RegisterBusinessEntry(Addon.NAME, {
        id = "ybb", brokerName = "YiboBuilds", pageID = Addon.PAGE_ID,
        text = "[Yibo] 角色构筑", icon = Addon.ICON, defaultMode = "none",
    })
    if not entry then return nil, entryError end
    self.initialized = true
    return true
end

function Addon:OpenAccountPage()
    if self.Core and self.Core.AccountView then self.Core.AccountView:Toggle(self.PAGE_ID) end
end
