if _G.YAB and _G.YAB.CoreReady == false then return end
local YAB = _G.YAB

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
}
function YAB.CreateLockoutsPage(parent) return YAB.CreateProgressPage(parent, view) end
function YAB.RefreshLockoutsPage(instance, context) return YAB.RefreshProgressPage(instance, context, view) end
function YAB.GetLockoutsSurfaceMetrics(context) return YAB.GetProgressSurfaceMetrics(context, view) end
function YAB.GetLockoutsMeasuredHeight(instance, context) return YAB.GetProgressMeasuredHeight(instance, context, view) end
function YAB.GetLockoutsHoverMetrics(context) return YAB.GetProgressHoverMetrics(context, view) end

function YAB.GetLockoutsSummary(characters)
    local count, limit = YAB.GetThrottleStatus()
    return string.format(_G.YiboCore.Locale:Get("YiboAltoBoss", "UI.NORMAL_DUNGEONS_D_D"), count, limit)
end

function YAB.GetLockoutsActions() return {} end
