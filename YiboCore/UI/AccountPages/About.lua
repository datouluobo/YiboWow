-- Internal account pages are loaded after AccountView.lua.  They own page-specific
-- presentation while AccountView remains the shared shell and public API.
local Core = _G.YiboCore
local AccountView = Core.AccountView
local Theme = Core.UITheme
local COLORS = Theme.Colors
local Helpers = AccountView._internal
local AddText = Helpers.AddText
local CreateChromeButton = Helpers.CreateChromeButton
local PageEnabled = Helpers.PageEnabled

local aboutAltoBossTitle = GetLocale and GetLocale() == "zhCN" and "首领追踪" or "Boss Tracker"
local aboutAltoBossDescription = GetLocale and GetLocale() == "zhCN"
    and "跨角色追踪世界首领、节日首领与自定义目标；副本 CD 监控即将加入。"
    or "Tracks world bosses, holiday bosses, and custom targets across characters; instance lockout tracking is planned."

local ABOUT_ADDONS = {
    {
        name = "YiboAltoBoss",
        title = aboutAltoBossTitle,
        version = "2.1",
        description = aboutAltoBossDescription,
        icon = "Interface\\AddOns\\YiboCore\\Media\\YAB_MinimapIcon",
        url = "https://www.curseforge.com/wow/addons/yiboaltoboss",
    },
    {
        name = "YiboCurrency",
        version = "0.1",
        description = "汇总多角色货币余额，统一查看常规货币与物品代币。",
        icon = "Interface\\AddOns\\YiboCurrency\\Media\\YiboCurrencyIcon-v1",
    },
    {
        name = "YiboLegendary",
        version = "1.0",
        description = "追踪多角色传说任务与橙色传说装备进度。",
        icon = "Interface\\AddOns\\YiboLegendary\\Media\\YiboLegendaryIcon-v1.tga",
        url = "https://www.curseforge.com/wow/addons/yibolegendary",
    },
    {
        name = "YiboQuestBlocker",
        version = "2.1",
        description = "识别任务限制与风险，避免误接关键任务。",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YQB_MinimapIcon",
        url = "https://www.curseforge.com/wow/addons/yiboquestblocker",
    },
    {
        name = "YiboTodo",
        version = "0.1",
        description = "汇总多角色待办与专业冷却，明确下一项可做事务。",
        icon = "Interface\\AddOns\\YiboTodo\\Media\\YiboTodoIcon-v6",
        url = "https://www.curseforge.com/wow/addons/yibotodo",
    },
    {
        name = "YiboReputation",
        version = "1.0",
        description = "汇总多角色声望，掌握阵营关系与晋升进度。",
        icon = "Interface\\AddOns\\YiboReputation\\Media\\YiboReputationIcon-v1",
        url = "https://www.curseforge.com/wow/addons/yiboreputation",
    },
    {
        name = "YiboAutoOpen",
        version = "1.0",
        description = "安全地自动开启账号目录中的容器物品。",
        icon = "Interface\\AddOns\\YiboAutoOpen\\Media\\YiboAutoOpenIcon-v2",
        relation = "optional-core",
        url = "https://www.curseforge.com/wow/addons/yiboautoopen",
    },
    {
        name = "YiboBeastPaths",
        version = "1.6",
        description = "在地图上显示稀有猎人宠物的巡逻路线。",
        icon = "Interface\\AddOns\\YiboCore\\Media\\YBP_AddonIcon",
        url = "https://www.curseforge.com/wow/addons/yibobeastpaths",
        relation = "optional-core",
    },
}

-- Compatibility fallback for an incomplete local checkout only.  Normal
-- releases replace this legacy presentation list with the shared catalog so
-- the UI never owns plugin versions.
ABOUT_ADDONS = Core.AddonCatalog or ABOUT_ADDONS

local function SetAboutLinkOpen(parent, target)
    for _, row in ipairs(parent.addonRows) do
        if row.linkButton then
            local open = row == target and not row.linkOpen
            row.linkOpen = open
            row.linkBox:SetShown(open)
            row.copyHint:SetShown(open)
            row.linkButton:SetText(open and "收起链接" or "获取链接")
            row:SetHeight(open and 130 or 96)
            if open then
                row.linkBox:SetText(row.addon.url)
                row.linkBox:SetFocus()
                row.linkBox:HighlightText()
            else
                row.linkBox:ClearFocus()
            end
        end
    end

    parent:LayoutAboutContent()
end

local CORE_PROJECT_URL = "https://www.curseforge.com/wow/addons/yibocore"

local function FormatVersion(version)
    if version == nil then return "" end
    local normalized = tostring(version):gsub("^[vV]+", "")
    return normalized ~= "" and "v" .. normalized or ""
