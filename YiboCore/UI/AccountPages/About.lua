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


-- The shared catalog is already filtered to the active client target.
local ABOUT_ADDONS = Core.AddonCatalog or {}

local function SetAboutLinkOpen(parent, target)
    for _, row in ipairs(parent.addonRows) do
        if row.linkButton then
            local open = row == target and not row.linkOpen
            row.linkOpen = open
            row.linkBox:SetShown(open)
            row.copyHint:SetShown(open)
            row.linkButton:SetText(open and Core:Text("CORE.HIDE_LINK") or Core:Text("CORE.GET_LINK"))
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
    hero.linkButton:SetText(hero.linkOpen and Core:Text("CORE.HIDE_LINK") or Core:Text("CORE.GET_LINK"))
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
    row.description:SetWordWrap(true)
    row.relation = addon.relation or (addon.independent and "independent" or "core-child")
    row.isIndependent = row.relation == "independent"
    row.isOptionalCore = row.relation == "optional-core"
    if row.isIndependent or row.isOptionalCore then
        row.badge = AddText(row, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted)
        row.badge:SetJustifyH("RIGHT")
        row.badge:SetPoint("RIGHT", -142, 0)
        row.badge:SetText(row.isOptionalCore and Core:Text("CORE.OPTIONAL_INTEGRATION") or Core:Text("CORE.STANDALONE_ADDON"))
    end

    if addon.url then
        row.linkButton = CreateChromeButton(row, 112, 26, Core:Text("CORE.GET_LINK"))
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
        row.copyHint:SetPoint("LEFT", row.linkBox, "RIGHT", 8, 0); row.copyHint:SetPoint("RIGHT", -12, 0); row.copyHint:SetText(Core:Text("CORE.PRESS_CTRL_C_TO_COPY"))
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
        if parent.LayoutAboutContent then parent:LayoutAboutContent() end
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
    parent.hero.icon:SetTexture("Interface\\AddOns\\YiboCore\\Media\\YiboCoreLogo")
    parent.hero.title = AddText(parent.hero, "GameFontNormalLarge", Theme.Font.title, COLORS.text)
    parent.hero.title:SetPoint("TOPLEFT", 110, -20); parent.hero.title:SetText("YiboCore")
    parent.hero.description = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.assist, COLORS.text)
    parent.hero.description:SetPoint("TOPLEFT", parent.hero.title, "BOTTOMLEFT", 0, -9); parent.hero.description:SetText(Core:Text("CORE.MANAGE_YIBO_ACCOUNT_CHARACTERS_ENTRIES_AND_BUSINESS"))
    parent.hero.description:SetPoint("RIGHT", -154, 0); parent.hero.description:SetWordWrap(true)
    parent.hero.status = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.assist, COLORS.muted)
    parent.hero.status:SetJustifyH("RIGHT")
    parent.hero.status:SetPoint("TOPRIGHT", -18, -22)
    parent.hero.metadata = AddText(parent.hero, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted)
    parent.hero.metadata:SetJustifyH("RIGHT")
    parent.hero.metadata:SetPoint("TOPRIGHT", parent.hero.status, "BOTTOMRIGHT", 0, -7)
    parent.hero.metadata:ClearAllPoints()
    parent.hero.metadata:SetPoint("TOPLEFT", parent.hero.description, "BOTTOMLEFT", 0, -8)
    parent.hero.metadata:SetPoint("RIGHT", -154, 0)
    parent.hero.metadata:SetJustifyH("LEFT")
    parent.hero.linkButton = CreateChromeButton(parent.hero, 112, 26, Core:Text("CORE.GET_LINK"))
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
    parent.hero.copyHint:SetPoint("LEFT", parent.hero.linkBox, "RIGHT", 8, 0); parent.hero.copyHint:SetPoint("RIGHT", -18, 0); parent.hero.copyHint:SetText(Core:Text("CORE.PRESS_CTRL_C_TO_COPY"))
    parent.hero.linkBox:Hide(); parent.hero.copyHint:Hide()
    parent.hero.linkButton:SetScript("OnClick", function() SetAboutCoreLinkOpen(parent) end)

    parent.childHeading = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    parent.childHeading:SetText(Core:Text("CORE.CORE_DEPENDENT_ADDONS"))
    parent.optionalHeading = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    parent.optionalHeading:SetText(Core:Text("CORE.OPTIONAL_INTEGRATIONS"))
    parent.optionalLine = parent.content:CreateTexture(nil, "ARTWORK")
    parent.optionalLine:SetHeight(1)
    parent.optionalLine:SetColorTexture(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], COLORS.lineSoft[4])
    parent.otherHeading = AddText(parent.content, "GameFontNormal", Theme.Font.section, COLORS.accent)
    parent.otherHeading:SetText(Core:Text("CORE.EXPLORE_OTHER_YIBO_ADDONS"))
    parent.otherLine = parent.content:CreateTexture(nil, "ARTWORK")
    parent.otherLine:SetHeight(1)
    parent.otherLine:SetColorTexture(COLORS.lineSoft[1], COLORS.lineSoft[2], COLORS.lineSoft[3], COLORS.lineSoft[4])
    for _, addon in ipairs(ABOUT_ADDONS) do CreateAboutAddonRow(parent, addon) end
    parent.footer = AddText(parent, "GameFontNormalSmall", Theme.Font.meta, COLORS.muted, "RIGHT")
    parent.footer:SetPoint("BOTTOMRIGHT", -20, 12); parent.footer:SetText(Core:Text("CORE.AUTHOR_YIBOSOFT_CURSEFORGE"))
    parent.LayoutAboutContent = function(container)
        for _, row in ipairs(container.addonRows) do
            row:SetHeight(math.max(96, row.description:GetStringHeight() + 50) + (row.linkBox and row.linkBox:IsShown() and 34 or 0))
        end
        container.hero:SetHeight(math.max(112, container.hero.description:GetStringHeight() + 82) + (container.hero.linkOpen and 34 or 0))
        local y = (container.hero:GetHeight() or 112) + 28
        local groups = {
            { heading = container.childHeading, Matches = function(row) return not row.isIndependent and not row.isOptionalCore end },
            { heading = container.optionalHeading, line = container.optionalLine, Matches = function(row) return row.isOptionalCore end },
            { heading = container.otherHeading, line = container.otherLine, Matches = function(row) return row.isIndependent end },
        }
        for _, group in ipairs(groups) do
            local rows = {}
            for _, row in ipairs(container.addonRows) do
                if group.Matches(row) then rows[#rows + 1] = row end
            end
            group.heading:SetShown(#rows > 0)
            if group.line then group.line:SetShown(#rows > 0) end
            if #rows > 0 then
                group.heading:ClearAllPoints(); group.heading:SetPoint("TOPLEFT", 0, -y)
                y = y + 26
                if group.line then
                    group.line:ClearAllPoints(); group.line:SetPoint("TOPLEFT", 0, -y); group.line:SetPoint("TOPRIGHT", 0, -y)
                    y = y + 12
                end
                for _, row in ipairs(rows) do
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetPoint("TOPRIGHT", 0, -y)
                    y = y + row:GetHeight() + 6
                end
                y = y + 14
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
        connected = Core:Text("CORE.ADDON_REGISTERED"),
        ["enabled-not-connected"] = Core:Text("CORE.ENABLED_NOT_CONNECTED"),
        ["installed-disabled"] = Core:Text("CORE.INSTALLED_DISABLED"),
        missing = Core:Text("CORE.NOT_INSTALLED"),
        unavailable = Core:Text("CORE.ADDON_STATUS_UNAVAILABLE"),
    }
    for _, addon in ipairs(ABOUT_ADDONS) do
        local status = Core.AddonStatus and Core.AddonStatus:Get(addon.name) or {}
        local row = parent.addonRowsByName[addon.name]
        if row then
            local installedVersion = FormatVersion(status.installedVersion)
            local packagedVersion = FormatVersion(status.packagedVersion)
            local installed
            if status.availability and status.availability ~= "known" then
                installed = Core:Text("CORE.ADDON_STATUS_UNAVAILABLE")
            elseif installedVersion ~= "" then
                installed = Core:Text("CORE.ADDON_INSTALLED_VERSION", installedVersion)
            elseif status.installed then
                installed = Core:Text("CORE.ADDON_VERSION_UNAVAILABLE")
            else
                installed = Core:Text("CORE.NOT_INSTALLED_LOCALLY")
            end
            local packaged = packagedVersion ~= "" and Core:Text("CORE.ADDON_PACKAGED_VERSION", packagedVersion) or nil
            row.version:SetText(installed .. (packaged and (" · " .. packaged) or ""))
            row.description:SetText((stateLabels[status.state] or Core:Text("CORE.UNKNOWN_STATUS")) .. " · " .. tostring(addon.description or ""))
        end
        if row and not row.isIndependent and status.connected then
            connected = connected + 1
        end
    end
    parent.hero.status:SetText(Core:Text("CORE.CONNECTED_302") .. connected .. Core:Text("CORE.ADDONS"))
    parent.hero.metadata:SetText("Public API v" .. tostring(Core.API_VERSION or "?") .. Core:Text("CORE.DATABASE_SCHEMA_V") .. tostring(Core.Migrations and Core.Migrations.CURRENT_SCHEMA or "?"))
    parent:LayoutAboutContent()
end

AccountView._pages.about = Core.Locale:Bind(function() return {
    id = "about", title = Core:Text("CORE.ABOUT"), order = 990, internal = true,
    Create = CreateAbout, Refresh = RefreshAbout,
    GetSurfaceMetrics = Helpers.GetAboutSurfaceMetrics,
} end)
