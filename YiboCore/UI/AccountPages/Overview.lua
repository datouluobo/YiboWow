-- Internal account pages are loaded after AccountView.lua.  They own page-specific
-- presentation while AccountView remains the shared shell and public API.
local Core = _G.YiboCore
local AccountView = Core.AccountView
local Theme = Core.UITheme
local COLORS = Theme.Colors
local Helpers = AccountView._internal
local AddText = Helpers.AddText
local Copy = Helpers.Copy
local PageEnabled = Helpers.PageEnabled

local function CreateOverview(parent)
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 0, 0); parent.scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    parent.content = CreateFrame("Frame", nil, parent.scroll); parent.scroll:SetScrollChild(parent.content)
    local content = parent.content
    parent.heading = AddText(content, "GameFontNormalLarge", nil, COLORS.text); parent.heading:SetPoint("TOPLEFT", 20, -18); parent.heading:SetText("账号概览")
    parent.hint = AddText(content, "GameFontNormalSmall", nil, COLORS.muted); parent.hint:SetPoint("TOPLEFT", 20, -47); parent.hint:SetText("从左侧选择业务页，比较角色的下一步行动。")
    parent.characterSummary = AddText(content, "GameFontNormalSmall", nil, COLORS.muted); parent.characterSummary:Hide()
    parent.actionHeading = AddText(content, "GameFontNormalSmall", nil, COLORS.muted); parent.actionHeading:SetPoint("TOPLEFT", 20, -78); parent.actionHeading:SetText("下一步行动")
    parent.lines = {}
    parent.actions = {}
end

local function RefreshOverview(parent, context)
    local lines = {}
    local actions = {}
    local actionsPerPage = {}
    local pageCharacters = {}
    local function CollectPageValue(page, callbackName)
        local ok, result = xpcall(function()
            if not pageCharacters[page.id] then pageCharacters[page.id] = AccountView:BuildContext(page).characters end
            return page[callbackName](pageCharacters[page.id])
        end, function(message) return tostring(message) end)
        if not ok then
            page.lastError = result
            Core:Print("账号概览读取页面 “" .. page.title .. "”（" .. tostring(page.addonName) .. "）的 " .. callbackName .. " 失败：" .. result)
            return nil
        end
        return result
    end
    for _, page in ipairs(AccountView._pageOrder) do
        if PageEnabled(page) and type(page.GetSummary) == "function" then
            local summary = CollectPageValue(page, "GetSummary")
            if summary and summary ~= "" then lines[#lines + 1] = { title = page.title, text = summary, pageID = page.id } end
        end
        if PageEnabled(page) and type(page.GetActions) == "function" then
            for _, suppliedAction in ipairs(CollectPageValue(page, "GetActions") or {}) do
                if type(suppliedAction) == "table" and (actionsPerPage[page.id] or 0) < 3 then
                    local action = Copy(suppliedAction)
                    action.pageID = page.id
                    action.pageTitle = page.title
                    action.addonName = page.addonName
                    actions[#actions + 1] = action
                    actionsPerPage[page.id] = (actionsPerPage[page.id] or 0) + 1
                end
            end
        end
    end
    table.sort(actions, function(left, right)
        if (left.priority or 0) ~= (right.priority or 0) then return (left.priority or 0) > (right.priority or 0) end
        if tostring(left.pageTitle) ~= tostring(right.pageTitle) then return tostring(left.pageTitle) < tostring(right.pageTitle) end
        return tostring(left.title) < tostring(right.title)
    end)
    for index, line in ipairs(lines) do
        local button = parent.lines[index]
        if not button then
            button = CreateFrame("Button", nil, parent.content, "BackdropTemplate"); button:SetHeight(38); button:SetPoint("TOPLEFT", 20, -104 - ((index - 1) * 42)); button:SetPoint("TOPRIGHT", -20, -104 - ((index - 1) * 42))
            button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); button:SetBackdropColor(0.03, 0.10, 0.12, 0.85); button:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.45)
            button.title = AddText(button, "GameFontNormalSmall", nil, COLORS.accent); button.title:SetPoint("LEFT", 10, 0); button.title:SetWidth(125)
            button.text = AddText(button, "GameFontNormalSmall", nil, COLORS.text); button.text:SetPoint("LEFT", button.title, "RIGHT", 8, 0); button.text:SetPoint("RIGHT", -10, 0)
            button:SetScript("OnClick", function(self) AccountView:ShowPage(self.pageID) end); parent.lines[index] = button
        end
        button.title:SetText(line.title); button.text:SetText(line.text); button.pageID = line.pageID; button:Show()
    end
    for index = #lines + 1, #parent.lines do parent.lines[index]:Hide() end
    local actionBase = -112 - (#lines * 42)
    parent.actionHeading:ClearAllPoints(); parent.actionHeading:SetPoint("TOPLEFT", 20, actionBase)
    local actionLimit = 8
    if context and context.preview then
        -- 悬停预览没有滚动区。按当前内容区高度收紧行动条数，确保每一条
        -- 都完整落在窗口内，而不是让底部条目溢出预览框。
        local availableHeight = parent:GetHeight() or 0
        local firstActionBottom = 170 + (#lines * 42)
        if availableHeight >= firstActionBottom then
            actionLimit = math.min(8, 1 + math.floor((availableHeight - firstActionBottom) / 38))
        else
            actionLimit = 0
        end
    end
    local visibleActionCount = math.min(#actions, actionLimit)
    parent.actionHeading:SetText(#actions > 0 and ("下一步行动（显示 " .. visibleActionCount .. " / " .. #actions .. "）") or "暂无需要处理的账号行动")
    for index = 1, visibleActionCount do
        local action = actions[index]
        local button = parent.actions[index]
        if not button then
            button = CreateFrame("Button", nil, parent.content, "BackdropTemplate"); button:SetHeight(34)
            button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }); button:SetBackdropColor(0.035, 0.12, 0.12, 0.9); button:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.45)
            button.title = AddText(button, "GameFontNormalSmall", nil, COLORS.text); button.title:SetPoint("LEFT", 9, 0); button.title:SetWidth(210)
            button.text = AddText(button, "GameFontNormalSmall", nil, COLORS.muted); button.text:SetPoint("LEFT", button.title, "RIGHT", 8, 0); button.text:SetPoint("RIGHT", -9, 0)
            button:SetScript("OnClick", function(self) AccountView:ShowPage(self.pageID) end); parent.actions[index] = button
        end
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", parent.content, "TOPLEFT", 20, actionBase - 24 - ((index - 1) * 38)); button:SetPoint("TOPRIGHT", parent.content, "TOPRIGHT", -20, actionBase - 24 - ((index - 1) * 38))
        button.title:SetText((action.pageTitle or "业务") .. " · " .. (action.title or "角色")); button.text:SetText(action.text or "")
        button.pageID = action.pageID; button:Show()
    end
    for index = visibleActionCount + 1, #parent.actions do parent.actions[index]:Hide() end
    local contentHeight = 136 + #lines * 42 + visibleActionCount * 38
    parent.content:SetSize(math.max(1, parent.scroll:GetWidth() or 1), math.max(1, contentHeight))
    parent.scroll:SetContentHeight(parent.content:GetHeight())
    parent.scroll:RefreshScrollbar()
end

AccountView._pages.overview = {
    id = "overview", title = "概览", order = -20, internal = true, previewEnabled = true,
    Create = CreateOverview, Refresh = RefreshOverview,
    GetSurfaceMetrics = Helpers.GetOverviewSurfaceMetrics,
}