end

local function SetAboutCoreLinkOpen(parent)
    local hero = parent.hero
    hero.linkOpen = not hero.linkOpen
    hero:SetHeight(hero.linkOpen and 146 or 112)
    hero.linkBox:SetShown(hero.linkOpen)
    hero.copyHint:SetShown(hero.linkOpen)
    hero.linkButton:SetText(hero.linkOpen and "收起链接" or "获取链接")
    if hero.linkOpen then
        hero.linkBox:SetText(CORE_PROJECT_URL)
        hero.linkBox:SetFocus()
        hero.linkBox:HighlightText()
    else
        hero.linkBox:ClearFocus()
    end
    parent:LayoutAboutContent()
end

local function CreateAboutAddonRow(parent, addon)
    addon.url = addon.projectURL or addon.url
    local row = CreateFrame("Frame", nil, parent.content or parent, "BackdropTemplate")
    row:SetHeight(96)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 0.72)
    row:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.58)
    row.addon = addon

    row.iconFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconFrame:SetSize(72, 72); row.iconFrame:SetPoint("TOPLEFT", 12, -12)
    row.iconFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row.iconFrame:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
    row.iconFrame:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.72)
    row.icon = row.iconFrame:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 3, -3); row.icon:SetPoint("BOTTOMRIGHT", -3, 3); row.icon:SetTexture(addon.icon)

    row.name = AddText(row, "GameFontNormal", Theme.Font.body, COLORS.text)
    row.name:SetPoint("TOPLEFT", row.iconFrame, "TOPRIGHT", 12, -2); row.name:SetText(addon.title or addon.name)
    row.version = AddText(row, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted)
    row.version:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    row.version:SetText(FormatVersion(addon.version))
    row.description = AddText(row, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
    row.description:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -8); row.description:SetPoint("RIGHT", addon.url and -154 or -12, 0); row.description:SetText(addon.description)
    row.relation = addon.relation or (addon.independent and "independent" or "core-child")
    row.isIndependent = row.relation == "independent"
    row.isOptionalCore = row.relation == "optional-core"
    if row.isIndependent or row.isOptionalCore then
        row.badge = AddText(row, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted)
        row.badge:SetJustifyH("RIGHT")
        row.badge:SetPoint("RIGHT", -142, 0)
        row.badge:SetText(row.isOptionalCore and "可选接入" or "独立作品")
    end

    if addon.url then
        row.linkButton = CreateChromeButton(row, 112, 26, "获取链接")
        row.linkButton:SetPoint("TOPRIGHT", -12, -22)
        row.linkBox = CreateFrame("EditBox", nil, row, "BackdropTemplate")
        row.linkBox:SetHeight(24); row.linkBox:SetPoint("BOTTOMLEFT", 96, 9); row.linkBox:SetPoint("BOTTOMRIGHT", -128, 9)
        row.linkBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        row.linkBox:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
        row.linkBox:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.82)
        -- EditBox:SetFont requires the flags argument on the client used by
        -- this UI.  FontStrings accept two arguments, EditBoxes do not.
        row.linkBox:SetFont(STANDARD_TEXT_FONT, Theme.Font.assist, "")
        row.linkBox:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
        row.linkBox:SetTextInsets(7, 7, 0, 0); row.linkBox:SetAutoFocus(false); row.linkBox:SetMaxLetters(240)
        row.linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        row.linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        row.linkBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        row.linkBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput and self:GetText() ~= addon.url then
                self:SetText(addon.url); self:HighlightText()
            end
        end)
        row.copyHint = AddText(row, "GameFontNormalSmall", Theme.Font.meta, COLORS.accent)
        row.copyHint:SetJustifyH("RIGHT")
        row.copyHint:SetPoint("LEFT", row.linkBox, "RIGHT", 8, 0); row.copyHint:SetPoint("RIGHT", -12, 0); row.copyHint:SetText("按 Ctrl+C 复制")
        row.linkBox:Hide(); row.copyHint:Hide()
        row.linkButton:SetScript("OnClick", function() SetAboutLinkOpen(parent, row) end)
    end
    parent.addonRows[#parent.addonRows + 1] = row
    parent.addonRowsByName[addon.name] = row
    return row
end

local function CreateAbout(parent)
    parent.addonRows = {}
    parent.addonRowsByName = {}
    -- The about page is a growing directory. Keep its footer and page chrome
    -- fixed, while only the directory content participates in scrolling.
    parent.scroll = Theme:CreateScrollFrame(parent)
    parent.scroll:SetPoint("TOPLEFT", 20, -18); parent.scroll:SetPoint("BOTTOMRIGHT", -Theme.Space.xs, 34)
    parent.content = CreateFrame("Frame", nil, parent.scroll)
    parent.content:SetPoint("TOPLEFT")
    parent.scroll:SetScrollChild(parent.content)
    local function GetContentWidth(scroll)
        return math.max(1, scroll:GetWidth() or 1)
    end
    parent.scroll:SetScript("OnSizeChanged", function(scroll)
        parent.content:SetWidth(GetContentWidth(scroll))
        scroll:RefreshScrollbar()
    end)

    parent.hero = CreateFrame("Frame", nil, parent.content, "BackdropTemplate")
    parent.hero:SetPoint("TOPLEFT", 0, 0); parent.hero:SetPoint("TOPRIGHT", 0, 0); parent.hero:SetHeight(112)
    parent.hero:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.hero:SetBackdropColor(COLORS.panel[1], COLORS.panel[2], COLORS.panel[3], 0.70)
    parent.hero:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.72)
    parent.hero.iconFrame = CreateFrame("Frame", nil, parent.hero, "BackdropTemplate")
    parent.hero.iconFrame:SetSize(72, 72); parent.hero.iconFrame:SetPoint("LEFT", 16, 0)
    parent.hero.iconFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.hero.iconFrame:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
    parent.hero.iconFrame:SetBackdropBorderColor(COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.72)
    parent.hero.icon = parent.hero.iconFrame:CreateTexture(nil, "ARTWORK")
    parent.hero.icon:SetPoint("TOPLEFT", 3, -3); parent.hero.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    parent.hero.icon:SetTexture("Interface\\AddOns\\YiboCore\\Media\\YiboCoreLogo-v7")
    parent.hero.title = AddText(parent.hero, "GameFontNormalLarge", Theme.Font.title, COLORS.text)
    parent.hero.title:SetPoint("TOPLEFT", 110, -20); parent.hero.title:SetText("YiboCore")
    parent.hero.description = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.assist, COLORS.text)
    parent.hero.description:SetPoint("TOPLEFT", parent.hero.title, "BOTTOMLEFT", 0, -9); parent.hero.description:SetText("统一管理 Yibo 系列的账号角色、入口与业务页面")
    parent.hero.status = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
    parent.hero.status:SetJustifyH("RIGHT")
    parent.hero.status:SetPoint("TOPRIGHT", -18, -22)
    parent.hero.metadata = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted)
    parent.hero.metadata:SetJustifyH("RIGHT")
    parent.hero.metadata:SetPoint("TOPRIGHT", parent.hero.status, "BOTTOMRIGHT", 0, -7)
    parent.hero.linkButton = CreateChromeButton(parent.hero, 112, 26, "获取链接")
    parent.hero.linkButton:SetPoint("TOPRIGHT", -18, -74)
    parent.hero.linkBox = CreateFrame("EditBox", nil, parent.hero, "BackdropTemplate")
    parent.hero.linkBox:SetHeight(24); parent.hero.linkBox:SetPoint("BOTTOMLEFT", 110, 10); parent.hero.linkBox:SetPoint("BOTTOMRIGHT", -128, 10)
    parent.hero.linkBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    parent.hero.linkBox:SetBackdropColor(COLORS.bg[1], COLORS.bg[2], COLORS.bg[3], 1)
    parent.hero.linkBox:SetBackdropBorderColor(COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.82)
    parent.hero.linkBox:SetFont(STANDARD_TEXT_FONT, Theme.Font.assist, "")
    parent.hero.linkBox:SetTextColor(COLORS.text[1], COLORS.text[2], COLORS.text[3])
    parent.hero.linkBox:SetTextInsets(7, 7, 0, 0); parent.hero.linkBox:SetAutoFocus(false); parent.hero.linkBox:SetMaxLetters(240)
    parent.hero.linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    parent.hero.linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    parent.hero.linkBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    parent.hero.linkBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and self:GetText() ~= CORE_PROJECT_URL then
            self:SetText(CORE_PROJECT_URL); self:HighlightText()
        end
    end)
    parent.hero.copyHint = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.meta, COLORS.accent)
    parent.hero.copyHint:SetJustifyH("RIGHT")
    parent.hero.copyHint:SetPoint("LEFT", parent.hero.linkBox, "RIGHT", 8, 0); parent.hero.copyHint:SetPoint("RIGHT", -18, 0); parent.hero.copyHint:SetText("按 Ctrl+C 复制")
    parent.hero.linkBox:Hide(); parent.hero.copyHint:Hide()
    parent.hero.linkButton:SetScript("OnClick", function() SetAboutCoreLinkOpen(parent) end)

    parent.childHeading = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    parent.childHeading:SetText("强依赖子插件")
    parent.optionalHeading = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    parent.optionalHeading:SetText("可选接入插件")
    parent.optionalLine = parent.content:CreateTexture(nil, "ARTWORK")
    parent.optionalLine:SetHeight(1)
    parent.optionalLine:SetColorTexture(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], COLORS.lineSoft[4])
    parent.otherHeading = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    parent.otherHeading:SetText("探索其它 Yibo 插件")
    parent.otherLine = parent.content:CreateTexture(nil, "ARTWORK")
    parent.otherLine:SetHeight(1)
    parent.otherLine:SetColorTexture(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], COLORS.lineSoft[4])
    for _, addon in ipairs(ABOUT_ADDONS) do CreateAboutAddonRow(parent, addon) end
    parent.footer = AddText(parent, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted, "RIGHT")
    parent.footer:SetPoint("BOTTOMRIGHT", -20, 12); parent.footer:SetText("作者 YiboSoft · CurseForge")
    parent.LayoutAboutContent = function(container)
        local y = (container.hero:GetHeight() or 112) + 28
        container.childHeading:ClearAllPoints(); container.childHeading:SetPoint("TOPLEFT", 0, -y)
        y = y + 26
        for _, row in ipairs(container.addonRows) do
            if not row.isIndependent and not row.isOptionalCore then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
                y = y + row:GetHeight() + 6
            end
        end
        y = y + 14
        container.optionalHeading:ClearAllPoints(); container.optionalHeading:SetPoint("TOPLEFT", 0, -y)
        y = y + 22
        container.optionalLine:ClearAllPoints(); container.optionalLine:SetPoint("TOPLEFT", 0, -y); container.optionalLine:SetPoint("TOPRIGHT", 0, -y)
        y = y + 12
        for _, row in ipairs(container.addonRows) do
            if row.isOptionalCore then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
                y = y + row:GetHeight() + 6
            end
        end
        y = y + 14
        container.otherHeading:ClearAllPoints(); container.otherHeading:SetPoint("TOPLEFT", 0, -y)
        y = y + 22
        container.otherLine:ClearAllPoints(); container.otherLine:SetPoint("TOPLEFT", 0, -y); container.otherLine:SetPoint("TOPRIGHT", 0, -y)
        y = y + 12
        for _, row in ipairs(container.addonRows) do
            if row.isIndependent then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
                y = y + row:GetHeight() + 6
            end
        end
        local contentHeight = y + 4
        container.content:SetHeight(math.max(contentHeight, container.scroll:GetHeight() or 1))
        container.scroll:SetContentHeight(contentHeight)
        container.scroll:RefreshScrollbar()
    end
    parent.content:SetWidth(GetContentWidth(parent.scroll))
    parent:LayoutAboutContent()
