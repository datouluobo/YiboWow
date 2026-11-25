if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB
local Core = _G.YiboCore
local Theme = Core.UITheme
local function Text(key) return Core.Locale:Get("YiboAltoBoss", key) end
local PANDARIA_TIER = 1

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
        if filters.expansionID == PANDARIA_TIER then filters.pandariaKind = value else filters.kindID = value end
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
            local label = id == PANDARIA_TIER and Text("LOCKOUT.MISTS_EXPANSION") or column.expansion or Text("UI.OTHER")
            expansions[id] = true
            expansionOptions[#expansionOptions + 1] = { value = id, label = label }
            expansionWidth = math.max(expansionWidth, Theme:MeasureText(Theme.Font.body, label))
        end
    end
    if not expansions[PANDARIA_TIER] then
        local label = Text("LOCKOUT.MISTS_EXPANSION")
        expansionOptions[#expansionOptions + 1] = { value = PANDARIA_TIER, label = label }
        expansions[PANDARIA_TIER] = true
        expansionWidth = math.max(expansionWidth, Theme:MeasureText(Theme.Font.body, label))
    end
    table.sort(expansionOptions, function(a, b) return a.value < b.value end)
    if not expansions[filters.expansionID] then filters.expansionID = expansionOptions[1].value end

    local pandaria = filters.expansionID == PANDARIA_TIER
    local types = { { value = "raid", label = Text("LOCKOUT.COMPACT_RAIDS") } }
    if pandaria then
        types[#types + 1] = { value = 1, label = Text("LOCKOUT.MISTS_NORMAL") }
        types[#types + 1] = { value = 2, label = Text("LOCKOUT.MISTS_HEROIC") }
        types[#types + 1] = { value = 237, label = Text("LOCKOUT.MISTS_CELESTIAL") }
    else
        types[#types + 1] = { value = "dungeon", label = Text("LOCKOUT.COMPACT_DUNGEONS") }
    end
    local gap = Theme.Space.xs
    local width = context.surfaceAvailableWidth - gap * 3
    local kind = filters.kindID or "raid"
    if pandaria then kind = filters.pandariaKind or "raid" end
    local pandariaDungeon = pandaria and type(kind) == "number"
    local selected = {}
    local hasOther = false
    for _, column in ipairs(allColumns) do
        if (column.tierOrder or 999) == filters.expansionID then
            local columnKind = column.isRaid == nil and "other" or column.isRaid and "raid" or "dungeon"
            if columnKind == "other" then hasOther = true end
            if columnKind == kind then selected[#selected + 1] = column end
        end
    end
    if hasOther or kind == "other" then types[#types + 1] = { value = "other", label = Text("UI.OTHER") } end
    if pandariaDungeon then selected = YAB.GetPandariaDungeonColumns(kind, allColumns) end
    local kindWidth = 0
    for _, option in ipairs(types) do kindWidth = math.max(kindWidth, Theme:MeasureText(Theme.Font.body, option.label)) end
    kindWidth = kindWidth + Theme.Space.md * 2
    expansionWidth = expansionWidth + Theme.Space.md * 2
    local tabsWidth = gap
    for _, tab in ipairs(YAB.BusinessTabs) do tabsWidth = tabsWidth + tab.width + 2 end
    local inline = tabsWidth + expansionWidth + gap + kindWidth + gap * 2 <= context.surfaceAvailableWidth
    local extraRow = not inline and #expansionOptions > 0
    local top = inline and -(YAB.GetBusinessTabHeight() - Theme.Size.standard) / 2
        or -YAB.GetBusinessTabHeight() - Theme.Space.xxs
    filters:SetShown(#expansionOptions > 0)
    filters:ClearAllPoints()
    filters:SetPoint("TOPLEFT", instance, "TOPLEFT", inline and tabsWidth + gap or gap, top)
    filters:SetPoint("TOPRIGHT", -gap, top)
    filters.expansion:SetWidth(math.max(1, math.min(expansionWidth, width - kindWidth)))
    filters.kind:SetWidth(kindWidth)
    filters.expansion:SetOptions(expansionOptions)
    filters.expansion:SetValue(filters.expansionID)
    filters.kind:SetOptions(types)
    filters.kind:SetValue(kind)

    return YAB.RefreshProgressPage(instance, context, view, {
        columns = selected,
        filterRowHeight = extraRow and Theme.Size.standard + gap or 0,
        pageKey = tostring(filters.expansionID) .. ":" .. kind,
        title = function(column)
            if column.plannedCatalogID and not pandariaDungeon then return column.abbreviation or column.name end
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
