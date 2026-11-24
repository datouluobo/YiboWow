if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB
local Core = _G.YiboCore
local Theme = Core.UITheme
local function Text(key) return Core.Locale:Get("YiboAltoBoss", key) end

function YAB.SetAccountBusinessPage(pageID)
    YiboAltoBossDB = YiboAltoBossDB or {}
    YiboAltoBossDB.settings = YiboAltoBossDB.settings or {}
    YiboAltoBossDB.settings.accountPage = pageID == "alto-lockouts" and "lockouts" or "boss"
end

function YAB.GetAccountBusinessPageID()
    local selected = YiboAltoBossDB and YiboAltoBossDB.settings and YiboAltoBossDB.settings.accountPage
    return selected == "lockouts" and "alto-lockouts" or "alto-boss"
end

YAB.BusinessTabs = {
    { id = "boss", title = "Boss", page = "alto-boss", width = 112 },
    { id = "lockouts", title = _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.INSTANCES"), page = "alto-lockouts", width = 126 },
}

local view = {
    id = "alto-lockouts", tab = "lockouts", goalActions = true,
    title = function() return _G.YiboCore.Locale:Get("YiboAltoBoss", "UI.INSTANCES") end,
    columns = function(context) return YAB.GetLockoutColumns(context) end,
    status = function(key, column) return YAB.GetLockoutStatus(key, column) end,
    tooltip = function(key, column) return YAB.GetLockoutTooltip(key, column) end,
    compactEmpty = function() return Text("LOCKOUT.COMPACT_EMPTY") end,
}

function YAB.CreateLockoutsPage(parent)
    YAB.CreateProgressPage(parent, view)
    local filters = CreateFrame("Frame", nil, parent)
    parent.lockoutFilters = filters
    filters:SetPoint("TOPLEFT", 8, -YAB.GetBusinessTabHeight() - Theme.Space.xxs)
    filters:SetPoint("TOPRIGHT", -8, -YAB.GetBusinessTabHeight() - Theme.Space.xxs)
    filters:SetHeight(Theme.Size.standard)
    filters.expansion = Theme:CreateDropdown(filters)
    filters.expansion:SetPoint("LEFT")
    filters.kind = Theme:CreateDropdown(filters)
    filters.kind:SetPoint("LEFT", filters.expansion, "RIGHT", Theme.Space.xs, 0)
    filters.expansion:SetOnValueChanged(function(value)
        filters.expansionID = value
        Core.AccountView:RefreshPage()
    end)
    filters.kind:SetOnValueChanged(function(value)
        filters.kindID = value
        Core.AccountView:RefreshPage()
    end)
    parent:HookScript("OnHide", function()
        filters.expansion.menu:Hide()
        filters.kind.menu:Hide()
    end)
    return parent
end

function YAB.RefreshLockoutsPage(instance, context)
    local filters = instance.lockoutFilters
    filters:SetShown(not context.preview)
    if context.preview then
        filters.expansion.menu:Hide()
        filters.kind.menu:Hide()
        return YAB.RefreshProgressPage(instance, context, view)
    end

    local allColumns = view.columns(context)
    local expansionOptions, expansions = {}, {}
    local expansionWidth = 0
    for _, column in ipairs(allColumns) do
        local id = column.tierOrder or 999
        if not expansions[id] then
            local label = column.expansion or Text("UI.OTHER")
            expansions[id] = true
            expansionOptions[#expansionOptions + 1] = { value = id, label = label }
            expansionWidth = math.max(expansionWidth, Theme:MeasureText(Theme.Font.body, label))
        end
    end
    table.sort(expansionOptions, function(a, b) return a.value < b.value end)
    if not expansions[filters.expansionID] then filters.expansionID = expansionOptions[1] and expansionOptions[1].value end

    local types = {
        { value = "raid", label = Text("LOCKOUT.COMPACT_RAIDS") },
        { value = "dungeon", label = Text("LOCKOUT.COMPACT_DUNGEONS") },
    }
    local width = context.surfaceAvailableWidth - Theme.Space.xs * 3
    local kindWidth = math.max(Theme:MeasureText(Theme.Font.body, types[1].label), Theme:MeasureText(Theme.Font.body, types[2].label),
        Theme:MeasureText(Theme.Font.body, Text("UI.OTHER"))) + Theme.Space.md * 2
    local kind, selected = filters.kindID or "raid", {}
    local hasOther = false
    for _, column in ipairs(allColumns) do
        if (column.tierOrder or 999) == filters.expansionID then
            local columnKind = column.isRaid == nil and "other" or column.isRaid and "raid" or "dungeon"
            if columnKind == "other" then hasOther = true end
            if columnKind == kind then selected[#selected + 1] = column end
        end
    end
    if hasOther or kind == "other" then types[#types + 1] = { value = "other", label = Text("UI.OTHER") } end
    filters.expansion:SetWidth(math.max(1, math.min(expansionWidth + Theme.Space.md * 2, width - kindWidth)))
    filters.kind:SetWidth(kindWidth)
    filters.expansion:SetOptions(expansionOptions)
    filters.expansion:SetValue(filters.expansionID)
    filters.kind:SetOptions(types)
    filters.kind:SetValue(kind)

    return YAB.RefreshProgressPage(instance, context, view, {
        columns = selected,
        pageKey = tostring(filters.expansionID) .. ":" .. kind,
        title = function(column)
            if column.plannedCatalogID then return column.abbreviation or column.name end
            return (Core.Locale:GetLanguage() == "zh" and column.shortName or column.abbreviation) or column.name
        end,
        label = function(status, label)
            if status == "open" then return Text("LOCKOUT.COMPACT_OPEN") end
            if status == "unknown" then return Text("LOCKOUT.COMPACT_UNKNOWN") end
            return label
        end,
    })
end
function YAB.GetLockoutsSurfaceMetrics(context) return YAB.GetProgressSurfaceMetrics(context, view) end
function YAB.GetLockoutsMeasuredHeight(instance, context) return YAB.GetProgressMeasuredHeight(instance, context, view) end
function YAB.GetLockoutsHoverMetrics(context) return YAB.GetProgressHoverMetrics(context, view) end

function YAB.GetLockoutsSummary(characters)
    local count, limit = YAB.GetThrottleStatus()
    return string.format(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NORMAL_DUNGEONS_D_D"), count, limit)
end

function YAB.GetLockoutsActions() return {} end