end

local function RefreshAbout(parent)
    local coreVersion = FormatVersion(Core:GetVersion())
    parent.hero.title:SetText("YiboCore " .. (coreVersion ~= "" and coreVersion or "v?"))
    local connected = 0
    local stateLabels = {
        connected = "已连接",
        ["enabled-not-connected"] = "已启用尚未连接",
        ["installed-disabled"] = "已安装但未启用",
        missing = "未安装",
    }
    for _, addon in ipairs(ABOUT_ADDONS) do
        local status = Core.AddonStatus and Core.AddonStatus:Get(addon.name) or {}
        local row = parent.addonRowsByName[addon.name]
        if row then
            local installedVersion = FormatVersion(status.installedVersion)
            local packagedVersion = FormatVersion(status.packagedVersion)
            local installed = installedVersion ~= "" and ("本机 " .. installedVersion) or "本机未安装"
            local packaged = packagedVersion ~= "" and (" · 打包时 " .. packagedVersion) or ""
            row.version:SetText(installed .. packaged)
            row.description:SetText((stateLabels[status.state] or "状态未知") .. " · " .. tostring(addon.description or ""))
        end
        if row and not row.isIndependent and status.connected then
            connected = connected + 1
        end
    end
    parent.hero.status:SetText("已连接 " .. connected .. " 个接入插件")
    parent.hero.metadata:SetText("Public API v" .. tostring(Core.API_VERSION or "?") .. " · 数据库 Schema v" .. tostring(Core.Migrations and Core.Migrations.CURRENT_SCHEMA or "?"))
end

AccountView._pages.about = {
    id = "about", title = "关于", order = 990, internal = true,
    Create = CreateAbout, Refresh = RefreshAbout,
    GetSurfaceMetrics = Helpers.GetAboutSurfaceMetrics,
}
