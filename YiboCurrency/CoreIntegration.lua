local Addon, Core = _G.YiboCurrency, _G.YiboCore
local Integration = {}; Addon.CoreIntegration = Integration
local PAGE_ID = "currency"
local ICON = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon-v1"

function Integration:Initialize()
    if self.initialized then return true end
    if not (Core and Core.CheckAPIVersion and Core.AccountView and Core.Entry and Core.CurrencyCatalog) then return nil, "YiboCore 货币 API 不可用。" end
    if not Core:CheckAPIVersion(5) then return nil, "需要 YiboCore API v5。" end
    local addon, err = Core:RegisterAddon(Addon.NAME, { version = Addon.VERSION, requiredAPI = 5 })
    if not addon then return nil, err end
    Addon:EnsureDB(); Addon:RegisterCatalogWithCore()
    local page, pageError = Core.AccountView:RegisterPage(Addon.NAME, {
        id = PAGE_ID, title = "货币总览", icon = ICON, order = 50, previewEnabled = true, defaultEnabled = true, scope = { mode = "realms", allTitle = "所有服务器" },
        fields = { { id = "value", title = "余额", defaultVisible = true } },
        characterFilter = {
            defaultExpression = "",
            GetExpression = function() return Addon:GetSettings().levelExpr or "" end,
            SetExpression = function(expression)
                local valid, normalized, badToken = Core.LevelFilter:Validate(expression)
                if not valid then return false, "无效等级规则：" .. tostring(badToken) end
                Addon:GetSettings().levelExpr = normalized; Addon:NotifyChanged(); return true
            end,
        },
        HasCharacterSnapshot = function(character) return Core.DataDomains:Get(character.id, "economy") ~= nil or Core.DataDomains:Get(character.id, "economy-items") ~= nil end,
        GetEligibleCharacters = function(characters) local result = {}; for _, character in ipairs(characters or {}) do if Core.DataDomains:Get(character.id, "economy") or Core.DataDomains:Get(character.id, "economy-items") then result[#result + 1] = character end end; return result end,
        settings = { title = "货币总览", description = "货币显示、悬停监控和自定义物品代币由本插件保存；页面、入口、字段和排序由 Core 管理。", CreateSettingsPanel = function(parent, context) return Addon:CreateSettingsPanel(parent, context) end },
        Create = function(parent) Addon:CreateCurrencyPage(parent) end, Refresh = function(parent, context) Addon:RefreshCurrencyPage(parent, context) end,
        GetSurfaceMetrics = function(context) return Addon:GetCurrencySurfaceMetrics(context) end,
        GetHoverMetrics = function(context)
            local metrics = Addon:GetCurrencySurfaceMetrics(context)
            local shell = Core.UITheme.Geometry.shellBorder * 2
            return {
                minWidth = metrics.minContentWidth + shell,
                preferredWidth = metrics.naturalContentWidth + shell,
                -- Header, its gap and at least one readable row must always
                -- be inside the hover shell, even with no monitored entries.
                minHeight = metrics.minContentHeight + Core.UITheme.Geometry.titleBar + shell,
                preferredHeight = metrics.naturalContentHeight + Core.UITheme.Geometry.titleBar + shell,
                horizontalOverflow = "content", verticalOverflow = "content",
            }
        end,
        GetSummary = function(characters) local monitored = 0; for _, entry in ipairs(Addon:GetCatalog()) do if Addon:IsMonitored(entry) then monitored = monitored + 1 end end; return string.format("%d 名角色 · %d 项悬停监控", #characters, monitored) end,
    })
    if not page then return nil, pageError end
    local entry, entryError = Core.Entry:RegisterBusinessEntry(Addon.NAME, { id = "ycu", brokerName = "YiboCurrency", pageID = PAGE_ID, text = "[Yibo] 货币总览", icon = ICON, defaultMode = "none" })
    if not entry then return nil, entryError end
    Core.Events:Register("DATA_DOMAIN_UPDATED", Addon, function(_, payload) if payload.domainID == "economy" or payload.domainID == "economy-items" then Addon:NotifyChanged() end end)
    self.initialized = true; return true
end
function Addon:NotifyChanged() if Core.AccountView then Core.AccountView:NotifyPageChanged(PAGE_ID) end end
function Addon:OpenAccountPage() if Core.AccountView then Core.AccountView:Toggle(PAGE_ID) end end
