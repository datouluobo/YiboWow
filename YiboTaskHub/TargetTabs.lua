local Addon = _G.YiboTaskHub
local Page = Addon.AccountPage
local CreateOverview, RefreshOverview, OverviewMetrics = Page.Create, Page.Refresh, Page.GetSurfaceMetrics
function Page.Create(frame)
    frame.overview = CreateFrame("Frame", nil, frame)
    frame.overview:SetPoint("TOPLEFT", 0, -38); frame.overview:SetPoint("BOTTOMRIGHT")
    CreateOverview(frame.overview)
    frame.targets = CreateFrame("Frame", nil, frame)
    frame.targets:SetPoint("TOPLEFT", 0, -76); frame.targets:SetPoint("BOTTOMRIGHT")
    Addon.TargetsPage.Create(frame.targets)
    frame.goals = CreateFrame("Frame", nil, frame)
    frame.goals:SetPoint("TOPLEFT", 0, -38); frame.goals:SetPoint("BOTTOMRIGHT")
    Addon.GoalEditor.Create(frame.goals)
    frame.back = Addon.Core.UITheme:CreateButton(frame, 180, Addon:T("TEXT.BACK_TO_GOAL_MANAGEMENT.D16267"))
    frame.back:SetPoint("TOPLEFT", 8, -40)
    frame.back:SetScript("OnClick", function() Page.activeTab = "goals"; Addon.Core.AccountView:NotifyPageChanged(Addon.PAGE_ID) end)
    frame.tabs = Addon.Core.UITheme:CreateBusinessTabs(frame, { { id = "overview", title = Addon:T("TEXT.OVERVIEW.5F32FF") }, { id = "goals", title = Addon:T("TEXT.GOAL_MANAGEMENT.D90E7E") } }, function(id)
        Page.activeTab = id; Page.Refresh(frame, frame.context); Addon.Core.AccountView:NotifyPageChanged(Addon.PAGE_ID)
    end)
end
function Page.Refresh(frame, context)
    if not frame.overview then return RefreshOverview(frame, context) end
    frame.context = context
    local preview, targets = context.preview, Page.activeTab == "targets" and not context.preview
    frame.tabs:SetShown(not preview); frame.tabs:SetActive(targets and "goals" or (Page.activeTab or "overview"))
    frame.back:SetShown(targets)
    local goals = Page.activeTab == "goals" and not preview
    frame.goals:SetShown(goals)
    frame.overview:SetShown(not targets and not goals); frame.targets:SetShown(targets)
    frame.overview:ClearAllPoints(); frame.overview:SetPoint("TOPLEFT", 0, preview and 0 or -38); frame.overview:SetPoint("BOTTOMRIGHT")
    if goals then Addon.GoalEditor.Refresh(frame.goals, context) elseif targets then Addon.TargetsPage.Refresh(frame.targets, context) else RefreshOverview(frame.overview, context) end
end
function Page.GetSurfaceMetrics(context)
    if not context.preview and (Page.activeTab == "targets" or Page.activeTab == "goals") then
        local height = Page.activeTab == "targets" and 418 or math.max(380, Addon.GoalEditor.requiredHeight or 0)
        return { minContentWidth = 860, naturalContentWidth = 1040, minContentHeight = height, naturalContentHeight = math.max(530, height), horizontalOverflow = "none", verticalOverflow = "none" }
    end
    local result = OverviewMetrics(context)
    if not context.preview then result.minContentHeight, result.naturalContentHeight = result.minContentHeight + 38, result.naturalContentHeight + 38 end
    return result
end
